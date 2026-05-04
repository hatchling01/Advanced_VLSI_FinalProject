"""Sweep FIR-output / magnitude-input signed width.

The current best RTL keeps the FIR output and magnitude-square input at 48
bits.  Because the latest critical path is inside the magnitude DSP cascade,
this sweep checks whether those operands can be narrowed without changing the
golden-model energy values for the current vectors.
"""

from pathlib import Path
import csv

from golden_model import (
    CONFIG,
    build_roms,
    fir_step,
    generate_input_samples,
    phase_step_for_bin,
    rom_lookup,
    run_lockin_model,
)


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports"
DOCS_DIR = ROOT / "docs"
PLOT_DIR = REPORT_DIR / "plots"
CSV_PATH = REPORT_DIR / "fir_mag_width_sweep.csv"
DOC_PATH = DOCS_DIR / "fir_mag_width_sweep.md"
PLOT_PATH = PLOT_DIR / "fir_mag_width_sweep.svg"


def wrap_signed(value, width):
    mask = (1 << width) - 1
    raw = value & mask
    sign = 1 << (width - 1)
    if raw & sign:
        return raw - (1 << width)
    return raw


def signed_bits_required(value):
    if value >= 0:
        return value.bit_length() + 1
    return (-value - 1).bit_length() + 1


def run_with_fir_mag_width(samples, sin_rom, cos_rom, width):
    i_hist = [0] * len(CONFIG["fir_coeffs"])
    q_hist = [0] * len(CONFIG["fir_coeffs"])
    energies = [0] * CONFIG["num_bins"]
    max_abs_fir = 0
    exact_no_truncation = True

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

            max_abs_fir = max(max_abs_fir, abs(i_filt), abs(q_filt))
            i_narrow = wrap_signed(i_filt, width)
            q_narrow = wrap_signed(q_filt, width)
            if i_narrow != i_filt or q_narrow != q_filt:
                exact_no_truncation = False

            energies[bin_index] += i_narrow * i_narrow + q_narrow * q_narrow
            phase = (phase + step) & ((1 << CONFIG["phase_width"]) - 1)

    detected_bin = max(range(CONFIG["num_bins"]), key=lambda idx: energies[idx])
    return energies, detected_bin, energies[detected_bin], max_abs_fir, exact_no_truncation


def write_svg_plot(path, rows, reference_bin, exact_threshold):
    width = 940
    height = 560
    left = 78
    right = 36
    top = 58
    bottom = 78
    plot_w = width - left - right
    plot_h = height - top - bottom
    x_min = min(row["fir_mag_width"] for row in rows)
    x_max = max(row["fir_mag_width"] for row in rows)
    y_min = -0.5
    y_max = 7.5

    def sx(value):
        return left + (value - x_min) / (x_max - x_min) * plot_w

    def sy(value):
        return top + plot_h - (value - y_min) / (y_max - y_min) * plot_h

    def text(x, y, label, size=13, anchor="middle", weight="400", fill="#1f2937"):
        return (
            f'<text x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}" '
            f'font-family="Arial, sans-serif" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}">{label}</text>'
        )

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        text(width / 2, 32, "FIR Output / Magnitude Input Width Sweep", 21, weight="700"),
        f'<line x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}" stroke="#2e3440" stroke-width="1.5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top + plot_h}" stroke="#2e3440" stroke-width="1.5"/>',
    ]

    for bin_index in range(CONFIG["num_bins"]):
        y = sy(bin_index)
        svg.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left + plot_w}" y2="{y:.1f}" stroke="#e3e8f0" stroke-width="1"/>')
        svg.append(text(left - 12, y + 4, str(bin_index), 12, anchor="end"))

    for tick in [16, 20, 24, 28, 32, 36, 40, 44, 48]:
        x = sx(tick)
        svg.append(f'<line x1="{x:.1f}" y1="{top + plot_h}" x2="{x:.1f}" y2="{top + plot_h + 6}" stroke="#2e3440"/>')
        svg.append(text(x, top + plot_h + 24, str(tick), 12))

    ref_y = sy(reference_bin)
    svg.append(f'<line x1="{left}" y1="{ref_y:.1f}" x2="{left + plot_w}" y2="{ref_y:.1f}" stroke="#111827" stroke-width="2" stroke-dasharray="7 5"/>')
    svg.append(text(left + 8, ref_y - 10, f"reference bin {reference_bin}", 12, anchor="start", weight="700"))

    exact_x = sx(exact_threshold)
    svg.append(f'<rect x="{exact_x:.1f}" y="{top}" width="{left + plot_w - exact_x:.1f}" height="{plot_h}" fill="#e9f7ef" opacity="0.55"/>')
    svg.append(f'<line x1="{exact_x:.1f}" y1="{top}" x2="{exact_x:.1f}" y2="{top + plot_h}" stroke="#2ca02c" stroke-width="2"/>')
    svg.append(text(exact_x + 8, top + 18, f"exact at >= {exact_threshold} signed bits", 12, anchor="start", weight="700", fill="#1f7a3a"))

    previous = None
    for row in rows:
        x = sx(row["fir_mag_width"])
        y = sy(row["detected_bin"])
        if row["exact_no_truncation"]:
            color = "#2ca02c"
        elif row["matches_reference_bin"]:
            color = "#f0ad00"
        else:
            color = "#d62728"

        if previous is not None:
            svg.append(
                f'<line x1="{sx(previous["fir_mag_width"]):.1f}" y1="{sy(previous["detected_bin"]):.1f}" '
                f'x2="{x:.1f}" y2="{y:.1f}" stroke="#9aa4b2" stroke-width="1"/>'
            )
        radius = 4.2 if row["fir_mag_width"] % 4 else 5.3
        svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius:.1f}" fill="{color}" stroke="#ffffff" stroke-width="1"/>')
        previous = row

    legend_y = height - 34
    svg.append(f'<circle cx="{left + 8}" cy="{legend_y - 4}" r="5" fill="#2ca02c" stroke="#ffffff" stroke-width="1"/>')
    svg.append(text(left + 20, legend_y, "exact energy match", 13, anchor="start"))
    svg.append(f'<circle cx="{left + 178}" cy="{legend_y - 4}" r="5" fill="#f0ad00" stroke="#ffffff" stroke-width="1"/>')
    svg.append(text(left + 190, legend_y, "bin only matches", 13, anchor="start"))
    svg.append(f'<circle cx="{left + 360}" cy="{legend_y - 4}" r="5" fill="#d62728" stroke="#ffffff" stroke-width="1"/>')
    svg.append(text(left + 372, legend_y, "detected bin changes", 13, anchor="start"))
    svg.append(text(left + plot_w / 2, height - 8, "Signed FIR output / magnitude input width (bits)", 14, weight="700"))
    svg.append(
        f'<text x="20" y="{top + plot_h / 2:.1f}" text-anchor="middle" '
        f'font-family="Arial, sans-serif" font-size="14" font-weight="700" '
        f'fill="#1f2937" transform="rotate(-90 20 {top + plot_h / 2:.1f})">Detected bin</text>'
    )
    svg.append("</svg>")
    path.write_text("\n".join(svg) + "\n", encoding="ascii")


def main():
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    PLOT_DIR.mkdir(parents=True, exist_ok=True)

    sin_rom, cos_rom = build_roms()
    samples = generate_input_samples(sin_rom)
    ref_energies, ref_bin, ref_best_energy, ref_trace = run_lockin_model(samples, sin_rom, cos_rom)
    max_abs_fir = max(max(abs(row["i_filt"]), abs(row["q_filt"])) for row in ref_trace)
    required_signed_bits = max(
        signed_bits_required(row["i_filt"]) for row in ref_trace
    )
    required_signed_bits = max(
        required_signed_bits,
        max(signed_bits_required(row["q_filt"]) for row in ref_trace),
    )

    rows = []
    for width in range(16, 49):
        energies, detected_bin, best_energy, width_max_abs_fir, exact = run_with_fir_mag_width(
            samples, sin_rom, cos_rom, width
        )
        rows.append(
            {
                "fir_mag_width": width,
                "exact_no_truncation": int(exact),
                "detected_bin": detected_bin,
                "matches_reference_bin": int(detected_bin == ref_bin),
                "best_energy_at_detected_bin": best_energy,
                "reference_bin_energy_at_width": energies[ref_bin],
                "reference_best_energy_error": ref_best_energy - energies[ref_bin],
                "max_abs_fir_iq": width_max_abs_fir,
                "required_signed_bits": required_signed_bits,
            }
        )

    fieldnames = [
        "fir_mag_width",
        "exact_no_truncation",
        "detected_bin",
        "matches_reference_bin",
        "best_energy_at_detected_bin",
        "reference_bin_energy_at_width",
        "reference_best_energy_error",
        "max_abs_fir_iq",
        "required_signed_bits",
    ]
    with CSV_PATH.open("w", newline="", encoding="ascii") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    write_svg_plot(PLOT_PATH, rows, ref_bin, required_signed_bits)

    safe_exact = [row["fir_mag_width"] for row in rows if row["exact_no_truncation"]]
    safe_match = [row["fir_mag_width"] for row in rows if row["matches_reference_bin"]]
    smallest_exact = min(safe_exact) if safe_exact else "none"
    smallest_match = min(safe_match) if safe_match else "none"

    lines = [
        "# FIR / Magnitude Width Sweep",
        "",
        "This sweep tests the signed width shared by the FIR outputs and",
        "magnitude-square inputs.  The current Energy62 design still uses",
        "48-bit FIR/magnitude operands, and its post-route critical path is",
        "inside the magnitude DSP cascade.",
        "",
        f"Reference detected bin: {ref_bin}",
        f"Reference best energy: {ref_best_energy}",
        f"Maximum absolute FIR I/Q value: {max_abs_fir}",
        f"Signed bits required for exact FIR I/Q values: {required_signed_bits}",
        "",
        "Plot:",
        "",
        "```text",
        "reports/plots/fir_mag_width_sweep.svg",
        "```",
        "",
        "| FIR/mag width | Exact no truncation | Detected bin | Matches reference | Reference energy error |",
        "|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            "| {fir_mag_width} | {exact_no_truncation} | {detected_bin} | {matches_reference_bin} | {reference_best_energy_error} |".format(
                **row
            )
        )

    lines.extend(
        [
            "",
            "Conclusion:",
            "",
            "```text",
            f"Smallest exact width tested: {smallest_exact} signed bits",
            f"Smallest bin-preserving width tested: {smallest_match} signed bits",
            f"Recommended safe RTL follow-up: FIR_OUT_WIDTH={smallest_exact}",
            "Narrower bin-preserving widths are not safe architecture choices",
            "because they change the energy values through signed wraparound.",
            "```",
            "",
            "Design implication:",
            "",
            "```text",
            "If the safe exact width is below 48 bits, the next RTL experiment should",
            "keep ENERGY_WIDTH=62 and reduce FIR_OUT_WIDTH to that exact signed width.",
            "This directly targets the current magnitude-DSP critical path instead of",
            "adding unrelated tracker or accumulator pipeline boundaries.",
            "```",
        ]
    )
    DOC_PATH.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(f"Reference detected bin: {ref_bin}")
    print(f"Reference best energy: {ref_best_energy}")
    print(f"Maximum absolute FIR I/Q value: {max_abs_fir}")
    print(f"Signed bits required for exact FIR I/Q values: {required_signed_bits}")
    print(f"Smallest exact width tested: {smallest_exact}")
    print(f"Smallest bin-preserving width tested: {smallest_match}")
    print(f"Wrote {CSV_PATH}")
    print(f"Wrote {PLOT_PATH}")
    print(f"Wrote {DOC_PATH}")


if __name__ == "__main__":
    main()
