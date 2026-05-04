# Bottleneck Diagnostic: Pipelined Plus5 FIR Out Accbuf

Last updated: May 3, 2026

## Purpose

This historical diagnostic pass inspected the then-current highest-Fmax design:

```text
pipelined_plus5_firout_accbuf
```

The goal is to decide what to optimize next after the negative `magpipe` and
`trackercmp` experiments.

## Source Reports

Generated from the routed checkpoint:

```text
reports/pipelined_plus5_firout_accbuf_impl/lockin_pipelined_plus5_firout_accbuf_routed.dcp
```

Diagnostic outputs:

- `reports/diagnostics/pipelined_plus5_firout_accbuf/timing_summary_deep.rpt`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/top20_setup_paths.rpt`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/top10_setup_paths_full_clock.rpt`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/top20_setup_paths.csv`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/top20_region_summary.csv`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/high_fanout_nets.rpt`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/control_net_fanout.csv`

## Top-20 Setup Path Summary

| Region | Paths in top 20 | Worst slack |
|---|---:|---:|
| Magnitude | 11 | 2.254 ns |
| Accumulator/tracker | 9 | 2.309 ns |

Interpretation:

```text
The design has two competing bottleneck families. The single worst path is in
the magnitude square DSP path, but the accumulator-output-buffer to tracker CE
paths are only 55 ps behind it. A local-only fix can easily move the bottleneck
back and lose Fmax, which is exactly what happened in the magpipe and
trackercmp experiments.
```

## Worst Magnitude Path

```text
Source:      u_impl/u_mag/q_square0/CLK
Destination: u_impl/u_mag/q_square_reg[5]/D
Slack:       2.254 ns
Data delay:  7.534 ns
Logic:       5.724 ns
Route:       1.810 ns
Logic levels: 1
```

Detailed path observation:

```text
The path is dominated by DSP48E1 internal/cascade delay from a 48-bit square
implementation. This is not a deep LUT path. Pure RTL carry-chain cleanup is
unlikely to fix it unless the magnitude arithmetic structure or precision is
changed.
```

## Worst Accumulator/Tracker Path

```text
Source:      u_impl/bin_energy_buf_reg[28]/C
Destination: u_impl/gen_regular_tracker.u_tracker/best_energy_reg[13]_lopt_replica/CE
Slack:       2.309 ns
Data delay:  7.478 ns
Logic:       2.550 ns
Route:       4.928 ns
Logic levels: 15
```

Detailed path observation:

```text
This path is route-heavy. It traverses comparator carry logic and then drives a
wide best_energy clock-enable/update decision. The high route fraction suggests
fanout/placement/control structure matters more than adding another arithmetic
pipeline stage.
```

## High-Fanout Nets

Important high-fanout nets from the routed design:

| Net | Fanout | Note |
|---|---:|---|
| `rst_IBUF` | 2188 | Global reset fanout |
| `u_impl/valid_s2` | 591 | Feeds large FIR/control region |
| `u_impl/gen_fir_outreg.u_fir_i/E[0]` | 405 | FIR I clock-enable/control fanout |
| `u_impl/gen_regular_tracker.u_tracker/best_energy[127]_i_1_n_0` | 251 | Tracker best-energy update/CE fanout |
| `u_impl/gen_fir_outreg.u_fir_i/valid_p2_reg_0[0]` | 225 | FIR valid pipeline fanout |
| `u_impl/u_mag/E[0]` | 132 | Magnitude enable/control fanout |
| `u_impl/u_mag/valid_out` | 130 | Accumulator-side valid/control fanout |

Interpretation:

```text
Control and enable distribution are now first-class timing concerns. The high
fanout is consistent with the route-heavy accumulator/tracker CE path and with
the FIR-output path reappearing after tracker-side staging.
```

## Design Implications

Negative experiments now make more sense:

| Experiment | What it fixed | What happened |
|---|---|---|
| `magpipe` | Removed magnitude DSP path as top bottleneck | Tracker CE became dominant and Fmax dropped |
| `trackercmp` | Removed tracker CE as top bottleneck | FIR final-output path became dominant and Fmax dropped |

Conclusion:

```text
The current design is at a balanced point among magnitude DSP delay,
accumulator/tracker CE delay, and FIR/control fanout. The next speed experiment
should not be a single isolated pipeline register. It should reduce
control/enable fanout and avoid worsening either of the two top path families.
```

## Recommended Next Experiment

Recommended RTL experiment:

```text
pipelined_plus5_firout_accbuf_fanout
```

Goal:

```text
Keep the current datapath architecture, but reduce routed control pressure by
replicating or localizing high-fanout valid/enable/control signals around the
FIR, magnitude, accumulator-output buffer, and tracker update decision.
```

What to try first:

- Add explicit replicated valid/enable registers for I-FIR and Q-FIR paths.
- Add local valid/enable registers near magnitude and accumulator boundary.
- Apply conservative `max_fanout` attributes to the worst valid/control nets.
- Do not change arithmetic precision or tracker algorithm in this experiment.

Success criteria:

```text
Simulation must still detect bin 3 with best energy 2926974856033640715.
Post-route Fmax must beat 129.099 MHz, or the experiment is recorded as
negative.
```

## Stage-A Fanout Probe Result

The first early-stop probe has been run and is documented in:

```text
docs/fanout_early_stop_probe.md
```

Verdict:

```text
The cheap gate passed enough to justify full route, but confidence is moderate.
FIR/valid fanout improved strongly; tracker update/CE fanout did not improve.
```
