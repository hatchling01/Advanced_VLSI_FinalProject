# Lock-In Resonance Tracking VLSI Project

This project implements and evaluates a fixed-point lock-in DSP accelerator for
real-time resonance tracking.

## Starting Configuration

- Input samples: 16-bit signed
- Reference sine/cosine: 16-bit signed
- Frequency bins: 8
- Samples per bin: 64
- FIR taps: 8
- Detection mode: peak detection
- Target FPGA: Artix-7 `xc7a35tcpg236-1`

## Project Layout

- `python/` - golden model, vector generation, plotting
- `vectors/` - generated ROMs, input samples, expected outputs
- `rtl/` - synthesizable SystemVerilog RTL
- `tb/` - simulation testbenches
- `vivado/` - constraints and Vivado Tcl scripts
- `reports/` - synthesis, timing, utilization, and simulation outputs
- `docs/` - report notes and project documentation

## Generate Golden Vectors

The Python model uses only the standard library.

```powershell
python .\python\golden_model.py
```

Generated files include:

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

## Run Baseline RTL Simulation

From the Vivado Tcl shell, run:

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/sim_baseline.tcl
```

Expected simulation result:

```text
Expected bin: 3
Detected bin: 3
PASS
```

## Run Baseline Synthesis

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/synth_baseline.tcl
```

The reports are written to `reports/baseline/`.

## Run Pipelined RTL Simulation

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/sim_pipelined.tcl
```

Expected simulation result:

```text
Expected bin: 3
Detected bin: 3
PASS
```

## Run Pipelined Synthesis

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/synth_pipelined.tcl
```

The reports are written to `reports/pipelined/`.

## Run Extra Pipeline Boundary Variants

The `plus1` and `plus5` variants add one and five extra register boundaries
between the FIR output and magnitude-square input. The `plus5_tracker` variant
keeps the five boundary registers and adds a registered tracker compare/update
split. The `plus5_firout` variant keeps the five boundary registers and adds a
registered FIR final-sum/output split. The `plus5_firout_tracker` variant
combines both FIR-output and tracker pipeline changes. The
`plus5_firout_accbuf` variant keeps the FIR-output split and adds a registered
accumulator-output buffer before the tracker. The
`plus5_firout_accbuf_magpipe` variant also decomposes the 48-bit magnitude
square into parallel 16-bit partial products. The
`plus5_firout_accbuf_trackercmp` variant keeps the accbuf design and adds a
two-stage tracker compare pipeline. The `plus5_firout_accbuf_fanout` variant
keeps accbuf and adds fanout hints on valid, enable, and tracker-control paths.
The `plus5_firout_accbuf_energy64` variant keeps accbuf but narrows the energy
datapath to 64 bits after the broad 16-to-256-bit precision sweep showed this
is exact for the current generated vectors.
The `plus5_firout_accbuf_energy62` variant uses the true 62-bit exact threshold
from that sweep.
The `plus5_firout_accbuf_energy62_fir29_fastround_accstart` variant is a
recorded negative experiment that removes the accumulator end-clear path but
exposes worse FIR valid/CE fanout.
The `plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart` variant
removes that FIR valid/CE fanout by using an always-on fast-round FIR datapath
plus accumulator start-load, and is the current highest-Fmax datapoint for the
current continuous-valid vectors.

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/sim_pipelined_plus1.tcl
vivado -mode batch -source vivado/synth_pipelined_plus1.tcl
vivado -mode batch -source vivado/impl_pipelined_plus1.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_tracker.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_tracker.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_tracker.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_tracker.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_tracker.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_tracker.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_magpipe.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_magpipe.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_magpipe.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_trackercmp.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_trackercmp.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_trackercmp.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_fanout.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_fanout.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_fanout.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_energy64.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_energy64.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_energy64.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_energy62.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_energy62.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_energy62.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29_fastround.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart.tcl
vivado -mode batch -source vivado/sim_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.tcl
vivado -mode batch -source vivado/synth_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.tcl
vivado -mode batch -source vivado/impl_pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart.tcl
```

Trade-off results are summarized in:

- `docs/pipeline_tradeoff_report.md`
- `docs/design_insights_by_stage.md`
- `reports/pipeline_tradeoff_summary.csv`

Trade-off plots are stored in `reports/plots/`:

- `pipeline_fmax_vs_latency.svg`
- `pipeline_fmax_vs_boundary_stages.svg`
- `pipeline_incremental_fmax_gain.svg`
- `pipeline_area_tradeoff.svg`
- `pipeline_power_tradeoff.svg`
- `tracker_pipeline_comparison.svg`
- `energy_precision_sweep_16_to_256.svg`
- `fir_mag_width_sweep.svg`

The current highest-Fmax recorded design is
`pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart`:
169.233 MHz post-route derived Fmax for the current continuous-valid vectors,
with 1342 LUTs, 1831 FFs, 10 DSPs, and 0.125 W vectorless post-route total
power. The wider Energy62 and Energy64 variants remain fallback contracts until
the 29-bit FIR/magnitude width and always-on valid assumption are validated
against broader stimuli.

The accumulator start-load follow-up is intentionally kept in the report as a
negative result: it passes simulation, but drops to 117.165 MHz post-route
derived Fmax, so it does not replace the fast-round design.

The always-on FIR plus accumulator start-load follow-up is intentionally kept
as the positive companion result: it shows that accstart became useful only
after FIR valid/CE fanout was removed. Its current bottleneck is the narrowed
magnitude-square carry chain.

## Run Post-Route Implementation

The implementation scripts use Artix-7 `xc7a35tfgg484-1` so the wide
debug-style top-level output bus has enough package I/O for place-and-route.

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/impl_baseline.tcl
vivado -mode batch -source vivado/impl_pipelined.tcl
```

The reports are written to:

- `reports/baseline_impl/`
- `reports/pipelined_impl/`

## Run Post-Route Clock Sweep

After implementation checkpoints exist, run:

```tcl
cd C:/Users/CHOUDN3/Downloads/VLSI_project
vivado -mode batch -source vivado/sweep_post_route_timing.tcl
```

The sweep output is written to:

- `reports/clock_sweep/post_route_clock_sweep.csv`
- `reports/clock_sweep/post_route_clock_sweep_summary.txt`

This sweep is derived from the routed 100 MHz timing paths. It characterizes
the already-routed netlists without rerunning place-and-route at each clock.
