# Fanout Early-Stop Probe

Last updated: May 3, 2026

## Purpose

This is the Stage-A sanity check for the proposed fanout/control-localization
experiment. The goal is to decide whether `pipelined_plus5_firout_accbuf_fanout`
is worth a full route run.

This run intentionally stops after:

```text
synth_design -> opt_design -> place_design
```

Stage B full route and clock sweep have now also been run for this variant.

## Trial Variant

New fanout trial top:

```text
rtl/lockin_pipelined_plus5_firout_accbuf_fanout_top.sv
```

New fanout-hint blocks:

- `rtl/fir_filter_pipelined_outreg_fanout.sv`
- `rtl/magnitude_sq_pipelined_fanout.sv`
- `rtl/resonance_tracker_fanout.sv`

Vivado Stage-A probe:

```text
vivado/place_probe_pipelined_plus5_firout_accbuf_fanout.tcl
```

Reports:

```text
reports/pipelined_plus5_firout_accbuf_fanout_place_probe/
```

## Early-Stop Criteria

Continue to full route only if:

```text
At least one major high-fanout control net drops by roughly 30% or more,
and the post-place top setup paths do not show a clearly worse new bottleneck.
```

## Fanout Result

| Control/fanout item | Before, routed accbuf | Stage-A fanout probe | Change |
|---|---:|---:|---:|
| `valid_s2` control | 591 | replicated into ~98-fanout nets | Strong reduction |
| FIR I enable/control | 405 | about 101-113 | Strong reduction |
| FIR valid P2 control | 225 | about 113 | Strong reduction |
| Magnitude `valid_out` | 130 | 64 plus one 64-fanout replica | Moderate reduction |
| Magnitude enable | 132 | 132 | No improvement |
| Tracker update/CE | 251 | 251 | No improvement |
| Reset | 2188 | 2209 | Not improved; not targeted |

## Post-Place Timing Snapshot

| Metric | Value |
|---|---:|
| Post-place setup WNS | 2.144 ns |
| Post-place hold WNS | -0.081 ns |
| LUTs | 1794 |
| FFs | 2393 |
| DSPs | 20 |

Hold note:

```text
This was a place-only probe. Hold timing is not final until routing is run, so
the small post-place hold violation is not used as the go/no-go decision.
```

Top post-place setup paths:

| Rank group | Region | Observation |
|---|---|---|
| 1-4 | Magnitude | DSP square path remains the worst setup family |
| 5-6 | FIR | FIR final-output paths appear but with margin |
| 7-20 | Magnitude | Many DSP cascade/register paths |

## Verdict

```text
Continue to full route is justified, but confidence is moderate rather than
high.
```

Reason:

```text
The fanout hints successfully reduce several major valid/FIR control fanouts
before route. However, the tracker update/CE fanout remains at 251 and the
magnitude enable remains at 132, so this is not a complete solution. A full
route run is worth doing because the cheap gate passed, but the success
criterion remains strict: it must beat 129.099 MHz post-route.
```

Next action:

```text
Stage B has been completed. Record the result as a partial/negative speed
experiment and keep `pipelined_plus5_firout_accbuf` as the highest-Fmax design.
```

## Stage-B Full-Route Result

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Post-route implementation:

| Metric | Value |
|---|---:|
| WNS | 2.136 ns |
| Hold slack | 0.022 ns |
| Derived min period | 7.864 ns |
| Derived Fmax | 127.162 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1794 |
| FFs | 2393 |
| DSPs | 20 |
| Total power | 0.150 W |
| Dynamic power | 0.080 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/gen_regular_mag_fanout.u_mag/i_square0/CLK
Destination: u_impl/gen_regular_mag_fanout.u_mag/i_square_reg[1]/D
Data delay:  7.667 ns
Logic:       5.724 ns
Route:       1.943 ns
Logic levels: 1
```

Final verdict:

```text
This is not the new speed winner. Fanout hints successfully reduce several
valid/FIR control nets, but post-route Fmax is 127.162 MHz versus 129.099 MHz
for the parent accbuf design. The magnitude DSP path remains dominant, while
the tracker update/CE fanout remains at 251.
```
