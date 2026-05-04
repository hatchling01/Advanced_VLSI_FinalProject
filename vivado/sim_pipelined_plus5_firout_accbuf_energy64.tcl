set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
set sim_dir [file join $root_dir reports pipelined_plus5_firout_accbuf_energy64 vivado_sim]
set xsim_run_dir [file join $sim_dir lockin_pipelined_plus5_firout_accbuf_energy64_sim.sim sim_1 behav xsim]

file mkdir $sim_dir
cd $root_dir

create_project -force lockin_pipelined_plus5_firout_accbuf_energy64_sim $sim_dir -part xc7a35tcpg236-1

file mkdir [file join $xsim_run_dir vectors]
foreach vector_file [glob -nocomplain [file join $root_dir vectors *]] {
    file copy -force $vector_file [file join $xsim_run_dir vectors]
}

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
    [file join $root_dir tb tb_lockin_pipelined_plus5_firout_accbuf_energy64.sv] \
]

set_property top tb_lockin_pipelined_plus5_firout_accbuf_energy64 [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
close_sim
close_project
