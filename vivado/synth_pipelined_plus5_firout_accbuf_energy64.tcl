set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
set out_dir [file join $root_dir reports pipelined_plus5_firout_accbuf_energy64]

file mkdir $out_dir
cd $root_dir

create_project -force lockin_pipelined_plus5_firout_accbuf_energy64_synth [file join $out_dir vivado_synth] -part xc7a35tcpg236-1

read_verilog -sv [list \
    [file join $root_dir rtl nco.sv] \
    [file join $root_dir rtl iq_mixer.sv] \
    [file join $root_dir rtl fir_filter.sv] \
    [file join $root_dir rtl fir_filter_pipelined.sv] \
    [file join $root_dir rtl fir_filter_pipelined_outreg.sv] \
    [file join $root_dir rtl fir_filter_pipelined_outreg_fanout.sv] \
    [file join $root_dir rtl magnitude_sq.sv] \
    [file join $root_dir rtl magnitude_sq_pipelined.sv] \
    [file join $root_dir rtl magnitude_sq_pipelined_fanout.sv] \
    [file join $root_dir rtl magnitude_sq_chunked_pipeline.sv] \
    [file join $root_dir rtl magnitude_sq_narrow_pipelined.sv] \
    [file join $root_dir rtl bin_accumulator.sv] \
    [file join $root_dir rtl bin_accumulator_startload.sv] \
    [file join $root_dir rtl resonance_tracker.sv] \
    [file join $root_dir rtl resonance_tracker_pipelined.sv] \
    [file join $root_dir rtl resonance_tracker_compare_pipeline.sv] \
    [file join $root_dir rtl resonance_tracker_fanout.sv] \
    [file join $root_dir rtl lockin_pipelined_boundary_top.sv] \
    [file join $root_dir rtl lockin_pipelined_plus5_firout_accbuf_energy64_top.sv] \
]

read_xdc [file join $root_dir vivado constraints.xdc]

synth_design -top lockin_pipelined_plus5_firout_accbuf_energy64_top -part xc7a35tcpg236-1

report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_timing -max_paths 10 -file [file join $out_dir critical_paths.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
report_power -file [file join $out_dir power.rpt]

write_checkpoint -force [file join $out_dir lockin_pipelined_plus5_firout_accbuf_energy64_synth.dcp]
close_project
