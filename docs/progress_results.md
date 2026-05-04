# Lock-In Resonance Tracking VLSI Project Progress

Last updated: May 3, 2026

## Project Objective

Design and evaluate a fixed-point Verilog/SystemVerilog lock-in DSP accelerator
for real-time resonance tracking. The project compares a baseline architecture
against a pipelined architecture using simulation correctness, timing, resource
usage, latency, throughput, and critical-path behavior.

## Current Configuration

| Parameter | Value |
|---|---:|
| Input sample width | 16-bit signed |
| Reference width | 16-bit signed |
| Sine/cosine ROM entries | 256 |
| Phase width | 32 bits |
| Number of bins | 8 |
| Samples per bin | 64 |
| Total input samples | 512 |
| FIR taps | 8 |
| FIR coefficients | 1, 2, 3, 4, 4, 3, 2, 1 |
| FIR normalization shift | 4 |
| Detection mode | Peak |
| Target FPGA | Artix-7 `xc7a35tcpg236-1` |
| Implementation package | Artix-7 `xc7a35tfgg484-1` |
| Clock constraint | 100 MHz |

Note:

Synthesis scripts use `xc7a35tcpg236-1`. Implementation scripts use
`xc7a35tfgg484-1` because the current top-level exposes a wide debug/result bus,
including `best_energy[127:0]`, and the larger package has enough I/O pins for
place-and-route.

## Work Completed

### Architecture Schematics

Added visual architecture schematics:

- `docs/architecture_schematics.md`

This file shows the design evolution from Python golden model to baseline RTL
to pipelined RTL, including datapath diagrams, control-delay diagrams, and
baseline-vs-pipelined comparison tables.

### Project Structure

Created the project folder layout:

```text
python/
vectors/
rtl/
tb/
vivado/
reports/
docs/
```

### Python Golden Model

Created the Python fixed-point golden model:

- `python/fixed_point.py`
- `python/golden_model.py`

The golden model generates:

- `vectors/sin_rom.mem`
- `vectors/cos_rom.mem`
- `vectors/input_samples.mem`
- `vectors/phase_steps.csv`
- `vectors/expected_energy_per_bin.csv`
- `vectors/expected_detected_bin.txt`
- `vectors/expected_best_energy.txt`
- `vectors/golden_trace.csv`
- `reports/reference_energy_per_bin.svg`
- `docs/golden_model_summary.md`

Command:

```powershell
python .\python\golden_model.py
```

Observed Python result:

```text
Generated vectors in C:\Users\CHOUDN3\Downloads\VLSI_project\vectors
Detected bin: 3
Best energy: 2926974856033640715
```

### Generated Energy Profile

| Bin | Amplitude | Energy | Detected |
|---:|---:|---:|---:|
| 0 | 2079 | 182688890228910093 | 0 |
| 1 | 4370 | 642263289524871929 | 0 |
| 2 | 8293 | 1939084045532921577 | 0 |
| 3 | 10500 | 2926974856033640715 | 1 |
| 4 | 8293 | 1936414908940284738 | 0 |
| 5 | 4370 | 598228653883401162 | 0 |
| 6 | 2079 | 136933010170341327 | 0 |
| 7 | 1414 | 57435938032847400 | 0 |

The expected resonance bin is therefore:

```text
expected_detected_bin = 3
```

### Baseline RTL Implementation

Created the baseline RTL modules:

- `rtl/nco.sv`
- `rtl/iq_mixer.sv`
- `rtl/fir_filter.sv`
- `rtl/magnitude_sq.sv`
- `rtl/bin_accumulator.sv`
- `rtl/resonance_tracker.sv`
- `rtl/lockin_baseline_top.sv`

The baseline datapath is:

```text
sample_in
   -> NCO sine/cosine reference generation
   -> I/Q mixer
   -> FIR_I and FIR_Q
   -> magnitude-squared estimator
   -> bin accumulator
   -> resonance tracker
   -> detected_bin, best_energy, done
```

### Baseline Testbench

Created:

- `tb/tb_lockin_baseline.sv`

The testbench:

- reads `vectors/input_samples.mem`
- reads sine/cosine ROMs through the NCO
- reads `vectors/expected_detected_bin.txt`
- drives 512 samples into the design
- waits for `done`
- checks that the RTL detected bin matches the Python model

### Vivado Scripts

Created:

- `vivado/constraints.xdc`
- `vivado/sim_baseline.tcl`
- `vivado/synth_baseline.tcl`

The simulation script stages vector files into the XSim run directory so that
relative `$readmemh` and `$fopen` paths work correctly.

## Results So Far

### Baseline RTL Simulation

Command:

```powershell
vivado -mode batch -source vivado/sim_baseline.tcl
```

Simulation result:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
PASS
```

Conclusion:

The baseline RTL correctly matches the Python golden model for the generated
resonance sweep.

### Baseline Synthesis

Command:

```powershell
vivado -mode batch -source vivado/synth_baseline.tcl
```

Synthesis completed successfully:

```text
Synthesis finished with 0 errors, 0 critical warnings and 0 warnings.
```

### Baseline Resource Utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 1574 | 20800 | 7.57% |
| Slice Registers | 860 | 41600 | 2.07% |
| DSPs | 20 | 90 | 22.22% |
| Block RAM Tile | 0 | 50 | 0.00% |

### Baseline Power

Vivado vectorless synthesized-power estimate:

| Metric | Value |
|---|---:|
| Total on-chip power | 0.144 W |
| Dynamic power | 0.074 W |
| Device static power | 0.070 W |
| Junction temperature | 25.7 C |
| Confidence level | Low |

Note:

Power confidence is low because this is a synthesized, vectorless estimate
without simulation activity data or post-place-and-route implementation.

### Baseline Timing

Clock constraint:

```text
100 MHz, 10.000 ns period
```

Timing result:

| Metric | Value |
|---|---:|
| WNS | -11.343 ns |
| TNS | -6961.166 ns |
| Setup failing endpoints | 868 |
| Hold slack | 0.139 ns |
| Critical path data delay | 19.235 ns |
| Critical path logic levels | 24 |

Vivado result:

```text
Timing constraints are not met.
```

Critical path reported by Vivado:

```text
Source:      sample_count_reg[3]/C
Destination: u_mag/i_square__1/A[10]
Data delay: 19.235 ns
Logic:       9.954 ns
Route:       9.281 ns
Logic levels: 24
```

Interpretation:

The baseline design is functionally correct but fails the 100 MHz timing
constraint. This is useful for the project because it gives a clear baseline
critical-path problem for the pipelined architecture to improve.

### Pipelined RTL Implementation

Created the pipelined RTL modules:

- `rtl/fir_filter_pipelined.sv`
- `rtl/magnitude_sq_pipelined.sv`
- `rtl/lockin_pipelined_top.sv`

The pipelined design reuses the same NCO, mixer, accumulator, and tracker
modules as the baseline, but adds pipeline registers around the major datapath
sections:

- sample/reference register stage
- I/Q mixer output stage
- pipelined FIR term and adder-tree stages
- pipelined magnitude-square stage
- delayed bin/end-of-bin control stages

The control signals are delayed alongside the datapath:

```text
sample_valid
bin_id
end_of_bin
```

This preserves functional correctness even though the datapath latency is
higher than the baseline.

### Pipelined Testbench

Created:

- `tb/tb_lockin_pipelined.sv`

The testbench uses the same Python-generated vector files and checks the same
expected resonance bin.

### Pipelined Vivado Scripts

Created:

- `vivado/sim_pipelined.tcl`
- `vivado/synth_pipelined.tcl`

### Pipelined RTL Simulation

Command:

```powershell
vivado -mode batch -source vivado/sim_pipelined.tcl
```

Simulation result:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 11 cycles
PASS
```

Conclusion:

The pipelined RTL preserves the same detection result and best-energy value as
the Python model and the baseline RTL.

### Pipelined Synthesis

Command:

```powershell
vivado -mode batch -source vivado/synth_pipelined.tcl
```

Synthesis completed successfully:

```text
synth_design completed successfully
```

Vivado reported non-critical synthesis warnings related to optimized/removed
unused sequential elements, but no synthesis errors or critical warnings.

### Pipelined Resource Utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 1732 | 20800 | 8.33% |
| Slice Registers | 1813 | 41600 | 4.36% |
| DSPs | 20 | 90 | 22.22% |
| Block RAM Tile | 0 | 50 | 0.00% |

### Pipelined Power

Vivado vectorless synthesized-power estimate:

| Metric | Value |
|---|---:|
| Total on-chip power | 0.156 W |
| Dynamic power | 0.086 W |
| Device static power | 0.070 W |
| Junction temperature | 25.8 C |
| Confidence level | Low |

Note:

The pipelined design has slightly higher estimated power than the baseline,
mainly because additional pipeline registers and switching activity increase
dynamic power.

### Pipelined Timing

Clock constraint:

```text
100 MHz, 10.000 ns period
```

Timing result:

| Metric | Value |
|---|---:|
| WNS | 1.004 ns |
| TNS | 0.000 ns |
| Setup failing endpoints | 0 |
| Hold slack | 0.086 ns |
| Critical path data delay | 8.366 ns |
| Critical path logic levels | 16 |

Vivado result:

```text
All user specified timing constraints are met.
```

Critical path reported by Vivado:

```text
Source:      u_fir_i/sum0123_reg[1]/C
Destination: u_mag/i_square0/B[10]
Data delay: 8.366 ns
Logic:       4.668 ns
Route:       3.698 ns
Logic levels: 16
```

Interpretation:

Pipelining reduced the critical path from 19.235 ns in the baseline to 8.366 ns
in the pipelined design. The pipelined design meets the 100 MHz timing
constraint, while the baseline does not.

## Baseline vs Pipelined Comparison

| Metric | Baseline | Pipelined |
|---|---:|---:|
| Correct detected bin | 3 | 3 |
| Best energy | 2926974856033640715 | 2926974856033640715 |
| Simulation result | PASS | PASS |
| 100 MHz timing met | No | Yes |
| WNS | -11.343 ns | 1.004 ns |
| TNS | -6961.166 ns | 0.000 ns |
| Setup failing endpoints | 868 | 0 |
| Critical path data delay | 19.235 ns | 8.366 ns |
| Critical path logic levels | 24 | 16 |
| Approx. minimum period from WNS | 21.343 ns | 8.996 ns |
| Approx. Fmax from WNS | 46.9 MHz | 111.2 MHz |
| Slice LUTs | 1574 | 1732 |
| Slice Registers | 860 | 1813 |
| DSPs | 20 | 20 |
| BRAM Tiles | 0 | 0 |
| Total on-chip power | 0.144 W | 0.156 W |
| Dynamic power | 0.074 W | 0.086 W |
| Static power | 0.070 W | 0.070 W |
| Power confidence | Low | Low |
| Latency after final sample | not separately measured | 11 cycles |

Main result:

```text
The pipelined architecture preserves correctness and meets 100 MHz timing.
It improves WNS by 12.347 ns compared with the baseline, at the cost of
additional registers and latency.
```

The approximate Fmax improvement from the current timing reports is:

```text
111.2 MHz / 46.9 MHz = 2.37x
```

## Post-Route Implementation Results

Implementation scripts created:

- `vivado/impl_baseline.tcl`
- `vivado/impl_pipelined.tcl`

Implementation commands:

```powershell
vivado -mode batch -source vivado/impl_baseline.tcl
vivado -mode batch -source vivado/impl_pipelined.tcl
```

Implementation flow:

```text
synth_design
opt_design
place_design
phys_opt_design
route_design
report_timing_summary
report_utilization
report_power
```

Implementation target:

```text
xc7a35tfgg484-1
```

Reason for using this package:

```text
The current top-level has a wide debug/output interface, especially
best_energy[127:0]. The larger package avoids I/O over-utilization during
place-and-route while keeping the same Artix-7 device family/capacity class.
```

### Baseline Post-Route Timing

| Metric | Value |
|---|---:|
| WNS | -11.142 ns |
| TNS | -7515.269 ns |
| Setup failing endpoints | 888 |
| Hold slack | 0.042 ns |
| Critical path data delay | 19.320 ns |
| Critical path logic levels | 25 |
| Timing met at 100 MHz | No |
| Approx. minimum period from WNS | 21.142 ns |
| Approx. Fmax from WNS | 47.3 MHz |

Baseline post-route critical path:

```text
Source:      sample_count_reg[3]_replica/C
Destination: u_mag/q_square__1/A[24]
Data delay: 19.320 ns
Logic:       9.959 ns
Route:       9.361 ns
Logic levels: 25
```

### Baseline Post-Route Utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 1579 | 20800 | 7.59% |
| Slice Registers | 1309 | 41600 | 3.15% |
| DSPs | 20 | 90 | 22.22% |
| Block RAM Tile | 0 | 50 | 0.00% |

### Baseline Post-Route Power

| Metric | Value |
|---|---:|
| Total on-chip power | 0.157 W |
| Dynamic power | 0.087 W |
| Device static power | 0.070 W |
| Junction temperature | 25.4 C |
| Confidence level | Low |

### Pipelined Post-Route Timing

| Metric | Value |
|---|---:|
| WNS | 0.692 ns |
| TNS | 0.000 ns |
| Setup failing endpoints | 0 |
| Hold slack | 0.017 ns |
| Critical path data delay | 8.778 ns |
| Critical path logic levels | 18 |
| Timing met at 100 MHz | Yes |
| Approx. minimum period from WNS | 9.308 ns |
| Approx. Fmax from WNS | 107.4 MHz |

Pipelined post-route critical path:

```text
Source:      u_fir_i/sum4567_reg[0]/C
Destination: u_mag/i_square0__0/B[12]
Data delay: 8.778 ns
Logic:       4.847 ns
Route:       3.931 ns
Logic levels: 18
```

### Pipelined Post-Route Utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 1680 | 20800 | 8.08% |
| Slice Registers | 2136 | 41600 | 5.13% |
| DSPs | 20 | 90 | 22.22% |
| Block RAM Tile | 0 | 50 | 0.00% |

### Pipelined Post-Route Power

| Metric | Value |
|---|---:|
| Total on-chip power | 0.151 W |
| Dynamic power | 0.081 W |
| Device static power | 0.070 W |
| Junction temperature | 25.4 C |
| Confidence level | Low |

Power note:

Post-route power is still vectorless because no SAIF/VCD switching activity file
has been provided. It is more physical-design-aware than the synthesized power
report, but confidence remains low.

### Post-Route Baseline vs Pipelined Comparison

| Metric | Baseline Post-Route | Pipelined Post-Route |
|---|---:|---:|
| Correct detected bin in RTL sim | 3 | 3 |
| 100 MHz timing met | No | Yes |
| WNS | -11.142 ns | 0.692 ns |
| TNS | -7515.269 ns | 0.000 ns |
| Setup failing endpoints | 888 | 0 |
| Critical path data delay | 19.320 ns | 8.778 ns |
| Critical path logic levels | 25 | 18 |
| Approx. Fmax | 47.3 MHz | 107.4 MHz |
| Slice LUTs | 1579 | 1680 |
| Slice Registers | 1309 | 2136 |
| DSPs | 20 | 20 |
| BRAM Tiles | 0 | 0 |
| Total on-chip power | 0.157 W | 0.151 W |
| Dynamic power | 0.087 W | 0.081 W |
| Static power | 0.070 W | 0.070 W |
| Power confidence | Low | Low |

Post-route main result:

```text
The pipelined architecture still preserves correctness and meets 100 MHz after
place-and-route. The baseline still fails timing. Post-route Fmax improves from
approximately 47.3 MHz to 107.4 MHz, a 2.27x improvement.
```

## Post-Route Clock Sweep for Fmax Characterization

Clock sweep script created:

- `vivado/sweep_post_route_timing.tcl`

Sweep output files:

- `reports/clock_sweep/post_route_clock_sweep.csv`
- `reports/clock_sweep/post_route_clock_sweep_summary.txt`

Command:

```powershell
vivado -mode batch -source vivado/sweep_post_route_timing.tcl
```

Important note:

```text
This sweep is derived from the routed 100 MHz timing checkpoint. Vivado keeps
clock PERIOD read-only after opening a routed checkpoint, so the script extracts
the actual post-route WNS and computes equivalent WNS/pass/fail across the
clock grid. It does not rerun place-and-route at each clock frequency.
```

### Clock Sweep Summary

| Design | Routed 100 MHz WNS | Derived min period | Derived Fmax | Highest passing sweep point | First failing sweep point |
|---|---:|---:|---:|---:|---:|
| Baseline | -11.142 ns | 21.142 ns | 47.299 MHz | 40.000 MHz | 50.000 MHz |
| Pipelined | 0.692 ns | 9.308 ns | 107.434 MHz | 105.263 MHz | 111.111 MHz |

### Clock Sweep Detail

| Design | Period | Frequency | Derived WNS | Result |
|---|---:|---:|---:|---|
| Baseline | 25.000 ns | 40.000 MHz | 3.858 ns | PASS |
| Baseline | 20.000 ns | 50.000 MHz | -1.142 ns | FAIL |
| Baseline | 15.000 ns | 66.667 MHz | -6.142 ns | FAIL |
| Baseline | 12.500 ns | 80.000 MHz | -8.642 ns | FAIL |
| Baseline | 11.000 ns | 90.909 MHz | -10.142 ns | FAIL |
| Baseline | 10.000 ns | 100.000 MHz | -11.142 ns | FAIL |
| Baseline | 9.500 ns | 105.263 MHz | -11.642 ns | FAIL |
| Baseline | 9.000 ns | 111.111 MHz | -12.142 ns | FAIL |
| Baseline | 8.500 ns | 117.647 MHz | -12.642 ns | FAIL |
| Baseline | 8.000 ns | 125.000 MHz | -13.142 ns | FAIL |
| Baseline | 7.500 ns | 133.333 MHz | -13.642 ns | FAIL |
| Pipelined | 25.000 ns | 40.000 MHz | 15.692 ns | PASS |
| Pipelined | 20.000 ns | 50.000 MHz | 10.692 ns | PASS |
| Pipelined | 15.000 ns | 66.667 MHz | 5.692 ns | PASS |
| Pipelined | 12.500 ns | 80.000 MHz | 3.192 ns | PASS |
| Pipelined | 11.000 ns | 90.909 MHz | 1.692 ns | PASS |
| Pipelined | 10.000 ns | 100.000 MHz | 0.692 ns | PASS |
| Pipelined | 9.500 ns | 105.263 MHz | 0.192 ns | PASS |
| Pipelined | 9.000 ns | 111.111 MHz | -0.308 ns | FAIL |
| Pipelined | 8.500 ns | 117.647 MHz | -0.808 ns | FAIL |
| Pipelined | 8.000 ns | 125.000 MHz | -1.308 ns | FAIL |
| Pipelined | 7.500 ns | 133.333 MHz | -1.808 ns | FAIL |

Clock sweep interpretation:

```text
The baseline implementation is only comfortably passing at the 40 MHz sweep
point and has a derived post-route Fmax of 47.299 MHz. The pipelined design
passes through 105.263 MHz and fails at 111.111 MHz, with a derived post-route
Fmax of 107.434 MHz.
```

## Extra Pipeline Boundary Variants

New RTL files:

- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus1_top.sv`
- `rtl/lockin_pipelined_plus5_top.sv`

New testbenches:

- `tb/tb_lockin_pipelined_plus1.sv`
- `tb/tb_lockin_pipelined_plus5.sv`

New Vivado scripts:

- `vivado/sim_pipelined_plus1.tcl`
- `vivado/synth_pipelined_plus1.tcl`
- `vivado/impl_pipelined_plus1.tcl`
- `vivado/sim_pipelined_plus5.tcl`
- `vivado/synth_pipelined_plus5.tcl`
- `vivado/impl_pipelined_plus5.tcl`

Trade-off report files:

- `docs/pipeline_tradeoff_report.md`
- `docs/design_insights_by_stage.md`
- `reports/pipeline_tradeoff_summary.csv`

Trade-off plot files:

- `reports/plots/pipeline_fmax_vs_latency.svg`
- `reports/plots/pipeline_fmax_vs_boundary_stages.svg`
- `reports/plots/pipeline_incremental_fmax_gain.svg`
- `reports/plots/pipeline_area_tradeoff.svg`
- `reports/plots/pipeline_power_tradeoff.svg`

### Extra Boundary Architecture

```text
Original pipelined:
FIR output -> magnitude-square input

Pipelined plus1:
FIR output -> register boundary x1 -> magnitude-square input

Pipelined plus5:
FIR output -> register boundary x5 -> magnitude-square input
```

### Extra Boundary Simulation Results

| Design | Simulation | Detected bin | Best energy | Latency after final sample |
|---|---|---:|---:|---:|
| Pipelined plus1 | PASS | 3 | 2926974856033640715 | 12 cycles |
| Pipelined plus5 | PASS | 3 | 2926974856033640715 | 16 cycles |

### Extra Boundary Synthesis Results

| Metric | Pipelined plus1 | Pipelined plus5 |
|---|---:|---:|
| WNS | 2.291 ns | 2.291 ns |
| TNS | 0.000 ns | 0.000 ns |
| Setup failing endpoints | 0 | 0 |
| Critical path data delay | 7.558 ns | 7.558 ns |
| Critical path logic levels | 16 | 16 |
| Approx. Fmax from WNS | 129.7 MHz | 129.7 MHz |
| Slice LUTs | 1684 | 1878 |
| Slice Registers | 1911 | 2011 |
| DSPs | 20 | 20 |
| BRAM Tiles | 0 | 0 |
| Total on-chip power | 0.156 W | 0.160 W |
| Dynamic power | 0.085 W | 0.089 W |
| Static power | 0.070 W | 0.070 W |
| Power confidence | Low | Low |

### Extra Boundary Post-Route Results

| Metric | Pipelined plus1 | Pipelined plus5 |
|---|---:|---:|
| 100 MHz timing met | Yes | Yes |
| WNS | 1.418 ns | 1.854 ns |
| TNS | 0.000 ns | 0.000 ns |
| Setup failing endpoints | 0 | 0 |
| Hold slack | 0.033 ns | 0.036 ns |
| Critical path data delay | 8.693 ns | 7.697 ns |
| Critical path logic levels | 17 | 18 |
| Derived minimum period | 8.582 ns | 8.146 ns |
| Derived Fmax | 116.523 MHz | 122.760 MHz |
| Highest passing sweep point | 111.111 MHz | 117.647 MHz |
| First failing sweep point | 117.647 MHz | 125.000 MHz |
| Slice LUTs | 1679 | 1777 |
| Slice Registers | 2031 | 2131 |
| DSPs | 20 | 20 |
| BRAM Tiles | 0 | 0 |
| Total on-chip power | 0.147 W | 0.149 W |
| Dynamic power | 0.076 W | 0.078 W |
| Static power | 0.070 W | 0.070 W |
| Power confidence | Low | Low |
| Latency after final sample | 12 cycles | 16 cycles |

Post-route critical paths:

```text
Pipelined plus1:
Source:      u_impl/u_fir_q/sum4567_reg[1]/C
Destination: u_impl/u_fir_q/sample_out_reg[44]/D
Data delay:  8.693 ns
Logic:       4.508 ns
Route:       4.185 ns
Logic levels: 17

Pipelined plus5:
Source:      u_impl/u_accumulator/bin_energy_reg[2]/C
Destination: u_impl/u_tracker/best_energy_reg[2]_lopt_replica/CE
Data delay:  7.697 ns
Logic:       3.052 ns
Route:       4.645 ns
Logic levels: 18
```

### Pipeline Trade-Off Summary

| Design | Extra boundary stages | Latency | Post-route Fmax | LUTs | FFs | Power | Critical path region |
|---|---:|---:|---:|---:|---:|---:|---|
| Baseline | N/A | not measured | 47.299 MHz | 1579 | 1309 | 0.157 W | control/magnitude |
| Pipelined | 0 | 11 cycles | 107.434 MHz | 1680 | 2136 | 0.151 W | FIR-to-magnitude |
| Pipelined plus1 | 1 | 12 cycles | 116.523 MHz | 1679 | 2031 | 0.147 W | FIR final output |
| Pipelined plus5 | 5 | 16 cycles | 122.760 MHz | 1777 | 2131 | 0.149 W | accumulator/tracker |
| Pipelined plus5 tracker | 5 | 17 cycles | 120.135 MHz | 1780 | 2273 | 0.149 W | FIR final output |
| Pipelined plus5 FIR out | 5 | 17 cycles | 125.031 MHz | 1793 | 2239 | 0.148 W | accumulator/tracker |
| Pipelined plus5 FIR out tracker | 5 | 18 cycles | 120.120 MHz | 1794 | 2381 | 0.149 W | magnitude valid to accumulator reset |

Incremental interpretation:

```text
Baseline -> pipelined: +60.135 MHz, very advantageous.
Pipelined -> plus1:    +9.089 MHz for +1 cycle, advantageous.
Plus1 -> plus5:        +6.237 MHz for +4 cycles, diminishing returns.
Plus5 -> plus5 tracker: -2.625 MHz for +1 cycle, not beneficial.
Plus5 -> plus5 FIR out: +2.271 MHz for +1 cycle, modestly beneficial.
Plus5 FIR out -> plus5 FIR out tracker: -4.911 MHz for +1 cycle, not beneficial.
```

The diminishing-return result is plotted in:

```text
reports/plots/pipeline_incremental_fmax_gain.svg
```

Current conclusion:

```text
Pipelined plus1 is the best balanced design so far. Pipelined plus5 is the
former highest-Fmax design, but it shows diminishing returns and moves the
critical path into accumulator/tracker logic. Pipelined plus5 FIR out is now
the highest-Fmax design so far.
```

## Plus5 Tracker Pipeline Experiment

The plus5 design revealed a new post-route bottleneck in the accumulator to
tracker path, so the next experiment added a registered tracker decision stage.

New or updated files:

- `rtl/resonance_tracker_pipelined.sv`
- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus5_tracker_top.sv`
- `tb/tb_lockin_pipelined_plus5_tracker.sv`
- `vivado/sim_pipelined_plus5_tracker.tcl`
- `vivado/synth_pipelined_plus5_tracker.tcl`
- `vivado/impl_pipelined_plus5_tracker.tcl`
- `vivado/sweep_post_route_timing.tcl`

Architecture schematic:

```text
plus5:
FIR -> boundary register x5 -> magnitude -> accumulator -> tracker
                                                     |
                                                     v
                                       critical path into tracker CE

plus5 tracker:
FIR -> boundary register x5 -> magnitude -> accumulator
                                             |
                                             v
                          tracker compare register -> tracker update register
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.291 ns |
| Hold slack | 0.073 ns |
| Critical path delay | 7.558 ns |
| Logic levels | 16 |
| LUTs | 1881 |
| FFs | 2145 |
| DSPs | 20 |
| Total power | 0.160 W |
| Dynamic power | 0.090 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 1.676 ns |
| Hold slack | 0.031 ns |
| Derived min period | 8.324 ns |
| Derived Fmax | 120.135 MHz |
| Highest passing sweep point | 117.647 MHz |
| First failing sweep point | 125.000 MHz |
| LUTs | 1780 |
| FFs | 2273 |
| DSPs | 20 |
| Total power | 0.149 W |
| Dynamic power | 0.079 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/u_fir_i/sum0123_reg[0]/C
Destination: u_impl/u_fir_i/sample_out_reg[47]/D
Data delay:  8.333 ns
Logic:       5.128 ns
Route:       3.205 ns
Logic levels: 19
```

Design insight:

```text
The tracker pipeline is functionally correct and removes the plus5
accumulator/tracker CE path from the top timing report. However, it does not
improve the design. Fmax drops from 122.760 MHz to 120.135 MHz, latency rises
from 16 to 17 cycles, FF count rises from 2131 to 2273, and dynamic power
rises slightly from 0.078 W to 0.079 W. The new worst path moves back into the
FIR final output logic.
```

Decision:

```text
Do not select plus5_tracker over plain plus5. Keep it as a recorded negative
experiment. The next useful optimization target is the FIR final-sum/output
register path.
```

New comparison plot:

```text
reports/plots/tracker_pipeline_comparison.svg
```

## Plus5 FIR Output Pipeline Experiment

The plus5 tracker experiment moved the critical path back into FIR final output
logic, so this experiment directly targeted that path without also changing the
tracker.

New or updated files:

- `rtl/fir_filter_pipelined_outreg.sv`
- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus5_firout_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout.sv`
- `vivado/sim_pipelined_plus5_firout.tcl`
- `vivado/synth_pipelined_plus5_firout.tcl`
- `vivado/impl_pipelined_plus5_firout.tcl`
- `vivado/sweep_post_route_timing.tcl`

Architecture schematic:

```text
plus5:
partial FIR sums -> final_sum / round_shift -> sample_out

plus5 FIR out:
partial FIR sums -> final_sum register -> round_shift -> sample_out
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| Critical path delay | 5.974 ns |
| Logic levels | 1 |
| LUTs | 1894 |
| FFs | 2119 |
| DSPs | 20 |
| Total power | 0.161 W |
| Dynamic power | 0.091 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 2.002 ns |
| Hold slack | 0.028 ns |
| Derived min period | 7.998 ns |
| Derived Fmax | 125.031 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1793 |
| FFs | 2239 |
| DSPs | 20 |
| Total power | 0.148 W |
| Dynamic power | 0.078 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/u_accumulator/bin_energy_reg[16]/C
Destination: u_impl/gen_regular_tracker.u_tracker/best_energy_reg[112]_lopt_replica/CE
Data delay:  7.648 ns
Logic:       2.806 ns
Route:       4.842 ns
Logic levels: 16
```

Design insight:

```text
This result confirms the lesson from plus5_tracker. The FIR final-output path
was a real limiter after the tracker experiment exposed it. Adding the FIR
final_sum register improves Fmax from 122.760 MHz to 125.031 MHz and reaches
the 125 MHz sweep point, but the critical path now returns to the
accumulator/tracker interface.
```

Decision:

```text
Pipelined plus5 FIR out is the new highest-Fmax architecture so far. It is a
modest improvement, not a huge one: +2.271 MHz over plus5 for one extra cycle
and +108 FFs. The follow-on combined experiment shows that the current tracker
pipeline is not the right companion fix.
```

## Plus5 FIR Output Plus Tracker Pipeline Experiment

This experiment combined the two earlier changes: FIR final-sum/output
pipelining plus tracker compare/update pipelining.

New files:

- `rtl/lockin_pipelined_plus5_firout_tracker_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_tracker.sv`
- `vivado/sim_pipelined_plus5_firout_tracker.tcl`
- `vivado/synth_pipelined_plus5_firout_tracker.tcl`
- `vivado/impl_pipelined_plus5_firout_tracker.tcl`

Architecture schematic:

```text
partial FIR sums -> final_sum register -> round_shift -> sample_out
        -> boundary register x5 -> magnitude -> accumulator
        -> tracker compare register -> tracker update register
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 18 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| Critical path delay | 5.974 ns |
| Logic levels | 1 |
| LUTs | 1897 |
| FFs | 2253 |
| DSPs | 20 |
| Total power | 0.161 W |
| Dynamic power | 0.091 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 1.675 ns |
| Hold slack | 0.024 ns |
| Derived min period | 8.325 ns |
| Derived Fmax | 120.120 MHz |
| Highest passing sweep point | 117.647 MHz |
| First failing sweep point | 125.000 MHz |
| LUTs | 1794 |
| FFs | 2381 |
| DSPs | 20 |
| Total power | 0.149 W |
| Dynamic power | 0.079 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/u_mag/valid_out_reg/C
Destination: u_impl/u_accumulator/running_energy_reg[124]/R
Data delay:  7.813 ns
Logic:       0.642 ns
Route:       7.171 ns
Logic levels: 1
```

Design insight:

```text
The combined design is functionally correct, but it is not a good trade-off.
It loses 4.911 MHz versus plus5 FIR out, adds one more cycle, and adds 142 FFs.
The worst path is now dominated by routing from magnitude valid/control into
the accumulator reset path, not by arithmetic.
```

Decision:

```text
Do not select plus5_firout_tracker. Keep plus5_firout as the parent for the
next accumulator-side experiment. The next optimization should target
accumulator control and reset/enable structure directly, instead of using the
current tracker pipeline as the companion fix.
```

## Plus5 FIR Output Plus Accumulator-Output Buffer Experiment

This experiment built on the negative `plus5_firout_tracker` result. Instead
of pipelining the tracker compare/update internals, it adds a clean registered
boundary on the accumulator outputs before they feed the tracker.

New or updated files:

- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf.tcl`
- `vivado/sweep_post_route_timing.tcl`

Architecture schematic:

```text
partial FIR sums -> final_sum register -> round_shift -> sample_out
        -> boundary register x5 -> magnitude -> accumulator
        -> accumulator output buffer -> tracker
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 18 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| Critical path delay | 5.974 ns |
| Logic levels | 1 |
| LUTs | 1895 |
| FFs | 2251 |
| DSPs | 20 |
| Total power | 0.162 W |
| Dynamic power | 0.092 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 2.254 ns |
| Hold slack | 0.022 ns |
| Derived min period | 7.746 ns |
| Derived Fmax | 129.099 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1792 |
| FFs | 2371 |
| DSPs | 20 |
| Total power | 0.148 W |
| Dynamic power | 0.077 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/u_mag/q_square0/CLK
Destination: u_impl/u_mag/q_square_reg[5]/D
Data delay:  7.534 ns
Logic:       5.724 ns
Route:       1.810 ns
Logic levels: 1
```

Near-critical accumulator/tracker path:

```text
Source:      u_impl/bin_energy_buf_reg[28]/C
Destination: u_impl/gen_regular_tracker.u_tracker/best_energy_reg[13]_lopt_replica/CE
Data delay:  7.478 ns
Logic:       2.550 ns
Route:       4.928 ns
Logic levels: 15
```

Design insight:

```text
This is a positive result. Registering accumulator outputs is more effective
than the previous tracker compare/update split. Fmax rises from 125.031 MHz to
129.099 MHz, and the top critical path moves out of accumulator/tracker into
the magnitude DSP register stage. Accumulator/tracker is still nearby in the
top-ten paths, so it remains relevant but is no longer dominant.
```

Decision:

```text
Select plus5_firout_accbuf as the highest-Fmax architecture at this stage.
Keep plus1 as the current best balanced architecture, because accbuf costs
seven extra latency cycles versus the original pipelined design. This result
was later superseded by the energy64 precision-aware variant.
```

## Plus5 FIR Output Accbuf Plus Chunked Magnitude Pipeline Experiment

This experiment tested whether arithmetic parallelization inside the current
magnitude bottleneck would improve Fmax. The 48-bit square was decomposed into
parallel 16-bit partial products and recombined exactly.

New or updated files:

- `rtl/magnitude_sq_chunked_pipeline.sv`
- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_magpipe_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf_magpipe.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_magpipe.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_magpipe.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_magpipe.tcl`
- `vivado/sweep_post_route_timing.tcl`

Architecture schematic:

```text
48-bit filtered I/Q -> hi/mid/lo 16-bit chunks
    -> parallel partial products -> exact square recombination
    -> I^2 + Q^2 -> accumulator -> accumulator output buffer -> tracker
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 19 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 3.338 ns |
| Hold slack | 0.073 ns |
| LUTs | 1968 |
| FFs | 2377 |
| DSPs | 14 |
| Total power | 0.162 W |
| Dynamic power | 0.091 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 2.156 ns |
| Hold slack | 0.027 ns |
| Derived min period | 7.844 ns |
| Derived Fmax | 127.486 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1862 |
| FFs | 2497 |
| DSPs | 14 |
| Total power | 0.152 W |
| Dynamic power | 0.081 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/bin_energy_buf_reg[0]/C
Destination: u_impl/gen_regular_tracker.u_tracker/best_energy_reg[0]_lopt_replica/CE
Data delay:  7.568 ns
Logic:       2.946 ns
Route:       4.622 ns
Logic levels: 18
```

Design insight:

```text
The chunked magnitude pipeline is correct and saves DSPs, but it is not a
highest-Fmax improvement. DSP usage drops from 20 to 14, but Fmax drops from
129.099 MHz to 127.486 MHz and latency rises from 18 to 19 cycles. The
critical path returns to accumulator-output-buffer to tracker CE logic.
```

Decision:

```text
Do not replace plus5_firout_accbuf for speed. Record this variant as a
DSP-saving experiment. For the next speed experiment, target the tracker CE
path exposed again by magpipe.
```

## Plus5 FIR Output Accbuf Plus Tracker Compare Pipeline Experiment

This experiment tested whether the accumulator-output-buffer to tracker CE
pressure could be reduced by adding a two-stage compare pipeline inside the
tracker.

New or updated files:

- `rtl/resonance_tracker_compare_pipeline.sv`
- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_trackercmp_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf_trackercmp.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_trackercmp.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_trackercmp.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_trackercmp.tcl`
- `vivado/sweep_post_route_timing.tcl`

Architecture schematic:

```text
FIR final_sum register -> boundary x5 -> magnitude -> accumulator
                                               |
                                               v
                         accumulator output buffer -> tracker candidate reg
                                                    -> compare/update reg
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 20 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| LUTs | 1896 |
| FFs | 2517 |
| DSPs | 20 |
| Total power | 0.164 W |
| Dynamic power | 0.093 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 1.872 ns |
| Hold slack | 0.037 ns |
| Derived min period | 8.128 ns |
| Derived Fmax | 123.031 MHz |
| Highest passing sweep point | 117.647 MHz |
| First failing sweep point | 125.000 MHz |
| LUTs | 1793 |
| FFs | 2645 |
| DSPs | 20 |
| Total power | 0.152 W |
| Dynamic power | 0.081 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/gen_fir_outreg.u_fir_q/final_sum_reg_reg[0]/C
Destination: u_impl/gen_fir_outreg.u_fir_q/sample_out_reg[47]/D
Data delay:  8.133 ns
Logic:       4.102 ns
Route:       4.031 ns
Logic levels: 16
```

Design insight:

```text
The tracker compare pipeline is functionally correct, but it is not a speed
improvement. Fmax drops from 129.099 MHz to 123.031 MHz, latency rises from 18
to 20 cycles, and FF count rises from 2371 to 2645. The critical path moves
back into FIR final-output logic, so the current simple tracker compare split
is another recorded negative experiment.
```

Decision:

```text
Do not replace plus5_firout_accbuf. Keep plus5_firout_accbuf as the speed
parent at this stage. The next speed experiment should inspect FIR
final-output placement/retiming and accumulator-to-tracker CE/control fanout
together, not simply add more tracker-side registers.
```

## Current-Best Bottleneck Diagnostic

We ran a focused diagnostic pass on the routed
`pipelined_plus5_firout_accbuf` checkpoint instead of creating another
architecture immediately.

New file:

- `vivado/diagnose_pipelined_plus5_firout_accbuf.tcl`

Diagnostic reports:

- `reports/diagnostics/pipelined_plus5_firout_accbuf/top20_setup_paths.csv`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/top20_region_summary.csv`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/high_fanout_nets.rpt`
- `reports/diagnostics/pipelined_plus5_firout_accbuf/top10_setup_paths_full_clock.rpt`
- `docs/bottleneck_diagnostic_accbuf.md`

Top-20 setup path distribution:

| Region | Paths in top 20 | Worst slack |
|---|---:|---:|
| Magnitude | 11 | 2.254 ns |
| Accumulator/tracker | 9 | 2.309 ns |

High-fanout clues:

| Net | Fanout |
|---|---:|
| `rst_IBUF` | 2188 |
| `u_impl/valid_s2` | 591 |
| `u_impl/gen_fir_outreg.u_fir_i/E[0]` | 405 |
| `u_impl/gen_regular_tracker.u_tracker/best_energy[127]_i_1_n_0` | 251 |
| `u_impl/gen_fir_outreg.u_fir_i/valid_p2_reg_0[0]` | 225 |
| `u_impl/u_mag/E[0]` | 132 |
| `u_impl/u_mag/valid_out` | 130 |

Diagnostic insight:

```text
The current best design is balanced between magnitude DSP delay and
route-heavy accumulator/tracker CE paths. The high-fanout valid/enable/control
nets explain why isolated datapath-only or tracker-only changes can make the
design slower. The next speed experiment should focus on reducing
control/enable fanout while preserving the current datapath architecture.
```

Recommended next experiment:

```text
pipelined_plus5_firout_accbuf_fanout
```

The first attempt should replicate/localize high-fanout valid and enable
signals around the FIR, magnitude, accumulator-output buffer, and tracker
update decision without changing arithmetic precision.

## Fanout Experiment Stage-A Early-Stop Probe

We added a separate fanout trial branch and ran only the early sanity gate:

```text
synth_design -> opt_design -> place_design
```

New RTL:

- `rtl/fir_filter_pipelined_outreg_fanout.sv`
- `rtl/magnitude_sq_pipelined_fanout.sv`
- `rtl/resonance_tracker_fanout.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_fanout_top.sv`

New Vivado script:

- `vivado/place_probe_pipelined_plus5_firout_accbuf_fanout.tcl`

Detailed note:

- `docs/fanout_early_stop_probe.md`

Stage-A fanout result:

| Control/fanout item | Before routed accbuf | Fanout probe after place | Gate result |
|---|---:|---:|---|
| `valid_s2` control | 591 | replicated into about 98-fanout nets | Pass |
| FIR I enable/control | 405 | about 101-113 | Pass |
| FIR valid P2 control | 225 | about 113 | Pass |
| Magnitude `valid_out` | 130 | 64 plus one 64-fanout replica | Pass |
| Magnitude enable | 132 | 132 | No improvement |
| Tracker update/CE | 251 | 251 | No improvement |

Stage-A post-place snapshot:

| Metric | Value |
|---|---:|
| Setup WNS | 2.144 ns |
| Hold WNS | -0.081 ns |
| LUTs | 1794 |
| FFs | 2393 |
| DSPs | 20 |

Early-stop verdict:

```text
The sanity gate passed enough to justify a full route attempt, but confidence
is moderate. Several FIR/valid control fanouts dropped strongly, but the
tracker update/CE fanout did not improve. Continue only with the strict
success criterion that post-route Fmax must beat 129.099 MHz.
```

## Fanout Experiment Stage-B Full Route

The fanout branch was advanced to full simulation, implementation, and the
standard post-route sweep.

New files:

- `tb/tb_lockin_pipelined_plus5_firout_accbuf_fanout.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_fanout.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_fanout.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_fanout.tcl`

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| LUTs | 1906 |
| FFs | 2273 |
| DSPs | 20 |
| Total power | 0.162 W |
| Dynamic power | 0.092 W |
| Static power | 0.070 W |

Post-route implementation result:

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

Design insight:

```text
The fanout hints reduce several major valid/FIR fanout nets, but do not improve
top-line Fmax. Fmax drops from 129.099 MHz to 127.162 MHz, and the top path
remains the magnitude DSP path. Tracker update/CE fanout also remains at 251.
```

Decision:

```text
Do not replace plus5_firout_accbuf. Record fanout as a partial/negative speed
experiment: it proves the fanout hints work mechanically, but they are not
enough to move the current Fmax limit.
```

## Energy64 Precision-Aware Architecture Experiment

This experiment changed the architecture as a whole instead of adding another
local register or fanout hint. A broad Python precision sweep from 16 through
256 bits showed that the current golden vectors have a maximum energy bit
length of 62 bits, so a 64-bit energy datapath is exact for this stimulus set.

New or updated files:

- `python/energy_precision_sweep.py`
- `docs/energy_precision_sweep.md`
- `rtl/magnitude_sq_narrow_pipelined.sv`
- `rtl/lockin_pipelined_boundary_top.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_energy64_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf_energy64.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_energy64.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_energy64.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_energy64.tcl`
- `vivado/sweep_post_route_timing.tcl`

Architecture schematic:

```text
FIR final_sum register -> boundary x5 -> narrowed 64-bit magnitude energy
                                      -> 64-bit accumulator output buffer
                                      -> 64-bit tracker
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Precision sweep result:

| Metric | Value |
|---|---:|
| Reference detected bin | 3 |
| Reference best energy | 2926974856033640715 |
| Maximum reference energy bit length | 62 |
| Sweep range | 16 to 256 bits |
| Smallest exact tested width | 62 bits |
| Smallest bin-preserving tested width | 30 bits, not energy-exact |
| Practical RTL target already tested | 64 bits |

Precision sweep outputs:

- `reports/energy_precision_sweep.csv`
- `reports/plots/energy_precision_sweep_16_to_256.svg`
- `docs/energy_precision_sweep.md`

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| Critical path delay | 5.974 ns |
| Logic levels | 1 |
| LUTs | 1561 |
| FFs | 1987 |
| DSPs | 18 |
| Total power | 0.152 W |
| Dynamic power | 0.081 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 2.548 ns |
| Hold slack | 0.085 ns |
| Derived min period | 7.452 ns |
| Derived Fmax | 134.192 MHz |
| Highest passing sweep point | 133.333 MHz |
| First failing sweep point | not observed in current sweep |
| LUTs | 1509 |
| FFs | 2043 |
| DSPs | 18 |
| Total power | 0.141 W |
| Dynamic power | 0.070 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/gen_narrow_mag.u_mag/q_square0__3/CLK
Destination: u_impl/gen_narrow_mag.u_mag/q_square_reg__0/PCIN[0]
Data delay:  5.977 ns
Logic levels: 1
```

Design insight:

```text
This is a positive architecture-level result. The local follow-ups after accbuf
either lowered Fmax or traded speed for resources. Energy64 improves Fmax from
129.099 MHz to 134.192 MHz while reducing LUTs, FFs, DSPs, and vectorless
power. The critical path remains in the magnitude DSP cascade, but the
accumulator/tracker contract is much narrower.
```

Decision:

```text
Select plus5_firout_accbuf_energy64 as the new highest-Fmax design for the
current vectors. Keep the precision caveat visible: 64 bits is exact for the
current generated vectors, but must be rechecked if amplitude, FIR scaling,
sample count, bin count, or accumulation window changes.
```

## Energy62 Exact-Threshold Architecture Experiment

This experiment tested whether using the true 62-bit exact threshold from the
precision sweep improves over the more alignment-friendly 64-bit Energy64
variant.

New files:

- `rtl/lockin_pipelined_plus5_firout_accbuf_energy62_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf_energy62.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_energy62.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_energy62.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_energy62.tcl`

Architecture schematic:

```text
FIR final_sum register -> boundary x5 -> narrowed 62-bit magnitude energy
                                      -> 62-bit accumulator output buffer
                                      -> 62-bit tracker
```

Functional simulation:

```text
Expected bin: 3
Detected bin: 3
Best energy:  2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Synthesis result:

| Metric | Value |
|---|---:|
| WNS | 2.446 ns |
| Hold slack | 0.073 ns |
| LUTs | 1550 |
| FFs | 1977 |
| DSPs | 18 |
| Total power | 0.151 W |
| Dynamic power | 0.081 W |
| Static power | 0.070 W |

Post-route implementation result:

| Metric | Value |
|---|---:|
| WNS | 2.549 ns |
| Hold slack | 0.079 ns |
| Derived min period | 7.451 ns |
| Derived Fmax | 134.210 MHz |
| Highest passing sweep point | 133.333 MHz |
| First failing sweep point | not observed in current sweep |
| LUTs | 1499 |
| FFs | 2033 |
| DSPs | 18 |
| Total power | 0.140 W |
| Dynamic power | 0.070 W |
| Static power | 0.070 W |

Post-route critical path:

```text
Source:      u_impl/gen_narrow_mag.u_mag/q_square0__3/CLK
Destination: u_impl/gen_narrow_mag.u_mag/q_square_reg__0/PCIN[0]
Data delay:  5.977 ns
Logic levels: 1
```

Design insight:

```text
Energy62 is correct and slightly improves Energy64: +0.018 MHz Fmax, -10 LUTs,
-10 FFs, and -0.001 W total vectorless power. The critical path is unchanged,
so this is an exact-threshold polish rather than a new architectural jump.
```

Decision:

```text
Record Energy62 as the highest-Fmax datapoint at this stage. Keep Energy64 as
an aligned-width fallback, because the Energy62 improvement is very small and
both widths require broader stimulus validation before being treated as general.
```

## Synthesis vs Post-Route Summary

| Design | Stage | WNS | Timing Met | LUTs | FFs | DSPs | Total Power |
|---|---|---:|---|---:|---:|---:|---:|
| Baseline | Synthesis | -11.343 ns | No | 1574 | 860 | 20 | 0.144 W |
| Baseline | Post-route | -11.142 ns | No | 1579 | 1309 | 20 | 0.157 W |
| Pipelined | Synthesis | 1.004 ns | Yes | 1732 | 1813 | 20 | 0.156 W |
| Pipelined | Post-route | 0.692 ns | Yes | 1680 | 2136 | 20 | 0.151 W |

## FIR/Magnitude Width Sweep and Energy62 FIR29 Result

Goal:

```text
Both Energy64 and Energy62 shared the same post-route critical path in the
narrowed magnitude DSP cascade. The next question was whether the FIR outputs
and magnitude-square inputs were still wider than the current vectors require.
```

Generated/updated files:

- `python/fir_mag_width_sweep.py`
- `reports/fir_mag_width_sweep.csv`
- `reports/plots/fir_mag_width_sweep.svg`
- `docs/fir_mag_width_sweep.md`
- `rtl/magnitude_sq_narrow_pipelined.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_energy62_fir29_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf_energy62_fir29.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29.tcl`

Python sweep result:

```text
Maximum absolute FIR I/Q value: 244435018
Signed bits required for exact FIR I/Q values: 29
Smallest exact width tested: 29
Smallest bin-preserving width tested: 16
```

Interpretation:

```text
The 16-bit bin-preserving result is not a safe architecture choice because it
changes energy values. The safe follow-up is FIR_OUT_WIDTH=29, which exactly
preserves the current-vector FIR I/Q values before magnitude square.
```

Energy62 FIR29 post-route result:

```text
Simulation: PASS
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
WNS: 2.994 ns
Derived min period: 7.006 ns
Derived Fmax: 142.735 MHz
LUTs: 1379
FFs: 1912
DSPs: 10
BRAM: 0
Total power: 0.126 W
Dynamic power: 0.056 W
Static power: 0.070 W
Critical path: FIR final_sum register to FIR sample_out register
```

Design insight:

```text
This is a positive architectural result. Energy62 FIR29 directly removes the
magnitude DSP cascade as the best-design bottleneck, improves Fmax by
8.525 MHz over Energy62, saves eight DSPs, and lowers vectorless power by
0.014 W without adding latency. The new bottleneck is FIR output rounding.
```

## FIR29 Fast-Round Bottleneck Experiment

Goal:

```text
FIR29 moved the top setup path to FIR final_sum-to-sample_out round/shift
logic. The experiment replaced the old sign-aware negate/add/negate expression
with an equivalent sign-biased arithmetic shift.
```

Generated/updated files:

- `rtl/fir_filter_pipelined_outreg_fast_round.sv`
- `rtl/lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_top.sv`
- `tb/tb_lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.sv`
- `vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.tcl`
- `vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.tcl`
- `vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.tcl`

Functional result:

```text
Simulation: PASS
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
```

Post-route implementation result:

```text
WNS: 3.885 ns
Derived min period: 6.115 ns
Derived Fmax: 163.532 MHz
LUTs: 1285
FFs: 1912
DSPs: 10
BRAM: 0
Total power: 0.125 W
Dynamic power: 0.055 W
Static power: 0.070 W
Critical path: magnitude valid to accumulator reset routing
```

Design insight:

```text
This is a strong positive result. Fast-round improves Fmax by 20.797 MHz over
FIR29 with no added latency and no DSP cost. The FIR output round/shift path is
no longer the limiter; the new bottleneck is route-dominated accumulator
control/reset driven by magnitude valid.
```

## Accumulator Start-Load Bottleneck Experiment

Goal:

```text
Attack the fast-round design's magnitude-valid to accumulator reset/control
path in a specific way: remove the end-of-bin clear of running_energy and
replace it with start-of-bin overwrite/load.
```

Architecture change:

```text
Old accumulator:
valid && end_of_bin -> running_energy <= 0

New accumulator:
valid && start_of_bin -> running_energy <= mag_sq
valid && !start_of_bin -> running_energy <= running_energy + mag_sq
valid && end_of_bin -> bin_energy <= accumulated_energy
```

Files added or updated:

```text
rtl/bin_accumulator_startload.sv
rtl/lockin_pipelined_boundary_top.sv
rtl/lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart_top.sv
tb/tb_lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.sv
vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.tcl
vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.tcl
vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.tcl
```

Simulation result:

```text
Expected bin: 3
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Post-route implementation result:

```text
WNS: 1.465 ns
Derived min period: 8.535 ns
Derived Fmax: 117.165 MHz
Highest passing sweep point: 111.111 MHz
First failing sweep point: 117.647 MHz
LUTs: 1342
FFs: 1900
DSPs: 10
BRAM: 0
Total power: 0.126 W
Dynamic power: 0.056 W
Static power: 0.070 W
Critical path: FIR valid_p1 to FIR partial-sum CE fanout
```

Design insight:

```text
This is a targeted negative result. The accumulator reset path was structurally
removed from the top timing path, so the original diagnosis was not random.
However, the start-load rewrite changes control/placement enough that a worse
route-dominated FIR valid-to-CE fanout path appears. The design is correct but
not faster, so it should not replace FIR29 fast-round.
```

## Always-On FIR Plus Accumulator Start-Load Experiment

Goal:

```text
Target both bounds exposed by the prior results: remove the FIR valid/CE
fanout path that made accstart fail, while keeping the accumulator start-load
rewrite that removed the reset-style running_energy clear.
```

Architecture change:

```text
Old fast-round FIR:
valid_p1/valid_p2 gate FIR arithmetic registers through clock-enable paths.

New always-on fast-round FIR:
FIR arithmetic datapath updates every cycle.
valid is delayed separately only to mark which outputs are meaningful.
Accumulator uses start-of-bin overwrite/load instead of end-of-bin clear.
```

Files added or updated:

```text
rtl/fir_filter_pipelined_outreg_fast_round_alwayson.sv
rtl/lockin_pipelined_boundary_top.sv
rtl/lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart_top.sv
tb/tb_lockin_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.sv
vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.tcl
vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.tcl
vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.tcl
```

Simulation result:

```text
Expected bin: 3
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
PASS
```

Post-route implementation result:

```text
WNS: 4.091 ns
Derived min period: 5.909 ns
Derived Fmax: 169.233 MHz
Highest passing sweep point: 133.333 MHz
First failing sweep point: not observed in current sweep
LUTs: 1342
FFs: 1831
DSPs: 10
BRAM: 0
Total power: 0.125 W
Dynamic power: 0.055 W
Static power: 0.070 W
Critical path: magnitude-square carry chain
```

Design insight:

```text
This is the new highest-Fmax result. Accstart alone was negative because FIR
valid/CE fanout became the dominant routed path. Removing valid-driven FIR
arithmetic CEs makes the same accumulator start-load structure beneficial:
Fmax improves by 52.068 MHz versus accstart and by 5.701 MHz versus FIR29
fast-round. The current top bottleneck is now magnitude-square carry logic,
not FIR fanout and not accumulator reset/control.
```

Caveat:

```text
The always-on FIR datapath assumes the current continuous-valid frame behavior.
If the interface later allows arbitrary sample_valid stalls inside a frame,
this variant needs stall-aware validation or a revised enable strategy.
```

## Current Project Status

| Phase | Status |
|---|---|
| Project folder setup | Complete |
| Python golden model | Complete |
| Vector generation | Complete |
| Baseline RTL modules | Complete |
| Baseline RTL simulation | Complete, PASS |
| Baseline synthesis | Complete |
| Baseline timing/resource collection | Complete |
| Pipelined RTL architecture | Complete |
| Pipelined simulation | Complete, PASS |
| Pipelined synthesis | Complete |
| Baseline vs pipelined comparison | Complete |
| Baseline implementation | Complete, timing fails |
| Pipelined implementation | Complete, timing passes |
| Synthesis vs implementation comparison | Complete |
| Post-route clock sweep / Fmax characterization | Complete |
| Pipelined plus1 RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 tracker RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 FIR out RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 FIR out tracker RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 FIR out accbuf RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 FIR out accbuf magpipe RTL/sim/synth/implementation/sweep | Complete |
| Pipelined plus5 FIR out accbuf trackercmp RTL/sim/synth/implementation/sweep | Complete |
| Current-best bottleneck diagnostic | Complete |
| Fanout experiment Stage-A place probe | Complete |
| Fanout experiment Stage-B full route/sweep | Complete |
| Energy64 precision sweep and RTL full route/sweep | Complete |
| Energy62 exact-threshold RTL full route/sweep | Complete |
| FIR/magnitude width sweep and Energy62 FIR29 RTL full route/sweep | Complete |
| FIR29 fast-round RTL full route/sweep | Complete |
| Accumulator start-load RTL full route/sweep | Complete, negative result |
| Always-on FIR plus accumulator start-load RTL full route/sweep | Complete, new highest-Fmax |
| Pipeline trade-off report | Complete |

## Standing Update Checklist

For every future design decision or architecture variant, update:

- `docs/progress_results.md`
- `docs/architecture_schematics.md`
- `docs/design_insights_by_stage.md`

Each update must include:

- [ ] Architecture change description
- [ ] Updated visual schematic/block diagram
- [ ] Functional simulation result
- [ ] Timing result
- [ ] Critical path summary
- [ ] Area/resource utilization
- [ ] Power result
- [ ] Latency and throughput impact
- [ ] Design insight and next implication
- [ ] Clear label: synthesis result or post-implementation result
- [ ] Warnings/caveats/assumptions

All reported numbers must be labeled as synthesis or post-route/implemented
results. The current trade-off decisions use post-route implementation numbers
unless a table explicitly says synthesis.

## Key Takeaways So Far

Detailed stage-by-stage insights are maintained in:

- `docs/design_insights_by_stage.md`

Report framing:

```text
The final report should keep every decision and branch we tried. It should not
collapse the project into only "baseline architecture" and "final
architecture." The correct narrative is a design-decision chain: each new
variant was created because the previous simulation/timing/critical-path
reports pointed to a specific bottleneck or hypothesis.
```

- The Python golden model detects resonance bin 3.
- The baseline RTL detects the same bin as the Python model.
- The baseline RTL simulation passes.
- Vivado synthesis completes successfully.
- The baseline uses 1574 LUTs, 860 FFs, and 20 DSPs.
- The baseline fails the 100 MHz timing constraint with WNS of -11.343 ns.
- The pipelined design uses 1732 LUTs, 1813 FFs, and 20 DSPs.
- The pipelined design meets the 100 MHz timing constraint with WNS of 1.004 ns.
- Pipelining improves the critical path delay from 19.235 ns to 8.366 ns.
- The cost of pipelining is higher register usage and higher latency.
- Post-route implementation confirms the main claim: baseline fails 100 MHz,
  while pipelined meets 100 MHz.
- Post-route approximate Fmax improves from 47.3 MHz to 107.4 MHz.
- Pipelined plus1 improves post-route Fmax to 116.5 MHz with one extra cycle.
- Pipelined plus5 improves post-route Fmax to 122.8 MHz, but adds five cycles
  and moves the critical path into accumulator/tracker logic.
- Pipelined plus5 tracker is functionally correct, but it lowers Fmax to
  120.1 MHz, adds one more latency cycle, and moves the critical path back
  into the FIR final output path.
- Pipelined plus5 FIR out improves post-route Fmax to 125.0 MHz and passes the
  125 MHz sweep point, but moves the critical path back to accumulator/tracker.
  It is now a former highest-Fmax design.
- Pipelined plus5 FIR out tracker is functionally correct, but drops Fmax to
  120.1 MHz and exposes a routed magnitude-valid to accumulator-reset path.
- Pipelined plus5 FIR out accbuf improves post-route Fmax to 129.1 MHz and
  moves the worst setup path into the magnitude DSP register stage.
- Pipelined plus5 FIR out accbuf magpipe reduces DSP usage from 20 to 14, but
  lowers Fmax to 127.5 MHz and moves the critical path back to tracker CE.
- Pipelined plus5 FIR out accbuf trackercmp is functionally correct, but lowers
  Fmax to 123.0 MHz, adds two cycles versus accbuf, and moves the critical path
  back into FIR final-output logic.
- Pipelined plus5 FIR out accbuf fanout reduces several high-fanout valid/FIR
  control nets, but lowers Fmax to 127.2 MHz and leaves tracker update/CE
  fanout high.
- Pipelined plus5 FIR out accbuf energy64 narrows the energy datapath to 64
  bits after a broad 16-to-256-bit Python precision sweep. The sweep shows the
  true exact threshold is 62 bits, while 64 bits remains the practical aligned
  RTL target. Energy64 improves post-route Fmax to 134.2 MHz while reducing
  LUTs, FFs, DSPs, and vectorless power.
- Pipelined plus5 FIR out accbuf energy62 uses the true 62-bit exact threshold.
  It reached 134.210 MHz, but the gain over Energy64 is marginal.
- The FIR/magnitude width sweep found that the current vectors require 29
  signed FIR I/Q bits for exact preservation. Narrower bin-preserving widths
  are not safe because they change the energy values.
- Pipelined plus5 FIR out accbuf energy62 FIR29 narrows FIR_OUT_WIDTH from 48
  to 29 while keeping ENERGY_WIDTH at 62. It preserves detected bin 3 and best
  energy 2926974856033640715, keeps latency at 17 cycles, improves post-route
  derived Fmax to 142.735 MHz, and reduces post-route resources to 1379 LUTs,
  1912 FFs, 10 DSPs, and 0.126 W.
- The Energy62 FIR29 critical path moved out of the magnitude DSP cascade and
  into the FIR final_sum-to-sample_out round/shift path.
- Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round replaces the FIR
  output round/shift with an equivalent sign-biased arithmetic shift. It
  preserves detected bin 3 and best energy 2926974856033640715, keeps latency
  at 17 cycles, improves post-route derived Fmax to 163.532 MHz, and reduces
  post-route resources to 1285 LUTs, 1912 FFs, 10 DSPs, and 0.125 W.
- The FIR29 fast-round critical path moved out of FIR output rounding and into
  route-dominated magnitude-valid to accumulator reset/control logic.
- The accumulator start-load experiment removed the targeted reset-style
  `running_energy` clear path, but lowered Fmax to 117.165 MHz because the new
  top path became FIR valid_p1 to FIR partial-sum CE fanout with fanout 405.
- The always-on FIR plus accumulator start-load experiment removes that FIR
  valid/CE fanout by letting FIR arithmetic update every cycle and carrying
  valid separately. It preserves detected bin 3 and best energy
  2926974856033640715, keeps latency at 17 cycles, improves post-route derived
  Fmax to 169.233 MHz, and uses 1342 LUTs, 1831 FFs, 10 DSPs, and 0.125 W.
- The current critical path is now the narrowed magnitude-square carry chain:
  `u_impl/gen_narrow_mag.u_mag/i_square_reg__0/CLK` to
  `u_impl/gen_narrow_mag.u_mag/mag_sq_reg[57]/D`.

## Next Steps

1. Keep `pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart` as the current highest-Fmax design for the current continuous-valid vectors.
2. Treat `pipelined_plus5_firout_accbuf_fanout` as recorded partial/negative
   result, not as the selected architecture.
3. Keep `pipelined_plus1` as the current best balanced design.
4. Broaden precision/stimulus validation for both the 62-bit energy contract
   and the 29-bit FIR/magnitude contract before freezing either width as a
   general design choice.
5. Keep `pipelined_plus5_firout_accbuf_magpipe` as a DSP-saving option, not as
   the speed winner.
6. Target the narrowed magnitude-square carry chain next. Monitor the
   accumulator iteration bound, but it is not the active top bottleneck after
   the always-on FIR fanout cleanup.
7. Optionally add peak-vs-dip detection mode.
8. Optionally create a reduced-I/O implementation wrapper for a smaller package.
