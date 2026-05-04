# Project Notes

## Goal

Build a baseline and pipelined fixed-point lock-in DSP accelerator that detects
the resonance bin from a swept noisy signal stream.

## Main Comparison

The final VLSI comparison should include:

- Functional correctness
- Critical path
- Estimated Fmax
- LUT usage
- FF usage
- DSP usage
- Latency
- Throughput

## Minimum Deliverables

- Python golden model
- Generated test vectors
- Baseline SystemVerilog accelerator
- Pipelined SystemVerilog accelerator
- RTL simulation results
- Vivado timing and utilization reports
- Final comparison table

## Standing Update Rule

After every design-decision update or new architecture variant, update both:

- `docs/progress_results.md`
- `docs/architecture_schematics.md`

Each update should record:

- What changed architecturally
- Updated schematic/block diagram
- Functional simulation result
- Timing result
- Critical path
- Area/resource utilization
- Power estimate
- Latency/throughput impact
- Whether results are from synthesis or post-implementation
- Any caveats, warnings, or assumptions

Do not mix synthesis and implementation numbers without clearly labeling them.
