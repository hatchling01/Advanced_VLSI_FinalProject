# Design Insights by Stage

Last updated: May 4, 2026

This file is the project's running design-decision narrative. Update it after
every new architecture variant so the report captures not only the numbers, but
what each result taught us.

Report framing note:

```text
The project should be presented as a full design-decision chain, not as only
two architectures. Baseline and the current always-on FIR plus accumulator
start-load architecture are the endpoints, but the intermediate positive and
negative variants are the evidence that explains why the final architecture
looks the way it does.
```

## Standing Update Rule

After each future design decision, update this file with:

- the architecture change
- functional result
- timing/Fmax result
- area/resource impact
- power impact
- latency/throughput impact
- critical-path movement
- design insight
- recommended next action

## Stage Summary

| Stage | Architecture | Main result | Trade-off | Design insight | Next implication |
|---|---|---|---|---|---|
| Python model | Fixed-point reference model and vector generator | Establishes expected detected bin 3 and best energy `2926974856033640715` | No hardware cost; software-only reference | Gives a stable correctness target for every RTL variant | All RTL variants must match this result before timing results matter |
| Baseline RTL | Direct lock-in datapath with NCO, mixer, FIR, magnitude-square, accumulator, tracker | Simulation passes, but synthesis and post-route timing fail at 100 MHz | Lower register count and low structural latency, but long combinational paths | Functional correctness alone is not enough; baseline exposes the timing bottleneck | Add pipeline stages around FIR/magnitude datapath |
| Original pipelined RTL | Registers added around mixer, FIR, magnitude, and aligned control path | Simulation passes and post-route timing meets 100 MHz; Fmax rises to 107.434 MHz | More registers and 11-cycle final-sample latency; same DSP count | Pipelining is highly advantageous: it fixes the main timing failure while preserving correctness | Inspect remaining critical path to decide where the next register boundary belongs |
| Pipelined plus1 | One extra FIR-to-magnitude boundary register | Simulation passes; post-route Fmax rises to 116.523 MHz | Adds one latency cycle; post-route area/power remain comparable | One extra boundary is still worthwhile and is the best balanced design so far | Keep plus1 as the current balanced architecture |
| Pipelined plus5 | Five extra FIR-to-magnitude boundary registers | Simulation passes; post-route Fmax rises to 122.760 MHz | Adds five cycles versus original pipelined; LUT/FF count increases versus plus1 | More boundary stages still help, but the return per cycle is smaller; critical path moves to accumulator/tracker | Stop adding FIR-to-magnitude boundary stages; optimize accumulator/tracker next |
| Pipelined plus5 tracker | Plus5 plus registered tracker compare/update stages | Simulation passes; post-route Fmax is 120.135 MHz | Adds one more cycle and 142 FFs versus plus5, with no Fmax gain | The accumulator/tracker path was real, but splitting tracker logic alone moves the bottleneck back to FIR final output | Do not replace plus5; optimize FIR final-sum/output path next |
| Pipelined plus5 FIR out | Plus5 plus registered FIR final-sum/output split | Simulation passes; post-route Fmax rises to 125.031 MHz | Adds one more cycle and 108 FFs versus plus5 | The FIR final-output path exposed by plus5_tracker was real; after fixing it, accumulator/tracker dominates again | Former highest-Fmax design; use as parent for accumulator-side tests |
| Pipelined plus5 FIR out tracker | Plus5 FIR out plus registered tracker compare/update stages | Simulation passes; post-route Fmax drops to 120.120 MHz | Adds one more cycle and 142 FFs versus plus5 FIR out | The current tracker split does not compose well with FIR-output pipelining; route delay on accumulator control/reset dominates | Keep plus5 FIR out; target accumulator control/reset/enable structure next |
| Pipelined plus5 FIR out accbuf | Plus5 FIR out plus registered accumulator-output buffer before tracker | Simulation passes; post-route Fmax rises to 129.099 MHz | Adds one more cycle and 132 FFs versus plus5 FIR out, with flat/lower vectorless power | Buffering accumulator outputs is a better companion than the tracker split; worst setup moves into magnitude DSP register stage | Former highest-Fmax parent; later superseded by energy64 |
| Pipelined plus5 FIR out accbuf magpipe | Accbuf plus chunked/parallel 16-bit partial-product magnitude square | Simulation passes; post-route Fmax is 127.486 MHz | Saves 6 DSPs, but adds one cycle, 70 LUTs, 126 FFs, and 0.004 W versus accbuf | Square parallelization removes the magnitude DSP-register path as the top bottleneck, but accumulator-buffer to tracker CE dominates again | Record as DSP-saving, not Fmax-winning; follow-up tracker compare staging was tested next |
| Pipelined plus5 FIR out accbuf trackercmp | Accbuf plus two-stage tracker compare pipeline | Simulation passes; post-route Fmax is 123.031 MHz | Adds two cycles, 274 FFs, and 0.004 W versus accbuf | Simple tracker compare staging is too costly here; the worst path moves back into FIR final output | Record as a negative experiment; keep accbuf as the speed parent |
| Pipelined plus5 FIR out accbuf fanout | Accbuf plus fanout hints on valid/enable/tracker control | Simulation passes; post-route Fmax is 127.162 MHz | Reduces several valid/FIR control fanouts, but adds 22 FFs and 0.002 W versus accbuf | Fanout hints help control distribution but do not fix the dominant magnitude DSP path or tracker update CE fanout | Record as partial/negative; consider implementation-strategy exploration or structural tracker update reduction |
| Pipelined plus5 FIR out accbuf energy64 | Accbuf plus 64-bit energy datapath after precision sweep | Simulation passes; post-route Fmax rises to 134.192 MHz and passes the 133.333 MHz sweep point | Cuts 283 LUTs, 328 FFs, 2 DSPs, and 0.007 W versus accbuf; current vectors remain exact | Whole-architecture precision reduction is more effective than local tracker/fanout tweaks; critical path stays in narrowed magnitude DSP cascade | Former highest-Fmax precision parent; Energy62 tested the exact threshold |
| Pipelined plus5 FIR out accbuf energy62 | Energy64 architecture narrowed to the true 62-bit exact threshold | Simulation passes; post-route Fmax rises slightly to 134.210 MHz | Saves 10 LUTs, 10 FFs, and 0.001 W versus Energy64; same DSP count and latency | Exact-threshold narrowing gives a measurable but marginal gain; critical path is unchanged | Former highest-Fmax datapoint; keep as wider fallback |
| Pipelined plus5 FIR out accbuf energy62 FIR29 | Energy62 plus exact 29-bit signed FIR/magnitude operands | Simulation passes; post-route Fmax rises to 142.735 MHz | Saves 120 LUTs, 121 FFs, 8 DSPs, and 0.014 W versus Energy62; same latency | Operand-width reduction directly removes the magnitude DSP cascade bottleneck; critical path moves to FIR output rounding | Former highest-Fmax datapoint; revalidate width for broader stimuli |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round | FIR29 plus equivalent sign-biased round/shift expression | Simulation passes; post-route Fmax rises to 163.532 MHz | Saves 94 LUTs and 0.001 W versus FIR29; same FFs, DSPs, and latency | The FIR output rounding bottleneck is removed without adding a register; critical path moves to magnitude-valid control routing into accumulator reset | Former highest-Fmax datapoint; accstart and fanout cleanup tested next |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round accstart | Fast-round plus accumulator start-load instead of end-clear | Simulation passes, but post-route Fmax drops to 117.165 MHz | Adds 57 LUTs, saves 12 FFs, adds 0.001 W versus fast-round; same latency and DSPs | The targeted reset path is removed, but the control rewrite exposes a worse FIR valid-to-CE fanout route | Negative experiment; keep fast-round and target valid/CE fanout before retrying accumulator control |
| Pipelined plus5 FIR out accbuf Energy62 FIR29 fast-round always-on accstart | Accstart plus always-on fast-round FIR datapath | Simulation passes; post-route Fmax rises to 169.233 MHz | Adds 57 LUTs, saves 81 FFs, same DSPs, same total power versus fast-round; same latency | Removing FIR arithmetic CEs fixes the fanout bound exposed by accstart; critical path moves to magnitude-square carry logic | Current highest-Fmax datapoint; validate continuous-valid assumption and target magnitude-square carry chain next |

## Detailed Insights

### 1. Python Golden Model

Purpose:

```text
Create deterministic fixed-point vectors and expected results before building
RTL.
```

Result:

| Metric | Value |
|---|---:|
| Expected detected bin | 3 |
| Expected best energy | 2926974856033640715 |

Insight:

```text
The Python model turns every future hardware experiment into a measurable
correctness check. A design that improves timing but changes the detected bin
is not acceptable.
```

### 2. Baseline RTL

Architecture:

```text
sample -> NCO/mixer -> FIR -> magnitude-square -> accumulator -> tracker
```

Key results:

| Metric | Synthesis | Post-route |
|---|---:|---:|
| Simulation | PASS | N/A |
| 100 MHz timing met | No | No |
| WNS | -11.343 ns | -11.142 ns |
| Approx. Fmax | 46.9 MHz | 47.299 MHz |
| LUTs | 1574 | 1579 |
| FFs | 860 | 1309 |
| DSPs | 20 | 20 |
| Total power | 0.144 W | 0.157 W |

Critical path:

```text
Post-route:
sample_count_reg[3]_replica/C -> u_mag/q_square__1/A[24]
Data delay: 19.320 ns
Logic levels: 25
```

Insight:

```text
The baseline is functionally correct but not timing viable at 100 MHz. Its
long path crosses control/datapath logic into magnitude-square logic, so the
first meaningful architectural improvement must reduce combinational depth.
```

Trade-off conclusion:

```text
Baseline has fewer registers, but the Fmax ceiling is too low for the target.
The area savings are not worth the timing failure.
```

### 3. Original Pipelined RTL

Architecture change:

```text
Add registered stages around sample/reference capture, mixer output, FIR
adder tree, magnitude-square calculation, and matching control delay.
```

Key results:

| Metric | Synthesis | Post-route |
|---|---:|---:|
| Simulation | PASS | N/A |
| 100 MHz timing met | Yes | Yes |
| WNS | 1.004 ns | 0.692 ns |
| Approx. Fmax | 111.2 MHz | 107.434 MHz |
| LUTs | 1732 | 1680 |
| FFs | 1813 | 2136 |
| DSPs | 20 | 20 |
| Total power | 0.156 W | 0.151 W |
| Latency after final sample | 11 cycles | 11 cycles |

Critical path:

```text
Post-route:
u_fir_i/sum4567_reg[0]/C -> u_mag/i_square0__0/B[12]
Data delay: 8.778 ns
Logic levels: 18
```

Insight:

```text
The original pipelined design is the largest architectural win so far. It
raises post-route Fmax from 47.299 MHz to 107.434 MHz and changes the design
from failing 100 MHz to passing 100 MHz.
```

Trade-off conclusion:

```text
The extra registers and latency are justified because they buy a 2.27x
post-route Fmax improvement while preserving the same detected bin and DSP
count.
```

### 4. Pipelined Plus1

Architecture change:

```text
Add one extra registered boundary between FIR output and magnitude-square
input.
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Latency after final sample | 12 cycles |
| Post-route WNS | 1.418 ns |
| Derived post-route Fmax | 116.523 MHz |
| LUTs | 1679 |
| FFs | 2031 |
| DSPs | 20 |
| Total power | 0.147 W |

Critical path:

```text
u_impl/u_fir_q/sum4567_reg[1]/C -> u_impl/u_fir_q/sample_out_reg[44]/D
Data delay: 8.693 ns
Logic levels: 17
```

Insight:

```text
The one-stage boundary improves Fmax by 9.089 MHz over the original pipelined
design with only one extra cycle of latency. This is still an efficient
pipeline trade.
```

Trade-off conclusion:

```text
Pipelined plus1 is the best balanced design so far: meaningful timing gain,
small latency cost, same DSP count, and no meaningful power penalty in the
current vectorless post-route estimate.
```

### 5. Pipelined Plus5

Architecture change:

```text
Add five extra registered boundaries between FIR output and magnitude-square
input.
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Latency after final sample | 16 cycles |
| Post-route WNS | 1.854 ns |
| Derived post-route Fmax | 122.760 MHz |
| LUTs | 1777 |
| FFs | 2131 |
| DSPs | 20 |
| Total power | 0.149 W |

Critical path:

```text
u_impl/u_accumulator/bin_energy_reg[2]/C
    -> u_impl/u_tracker/best_energy_reg[2]_lopt_replica/CE
Data delay: 7.697 ns
Logic levels: 18
```

Insight:

```text
The five-stage boundary pushes Fmax higher, but the incremental gain is only
6.237 MHz beyond plus1 while adding four more cycles. Most importantly, the
critical path moved out of FIR-to-magnitude and into accumulator/tracker logic.
```

Trade-off conclusion:

```text
Pipelined plus5 was the highest-Fmax design at this stage, but it shows
diminishing returns for additional FIR-to-magnitude boundary registers. Further
registers in this location are unlikely to be the best next optimization.
```

### 6. Pipelined Plus5 Tracker

Architecture change:

```text
Keep the plus5 FIR-to-magnitude boundary chain and add a registered tracker
compare/update split after the accumulator.
```

Schematic:

```text
FIR -> boundary register x5 -> magnitude -> accumulator
                                             |
                                             v
                          tracker compare register -> tracker update register
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Latency after final sample | 17 cycles |
| Post-route WNS | 1.676 ns |
| Derived post-route Fmax | 120.135 MHz |
| LUTs | 1780 |
| FFs | 2273 |
| DSPs | 20 |
| Total power | 0.149 W |
| Dynamic power | 0.079 W |

Critical path:

```text
u_impl/u_fir_i/sum0123_reg[0]/C
    -> u_impl/u_fir_i/sample_out_reg[47]/D
Data delay: 8.333 ns
Logic levels: 19
```

Insight:

```text
This experiment confirms that the plus5 accumulator/tracker path was worth
investigating: adding the tracker pipeline removes that path from the top
timing report. The result is still not advantageous, because the worst path
moves back to the FIR final output logic and the design loses 2.625 MHz of
Fmax versus plain plus5.
```

Trade-off conclusion:

```text
Pipelined plus5 tracker should be kept as a recorded negative experiment, not
as the selected architecture. It adds one cycle, increases FF count from 2131
to 2273, slightly raises dynamic power, and does not improve Fmax.
```

Next implication:

```text
The next timing target is the FIR final-sum/output path, especially the logic
around sum0123/sum4567, final_sum, rounding/shift, and sample_out.
```

### 7. Pipelined Plus5 FIR Out

Architecture change:

```text
Keep the plus5 FIR-to-magnitude boundary chain and add a register between the
FIR final sum and the round/shift output stage.
```

Schematic:

```text
sum0123 + sum4567 -> final_sum register -> round_shift -> sample_out
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Latency after final sample | 17 cycles |
| Post-route WNS | 2.002 ns |
| Derived post-route Fmax | 125.031 MHz |
| Highest passing sweep point | 125.000 MHz |
| LUTs | 1793 |
| FFs | 2239 |
| DSPs | 20 |
| Total power | 0.148 W |
| Dynamic power | 0.078 W |

Critical path:

```text
u_impl/u_accumulator/bin_energy_reg[16]/C
    -> u_impl/gen_regular_tracker.u_tracker/best_energy_reg[112]_lopt_replica/CE
Data delay: 7.648 ns
Logic levels: 16
```

Insight:

```text
This is the first experiment after the plus5_tracker negative result that
improves the top-line Fmax. It confirms that the FIR final output path exposed
by plus5_tracker was a real next limiter. Once that path is split, the worst
path returns to accumulator/tracker.
```

Trade-off conclusion:

```text
Pipelined plus5 FIR out became the highest-Fmax design at this stage. The gain is modest:
+2.271 MHz over plus5 for one extra cycle and +108 FFs, with essentially flat
post-route power. It is useful if 125 MHz is the target, but it does not remove
the need to address accumulator/tracker for higher Fmax.
```

Next implication:

```text
The next experiment should test whether the FIR-output split can be paired with
an accumulator/tracker improvement, rather than adding more FIR-to-magnitude
boundary registers.
```

### 8. Pipelined Plus5 FIR Out Tracker

Architecture change:

```text
Combine the plus5 FIR-output split with the tracker compare/update pipeline.
```

Schematic:

```text
FIR final_sum register -> boundary x5 -> magnitude -> accumulator
                                               |
                                               v
                            tracker compare register -> tracker update register
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Latency after final sample | 18 cycles |
| Post-route WNS | 1.675 ns |
| Derived post-route Fmax | 120.120 MHz |
| Highest passing sweep point | 117.647 MHz |
| LUTs | 1794 |
| FFs | 2381 |
| DSPs | 20 |
| Total power | 0.149 W |
| Dynamic power | 0.079 W |

Critical path:

```text
u_impl/u_mag/valid_out_reg/C
    -> u_impl/u_accumulator/running_energy_reg[124]/R
Data delay: 7.813 ns
Logic levels: 1
```

Insight:

```text
The combined design proves that the current tracker pipeline is not the right
partner for the FIR-output split. It removes the previous tracker CE path, but
the design loses nearly 5 MHz versus plus5 FIR out and exposes a routed
magnitude-valid to accumulator-reset path.
```

Trade-off conclusion:

```text
Pipelined plus5 FIR out tracker is a negative experiment. It adds one cycle and
142 FFs versus plus5 FIR out, raises dynamic power slightly, and lowers Fmax
from 125.031 MHz to 120.120 MHz.
```

Next implication:

```text
Keep plus5 FIR out as the parent for the next accumulator-side experiment. The
next optimization should target accumulator control/reset/enable structure
directly.
```

### 9. Pipelined Plus5 FIR Out Accumulator-Output Buffer

Architecture change:

```text
Keep the plus5 FIR-output split, but register accumulator bin_valid, bin index,
and bin_energy before the tracker consumes them.
```

Schematic:

```text
FIR final_sum register -> boundary x5 -> magnitude -> accumulator
                                               |
                                               v
                         accumulator output buffer -> tracker
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Latency after final sample | 18 cycles |
| Post-route WNS | 2.254 ns |
| Derived post-route Fmax | 129.099 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1792 |
| FFs | 2371 |
| DSPs | 20 |
| Total power | 0.148 W |
| Dynamic power | 0.077 W |

Critical path:

```text
u_impl/u_mag/q_square0/CLK
    -> u_impl/u_mag/q_square_reg[5]/D
Data delay: 7.534 ns
Logic levels: 1
```

Near-critical follow-up path:

```text
u_impl/bin_energy_buf_reg[28]/C
    -> u_impl/gen_regular_tracker.u_tracker/best_energy_reg[13]_lopt_replica/CE
Data delay: 7.478 ns
Logic levels: 15
```

Insight:

```text
This is a positive result. The previous negative tracker split showed that
changing tracker internals could move the problem into routed control/reset
logic. Registering the accumulator outputs is a cleaner boundary: it improves
Fmax from 125.031 MHz to 129.099 MHz and moves the top setup path into the
magnitude DSP register stage. The accumulator/tracker interface is not gone,
but it is no longer the worst path.
```

Trade-off conclusion:

```text
Pipelined plus5 FIR out accbuf is now the highest-Fmax design. The trade-off is
+1 cycle and +132 FFs versus plus5 FIR out, with no total-power increase in the
current vectorless post-route estimate. This is advantageous for a
highest-frequency target, but plus1 remains the better balanced design.
```

Next implication:

```text
For more Fmax, inspect the magnitude DSP register path first, then the remaining
near-critical accumulator-output-buffer to tracker CE paths. Avoid returning to
the current tracker compare/update split unless its control/reset behavior is
redesigned.
```

### 10. Pipelined Plus5 FIR Out Accbuf Magpipe

Architecture change:

```text
Keep plus5 FIR out accbuf, but replace the inferred 48x48 magnitude-square
implementation with parallel 16-bit partial products and a recombination
pipeline.
```

Schematic:

```text
I/Q filtered samples
    -> split each 48-bit value into hi/mid/lo 16-bit chunks
    -> parallel partial products
    -> recombine exact 96-bit I^2 and Q^2
    -> add I^2 + Q^2
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Best energy | 2926974856033640715 |
| Latency after final sample | 19 cycles |
| Post-route WNS | 2.156 ns |
| Derived post-route Fmax | 127.486 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1862 |
| FFs | 2497 |
| DSPs | 14 |
| Total power | 0.152 W |
| Dynamic power | 0.081 W |

Critical path:

```text
u_impl/bin_energy_buf_reg[0]/C
    -> u_impl/gen_regular_tracker.u_tracker/best_energy_reg[0]_lopt_replica/CE
Data delay: 7.568 ns
Logic levels: 18
```

Insight:

```text
This experiment validates that arithmetic parallelization can reduce DSP
usage, but it does not improve Fmax here. The magnitude DSP-register path is
no longer the top bottleneck; instead, timing moves back to the
accumulator-output-buffer to tracker CE path. The extra recombination logic and
one additional cycle make this a resource trade-off, not a speed win.
```

Trade-off conclusion:

```text
Do not replace plus5 FIR out accbuf for the highest-Fmax target. Keep this
variant as a useful DSP-saving datapoint: it reduces DSPs from 20 to 14 while
still passing 125 MHz, but lowers derived Fmax from 129.099 MHz to
127.486 MHz.
```

Next implication:

```text
For speed, target the accumulator-output-buffer to tracker CE path directly.
For resource-constrained devices, keep the chunked magnitude option in mind.
```

### 11. Pipelined Plus5 FIR Out Accbuf Tracker Compare Pipeline

Architecture change:

```text
Keep plus5 FIR out accbuf, but replace the regular tracker with a two-stage
tracker compare pipeline. The first stage captures the candidate bin/energy,
and the second stage registers the compare result before updating best_energy
and detected_bin.
```

Schematic:

```text
FIR final_sum register -> boundary x5 -> magnitude -> accumulator
                                               |
                                               v
                         accumulator output buffer -> tracker candidate reg
                                                    -> compare/update reg
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Best energy | 2926974856033640715 |
| Latency after final sample | 20 cycles |
| Post-route WNS | 1.872 ns |
| Derived post-route Fmax | 123.031 MHz |
| Highest passing sweep point | 117.647 MHz |
| First failing sweep point | 125.000 MHz |
| LUTs | 1793 |
| FFs | 2645 |
| DSPs | 20 |
| Total power | 0.152 W |
| Dynamic power | 0.081 W |

Critical path:

```text
u_impl/gen_fir_outreg.u_fir_q/final_sum_reg_reg[0]/C
    -> u_impl/gen_fir_outreg.u_fir_q/sample_out_reg[47]/D
Data delay: 8.133 ns
Logic levels: 16
```

Insight:

```text
This is a negative speed result. The design is functionally correct, but the
simple two-stage tracker compare pipeline lowers Fmax from 129.099 MHz to
123.031 MHz and adds two latency cycles. It removes the tracker CE path as the
top reported bottleneck, but the overall design gets slower because the worst
path moves back into FIR final-output logic while FF count and power rise.
```

Trade-off conclusion:

```text
Do not replace plus5 FIR out accbuf with the tracker compare pipeline. The
experiment is valuable because it confirms that tracker-side staging must be
done together with broader placement/fanout/control cleanup; adding registers
inside the tracker alone is not enough.
```

Next implication:

```text
Keep plus5 FIR out accbuf as the speed parent. The next speed experiment should
not simply add tracker stages. It should inspect the FIR final-output path and
the accumulator-to-tracker CE/control fanout together.
```

### 12. Pipelined Plus5 FIR Out Accbuf Fanout

Architecture change:

```text
Keep plus5 FIR out accbuf, but add fanout-hint versions of the FIR output,
magnitude, and tracker blocks. The goal is to reduce high-fanout valid, enable,
and tracker-update control pressure without changing arithmetic precision.
```

Schematic:

```text
FIR fanout-hint path -> boundary x5 -> magnitude fanout-hint path
                                      -> accumulator output buffer
                                      -> tracker fanout-hint update
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Best energy | 2926974856033640715 |
| Latency after final sample | 17 cycles |
| Post-route WNS | 2.136 ns |
| Derived post-route Fmax | 127.162 MHz |
| Highest passing sweep point | 125.000 MHz |
| First failing sweep point | 133.333 MHz |
| LUTs | 1794 |
| FFs | 2393 |
| DSPs | 20 |
| Total power | 0.150 W |
| Dynamic power | 0.080 W |

Post-route fanout observations:

| Control/fanout item | Before routed accbuf | Fanout result |
|---|---:|---:|
| `valid_s2` control | 591 | replicated into about 98-fanout nets |
| FIR I enable/control | 405 | about 101-113 |
| FIR valid P2 control | 225 | about 113 |
| Magnitude `valid_out` | 130 | 64 plus one 64-fanout replica |
| Magnitude enable | 132 | 132 |
| Tracker update/CE | 251 | 251 |

Critical path:

```text
u_impl/gen_regular_mag_fanout.u_mag/i_square0/CLK
    -> u_impl/gen_regular_mag_fanout.u_mag/i_square_reg[1]/D
Data delay: 7.667 ns
Logic levels: 1
```

Insight:

```text
The early-stop gate correctly identified real fanout reduction, but the full
routed result is not a speed win. The branch lowers Fmax from 129.099 MHz to
127.162 MHz. It reduces several valid/FIR control fanouts, but leaves the
tracker update/CE fanout at 251 and the magnitude DSP path remains dominant.
```

Trade-off conclusion:

```text
Do not replace plus5 FIR out accbuf. Keep fanout as a partial/negative
datapoint: it proves control fanout can be reduced, but that reduction alone
does not lift the current Fmax plateau.
```

Next implication:

```text
The project is now likely at a local RTL plateau for isolated tweaks. The next
speed effort should either explore implementation strategies on the current
best design or make a more structural tracker/update change that reduces the
wide best_energy update/CE fanout itself.
```

### 13. Pipelined Plus5 FIR Out Accbuf Energy64

Architecture change:

```text
Keep plus5 FIR out accbuf, but reduce the accumulator/tracker energy datapath
from 128 bits to 64 bits. A broad Python precision sweep from 16 through 256
bits showed that the current generated vectors have a maximum energy bit length
of 62 bits, so 64 bits is exact for this stimulus set.
```

Schematic:

```text
48-bit filtered I/Q -> narrowed 64-bit magnitude energy
    -> 64-bit accumulator -> accumulator output buffer -> 64-bit tracker
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Best energy | 2926974856033640715 |
| Latency after final sample | 17 cycles |
| Post-route WNS | 2.548 ns |
| Derived post-route Fmax | 134.192 MHz |
| Highest passing sweep point | 133.333 MHz |
| First failing sweep point | not observed in current sweep |
| LUTs | 1509 |
| FFs | 2043 |
| DSPs | 18 |
| Total power | 0.141 W |
| Dynamic power | 0.070 W |

Critical path:

```text
u_impl/gen_narrow_mag.u_mag/q_square0__3/CLK
    -> u_impl/gen_narrow_mag.u_mag/q_square_reg__0/PCIN[0]
Data delay: 5.977 ns
Logic levels: 1
```

Insight:

```text
This is the strongest post-accbuf result. The previous negative experiments
showed that local tracker staging, fanout hints, and chunked magnitude logic
did not beat accbuf. Energy64 succeeds because it changes the whole datapath
contract: the accumulator and tracker no longer carry unnecessary 128-bit
state for vectors whose maximum energy is 62 bits. That reduces area, power,
and DSP usage while improving Fmax from 129.099 MHz to 134.192 MHz.
```

Quantization sweep note:

```text
The dense 16-to-256-bit sweep found that 62 bits is the true exact threshold.
Some narrower widths accidentally preserve detected bin 3 after modulo
truncation, but they are not energy-exact and should not be used as safe RTL
targets. The recorded plot is reports/plots/energy_precision_sweep_16_to_256.svg.
```

Trade-off conclusion:

```text
Select energy64 as the new highest-Fmax design for the current stimulus set.
It is better than accbuf in speed, LUTs, FFs, DSPs, and vectorless power.
The caveat is verification scope: 64 bits is exact for the generated vectors,
but must be revalidated if input amplitude, sample count, FIR scaling, bin
count, or accumulation window changes.
```

Next implication:

```text
The next useful step is not another register in the old 128-bit datapath. Use
energy64 as the new parent, then either broaden the precision/stimulus
validation or test a reduced-I/O implementation wrapper around this narrower
architecture.
```

### 14. Pipelined Plus5 FIR Out Accbuf Energy62

Architecture change:

```text
Keep the Energy64 architecture, but set ENERGY_WIDTH to 62 bits, the exact
threshold found by the 16-to-256-bit Python precision sweep for the current
vectors.
```

Schematic:

```text
48-bit filtered I/Q -> narrowed 62-bit magnitude energy
    -> 62-bit accumulator -> accumulator output buffer -> 62-bit tracker
```

Key results:

| Metric | Value |
|---|---:|
| Simulation | PASS |
| Detected bin | 3 |
| Best energy | 2926974856033640715 |
| Latency after final sample | 17 cycles |
| Post-route WNS | 2.549 ns |
| Derived post-route Fmax | 134.210 MHz |
| Highest passing sweep point | 133.333 MHz |
| First failing sweep point | not observed in current sweep |
| LUTs | 1499 |
| FFs | 2033 |
| DSPs | 18 |
| Total power | 0.140 W |
| Dynamic power | 0.070 W |

Critical path:

```text
u_impl/gen_narrow_mag.u_mag/q_square0__3/CLK
    -> u_impl/gen_narrow_mag.u_mag/q_square_reg__0/PCIN[0]
Data delay: 5.977 ns
Logic levels: 1
```

Insight:

```text
Energy62 confirms that the 62-bit Python threshold is implementable in RTL and
still exact for the current vectors. It slightly improves the Energy64 result:
+0.018 MHz Fmax, -10 LUTs, -10 FFs, and -0.001 W total vectorless power. The
critical path is unchanged and remains in the narrowed magnitude DSP cascade.
```

Trade-off conclusion:

```text
Energy62 became the highest-Fmax datapoint at this stage, but the improvement
over Energy64 was marginal. After the FIR29 follow-up, keep Energy62 as the
wider exact-energy fallback and use FIR29 for the current best measured
implementation.
```

Next implication:

```text
Do not expect large gains from shaving only one or two more exact energy bits;
there are no more exact bits to remove for the current vectors. The next useful
step is to inspect FIR/magnitude operand width, which led to the FIR29
follow-up below.
```

### 15. Pipelined Plus5 FIR Out Accbuf Energy62 FIR29

Architecture change:

```text
Keep Energy62, but reduce FIR_OUT_WIDTH from 48 signed bits to 29 signed bits.
This narrows both FIR output registers and magnitude-square input operands.
```

Why we tried it:

```text
Energy64 and Energy62 shared the same critical path in the narrowed magnitude
DSP cascade. The next useful question was whether the operands feeding that
square were still over-wide.
```

Python sanity check:

```text
python/fir_mag_width_sweep.py found that the current generated vectors require
29 signed FIR I/Q bits for exact preservation. Widths below 29 can sometimes
preserve only the detected bin, but they change energy values and are not safe
architecture choices.
```

Post-route result:

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
```

Critical path:

```text
u_impl/gen_fir_outreg.u_fir_q/final_sum_reg_reg[0]/C
to
u_impl/gen_fir_outreg.u_fir_q/sample_out_reg[28]/D
```

Insight:

```text
This is a strong positive result. FIR29 improves Fmax by 8.525 MHz over
Energy62 while reducing LUTs, FFs, DSPs, and power with no extra latency. The
critical path moving back to FIR output rounding is exactly what we hoped to
see: the magnitude DSP cascade is no longer the limiting path.
```

Trade-off conclusion:

```text
Use Energy62 FIR29 as the current highest-Fmax implementation for the current
vectors. Keep Energy62 and Energy64 as wider fallback contracts until the
29-bit FIR/magnitude threshold is revalidated across broader stimuli.
```

Next implication:

```text
The next bottleneck is the FIR final_sum-to-sample_out round/shift/output path.
Further work should target that FIR output rounding path rather than adding
more magnitude, accumulator, or tracker registers.
```

### 16. Pipelined Plus5 FIR Out Accbuf Energy62 FIR29 Fast-Round

Architecture change:

```text
Keep the FIR29 architecture, but replace the FIR output round/shift expression
with an equivalent sign-biased arithmetic shift. Positive values add 8 before
the shift; negative values add 7 before the arithmetic shift.
```

Why we tried it:

```text
FIR29 moved the critical path to the FIR final_sum-to-sample_out round/shift
path. The old expression implemented negative rounding with negate/add/negate,
which created more carry-chain logic than necessary.
```

Sanity check:

```text
A Python exactness check over all current FIR sums found zero mismatches between
the old round_shift and the fast-round expression.
```

Post-route result:

```text
Simulation: PASS
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
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
```

Critical path:

```text
u_impl/gen_narrow_mag.u_mag/valid_out_reg/C
to
u_impl/u_accumulator/running_energy_reg[60]/R
```

Insight:

```text
This is a strong positive result. The FIR output rounding path is no longer the
top setup path, and the design gains 20.797 MHz over FIR29 with no latency or
DSP cost. LUTs drop from 1379 to 1285, and total vectorless power drops from
0.126 W to 0.125 W.
```

Trade-off conclusion:

```text
Use FIR29 fast-round as the current highest-Fmax implementation for the current
vectors. This is preferable to adding another register because it improves
timing and area while keeping latency unchanged.
```

Next implication:

```text
The new bottleneck is route-dominated control from magnitude valid into the
accumulator reset path. Further gains should target accumulator control/reset
structure or valid distribution, not FIR rounding.
```

### 17. Pipelined Plus5 FIR Out Accbuf Energy62 FIR29 Fast-Round AccStart

Architecture change:

```text
Keep FIR29 fast-round, but replace the accumulator's end-of-bin clear with a
start-of-bin overwrite/load. The completed bin sum is reported at end_of_bin;
on the first sample of the next bin, running_energy loads mag_sq directly
instead of relying on a clear from the previous bin.
```

Why we tried it:

```text
The fast-round design's top path ended at running_energy_reg[*]/R. That showed
Vivado had mapped valid/end-of-bin accumulator clearing onto a synchronous
reset input across the 62-bit running accumulator. The specific hypothesis was:
remove that reset-like clear and the magnitude-valid-to-accumulator-reset path
should disappear.
```

Post-route result:

```text
Simulation: PASS
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
WNS: 1.465 ns
Derived min period: 8.535 ns
Derived Fmax: 117.165 MHz
LUTs: 1342
FFs: 1900
DSPs: 10
BRAM: 0
Total power: 0.126 W
Dynamic power: 0.056 W
Static power: 0.070 W
```

Critical path:

```text
u_impl/gen_fir_outreg_fast_round.u_fir_q/valid_p1_reg/C
to
u_impl/gen_fir_outreg_fast_round.u_fir_i/sum67_reg[1]/CE
```

Insight:

```text
This is a precise negative result. The targeted running_energy reset path is no
longer the top setup path, so the structural diagnosis was correct. However,
the added start-load control and changed placement expose a much worse
route-dominated FIR valid-to-CE path with fanout 405. Fmax drops by 46.367 MHz
versus FIR29 fast-round while preserving correctness and latency.
```

Trade-off conclusion:

```text
Do not select the accumulator start-load variant. Keep FIR29 fast-round as the
best implementation. The result says accumulator reset removal cannot be
treated in isolation; valid/CE fanout around the FIR/magnitude/accumulator
boundary must be controlled first.
```

Next implication:

```text
The next improvement attempt should not be another accumulator-only rewrite.
The next specific direction is to reduce FIR valid/CE fanout, especially the
valid_p1/valid_p2 enables feeding FIR partial-sum registers, then revisit
accumulator control if the magnitude-valid reset path returns.
```

### 18. Pipelined Plus5 FIR Out Accbuf Energy62 FIR29 Fast-Round Always-On AccStart

Architecture change:

```text
Keep the accumulator start-of-bin overwrite/load from stage 17, but remove the
FIR arithmetic clock-enable dependency on valid. The fast-round FIR datapath
now updates every cycle; valid is carried only as a validity pipeline.
```

Why we tried it:

```text
Stage 17 proved that the accumulator reset-style end-clear could be removed,
but also showed a new 405-fanout FIR valid-to-CE path. This stage directly
targets that fanout bound while keeping the accumulator-control rewrite in
place.
```

Post-route result:

```text
Simulation: PASS
Detected bin: 3
Best energy: 2926974856033640715
Latency after final sample: 17 cycles
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
```

Critical path:

```text
u_impl/gen_narrow_mag.u_mag/i_square_reg__0/CLK
to
u_impl/gen_narrow_mag.u_mag/mag_sq_reg[57]/D
```

Insight:

```text
This is a positive result and the new highest-Fmax datapoint. Removing FIR
valid-driven arithmetic CEs eliminates the specific fanout path that made
stage 17 fail. With fanout controlled, the accumulator start-load structure no
longer hurts timing; the top path moves into the narrowed magnitude-square
carry chain.
```

Trade-off conclusion:

```text
Select this as the current highest-Fmax architecture for the current
continuous-valid vectors. Compared with FIR29 fast-round, Fmax improves by
5.701 MHz, latency stays at 17 cycles, DSP count is unchanged, FF count drops
by 81, LUT count rises by 57, and total vectorless power is unchanged at
0.125 W.
```

Next implication:

```text
We have now handled the immediate FIR fanout bound. The accumulator recurrence
still exists as an architectural loop, but it is not the current top setup
path. The next timing target should be the narrowed magnitude-square carry
chain, with caution because the earlier magpipe branch saved DSPs but did not
increase Fmax.

Caveat: this always-on FIR form assumes the current continuous-valid frame
behavior. If the external interface later allows arbitrary sample_valid stalls
inside a frame, this variant needs a stall-aware validation pass or a different
enable strategy.
```

## Cross-Stage Trade-Off View

| Design | Post-route Fmax | Latency | LUTs | FFs | Total power | Critical-path region | Decision |
|---|---:|---:|---:|---:|---:|---|---|
| Baseline | 47.299 MHz | not measured | 1579 | 1309 | 0.157 W | control/magnitude | Not timing viable |
| Pipelined | 107.434 MHz | 11 cycles | 1680 | 2136 | 0.151 W | FIR-to-magnitude | Major win |
| Pipelined plus1 | 116.523 MHz | 12 cycles | 1679 | 2031 | 0.147 W | FIR final output | Best balanced |
| Pipelined plus5 | 122.760 MHz | 16 cycles | 1777 | 2131 | 0.149 W | accumulator/tracker | Former highest Fmax, diminishing returns |
| Pipelined plus5 tracker | 120.135 MHz | 17 cycles | 1780 | 2273 | 0.149 W | FIR final output | Negative experiment |
| Pipelined plus5 FIR out | 125.031 MHz | 17 cycles | 1793 | 2239 | 0.148 W | accumulator/tracker | Former highest Fmax |
| Pipelined plus5 FIR out tracker | 120.120 MHz | 18 cycles | 1794 | 2381 | 0.149 W | mag valid to accumulator reset | Negative experiment |
| Pipelined plus5 FIR out accbuf | 129.099 MHz | 18 cycles | 1792 | 2371 | 0.148 W | magnitude DSP register | Former highest Fmax |
| Pipelined plus5 FIR out accbuf magpipe | 127.486 MHz | 19 cycles | 1862 | 2497 | 0.152 W | accumulator-buffer to tracker CE | DSP-saving, not Fmax-winning |
| Pipelined plus5 FIR out accbuf trackercmp | 123.031 MHz | 20 cycles | 1793 | 2645 | 0.152 W | FIR final output | Negative experiment |
| Pipelined plus5 FIR out accbuf fanout | 127.162 MHz | 17 cycles | 1794 | 2393 | 0.150 W | magnitude DSP register | Partial fanout win, not Fmax-winning |
| Pipelined plus5 FIR out accbuf energy64 | 134.192 MHz | 17 cycles | 1509 | 2043 | 0.141 W | narrowed magnitude DSP cascade | Former highest Fmax |
| Pipelined plus5 FIR out accbuf energy62 | 134.210 MHz | 17 cycles | 1499 | 2033 | 0.140 W | narrowed magnitude DSP cascade | Former highest Fmax |
| Pipelined plus5 FIR out accbuf energy62 FIR29 | 142.735 MHz | 17 cycles | 1379 | 1912 | 0.126 W | FIR output rounding | Former highest Fmax |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round | 163.532 MHz | 17 cycles | 1285 | 1912 | 0.125 W | magnitude-valid to accumulator reset | Former highest Fmax |
| Pipelined plus5 FIR out accbuf energy62 FIR29 fast-round accstart | 117.165 MHz | 17 cycles | 1342 | 1900 | 0.126 W | FIR valid to CE fanout | Negative experiment |
| Pipelined plus5 FIR out accbuf Energy62 FIR29 fast-round always-on accstart | 169.233 MHz | 17 cycles | 1342 | 1831 | 0.125 W | magnitude-square carry chain | New highest Fmax |

Incremental Fmax gain:

| Step | Fmax gain | Latency impact | Insight |
|---|---:|---:|---|
| Baseline -> pipelined | +60.135 MHz | Adds pipeline latency | Very advantageous |
| Pipelined -> plus1 | +9.089 MHz | +1 cycle | Still advantageous |
| Plus1 -> plus5 | +6.237 MHz | +4 cycles | Diminishing returns |
| Plus5 -> plus5 tracker | -2.625 MHz | +1 cycle | Not beneficial |
| Plus5 -> plus5 FIR out | +2.271 MHz | +1 cycle | Modestly beneficial |
| Plus5 FIR out -> plus5 FIR out tracker | -4.911 MHz | +1 cycle | Not beneficial |
| Plus5 FIR out -> plus5 FIR out accbuf | +4.068 MHz | +1 cycle | Beneficial for highest Fmax |
| Plus5 FIR out accbuf -> accbuf magpipe | -1.613 MHz | +1 cycle | Saves DSPs, not beneficial for Fmax |
| Plus5 FIR out accbuf -> accbuf trackercmp | -6.068 MHz | +2 cycles | Not beneficial |
| Plus5 FIR out accbuf -> accbuf fanout | -1.937 MHz | -1 cycle measured | Fanout improves, Fmax does not |
| Plus5 FIR out accbuf -> accbuf energy64 | +5.093 MHz | -1 cycle measured | Precision-aware architecture is beneficial |
| Accbuf energy64 -> accbuf energy62 | +0.018 MHz | 0 cycles | Exact-threshold narrowing gives a marginal gain |
| Accbuf energy62 -> accbuf energy62 FIR29 | +8.525 MHz | 0 cycles | Exact operand-width reduction is strongly beneficial |
| Accbuf energy62 FIR29 -> FIR29 fast-round | +20.797 MHz | 0 cycles | Algebraic simplification is strongly beneficial |
| FIR29 fast-round -> fast-round accstart | -46.367 MHz | 0 cycles | Reset-path removal alone is negative because FIR valid/CE fanout becomes dominant |
| Fast-round accstart -> always-on accstart | +52.068 MHz | 0 cycles | Fanout cleanup makes the accumulator start-load architecture beneficial |

## Current Recommendation

Best balanced architecture:

```text
pipelined_plus1
```

Reason:

```text
It gives a meaningful Fmax improvement over the original pipelined design with
only one extra cycle of latency.
```

Highest-Fmax architecture:

```text
pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart
```

Reason:

```text
It reaches 169.233 MHz, passes the 133.333 MHz sweep point in the current
sweep, and keeps 17-cycle latency. It validates the two-step diagnosis:
accumulator reset removal alone was negative because FIR valid/CE fanout became
dominant; once that fanout is removed by an always-on FIR datapath, the
accumulator start-load form becomes part of the new best design. Caveats:
FIR/magnitude 29-bit exactness and the continuous-valid always-on FIR
assumption must both be revalidated for broader stimuli.
```

Recorded negative experiment:

```text
pipelined_plus5_tracker
```

Reason:

```text
It passes simulation and timing, but it lowers Fmax and adds latency/register
cost. Its main value is showing that the next bottleneck after tracker cleanup
is the FIR final output path.
```

Additional recorded negative experiment:

```text
pipelined_plus5_firout_tracker
```

Reason:

```text
It combines two correct changes, but the combination lowers Fmax and exposes a
routed accumulator control/reset path.
```

Recorded resource-saving experiment:

```text
pipelined_plus5_firout_accbuf_magpipe
```

Reason:

```text
It reduces DSP usage from 20 to 14 and preserves correctness, but lowers Fmax
from 129.099 MHz to 127.486 MHz and adds one more cycle.
```

Additional recorded negative experiment:

```text
pipelined_plus5_firout_accbuf_trackercmp
```

Reason:

```text
It directly targets the tracker compare path, but lowers Fmax to 123.031 MHz,
adds two cycles versus accbuf, and moves the top path back into FIR final
output logic.
```

Recorded partial/negative experiment:

```text
pipelined_plus5_firout_accbuf_fanout
```

Reason:

```text
It reduces several high-fanout valid/FIR control nets, but leaves tracker
update/CE fanout high and lowers Fmax to 127.162 MHz.
```

Additional recorded negative experiment:

```text
pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart
```

Reason:

```text
It directly removes the accumulator end-of-bin clear/reset path, but lowers
Fmax to 117.165 MHz. The new top path is FIR valid_p1 to partial-sum CE fanout,
so the next useful work is FIR valid/enable fanout control rather than another
accumulator-only rewrite.
```

Recorded positive fanout/control experiment:

```text
pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart
```

Reason:

```text
It removes the FIR valid/CE fanout exposed by the negative accstart branch,
raises Fmax to 169.233 MHz, keeps latency at 17 cycles, and moves the top path
to magnitude-square carry logic. This shows the current design is no longer
FIR-fanout-bound at the top level.
```

Next design target:

```text
Keep `pipelined_plus5_firout_accbuf_energy62` only as the wider precision
fallback. Use
`pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart` as
the latest highest-Fmax parent for the current continuous-valid vectors. The
next step should broaden stimulus validation for the 62-bit energy contract,
the 29-bit FIR/magnitude contract, and the always-on FIR valid assumption. For
timing, the next concrete target is the narrowed magnitude-square carry chain;
the accumulator iteration bound should be monitored, but it is not the active
top bottleneck right now.
```
