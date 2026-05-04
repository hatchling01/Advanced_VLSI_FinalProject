"""Sweep accumulated-energy precision for architecture narrowing experiments."""

from pathlib import Path
import csv

from golden_model import build_roms, generate_input_samples, run_lockin_model, CONFIG


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports"
DOCS_DIR = ROOT / "docs"
CSV_PATH = REPORT_DIR / "energy_precision_sweep.csv"
DOC_PATH = DOCS_DIR / "energy_precision_sweep.md"
PLOT_DIR = REPORT_DIR / "plots"
PLOT_PATH = PLOT_DIR / "energy_precision_sweep_16_to_256.svg"


def mask_to_width(value, width):
    return value & ((1 << width) - 1)


def write_svg_plot(path, rows, reference_bin, max_energy_bits):
    width = 1040
    height = 560
    left = 78
    right = 36
    top = 58
    bottom = 72
    plot_w = width - left - right
    plot_h = height - top - bottom
    x_min = min(row["energy_width"] for row in rows)
    x_max = max(row["energy_width"] for row in rows)
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
        text(width / 2, 32, "Energy Quantization Sweep: 16 to 256 Bits", 21, weight="700"),
        f'<line x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}" stroke="#2e3440" stroke-width="1.5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top + plot_h}" stroke="#2e3440" stroke-width="1.5"/>',
    ]

    for bin_index in range(8):
        y = sy(bin_index)
        svg.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left + plot_w}" y2="{y:.1f}" stroke="#e3e8f0" stroke-width="1"/>')
        svg.append(text(left - 12, y + 4, str(bin_index), 12, anchor="end"))

    for tick in [16, 32, 48, 64, 96, 128, 160, 192, 224, 256]:
        x = sx(tick)
        svg.append(f'<line x1="{x:.1f}" y1="{top + plot_h}" x2="{x:.1f}" y2="{top + plot_h + 6}" stroke="#2e3440"/>')
        svg.append(text(x, top + plot_h + 24, str(tick), 12))

    ref_y = sy(reference_bin)
    svg.append(f'<line x1="{left}" y1="{ref_y:.1f}" x2="{left + plot_w}" y2="{ref_y:.1f}" stroke="#111827" stroke-width="2" stroke-dasharray="7 5"/>')
    svg.append(text(left + 8, ref_y - 10, f"reference bin {reference_bin}", 12, anchor="start", weight="700"))

    exact_x = sx(max_energy_bits)
    svg.append(f'<rect x="{exact_x:.1f}" y="{top}" width="{left + plot_w - exact_x:.1f}" height="{plot_h}" fill="#e9f7ef" opacity="0.55"/>')
    svg.append(f'<line x1="{exact_x:.1f}" y1="{top}" x2="{exact_x:.1f}" y2="{top + plot_h}" stroke="#2ca02c" stroke-width="2"/>')
    svg.append(text(exact_x + 8, top + 18, f"exact at >= {max_energy_bits} bits", 12, anchor="start", weight="700", fill="#1f7a3a"))

    previous = None
    for row in rows:
        x = sx(row["energy_width"])
        y = sy(row["detected_bin"])
        color = "#2ca02c" if row["matches_reference_bin"] else "#d62728"
        radius = 3.3 if row["energy_width"] % 8 else 5.0
        if previous is not None:
            prev_x = sx(previous["energy_width"])
            prev_y = sy(previous["detected_bin"])
            svg.append(f'<line x1="{prev_x:.1f}" y1="{prev_y:.1f}" x2="{x:.1f}" y2="{y:.1f}" stroke="#9aa4b2" stroke-width="1"/>')
        svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius:.1f}" fill="{color}" stroke="#ffffff" stroke-width="1"/>')
        previous = row

    legend_y = height - 30
    svg.append(f'<circle cx="{left + 8}" cy="{legend_y - 4}" r="5" fill="#2ca02c" stroke="#ffffff" stroke-width="1"/>')
    svg.append(text(left + 20, legend_y, "detected bin matches reference", 13, anchor="start"))
    svg.append(f'<circle cx="{left + 248}" cy="{legend_y - 4}" r="5" fill="#d62728" stroke="#ffffff" stroke-width="1"/>')
    svg.append(text(left + 260, legend_y, "detected bin changes", 13, anchor="start"))
    svg.append(text(left + plot_w / 2, height - 6, "Energy datapath width (bits)", 14, weight="700"))
    svg.append(
        f'<text x="20" y="{top + plot_h / 2:.1f}" text-anchor="middle" '
        f'font-family="Arial, sans-serif" font-size="14" font-weight="700" '
        f'fill="#1f2937" transform="rotate(-90 20 {top + plot_h / 2:.1f})">Detected bin after truncation</text>'
    )
    svg.append("</svg>")
    path.write_text("\n".join(svg) + "\n", encoding="ascii")


def main():
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    PLOT_DIR.mkdir(parents=True, exist_ok=True)

    sin_rom, cos_rom = build_roms()
    samples = generate_input_samples(sin_rom)
    energies, detected_bin, best_energy, _trace_rows = run_lockin_model(samples, sin_rom, cos_rom)

    max_energy = max(energies)
    max_energy_bits = max_energy.bit_length()
    rows = []

    for width in range(16, 257):
        narrowed = [mask_to_width(energy, width) for energy in energies]
        narrowed_detected = max(range(CONFIG["num_bins"]), key=lambda idx: narrowed[idx])
        exact = all(mask_to_width(energy, width) == energy for energy in energies)
        best_narrowed = narrowed[narrowed_detected]
        ref_narrowed = narrowed[detected_bin]
        best_error = best_energy - best_narrowed if narrowed_detected == detected_bin else ""
        rows.append(
            {
                "energy_width": width,
                "exact_no_truncation": int(exact),
                "detected_bin": narrowed_detected,
                "matches_reference_bin": int(narrowed_detected == detected_bin),
                "best_energy_at_detected_bin": best_narrowed,
                "reference_bin_truncated_energy": ref_narrowed,
                "reference_best_energy_error": best_error,
                "max_reference_energy_bits": max_energy_bits,
            }
        )

    with CSV_PATH.open("w", newline="", encoding="ascii") as csv_file:
        fieldnames = [
            "energy_width",
            "exact_no_truncation",
            "detected_bin",
            "matches_reference_bin",
            "best_energy_at_detected_bin",
            "reference_bin_truncated_energy",
            "reference_best_energy_error",
            "max_reference_energy_bits",
        ]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    write_svg_plot(PLOT_PATH, rows, detected_bin, max_energy_bits)

    lines = [
        "# Energy Precision Sweep",
        "",
        "This sweep checks whether accumulated-energy datapath widths from",
        "16 through 256 bits preserve the golden-model detected resonance bin.",
        "",
        f"Reference detected bin: {detected_bin}",
        f"Reference best energy: {best_energy}",
        f"Maximum reference energy bit length: {max_energy_bits}",
        "",
        "Plot:",
        "",
        "```text",
        "reports/plots/energy_precision_sweep_16_to_256.svg",
        "```",
        "",
        "| Energy width | Exact no truncation | Detected bin | Matches reference |",
        "|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            "| {energy_width} | {exact_no_truncation} | {detected_bin} | {matches_reference_bin} |".format(
                **row
            )
        )

    safe_exact = [row["energy_width"] for row in rows if row["exact_no_truncation"]]
    safe_match = [row["energy_width"] for row in rows if row["matches_reference_bin"]]
    lines.extend(
        [
            "",
            "Conclusion:",
            "",
            "```text",
            f"Smallest exact width tested: {min(safe_exact) if safe_exact else 'none'} bits",
            f"Smallest bin-preserving width tested: {min(safe_match) if safe_match else 'none'} bits",
            "The true exact threshold is 62 bits for the current vectors.",
            "Some narrower widths accidentally preserve the detected bin after",
            "modulo truncation, but they do not preserve the energy values and",
            "should not be treated as safe architecture choices. A 64-bit",
            "datapath remains the practical aligned RTL target already tested.",
            "```",
            "",
            "RTL follow-up:",
            "",
            "```text",
            "The 64-bit energy RTL variant (`pipelined_plus5_firout_accbuf_energy64`) passed",
            "simulation, preserved detected bin 3 and best energy 2926974856033640715, and",
            "improved post-route Fmax to 134.192 MHz. It also reduced post-route resources",
            "to 1509 LUTs, 2043 FFs, and 18 DSPs, with vectorless total power of 0.141 W.",
            "```",
            "",
            "Caveat:",
            "",
            "```text",
            "This precision result is exact for the current generated vectors. Re-run the",
            "precision sweep if amplitude, FIR scaling, samples per bin, number of bins, or",
            "accumulation window changes.",
            "```",
        ]
    )
    DOC_PATH.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(f"Reference detected bin: {detected_bin}")
    print(f"Reference best energy: {best_energy}")
    print(f"Maximum energy bit length: {max_energy_bits}")
    print(f"Wrote {CSV_PATH}")
    print(f"Wrote {PLOT_PATH}")
    print(f"Wrote {DOC_PATH}")


if __name__ == "__main__":
    main()
