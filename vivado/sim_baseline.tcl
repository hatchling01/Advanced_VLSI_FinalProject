set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
set sim_dir [file join $root_dir reports baseline vivado_sim]
set xsim_run_dir [file join $sim_dir lockin_baseline_sim.sim sim_1 behav xsim]

file mkdir $sim_dir
cd $root_dir

create_project -force lockin_baseline_sim $sim_dir -part xc7a35tcpg236-1

file mkdir [file join $xsim_run_dir vectors]
foreach vector_file [glob -nocomplain [file join $root_dir vectors *]] {
    file copy -force $vector_file [file join $xsim_run_dir vectors]
}

read_verilog -sv [list \
    [file join $root_dir rtl nco.sv] \
    [file join $root_dir rtl iq_mixer.sv] \
    [file join $root_dir rtl fir_filter.sv] \
    [file join $root_dir rtl magnitude_sq.sv] \
    [file join $root_dir rtl bin_accumulator.sv] \
    [file join $root_dir rtl bin_accumulator_startload.sv] \
    [file join $root_dir rtl resonance_tracker.sv] \
    [file join $root_dir rtl lockin_baseline_top.sv] \
    [file join $root_dir tb tb_lockin_baseline.sv] \
]

set_property top tb_lockin_baseline [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
close_sim
close_project
