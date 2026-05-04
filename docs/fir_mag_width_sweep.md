# FIR / Magnitude Width Sweep

This sweep tests the signed width shared by the FIR outputs and
magnitude-square inputs.  The current Energy62 design still uses
48-bit FIR/magnitude operands, and its post-route critical path is
inside the magnitude DSP cascade.

Reference detected bin: 3
Reference best energy: 2926974856033640715
Maximum absolute FIR I/Q value: 244435018
Signed bits required for exact FIR I/Q values: 29

Plot:

```text
reports/plots/fir_mag_width_sweep.svg
```

| FIR/mag width | Exact no truncation | Detected bin | Matches reference | Reference energy error |
|---:|---:|---:|---:|---:|
| 16 | 0 | 3 | 1 | 2926974808092180480 |
| 17 | 0 | 7 | 0 | 2926974690907389952 |
| 18 | 0 | 5 | 0 | 2926974170902298624 |
| 19 | 0 | 0 | 0 | 2926971983563325440 |
| 20 | 0 | 6 | 0 | 2926962471088422912 |
| 21 | 0 | 2 | 0 | 2926930787624288256 |
| 22 | 0 | 0 | 0 | 2926790028409438208 |
| 23 | 0 | 1 | 0 | 2926193743797157888 |
| 24 | 0 | 6 | 0 | 2923573260819890176 |
| 25 | 0 | 2 | 0 | 2915448483299196928 |
| 26 | 0 | 4 | 0 | 2874823299521576960 |
| 27 | 0 | 2 | 0 | 2745794664169734144 |
| 28 | 0 | 2 | 0 | 2656909544495513600 |
| 29 | 1 | 3 | 1 | 0 |
| 30 | 1 | 3 | 1 | 0 |
| 31 | 1 | 3 | 1 | 0 |
| 32 | 1 | 3 | 1 | 0 |
| 33 | 1 | 3 | 1 | 0 |
| 34 | 1 | 3 | 1 | 0 |
| 35 | 1 | 3 | 1 | 0 |
| 36 | 1 | 3 | 1 | 0 |
| 37 | 1 | 3 | 1 | 0 |
| 38 | 1 | 3 | 1 | 0 |
| 39 | 1 | 3 | 1 | 0 |
| 40 | 1 | 3 | 1 | 0 |
| 41 | 1 | 3 | 1 | 0 |
| 42 | 1 | 3 | 1 | 0 |
| 43 | 1 | 3 | 1 | 0 |
| 44 | 1 | 3 | 1 | 0 |
| 45 | 1 | 3 | 1 | 0 |
| 46 | 1 | 3 | 1 | 0 |
| 47 | 1 | 3 | 1 | 0 |
| 48 | 1 | 3 | 1 | 0 |

Conclusion:

```text
Smallest exact width tested: 29 signed bits
Smallest bin-preserving width tested: 16 signed bits
Recommended safe RTL follow-up: FIR_OUT_WIDTH=29
Narrower bin-preserving widths are not safe architecture choices
because they change the energy values through signed wraparound.
```

Design implication:

```text
If the safe exact width is below 48 bits, the next RTL experiment should
keep ENERGY_WIDTH=62 and reduce FIR_OUT_WIDTH to that exact signed width.
This directly targets the current magnitude-DSP critical path instead of
adding unrelated tracker or accumulator pipeline boundaries.
```

RTL follow-up:

```text
The Energy62 FIR29 RTL variant passed simulation with detected bin 3, best
energy 2926974856033640715, and 17-cycle latency. Post-route implementation
improved derived Fmax to 142.735 MHz, reduced utilization to 1379 LUTs,
1912 FFs, and 10 DSPs, and lowered vectorless total power to 0.126 W.
```

Critical-path result:

```text
The previous Energy62 bottleneck was the narrowed magnitude DSP cascade. After
FIR_OUT_WIDTH=29, the top path moved to the FIR final_sum-to-sample_out
round/shift path, so the operand-width reduction successfully removed the
best-design magnitude bottleneck.

A later FIR29 fast-round follow-up replaced the round/shift expression with an
equivalent sign-biased arithmetic shift. That raised post-route Fmax to
163.532 MHz and moved the top path to magnitude-valid accumulator control
routing.
```
