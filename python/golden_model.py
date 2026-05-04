"""Generate fixed-point vectors for the lock-in resonance tracking project.

The model intentionally mirrors hardware-friendly operations:

- Q1.15 sine/cosine ROMs
- 16-bit signed input samples
- 16x16 I/Q mixing
- 8-tap integer FIR with shift normalization
- magnitude-squared energy estimate
- per-bin accumulation and peak detection
"""

from pathlib import Path
import csv
import math
import sys

from fixed_point import clamp_signed, round_shift, twos_complement_hex


ROOT = Path(__file__).resolve().parents[1]
VECTOR_DIR = ROOT / "vectors"
REPORT_DIR = ROOT / "reports"
DOCS_DIR = ROOT / "docs"


CONFIG = {
    "input_width": 16,
    "ref_width": 16,
    "rom_addr_bits": 8,
    "phase_width": 32,
    "num_bins": 8,
    "samples_per_bin": 64,
    "fir_coeffs": [1, 2, 3, 4, 4, 3, 2, 1],
    "fir_shift": 4,
    "peak_bin": 3,
    "noise_peak": 180,
    "random_seed": 7,
}


def rom_size():
    return 1 << CONFIG["rom_addr_bits"]


def signed_sine(angle):
    scale = (1 << (CONFIG["ref_width"] - 1)) - 1
    return clamp_signed(round(scale * math.sin(angle)), CONFIG["ref_width"])


def signed_cosine(angle):
    scale = (1 << (CONFIG["ref_width"] - 1)) - 1
    return clamp_signed(round(scale * math.cos(angle)), CONFIG["ref_width"])


def build_roms():
    sin_rom = []
    cos_rom = []
    for index in range(rom_size()):
        angle = 2.0 * math.pi * index / rom_size()
        sin_rom.append(signed_sine(angle))
        cos_rom.append(signed_cosine(angle))
    return sin_rom, cos_rom


def phase_step_for_bin(bin_index):
    """Use an integer number of cycles per bin so references are periodic."""
    cycles_per_bin = bin_index + 2
    return round(cycles_per_bin * (1 << CONFIG["phase_width"]) / CONFIG["samples_per_bin"])


def amplitude_profile():
    """Synthetic resonance peak centered at CONFIG['peak_bin']."""
    base = 1300
    peak = 9200
    sigma = 1.35
    profile = []
    for bin_index in range(CONFIG["num_bins"]):
        dist = bin_index - CONFIG["peak_bin"]
        amp = base + peak * math.exp(-(dist * dist) / (2.0 * sigma * sigma))
        profile.append(round(amp))
    return profile


class LcgRandom:
    """Deterministic cross-language RNG for reproducible vector files."""

    def __init__(self, seed):
        self.state = seed & 0xFFFFFFFF

    def randint(self, low, high):
        self.state = (1664525 * self.state + 1013904223) & 0xFFFFFFFF
        span = high - low + 1
        return low + (self.state % span)


def rom_lookup(rom, phase):
    addr_shift = CONFIG["phase_width"] - CONFIG["rom_addr_bits"]
    addr = (phase >> addr_shift) & (rom_size() - 1)
    return rom[addr]


def generate_input_samples(sin_rom):
    rng = LcgRandom(CONFIG["random_seed"])
    amplitudes = amplitude_profile()
    samples = []

    for bin_index, amplitude in enumerate(amplitudes):
        phase = 0
        step = phase_step_for_bin(bin_index)
        for _ in range(CONFIG["samples_per_bin"]):
            ref = rom_lookup(sin_rom, phase)
            clean = round(amplitude * ref / ((1 << (CONFIG["ref_width"] - 1)) - 1))
            noise = rng.randint(-CONFIG["noise_peak"], CONFIG["noise_peak"])
            sample = clamp_signed(clean + noise, CONFIG["input_width"])
            samples.append(
                {
                    "bin": bin_index,
                    "sample": sample,
                    "clean": clean,
                    "noise": noise,
                    "phase_step": step,
                }
            )
            phase = (phase + step) & ((1 << CONFIG["phase_width"]) - 1)

    return samples


def fir_step(history, sample):
    history.insert(0, sample)
    del history[len(CONFIG["fir_coeffs"]) :]

    acc = 0
    for coeff, value in zip(CONFIG["fir_coeffs"], history):
        acc += coeff * value
    return round_shift(acc, CONFIG["fir_shift"])


def run_lockin_model(samples, sin_rom, cos_rom):
    i_hist = [0] * len(CONFIG["fir_coeffs"])
    q_hist = [0] * len(CONFIG["fir_coeffs"])
    energies = [0] * CONFIG["num_bins"]
    trace_rows = []

    for bin_index in range(CONFIG["num_bins"]):
        phase = 0
        step = phase_step_for_bin(bin_index)

        for sample_index in range(CONFIG["samples_per_bin"]):
            stream_index = bin_index * CONFIG["samples_per_bin"] + sample_index
            sample = samples[stream_index]["sample"]
            sin_ref = rom_lookup(sin_rom, phase)
            cos_ref = rom_lookup(cos_rom, phase)

            i_mixed = sample * cos_ref
            q_mixed = sample * sin_ref

            i_filt = fir_step(i_hist, i_mixed)
            q_filt = fir_step(q_hist, q_mixed)

            mag_sq = i_filt * i_filt + q_filt * q_filt
            energies[bin_index] += mag_sq

            trace_rows.append(
                {
                    "global_sample": stream_index,
                    "bin": bin_index,
                    "bin_sample": sample_index,
                    "sample": sample,
                    "sin_ref": sin_ref,
                    "cos_ref": cos_ref,
                    "i_mixed": i_mixed,
                    "q_mixed": q_mixed,
                    "i_filt": i_filt,
                    "q_filt": q_filt,
                    "mag_sq": mag_sq,
                    "energy_so_far": energies[bin_index],
                }
            )

            phase = (phase + step) & ((1 << CONFIG["phase_width"]) - 1)

    detected_bin = max(range(CONFIG["num_bins"]), key=lambda idx: energies[idx])
    best_energy = energies[detected_bin]
    return energies, detected_bin, best_energy, trace_rows


def write_mem(path, values, bits):
    with path.open("w", encoding="ascii") as file:
        for value in values:
            file.write(twos_complement_hex(value, bits) + "\n")


def write_csv(path, rows, fieldnames):
    with path.open("w", newline="", encoding="ascii") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_energy_plot_svg(path, energies, detected_bin):
    width = 720
    height = 420
    margin_left = 70
    margin_bottom = 60
    margin_top = 30
    plot_width = width - margin_left - 30
    plot_height = height - margin_top - margin_bottom
    max_energy = max(energies)
    bar_gap = 12
    bar_width = (plot_width - bar_gap * (len(energies) - 1)) / len(energies)

    def x_for_bin(idx):
        return margin_left + idx * (bar_width + bar_gap)

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<text x="360" y="22" text-anchor="middle" font-family="Arial" font-size="18">Reference Energy per Bin</text>',
        f'<line x1="{margin_left}" y1="{height - margin_bottom}" x2="{width - 30}" y2="{height - margin_bottom}" stroke="#222"/>',
        f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{height - margin_bottom}" stroke="#222"/>',
    ]

    for idx, energy in enumerate(energies):
        bar_height = plot_height * energy / max_energy
        x = x_for_bin(idx)
        y = height - margin_bottom - bar_height
        fill = "#0072B2" if idx != detected_bin else "#D55E00"
        svg.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_width:.1f}" height="{bar_height:.1f}" fill="{fill}"/>')
        svg.append(f'<text x="{x + bar_width / 2:.1f}" y="{height - 38}" text-anchor="middle" font-family="Arial" font-size="13">{idx}</text>')
        svg.append(f'<text x="{x + bar_width / 2:.1f}" y="{y - 6:.1f}" text-anchor="middle" font-family="Arial" font-size="10">{energy:.2e}</text>')

    svg.append(f'<text x="{width / 2}" y="{height - 10}" text-anchor="middle" font-family="Arial" font-size="13">Frequency bin</text>')
    svg.append('<text transform="translate(18 230) rotate(-90)" text-anchor="middle" font-family="Arial" font-size="13">Accumulated magnitude squared</text>')
    svg.append("</svg>\n")

    path.write_text("\n".join(svg), encoding="ascii")


def write_summary(path, energies, detected_bin, best_energy):
    lines = [
        "# Golden Model Summary",
        "",
        f"Input width: {CONFIG['input_width']}",
        f"Reference width: {CONFIG['ref_width']}",
        f"ROM entries: {rom_size()}",
        f"Number of bins: {CONFIG['num_bins']}",
        f"Samples per bin: {CONFIG['samples_per_bin']}",
        f"FIR coefficients: {CONFIG['fir_coeffs']}",
        f"FIR shift: {CONFIG['fir_shift']}",
        f"Expected resonance bin: {CONFIG['peak_bin']}",
        f"Detected resonance bin: {detected_bin}",
        f"Best energy: {best_energy}",
        "",
        "| Bin | Phase Step | Amplitude | Energy |",
        "|---:|---:|---:|---:|",
    ]

    amps = amplitude_profile()
    for idx, energy in enumerate(energies):
        lines.append(f"| {idx} | {phase_step_for_bin(idx)} | {amps[idx]} | {energy} |")

    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def main():
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    sin_rom, cos_rom = build_roms()
    samples = generate_input_samples(sin_rom)
    energies, detected_bin, best_energy, trace_rows = run_lockin_model(samples, sin_rom, cos_rom)

    write_mem(VECTOR_DIR / "sin_rom.mem", sin_rom, CONFIG["ref_width"])
    write_mem(VECTOR_DIR / "cos_rom.mem", cos_rom, CONFIG["ref_width"])
    write_mem(VECTOR_DIR / "input_samples.mem", [row["sample"] for row in samples], CONFIG["input_width"])

    phase_rows = [
        {
            "bin": idx,
            "cycles_per_bin": idx + 2,
            "phase_step_decimal": phase_step_for_bin(idx),
            "phase_step_hex": twos_complement_hex(phase_step_for_bin(idx), CONFIG["phase_width"]),
        }
        for idx in range(CONFIG["num_bins"])
    ]
    write_csv(VECTOR_DIR / "phase_steps.csv", phase_rows, ["bin", "cycles_per_bin", "phase_step_decimal", "phase_step_hex"])

    energy_rows = [
        {
            "bin": idx,
            "amplitude": amplitude_profile()[idx],
            "energy": energy,
            "is_detected": int(idx == detected_bin),
        }
        for idx, energy in enumerate(energies)
    ]
    write_csv(VECTOR_DIR / "expected_energy_per_bin.csv", energy_rows, ["bin", "amplitude", "energy", "is_detected"])

    (VECTOR_DIR / "expected_detected_bin.txt").write_text(f"{detected_bin}\n", encoding="ascii")
    (VECTOR_DIR / "expected_best_energy.txt").write_text(f"{best_energy}\n", encoding="ascii")

    write_csv(
        VECTOR_DIR / "golden_trace.csv",
        trace_rows,
        [
            "global_sample",
            "bin",
            "bin_sample",
            "sample",
            "sin_ref",
            "cos_ref",
            "i_mixed",
            "q_mixed",
            "i_filt",
            "q_filt",
            "mag_sq",
            "energy_so_far",
        ],
    )

    write_energy_plot_svg(REPORT_DIR / "reference_energy_per_bin.svg", energies, detected_bin)
    write_summary(DOCS_DIR / "golden_model_summary.md", energies, detected_bin, best_energy)

    print(f"Generated vectors in {VECTOR_DIR}")
    print(f"Detected bin: {detected_bin}")
    print(f"Best energy: {best_energy}")

    if detected_bin != CONFIG["peak_bin"]:
        print("ERROR: detected bin does not match configured resonance bin", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
