# Pipeline Trade-Off Report

Last updated: May 4, 2026

## Purpose

This report records the complete architecture exploration path, not just a
baseline-versus-final comparison. Every design branch is kept because each one
answered a specific question about the current bottleneck: whether a register
boundary, arithmetic restructuring, fanout control, or precision change was the
right lever.

The report therefore treats negative results as useful evidence. A failed
variant is still part of the design logic if it moved the critical path,
exposed a new bottleneck, reduced a resource, or showed that a tempting change
was not worth its latency/area/power cost.

This report also compares the current architecture variants to show when
additional pipelining is useful and when it begins to give diminishing returns.

The stage-by-stage design-decision narrative is maintained in:

```text
docs/design_insights_by_stage.md
```

The currently recorded variants are:

- `pipelined_plus1`: one extra registered boundary between FIR output and
  magnitude-square input
- `pipelined_plus5`: five extra registered boundaries between FIR output and
  magnitude-square input
- `pipelined_plus5_tracker`: the plus5 design plus a registered tracker
  compare/update boundary
- `pipelined_plus5_firout`: the plus5 design plus a registered FIR final-sum
  output boundary
- `pipelined_plus5_firout_tracker`: combines the FIR-output split and tracker
  compare/update split
- `pipelined_plus5_firout_accbuf`: keeps the FIR-output split and registers
  accumulator outputs before the tracker
- `pipelined_plus5_firout_accbuf_magpipe`: adds chunked/parallel 16-bit
  partial-product magnitude squaring on top of `plus5_firout_accbuf`
- `pipelined_plus5_firout_accbuf_trackercmp`: keeps `plus5_firout_accbuf` and
  adds a two-stage tracker compare pipeline
- `pipelined_plus5_firout_accbuf_fanout`: keeps `plus5_firout_accbuf` and adds
  fanout hints/replication pressure on valid, enable, and tracker control nets
- `pipelined_plus5_firout_accbuf_energy64`: keeps `plus5_firout_accbuf`, but
  narrows the accumulated-energy datapath to 64 bits after a broad 16-to-256
  bit Python precision sweep showed this is exact for the current vectors
- `pipelined_plus5_firout_accbuf_energy62`: keeps the same precision-aware
  architecture but uses the true 62-bit exact threshold from the sweep
- `pipelined_plus5_firout_accbuf_energy62_fir29`: keeps Energy62 but narrows
  FIR outputs and magnitude-square inputs from 48 signed bits to the exact
  29-bit threshold from the FIR/magnitude width sweep
- `pipelined_plus5_firout_accbuf_energy62_fir29_fastround`: keeps FIR29 but
  replaces the FIR output round/shift expression with an equivalent
  sign-biased arithmetic shift that removes the negate/add/negate structure
- `pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart`: keeps
  fast-round and replaces the accumulator end-clear/reset with start-of-bin
  overwrite/load; recorded as a negative branch because FIR valid/CE fanout
  becomes dominant
- `pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart`:
  keeps accumulator start-load, but changes the fast-round FIR datapath to
  run every cycle so `valid` is only a validity pipeline, not a high-fanout
  arithmetic clock-enable

## Method

Each variant was run through the same flow:

1. RTL simulation against Python-generated vectors
2. Vivado synthesis
3. Vivado post-route implementation
4. Derived post-route clock sweep from the routed 100 MHz checkpoint
5. Timing, area, power, latency, and critical-path recording

Clock-sweep caveat:

```text
The clock sweep is derived from the routed 100 MHz timing checkpoint. It does
not rerun place-and-route at each clock frequency.
```

Power caveat:

```text
Power is Vivado vectorless power. Confidence is Low because no SAIF/VCD
switching activity file has been provided.
```

## Design Decision Log

| Step | Design decision | Bottleneck or question targeted | Result | Kept for final architecture? | Logic learned |
|---|---|---|---|---|---|
| 1 | Build Python golden model | Need a correctness reference before hardware changes | Expected bin 3, best energy `2926974856033640715` | Yes, as reference | Timing improvements only matter if detected bin stays correct |
| 2 | Baseline RTL | Establish direct hardware datapath and initial timing | PASS sim, but post-route Fmax only 47.299 MHz | No | Direct datapath is functionally correct but timing-infeasible at 100 MHz |
| 3 | Original pipelining | Long baseline combinational path through FIR/magnitude | Fmax rises to 107.434 MHz | Yes, foundational | Registering major DSP stages is the first large win |
| 4 | Plus1 FIR-to-magnitude boundary | Remaining FIR-to-magnitude pressure | Fmax rises to 116.523 MHz | Yes, as best balanced option | One extra boundary gives strong gain for one cycle |
| 5 | Plus5 FIR-to-magnitude boundary | Test deeper boundary pipelining | Fmax rises to 122.760 MHz | Partially, as parent idea | More stages help, but return diminishes and bottleneck moves downstream |
| 6 | Plus5 tracker pipeline | Accumulator/tracker CE path | Fmax drops to 120.135 MHz | No | Tracker staging alone moves the bottleneck back to FIR output |
| 7 | Plus5 FIR output split | FIR output path exposed by tracker experiment | Fmax rises to 125.031 MHz | Yes, used in later parents | The negative tracker result correctly identified FIR final output as real |
| 8 | FIR output plus tracker pipeline | Combine two local fixes | Fmax drops to 120.120 MHz | No | Correct local fixes can compose poorly; routed control/reset path dominates |
| 9 | FIR output plus accumulator-output buffer | Cleaner accumulator/tracker boundary | Fmax rises to 129.099 MHz | Yes, becomes speed parent | Buffering accumulator outputs works better than splitting tracker internals |
| 10 | Chunked magnitude pipeline | Parallelize magnitude square and reduce DSP pressure | Fmax drops to 127.486 MHz, DSPs drop to 14 | No for speed; yes as DSP-saving note | Arithmetic parallelization saves DSPs but re-exposes tracker CE bottleneck |
| 11 | Tracker compare pipeline after accbuf | Tracker CE/compare pressure after magpipe | Fmax drops to 123.031 MHz | No | More tracker registers add latency/FFs and move bottleneck back to FIR |
| 12 | Fanout-hint branch | High-fanout valid/enable/control nets | Fmax drops to 127.162 MHz | No | Fanout reduction helps mechanically but does not beat magnitude/CE limits |
| 13 | Energy64 precision-aware datapath | Over-wide 128-bit energy state in accumulator/tracker | Fmax rises to 134.192 MHz, area/power/DSPs drop | Yes, former highest-Fmax precision parent | Changing the datapath precision contract is more effective than more local tweaks |
| 14 | Energy62 exact-threshold datapath | Test whether the exact 62-bit threshold improves beyond aligned 64 bits | Fmax rises slightly to 134.210 MHz, LUTs/FFs/power drop slightly | Yes, former highest-Fmax; marginal gain | The two-bit reduction is measurable but very small; Energy64 remains easier to justify if alignment matters |
| 15 | Energy62 FIR29 exact FIR/magnitude width | Current Energy62 bottleneck is the narrowed magnitude DSP cascade | Fmax rises to 142.735 MHz; LUTs/FFs/DSPs/power all drop | Yes, former highest-Fmax | Reducing the operand width directly attacks the real bottleneck; critical path moves back to FIR output rounding |
| 16 | FIR29 fast-round output path | FIR29 bottleneck is FIR output round/shift carry logic | Fmax rises to 163.532 MHz; LUTs/power drop | Yes, former highest-Fmax | Algebraic RTL simplification beats adding latency; bottleneck moves to magnitude-valid accumulator reset routing |
| 17 | Accumulator start-load instead of end-clear | Fast-round bottleneck is `valid_s4/end_s4` control into `running_energy_reg[*]/R` | Fmax drops to 117.165 MHz | No | The reset path is removed, but the start-load mux/control perturbs placement and exposes a worse FIR valid-to-CE fanout path |
| 18 | Always-on FIR datapath plus accumulator start-load | Target the FIR valid/CE fanout exposed by step 17 while keeping the accumulator reset/control rewrite | Fmax rises to 169.233 MHz | Yes, new highest-Fmax with caveat | FIR valid/CE fanout was the active limiter after acc-start; once removed, the top path moves to the magnitude-square carry chain rather than the accumulator recurrence |

Report framing:

```text
The final write-up should not present only two architectures. It should present
the full sequence above as an evidence chain: each variant was a controlled
answer to the previous critical-path report, and the current final design is
just the latest selected point in that chain.
```

## Functional Results

| Design | Extra FIR-to-mag stages | Simulation | Detected bin | Best energy | Latency after final sample |
|---|---:|---|---:|---:|---:|
| Baseline | N/A | PASS | 3 | 2926974856033640715 | not separately measured |
| Pipelined | 0 | PASS | 3 | 2926974856033640715 | 11 cycles |
| Pipelined plus1 | 1 | PASS | 3 | 2926974856033640715 | 12 cycles |
| Pipelined plus5 | 5 | PASS | 3 | 2926974856033640715 | 16 cycles |
| Pipelined plus5 tracker | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out tracker | 5 | PASS | 3 | 2926974856033640715 | 18 cycles |
| Pipelined plus5 FIR out accbuf | 5 | PASS | 3 | 2926974856033640715 | 18 cycles |
| Pipelined plus5 FIR out accbuf magpipe | 5 | PASS | 3 | 2926974856033640715 | 19 cycles |
| Pipelined plus5 FIR out accbuf trackercmp | 5 | PASS | 3 | 2926974856033640715 | 20 cycles |
| Pipelined plus5 FIR out accbuf fanout | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out accbuf energy64 | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out accbuf energy62 | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out accbuf energy62 FIR29 | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round accstart | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |
| Pipelined plus5 FIR out accbuf Energy62 FIR29 fast-round always-on accstart | 5 | PASS | 3 | 2926974856033640715 | 17 cycles |

All variants preserve the expected resonance result.

## Post-Route Timing and Fmax

| Design | WNS | Min period | Derived Fmax | Highest passing sweep point | First failing sweep point |
|---|---:|---:|---:|---:|---:|
| Baseline | -11.142 ns | 21.142 ns | 47.299 MHz | 40.000 MHz | 50.000 MHz |
| Pipelined | 0.692 ns | 9.308 ns | 107.434 MHz | 105.263 MHz | 111.111 MHz |
| Pipelined plus1 | 1.418 ns | 8.582 ns | 116.523 MHz | 111.111 MHz | 117.647 MHz |
| Pipelined plus5 | 1.854 ns | 8.146 ns | 122.760 MHz | 117.647 MHz | 125.000 MHz |
| Pipelined plus5 tracker | 1.676 ns | 8.324 ns | 120.135 MHz | 117.647 MHz | 125.000 MHz |
| Pipelined plus5 FIR out | 2.002 ns | 7.998 ns | 125.031 MHz | 125.000 MHz | 133.333 MHz |
| Pipelined plus5 FIR out tracker | 1.675 ns | 8.325 ns | 120.120 MHz | 117.647 MHz | 125.000 MHz |
| Pipelined plus5 FIR out accbuf | 2.254 ns | 7.746 ns | 129.099 MHz | 125.000 MHz | 133.333 MHz |
| Pipelined plus5 FIR out accbuf magpipe | 2.156 ns | 7.844 ns | 127.486 MHz | 125.000 MHz | 133.333 MHz |
| Pipelined plus5 FIR out accbuf trackercmp | 1.872 ns | 8.128 ns | 123.031 MHz | 117.647 MHz | 125.000 MHz |
| Pipelined plus5 FIR out accbuf fanout | 2.136 ns | 7.864 ns | 127.162 MHz | 125.000 MHz | 133.333 MHz |
| Pipelined plus5 FIR out accbuf energy64 | 2.548 ns | 7.452 ns | 134.192 MHz | 133.333 MHz | not observed in current sweep |
| Pipelined plus5 FIR out accbuf energy62 | 2.549 ns | 7.451 ns | 134.210 MHz | 133.333 MHz | not observed in current sweep |
| Pipelined plus5 FIR out accbuf energy62 FIR29 | 2.994 ns | 7.006 ns | 142.735 MHz | 133.333 MHz | not observed in current sweep |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round | 3.885 ns | 6.115 ns | 163.532 MHz | 133.333 MHz | not observed in current sweep |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round accstart | 1.465 ns | 8.535 ns | 117.165 MHz | 111.111 MHz | 117.647 MHz |
| Pipelined plus5 FIR out accbuf Energy62 FIR29 fast-round always-on accstart | 4.091 ns | 5.909 ns | 169.233 MHz | 133.333 MHz | not observed in current sweep |

Fmax plots:

- `reports/plots/pipeline_fmax_vs_latency.svg`
- `reports/plots/pipeline_fmax_vs_boundary_stages.svg`
- `reports/plots/pipeline_incremental_fmax_gain.svg`
- `reports/plots/tracker_pipeline_comparison.svg`

## Post-Route Area and Power

| Design | LUTs | FFs | DSPs | BRAM | Total power | Dynamic power | Static power |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline | 1579 | 1309 | 20 | 0 | 0.157 W | 0.087 W | 0.070 W |
| Pipelined | 1680 | 2136 | 20 | 0 | 0.151 W | 0.081 W | 0.070 W |
| Pipelined plus1 | 1679 | 2031 | 20 | 0 | 0.147 W | 0.076 W | 0.070 W |
| Pipelined plus5 | 1777 | 2131 | 20 | 0 | 0.149 W | 0.078 W | 0.070 W |
| Pipelined plus5 tracker | 1780 | 2273 | 20 | 0 | 0.149 W | 0.079 W | 0.070 W |
| Pipelined plus5 FIR out | 1793 | 2239 | 20 | 0 | 0.148 W | 0.078 W | 0.070 W |
| Pipelined plus5 FIR out tracker | 1794 | 2381 | 20 | 0 | 0.149 W | 0.079 W | 0.070 W |
| Pipelined plus5 FIR out accbuf | 1792 | 2371 | 20 | 0 | 0.148 W | 0.077 W | 0.070 W |
| Pipelined plus5 FIR out accbuf magpipe | 1862 | 2497 | 14 | 0 | 0.152 W | 0.081 W | 0.070 W |
| Pipelined plus5 FIR out accbuf trackercmp | 1793 | 2645 | 20 | 0 | 0.152 W | 0.081 W | 0.070 W |
| Pipelined plus5 FIR out accbuf fanout | 1794 | 2393 | 20 | 0 | 0.150 W | 0.080 W | 0.070 W |
| Pipelined plus5 FIR out accbuf energy64 | 1509 | 2043 | 18 | 0 | 0.141 W | 0.070 W | 0.070 W |
| Pipelined plus5 FIR out accbuf energy62 | 1499 | 2033 | 18 | 0 | 0.140 W | 0.070 W | 0.070 W |
| Pipelined plus5 FIR out accbuf energy62 FIR29 | 1379 | 1912 | 10 | 0 | 0.126 W | 0.056 W | 0.070 W |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round | 1285 | 1912 | 10 | 0 | 0.125 W | 0.055 W | 0.070 W |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round accstart | 1342 | 1900 | 10 | 0 | 0.126 W | 0.056 W | 0.070 W |
| Pipelined plus5 FIR out accbuf Energy62 FIR29 fast-round always-on accstart | 1342 | 1831 | 10 | 0 | 0.125 W | 0.055 W | 0.070 W |

Note:

Post-route resource and power numbers can move non-monotonically because Vivado
can map delay/control chains into SRLs and make different placement decisions.
The trend that matters most here is the Fmax-vs-latency trade-off.

Area/power plots:

- `reports/plots/pipeline_area_tradeoff.svg`
- `reports/plots/pipeline_power_tradeoff.svg`
- `reports/plots/tracker_pipeline_comparison.svg`

## Incremental Trade-Off

| Step | Fmax gain | Added latency | Area/power observation | Interpretation |
|---|---:|---:|---|---|
| Baseline -> pipelined | +60.135 MHz | +latency | More registers, same DSP count | Very advantageous |
| Pipelined -> plus1 | +9.089 MHz | +1 cycle | Similar or slightly lower post-route area/power | Advantageous |
| Plus1 -> plus5 | +6.237 MHz | +4 cycles | +98 LUTs, +100 FFs, +0.002 W | Diminishing returns |
| Plus5 -> plus5 tracker | -2.625 MHz | +1 cycle | +3 LUTs, +142 FFs, +0.001 W dynamic | Not beneficial |
| Plus5 -> plus5 FIR out | +2.271 MHz | +1 cycle | +16 LUTs, +108 FFs, -0.001 W total | Modestly beneficial |
| Plus5 FIR out -> plus5 FIR out tracker | -4.911 MHz | +1 cycle | +1 LUT, +142 FFs, +0.001 W total | Not beneficial |
| Plus5 FIR out -> plus5 FIR out accbuf | +4.068 MHz | +1 cycle | -1 LUT, +132 FFs, -0.001 W dynamic | Beneficial for Fmax |
| Plus5 FIR out accbuf -> accbuf magpipe | -1.613 MHz | +1 cycle | +70 LUTs, +126 FFs, -6 DSPs, +0.004 W total | DSP-saving but not Fmax-beneficial |
| Plus5 FIR out accbuf -> accbuf trackercmp | -6.068 MHz | +2 cycles | +1 LUT, +274 FFs, +0.004 W total | Not beneficial |
| Plus5 FIR out accbuf -> accbuf fanout | -1.937 MHz | -1 cycle measured | +2 LUTs, +22 FFs, +0.002 W total | Partial fanout win, not Fmax-beneficial |
| Plus5 FIR out accbuf -> accbuf energy64 | +5.093 MHz | -1 cycle measured | -283 LUTs, -328 FFs, -2 DSPs, -0.007 W total | Beneficial precision-aware architecture |
| Accbuf energy64 -> accbuf energy62 | +0.018 MHz | 0 cycles | -10 LUTs, -10 FFs, -0.001 W total | Marginal exact-threshold gain |
| Accbuf energy62 -> accbuf energy62 FIR29 | +8.525 MHz | 0 cycles | -120 LUTs, -121 FFs, -8 DSPs, -0.014 W total | Beneficial operand-width reduction |
| Accbuf energy62 FIR29 -> FIR29 fast-round | +20.797 MHz | 0 cycles | -94 LUTs, same FFs/DSPs, -0.001 W total | Beneficial algebraic simplification |
| FIR29 fast-round -> fast-round accstart | -46.367 MHz | 0 cycles | +57 LUTs, -12 FFs, +0.001 W total | Negative reset-path experiment; removed one bottleneck but worsened FIR valid/CE fanout |
| Fast-round accstart -> always-on accstart | +52.068 MHz | 0 cycles | Same LUTs/DSPs, -69 FFs, -0.001 W total | Positive fanout fix; valid/CE fanout was the exposed limiter |

The incremental Fmax gain plot makes the diminishing return visible:

```text
reports/plots/pipeline_incremental_fmax_gain.svg
```

## Critical Path Movement

| Design | Post-route critical path |
|---|---|
| Baseline | `sample_count_reg[3]_replica/C` -> `u_mag/q_square__1/A[24]` |
| Pipelined | `u_fir_i/sum4567_reg[0]/C` -> `u_mag/i_square0__0/B[12]` |
| Pipelined plus1 | `u_impl/u_fir_q/sum4567_reg[1]/C` -> `u_impl/u_fir_q/sample_out_reg[44]/D` |
| Pipelined plus5 | `u_impl/u_accumulator/bin_energy_reg[2]/C` -> `u_impl/u_tracker/best_energy_reg[2]_lopt_replica/CE` |
| Pipelined plus5 tracker | `u_impl/u_fir_i/sum0123_reg[0]/C` -> `u_impl/u_fir_i/sample_out_reg[47]/D` |
| Pipelined plus5 FIR out | `u_impl/u_accumulator/bin_energy_reg[16]/C` -> `u_impl/gen_regular_tracker.u_tracker/best_energy_reg[112]_lopt_replica/CE` |
| Pipelined plus5 FIR out tracker | `u_impl/u_mag/valid_out_reg/C` -> `u_impl/u_accumulator/running_energy_reg[124]/R` |
| Pipelined plus5 FIR out accbuf | `u_impl/u_mag/q_square0/CLK` -> `u_impl/u_mag/q_square_reg[5]/D` |
| Pipelined plus5 FIR out accbuf magpipe | `u_impl/bin_energy_buf_reg[0]/C` -> `u_impl/gen_regular_tracker.u_tracker/best_energy_reg[0]_lopt_replica/CE` |
| Pipelined plus5 FIR out accbuf trackercmp | `u_impl/gen_fir_outreg.u_fir_q/final_sum_reg_reg[0]/C` -> `u_impl/gen_fir_outreg.u_fir_q/sample_out_reg[47]/D` |
| Pipelined plus5 FIR out accbuf fanout | `u_impl/gen_regular_mag_fanout.u_mag/i_square0/CLK` -> `u_impl/gen_regular_mag_fanout.u_mag/i_square_reg[1]/D` |
| Pipelined plus5 FIR out accbuf energy64 | `u_impl/gen_narrow_mag.u_mag/q_square0__3/CLK` -> `u_impl/gen_narrow_mag.u_mag/q_square_reg__0/PCIN[0]` |
| Pipelined plus5 FIR out accbuf energy62 | `u_impl/gen_narrow_mag.u_mag/q_square0__3/CLK` -> `u_impl/gen_narrow_mag.u_mag/q_square_reg__0/PCIN[0]` |
| Pipelined plus5 FIR out accbuf energy62 FIR29 | `u_impl/gen_fir_outreg.u_fir_q/final_sum_reg_reg[0]/C` -> `u_impl/gen_fir_outreg.u_fir_q/sample_out_reg[28]/D` |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round | `u_impl/gen_narrow_mag.u_mag/valid_out_reg/C` -> `u_impl/u_accumulator/running_energy_reg[60]/R` |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round accstart | `u_impl/gen_fir_outreg_fast_round.u_fir_q/valid_p1_reg/C` -> `u_impl/gen_fir_outreg_fast_round.u_fir_i/sum67_reg[1]/CE` |
| Pipelined plus5 FIR out accbuf Energy62 FIR29 fast-round always-on accstart | `u_impl/gen_narrow_mag.u_mag/i_square_reg__0/CLK` -> `u_impl/gen_narrow_mag.u_mag/mag_sq_reg[57]/D` |

The `plus5` result is the key architectural signal: after five extra boundary
registers, the bottleneck is no longer FIR-to-magnitude. It has moved into the
accumulator/tracker path.

The `plus5_tracker` result is a useful negative experiment. Pipelining the
tracker decision removes the previous accumulator/tracker CE path from the
worst timing report, but the design does not become faster. The critical path
moves back into FIR final output logic, while latency and FF count increase.

The `plus5_firout` result builds directly on that negative experiment. It
pipelines the FIR final-sum/output path that `plus5_tracker` exposed and raises
post-route Fmax to 125.031 MHz. The new critical path moves back to
accumulator/tracker, which means both regions are now close competitors.

The `plus5_firout_tracker` result is another negative experiment. Combining
the current tracker pipeline with FIR-output pipelining lowers Fmax to
120.120 MHz and exposes a routed control/reset path from magnitude valid into
the accumulator. The problem is dominated by route delay, not arithmetic depth.

The `plus5_firout_accbuf` result is a positive accumulator-side experiment.
Instead of splitting the tracker update itself, it registers the accumulator
bin-valid/bin/energy outputs before the tracker. Fmax rises to 129.099 MHz, and
the top setup path moves away from accumulator/tracker into the magnitude DSP
register stage. Accumulator-to-tracker paths remain near the top-ten report,
so this is an improvement rather than a complete removal of that pressure.

The `plus5_firout_accbuf_magpipe` result answers the parallelization question.
It decomposes each 48-bit square into parallel 16-bit partial products and
recombines them in a deeper pipeline. It preserves the exact detected bin and
best-energy result and reduces DSP usage from 20 to 14, but post-route Fmax
drops from 129.099 MHz to 127.486 MHz. The worst path moves back to the
accumulator-output-buffer to tracker CE path, so this version is useful if DSP
budget matters, but it is not the highest-Fmax choice.

The `plus5_firout_accbuf_trackercmp` result targets that tracker CE pressure
directly with a two-stage compare pipeline. It is functionally correct, but it
is a negative speed result: post-route Fmax falls to 123.031 MHz, latency
increases to 20 cycles, FF count rises to 2645, and the worst setup path moves
back into the FIR final output register path. This means the compare split
over-registered the tracker side without improving the overall limiting path.

The `plus5_firout_accbuf_fanout` result tests whether the high-fanout
valid/enable/control nets were the missing route-pressure lever. The early
place probe reduced several large valid/FIR fanout nets, but the full routed
result is not a speed win: Fmax is 127.162 MHz, below the parent accbuf
design. The magnitude DSP path remains dominant, and the tracker update/CE
fanout remains high at 251. This is useful as a control-fanout datapoint, not
as the selected architecture.

The `plus5_firout_accbuf_energy64` result is the first whole-architecture
precision tweak after the local negative experiments. The Python precision
sweep showed that the current vectors need only 62 energy bits, so the RTL
narrows the magnitude/accumulator/tracker energy path to 64 bits. This improves
Fmax to 134.192 MHz, passes the 133.333 MHz sweep point, reduces LUTs/FFs/DSPs,
and lowers vectorless total power. The critical path is now a narrowed
magnitude DSP cascade rather than the old 128-bit accumulator/tracker contract.
The recorded quantization graph is
`reports/plots/energy_precision_sweep_16_to_256.svg`.

The `plus5_firout_accbuf_energy62` result tests the exact threshold from that
same sweep. It preserves the same detected bin and best energy, reduces
post-route resources slightly versus Energy64, and improves derived Fmax by
only 0.018 MHz. This made Energy62 the highest-Fmax datapoint before the FIR29
follow-up, but the incremental gain is small enough that Energy64 remains a
cleaner aligned-width option if interface convenience or future guard bits
matter.

The `plus5_firout_accbuf_energy62_fir29` result builds directly on the
Energy62 bottleneck. Since both Energy64 and Energy62 were limited by the same
magnitude DSP cascade, a Python FIR/magnitude width sweep checked the operand
width feeding that square. The current vectors require 29 signed FIR I/Q bits
for exact energy preservation. Narrowing `FIR_OUT_WIDTH` from 48 to 29 keeps
the same detected bin and best energy, improves derived post-route Fmax to
142.735 MHz, reduces DSPs from 18 to 10, and lowers total vectorless power to
0.126 W. The critical path moves out of the magnitude DSP cascade and back to
the FIR output round/shift register path.

The `plus5_firout_accbuf_energy62_fir29_fastround` result targets that new FIR
output bottleneck without adding latency. A Python exactness check showed that
the original sign-aware round/shift is equivalent on all current FIR sums to a
single sign-biased arithmetic shift: positive values add 8, negative values add
7, then arithmetic-shift right by 4. The RTL variant preserves the same
simulation output, improves derived post-route Fmax to 163.532 MHz, reduces
LUTs to 1285, and lowers total vectorless power to 0.125 W. The critical path
now moves to route-dominated magnitude-valid control into the accumulator reset
path.

The `plus5_firout_accbuf_energy62_fir29_fastround_accstart` result is a
targeted negative accumulator-control experiment. It replaces the accumulator's
end-of-bin clear with start-of-bin overwrite/load, so the completed bin sum is
reported and the next bin's first sample overwrites `running_energy` instead of
clearing it through a synchronous reset. Simulation remains exact and latency
stays at 17 cycles. The specific `running_energy_reg[*]/R` path disappears from
the top setup report, so the hypothesis was structurally correct. However, the
routed Fmax drops to 117.165 MHz because the new control shape and placement
expose a 405-fanout FIR valid-to-CE route path. This branch should be recorded
as evidence that removing the accumulator reset path alone is not sufficient;
the control-valid fanout around FIR enables must be handled before revisiting
start-load.

The `plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart` result
targets both the fanout bound and the accumulator-control/iteration concern in
two linked steps. First, the fast-round FIR datapath is changed to update every
cycle so `valid` no longer gates the arithmetic registers through high-fanout
CE nets. Second, the accumulator keeps the start-of-bin overwrite/load form
that removed the reset-style end-clear path. This combination preserves the
same simulation result and 17-cycle latency, improves derived post-route Fmax
to 169.233 MHz, and keeps total vectorless power at 0.125 W. The old FIR
valid/CE fanout path disappears from the top report; the new critical path is
inside the narrowed magnitude-square carry chain. This means the fanout bound
was the immediate limiter. The accumulator recurrence still exists
architecturally, but it is not the current top post-route setup path.

## Conclusion

Pipelining is clearly advantageous through the original pipelined design and
still useful for the one-extra-boundary variant. The five-boundary version also
improves Fmax, but with noticeably smaller return per added cycle.

Current best balanced choice:

```text
pipelined_plus1
```

It improves post-route Fmax from 107.434 MHz to 116.523 MHz with only one
additional cycle of latency.

Current highest-Fmax choice:

```text
pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart
```

It reaches 169.233 MHz and passes the 133.333 MHz sweep point in the current
sweep. It keeps the same 17-cycle latency as FIR29 fast-round, removes the FIR
valid/CE fanout exposed by accumulator start-load, and keeps total vectorless
power at 0.125 W. The caveat is interface scope: the always-on FIR datapath is
safe for the current continuous-valid frame stimulus. If future inputs allow
arbitrary `sample_valid` stalls inside a frame, this variant must be
revalidated or adjusted.

Recorded resource-saving experiment:

```text
pipelined_plus5_firout_accbuf_magpipe
```

It saves six DSPs versus `pipelined_plus5_firout_accbuf`, but costs one extra
cycle, more LUTs/FFs, and lower Fmax. It should not replace the current
highest-Fmax design.

Recorded negative experiment:

```text
pipelined_plus5_tracker
```

It passes simulation and timing, but it lowers post-route Fmax to 120.135 MHz
and adds one more latency cycle. It should not replace `pipelined_plus5`.

Additional recorded negative experiment:

```text
pipelined_plus5_firout_tracker
```

It passes simulation, but does not improve timing. It should not replace
`pipelined_plus5_firout`.

Additional recorded negative experiment:

```text
pipelined_plus5_firout_accbuf_trackercmp
```

It passes simulation, but lowers Fmax to 123.031 MHz, adds two cycles versus
`pipelined_plus5_firout_accbuf`, and increases FF count. It should not replace
the accbuf parent or the current FIR29 highest-Fmax design.

Additional recorded partial/negative experiment:

```text
pipelined_plus5_firout_accbuf_fanout
```

It reduces several high-fanout valid/FIR control nets and passes simulation,
but post-route Fmax is 127.162 MHz. It should not replace
`pipelined_plus5_firout_accbuf` or the current FIR29 highest-Fmax design.

Additional recorded negative experiment:

```text
pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart
```

It removes the accumulator end-clear/reset path from the top setup report, but
post-route Fmax drops to 117.165 MHz because FIR valid-to-CE fanout becomes the
dominant routed path. It should not replace the fast-round design.

Recorded positive fanout/control experiment:

```text
pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart
```

It shows why the previous accstart branch failed: after removing the FIR
valid-driven arithmetic CEs, the same accumulator start-load concept becomes a
speed win rather than a regression. The top path moves into the magnitude
square carry chain, so future timing work should target that arithmetic path
before assuming the accumulator recurrence is the active limiter.

Next implication:

```text
If the target is above roughly 129 MHz, keep
`pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart` as
the latest highest-Fmax parent for the current continuous-valid vectors, while
keeping Energy62 and Energy64 as wider fallback contracts. The failed magpipe,
trackercmp, and first fanout follow-ups show that isolated local tweaks were
not enough; the successful precision, operand-width, fast-round, and always-on
FIR changes show that changing the datapath/control contract is the stronger
architectural lever. The next immediate bottleneck is narrowed magnitude-square
carry logic, not FIR fanout and not accumulator reset/control.
```
