"""Generate SVG trade-off plots from reports/pipeline_tradeoff_summary.csv."""

from pathlib import Path
import csv
import html


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports"
PLOT_DIR = REPORT_DIR / "plots"
CSV_PATH = REPORT_DIR / "pipeline_tradeoff_summary.csv"


COLORS = {
    "baseline": "#7a869a",
    "pipelined": "#1f77b4",
    "pipelined_plus1": "#2ca02c",
    "pipelined_plus5": "#d62728",
    "pipelined_plus5_tracker": "#9467bd",
    "pipelined_plus5_firout": "#ff7f0e",
    "pipelined_plus5_firout_tracker": "#17becf",
    "pipelined_plus5_firout_accbuf": "#8c564b",
    "pipelined_plus5_firout_accbuf_magpipe": "#e377c2",
    "pipelined_plus5_firout_accbuf_trackercmp": "#bcbd22",
    "pipelined_plus5_firout_accbuf_fanout": "#4c78a8",
    "pipelined_plus5_firout_accbuf_energy64": "#59a14f",
    "pipelined_plus5_firout_accbuf_energy62": "#1b9e77",
    "pipelined_plus5_firout_accbuf_energy62_fir29": "#117733",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround": "#004d40",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart": "#a6761d",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart": "#7f3c8d",
    "accent": "#6f42c1",
    "grid": "#d7dde8",
    "axis": "#2e3440",
    "text": "#1f2937",
}


LABELS = {
    "baseline": "Baseline",
    "pipelined": "Pipelined",
    "pipelined_plus1": "Plus1",
    "pipelined_plus5": "Plus5",
    "pipelined_plus5_tracker": "Plus5 Tracker",
    "pipelined_plus5_firout": "Plus5 FIR Out",
    "pipelined_plus5_firout_tracker": "Plus5 FIR+Tracker",
    "pipelined_plus5_firout_accbuf": "Plus5 FIR+AccBuf",
    "pipelined_plus5_firout_accbuf_magpipe": "Plus5 AccBuf+MagPipe",
    "pipelined_plus5_firout_accbuf_trackercmp": "Plus5 AccBuf+TrackCmp",
    "pipelined_plus5_firout_accbuf_fanout": "Plus5 AccBuf+Fanout",
    "pipelined_plus5_firout_accbuf_energy64": "Plus5 AccBuf+Energy64",
    "pipelined_plus5_firout_accbuf_energy62": "Plus5 AccBuf+Energy62",
    "pipelined_plus5_firout_accbuf_energy62_fir29": "Plus5 AccBuf+E62 FIR29",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround": "Plus5 E62 FIR29 FastRound",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart": "Plus5 FastRound+AccStart",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart": "Plus5 AlwaysOn+AccStart",
}


LATENCY_HIGHLIGHTS = {
    "pipelined",
    "pipelined_plus1",
    "pipelined_plus5",
    "pipelined_plus5_firout_accbuf",
    "pipelined_plus5_firout_accbuf_energy64",
    "pipelined_plus5_firout_accbuf_energy62_fir29",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart",
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart",
}


LATENCY_LABEL_OFFSETS = {
    "pipelined": (0, -18),
    "pipelined_plus1": (0, -18),
    "pipelined_plus5": (-42, -24),
    "pipelined_plus5_firout_accbuf": (48, 28),
    "pipelined_plus5_firout_accbuf_energy64": (-76, 22),
    "pipelined_plus5_firout_accbuf_energy62_fir29": (-82, -22),
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround": (86, 10),
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart": (96, 36),
    "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart": (88, -18),
}


def read_rows():
    with CSV_PATH.open(newline="", encoding="utf-8") as csv_file:
        return list(csv.DictReader(csv_file))


def numeric(value):
    try:
        return float(value)
    except ValueError:
        return None


def svg_text(x, y, text, size=14, anchor="middle", weight="400", fill=None):
    fill = fill or COLORS["text"]
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}" '
        f'font-family="Arial, sans-serif" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}">{html.escape(str(text))}</text>'
    )


def write_svg(path, width, height, body):
    content = "\n".join(
        [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            '<rect width="100%" height="100%" fill="#ffffff"/>',
            *body,
            "</svg>",
        ]
    )
    path.write_text(content + "\n", encoding="utf-8")


def chart_bounds(values, padding_ratio=0.1, include_zero=True):
    min_value = min(values)
    max_value = max(values)
    if include_zero:
        min_value = min(0.0, min_value)
    span = max_value - min_value
    if span == 0:
        span = max(abs(max_value), 1.0)
    return min_value - span * padding_ratio, max_value + span * padding_ratio


def line_chart(
    path,
    title,
    rows,
    x_key,
    y_key,
    x_label,
    y_label,
    include_zero=False,
    label_designs=None,
    label_offsets=None,
    subtitle=None,
):
    width = 1120 if label_designs else 940
    height = 600 if label_designs else 560
    left = 90
    right = 130 if label_designs else 40
    top = 75
    bottom = 105 if label_designs else 90
    plot_w = width - left - right
    plot_h = height - top - bottom

    points = []
    for row in rows:
        x_value = numeric(row[x_key])
        y_value = numeric(row[y_key])
        if x_value is not None and y_value is not None:
            points.append((row["design"], x_value, y_value))

    x_min, x_max = chart_bounds([point[1] for point in points], 0.08, include_zero=True)
    y_min, y_max = chart_bounds([point[2] for point in points], 0.08, include_zero=include_zero)

    def sx(value):
        return left + (value - x_min) / (x_max - x_min) * plot_w

    def sy(value):
        return top + plot_h - (value - y_min) / (y_max - y_min) * plot_h

    body = [
        svg_text(width / 2, 36, title, 22, weight="700"),
        f'<line x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}" stroke="{COLORS["axis"]}" stroke-width="1.5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top + plot_h}" stroke="{COLORS["axis"]}" stroke-width="1.5"/>',
    ]
    if subtitle:
        body.append(svg_text(width / 2, 58, subtitle, 13, weight="400", fill="#4b5563"))

    for idx in range(6):
        value = y_min + (y_max - y_min) * idx / 5
        y = sy(value)
        body.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left + plot_w}" y2="{y:.1f}" stroke="{COLORS["grid"]}" stroke-width="1"/>')
        body.append(svg_text(left - 12, y + 5, f"{value:.1f}", 12, anchor="end"))

    for idx in range(6):
        value = x_min + (x_max - x_min) * idx / 5
        x = sx(value)
        body.append(svg_text(x, top + plot_h + 24, f"{value:.1f}", 12))

    body.append(svg_text(left + plot_w / 2, height - 28, x_label, 15, weight="700"))
    body.append(
        f'<text x="24" y="{top + plot_h / 2:.1f}" text-anchor="middle" '
        f'font-family="Arial, sans-serif" font-size="15" font-weight="700" '
        f'fill="{COLORS["text"]}" transform="rotate(-90 24 {top + plot_h / 2:.1f})">{html.escape(y_label)}</text>'
    )

    polyline_points = " ".join(f"{sx(x):.1f},{sy(y):.1f}" for _, x, y in points)
    body.append(f'<polyline points="{polyline_points}" fill="none" stroke="{COLORS["accent"]}" stroke-width="3"/>')

    for design, x_value, y_value in points:
        x = sx(x_value)
        y = sy(y_value)
        color = COLORS.get(design, COLORS["accent"])
        radius = 7 if label_designs is None or design in label_designs else 4
        opacity = "1" if label_designs is None or design in label_designs else "0.45"
        body.append(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius}" fill="{color}" '
            f'stroke="#ffffff" stroke-width="2" opacity="{opacity}"/>'
        )
        if label_designs is not None and design not in label_designs:
            continue

        dx, dy = (0, -14)
        if label_offsets and design in label_offsets:
            dx, dy = label_offsets[design]
        label_x = x + dx
        label_y = y + dy
        anchor = "start" if dx > 0 else "end" if dx < 0 else "middle"
        label = f'{LABELS[design]} ({y_value:.1f})'
        if dx or dy:
            body.append(
                f'<line x1="{x:.1f}" y1="{y:.1f}" x2="{label_x:.1f}" y2="{label_y - 5:.1f}" '
                f'stroke="{color}" stroke-width="1" opacity="0.55"/>'
            )
        text_width = max(42, len(label) * 6.4)
        rect_x = label_x - text_width / 2
        if anchor == "start":
            rect_x = label_x - 4
        elif anchor == "end":
            rect_x = label_x - text_width + 4
        body.append(
            f'<rect x="{rect_x:.1f}" y="{label_y - 15:.1f}" width="{text_width:.1f}" '
            f'height="19" rx="3" fill="#ffffff" opacity="0.86"/>'
        )
        body.append(svg_text(label_x, label_y, label, 12, anchor=anchor, weight="700"))

    write_svg(path, width, height, body)


def grouped_bar_chart(path, title, rows, metrics, y_label):
    width = 1080
    height = 600
    left = 90
    right = 40
    top = 75
    bottom = 105
    plot_w = width - left - right
    plot_h = height - top - bottom

    all_values = [numeric(row[key]) for row in rows for key, _ in metrics]
    all_values = [value for value in all_values if value is not None]
    y_min, y_max = chart_bounds(all_values, 0.1, include_zero=True)

    def sy(value):
        return top + plot_h - (value - y_min) / (y_max - y_min) * plot_h

    body = [
        svg_text(width / 2, 36, title, 22, weight="700"),
        f'<line x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}" stroke="{COLORS["axis"]}" stroke-width="1.5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top + plot_h}" stroke="{COLORS["axis"]}" stroke-width="1.5"/>',
    ]

    for idx in range(6):
        value = y_min + (y_max - y_min) * idx / 5
        y = sy(value)
        body.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left + plot_w}" y2="{y:.1f}" stroke="{COLORS["grid"]}" stroke-width="1"/>')
        body.append(svg_text(left - 12, y + 5, f"{value:.3g}", 12, anchor="end"))

    group_w = plot_w / len(rows)
    bar_w = group_w / (len(metrics) + 1.4)
    metric_colors = ["#1f77b4", "#2ca02c", "#d62728"]

    for row_idx, row in enumerate(rows):
        group_x = left + row_idx * group_w
        center = group_x + group_w / 2
        body.append(svg_text(center, top + plot_h + 25, LABELS[row["design"]], 13, weight="700"))
        for metric_idx, (key, _label) in enumerate(metrics):
            value = numeric(row[key])
            if value is None:
                continue
            x = group_x + (metric_idx + 0.55) * bar_w
            y = sy(value)
            h = top + plot_h - y
            body.append(
                f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w * 0.82:.1f}" height="{h:.1f}" '
                f'rx="3" fill="{metric_colors[metric_idx % len(metric_colors)]}"/>'
            )
            body.append(svg_text(x + bar_w * 0.41, y - 6, f"{value:.3g}", 11))

    legend_x = left + 20
    for idx, (_, label) in enumerate(metrics):
        x = legend_x + idx * 145
        body.append(f'<rect x="{x}" y="{height - 58}" width="15" height="15" fill="{metric_colors[idx % len(metric_colors)]}"/>')
        body.append(svg_text(x + 22, height - 45, label, 13, anchor="start"))

    body.append(svg_text(left + plot_w / 2, height - 18, "Design variant", 15, weight="700"))
    body.append(
        f'<text x="24" y="{top + plot_h / 2:.1f}" text-anchor="middle" '
        f'font-family="Arial, sans-serif" font-size="15" font-weight="700" '
        f'fill="{COLORS["text"]}" transform="rotate(-90 24 {top + plot_h / 2:.1f})">{html.escape(y_label)}</text>'
    )

    write_svg(path, width, height, body)


def incremental_gain_chart(path, rows):
    step_pairs = [
        ("baseline", "pipelined"),
        ("pipelined", "pipelined_plus1"),
        ("pipelined_plus1", "pipelined_plus5"),
        ("pipelined_plus5", "pipelined_plus5_tracker"),
        ("pipelined_plus5", "pipelined_plus5_firout"),
        ("pipelined_plus5_firout", "pipelined_plus5_firout_tracker"),
        ("pipelined_plus5_firout", "pipelined_plus5_firout_accbuf"),
        ("pipelined_plus5_firout_accbuf", "pipelined_plus5_firout_accbuf_magpipe"),
        ("pipelined_plus5_firout_accbuf", "pipelined_plus5_firout_accbuf_trackercmp"),
        ("pipelined_plus5_firout_accbuf", "pipelined_plus5_firout_accbuf_fanout"),
        ("pipelined_plus5_firout_accbuf", "pipelined_plus5_firout_accbuf_energy64"),
        ("pipelined_plus5_firout_accbuf_energy64", "pipelined_plus5_firout_accbuf_energy62"),
        ("pipelined_plus5_firout_accbuf_energy62", "pipelined_plus5_firout_accbuf_energy62_fir29"),
        ("pipelined_plus5_firout_accbuf_energy62_fir29", "pipelined_plus5_firout_accbuf_energy62_fir29_fastround"),
        ("pipelined_plus5_firout_accbuf_energy62_fir29_fastround", "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart"),
        ("pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart", "pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart"),
    ]
    row_by_design = {row["design"]: row for row in rows}
    steps = []
    for previous_design, current_design in step_pairs:
        previous = row_by_design[previous_design]
        current = row_by_design[current_design]
        prev_fmax = numeric(previous["post_route_fmax_mhz"])
        curr_fmax = numeric(current["post_route_fmax_mhz"])
        prev_latency = numeric(previous["latency_after_final_sample_cycles"])
        curr_latency = numeric(current["latency_after_final_sample_cycles"])
        latency_delta = None
        if prev_latency is not None and curr_latency is not None:
            latency_delta = curr_latency - prev_latency
        steps.append(
            {
                "label": f'{LABELS[previous["design"]]} to {LABELS[current["design"]]}',
                "gain": curr_fmax - prev_fmax,
                "latency_delta": latency_delta,
            }
        )

    width = 1180
    height = 540
    left = 90
    right = 40
    top = 75
    bottom = 110
    plot_w = width - left - right
    plot_h = height - top - bottom

    y_min, y_max = chart_bounds([step["gain"] for step in steps], 0.15, include_zero=True)

    def sy(value):
        return top + plot_h - (value - y_min) / (y_max - y_min) * plot_h

    body = [
        svg_text(width / 2, 36, "Incremental Fmax Gain Shows Diminishing Returns", 22, weight="700"),
        f'<line x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}" stroke="{COLORS["axis"]}" stroke-width="1.5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top + plot_h}" stroke="{COLORS["axis"]}" stroke-width="1.5"/>',
    ]

    for idx in range(6):
        value = y_min + (y_max - y_min) * idx / 5
        y = sy(value)
        body.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left + plot_w}" y2="{y:.1f}" stroke="{COLORS["grid"]}" stroke-width="1"/>')
        body.append(svg_text(left - 12, y + 5, f"{value:.1f}", 12, anchor="end"))

    zero_y = sy(0)
    body.append(f'<line x1="{left}" y1="{zero_y:.1f}" x2="{left + plot_w}" y2="{zero_y:.1f}" stroke="{COLORS["axis"]}" stroke-width="1"/>')

    bar_w = plot_w / (len(steps) * 1.8)
    for idx, step in enumerate(steps):
        center = left + (idx + 0.5) * plot_w / len(steps)
        y = sy(step["gain"])
        rect_y = min(y, zero_y)
        h = abs(zero_y - y)
        color = "#2ca02c" if step["gain"] >= 0 else "#d62728"
        gain_text = f'{step["gain"]:+.3f} MHz'
        label_y = rect_y - 10 if step["gain"] >= 0 else rect_y + h + 18
        body.append(f'<rect x="{center - bar_w / 2:.1f}" y="{rect_y:.1f}" width="{bar_w:.1f}" height="{h:.1f}" rx="4" fill="{color}"/>')
        body.append(svg_text(center, label_y, gain_text, 13, weight="700"))
        body.append(svg_text(center, top + plot_h + 24, step["label"], 12))
        latency_text = "latency unknown" if step["latency_delta"] is None else f'+{step["latency_delta"]:.0f} cycles'
        body.append(svg_text(center, top + plot_h + 45, latency_text, 12))

    body.append(svg_text(left + plot_w / 2, height - 22, "Architecture step", 15, weight="700"))
    body.append(
        f'<text x="24" y="{top + plot_h / 2:.1f}" text-anchor="middle" '
        f'font-family="Arial, sans-serif" font-size="15" font-weight="700" '
        f'fill="{COLORS["text"]}" transform="rotate(-90 24 {top + plot_h / 2:.1f})">Fmax gain (MHz)</text>'
    )
    write_svg(path, width, height, body)


def main():
    PLOT_DIR.mkdir(parents=True, exist_ok=True)
    rows = read_rows()
    pipeline_rows = [row for row in rows if numeric(row["latency_after_final_sample_cycles"]) is not None]
    stage_rows = [row for row in rows if numeric(row["extra_fir_to_mag_boundary_stages"]) is not None]

    line_chart(
        PLOT_DIR / "pipeline_fmax_vs_latency.svg",
        "Fmax vs Latency",
        pipeline_rows,
        "latency_after_final_sample_cycles",
        "post_route_fmax_mhz",
        "Latency after final sample (cycles)",
        "Derived post-route Fmax (MHz)",
        include_zero=False,
        label_designs=LATENCY_HIGHLIGHTS,
        label_offsets=LATENCY_LABEL_OFFSETS,
        subtitle="All variants are plotted; only major decision points are labeled for readability.",
    )

    line_chart(
        PLOT_DIR / "pipeline_fmax_vs_boundary_stages.svg",
        "Fmax vs Extra FIR-to-Magnitude Boundary Registers",
        stage_rows,
        "extra_fir_to_mag_boundary_stages",
        "post_route_fmax_mhz",
        "Extra FIR-to-magnitude boundary stages",
        "Derived post-route Fmax (MHz)",
        include_zero=False,
    )

    grouped_bar_chart(
        PLOT_DIR / "pipeline_area_tradeoff.svg",
        "Post-Route Area by Architecture",
        rows,
        [("post_route_luts", "LUTs"), ("post_route_ffs", "FFs")],
        "Resource count",
    )

    grouped_bar_chart(
        PLOT_DIR / "pipeline_power_tradeoff.svg",
        "Post-Route Power by Architecture",
        rows,
        [("total_power_w", "Total W"), ("dynamic_power_w", "Dynamic W"), ("static_power_w", "Static W")],
        "Power (W)",
    )

    incremental_gain_chart(PLOT_DIR / "pipeline_incremental_fmax_gain.svg", rows)

    generated = [
        PLOT_DIR / "pipeline_fmax_vs_latency.svg",
        PLOT_DIR / "pipeline_fmax_vs_boundary_stages.svg",
        PLOT_DIR / "pipeline_area_tradeoff.svg",
        PLOT_DIR / "pipeline_power_tradeoff.svg",
        PLOT_DIR / "pipeline_incremental_fmax_gain.svg",
    ]
    print("Generated trade-off plots:")
    for path in generated:
        print(path)


if __name__ == "__main__":
    main()
