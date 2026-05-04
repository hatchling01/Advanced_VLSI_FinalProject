set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
set out_dir [file join $root_dir reports pipelined_plus5_firout_accbuf_fanout_place_probe]
set part_name xc7a35tfgg484-1

file mkdir $out_dir
cd $root_dir

proc prop_or_na {object prop_name} {
    if {[catch {set value [get_property $prop_name $object]}]} {
        return "NA"
    }
    if {$value eq ""} {
        return "NA"
    }
    return $value
}

proc csv_escape {value} {
    set text [string map {"\"" "\"\""} $value]
    return "\"$text\""
}

proc classify_region {startpoint endpoint} {
    set text [string tolower "$startpoint $endpoint"]
    if {[string first "u_fir" $text] >= 0 || [string first "gen_fir" $text] >= 0} {
        return "FIR"
    }
    if {[string first "u_mag" $text] >= 0 || [string first "gen_regular_mag" $text] >= 0 || [string first "gen_chunked_mag" $text] >= 0} {
        return "magnitude"
    }
    if {[string first "accumulator" $text] >= 0 || [string first "bin_energy" $text] >= 0 || [string first "running_energy" $text] >= 0} {
        return "accumulator"
    }
    if {[string first "tracker" $text] >= 0 || [string first "best_energy" $text] >= 0 || [string first "detected_bin" $text] >= 0} {
        return "tracker"
    }
    if {[string first "boundary" $text] >= 0} {
        return "boundary"
    }
    return "other"
}

proc write_top_paths_csv {csv_path max_paths} {
    set fd [open $csv_path w]
    puts $fd "rank,slack_ns,requirement_ns,data_path_delay_ns,logic_delay_ns,route_delay_ns,logic_levels,region,startpoint,endpoint"
    set rank 1
    foreach path [get_timing_paths -setup -max_paths $max_paths -nworst 1 -sort_by slack] {
        set slack [prop_or_na $path SLACK]
        set requirement [prop_or_na $path REQUIREMENT]
        set datapath [prop_or_na $path DATAPATH_DELAY]
        set logic_delay [prop_or_na $path DATAPATH_LOGIC_DELAY]
        set route_delay [prop_or_na $path DATAPATH_NET_DELAY]
        set logic_levels [prop_or_na $path LOGIC_LEVELS]
        set startpoint [prop_or_na $path STARTPOINT_PIN]
        set endpoint [prop_or_na $path ENDPOINT_PIN]
        set region [classify_region $startpoint $endpoint]
        puts $fd [join [list \
            $rank \
            $slack \
            $requirement \
            $datapath \
            $logic_delay \
            $route_delay \
            $logic_levels \
            $region \
            [csv_escape $startpoint] \
            [csv_escape $endpoint] \
        ] ","]
        incr rank
    }
    close $fd
}

create_project -force lockin_pipelined_plus5_firout_accbuf_fanout_place_probe [file join $out_dir vivado_place_probe] -part $part_name

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
    [file join $root_dir rtl magnitude_sq_narrow_pipelined.sv] \
    [file join $root_dir rtl bin_accumulator.sv] \
    [file join $root_dir rtl bin_accumulator_startload.sv] \
    [file join $root_dir rtl resonance_tracker.sv] \
    [file join $root_dir rtl resonance_tracker_pipelined.sv] \
    [file join $root_dir rtl resonance_tracker_compare_pipeline.sv] \
    [file join $root_dir rtl resonance_tracker_fanout.sv] \
    [file join $root_dir rtl lockin_pipelined_boundary_top.sv] \
    [file join $root_dir rtl lockin_pipelined_plus5_firout_accbuf_fanout_top.sv] \
]

read_xdc [file join $root_dir vivado constraints.xdc]

synth_design -top lockin_pipelined_plus5_firout_accbuf_fanout_top -part $part_name
report_timing_summary -file [file join $out_dir post_synth_timing_summary.rpt]
report_timing -setup -max_paths 20 -nworst 1 -sort_by slack -file [file join $out_dir post_synth_top20_setup_paths.rpt]
report_utilization -file [file join $out_dir post_synth_utilization.rpt]
if {[catch {report_high_fanout_nets -fanout_greater_than 20 -max_nets 50 -file [file join $out_dir post_synth_high_fanout_nets.rpt]} err]} {
    set fd [open [file join $out_dir post_synth_high_fanout_nets.rpt] w]
    puts $fd "report_high_fanout_nets failed: $err"
    close $fd
}

opt_design
place_design

report_timing_summary -file [file join $out_dir post_place_timing_summary.rpt]
report_timing -setup -max_paths 20 -nworst 1 -sort_by slack -file [file join $out_dir post_place_top20_setup_paths.rpt]
report_utilization -file [file join $out_dir post_place_utilization.rpt]
report_clock_utilization -file [file join $out_dir post_place_clock_utilization.rpt]
if {[catch {report_high_fanout_nets -fanout_greater_than 20 -max_nets 50 -file [file join $out_dir post_place_high_fanout_nets.rpt]} err]} {
    set fd [open [file join $out_dir post_place_high_fanout_nets.rpt] w]
    puts $fd "report_high_fanout_nets failed: $err"
    close $fd
}

write_top_paths_csv [file join $out_dir post_place_top20_setup_paths.csv] 20
write_checkpoint -force [file join $out_dir lockin_pipelined_plus5_firout_accbuf_fanout_placed.dcp]

set summary_fd [open [file join $out_dir early_stop_summary.txt] w]
puts $summary_fd "Stage-A place probe for pipelined_plus5_firout_accbuf_fanout"
puts $summary_fd "This run intentionally stops after place_design."
puts $summary_fd "Continue to full route only if high-fanout control nets are meaningfully reduced without a suspicious new timing path."
close $summary_fd

puts "Place-probe reports written to $out_dir"
close_project
