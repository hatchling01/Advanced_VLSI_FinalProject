set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
set design_name pipelined_plus5_firout_accbuf
set checkpoint_path [file join $root_dir reports pipelined_plus5_firout_accbuf_impl lockin_pipelined_plus5_firout_accbuf_routed.dcp]
set out_dir [file join $root_dir reports diagnostics $design_name]

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

proc write_region_summary {csv_path top_paths_csv} {
    array set count {}
    array set worst {}

    set fd [open $top_paths_csv r]
    gets $fd
    while {[gets $fd line] >= 0} {
        set fields [split $line ","]
        set slack [lindex $fields 1]
        set region [lindex $fields 7]
        if {![info exists count($region)]} {
            set count($region) 0
            set worst($region) $slack
        }
        incr count($region)
        if {$slack < $worst($region)} {
            set worst($region) $slack
        }
    }
    close $fd

    set out [open $csv_path w]
    puts $out "region,path_count_in_top_paths,worst_slack_ns"
    foreach region [lsort [array names count]] {
        puts $out "$region,$count($region),$worst($region)"
    }
    close $out
}

proc write_control_net_csv {csv_path} {
    set fd [open $csv_path w]
    puts $fd "pin_type,net,fanout,driver"
    foreach pin_type {CE R S CLR SR PRE} {
        set pins [get_pins -quiet -hier -filter "REF_PIN_NAME == $pin_type"]
        foreach net [lsort -unique [get_nets -quiet -of_objects $pins]] {
            set fanout [prop_or_na $net FANOUT]
            set driver "NA"
            set driver_pins [get_pins -quiet -of_objects $net -filter {DIRECTION == OUT}]
            if {[llength $driver_pins] > 0} {
                set driver [lindex $driver_pins 0]
            }
            puts $fd [join [list $pin_type [csv_escape $net] $fanout [csv_escape $driver]] ","]
        }
    }
    close $fd
}

open_checkpoint $checkpoint_path
update_timing

report_timing_summary -file [file join $out_dir timing_summary_deep.rpt]
report_timing -setup -max_paths 20 -nworst 1 -sort_by slack -file [file join $out_dir top20_setup_paths.rpt]
report_timing -setup -max_paths 10 -nworst 1 -sort_by slack -path_type full_clock_expanded -file [file join $out_dir top10_setup_paths_full_clock.rpt]
report_utilization -file [file join $out_dir utilization_snapshot.rpt]
report_power -file [file join $out_dir power_snapshot.rpt]
report_clock_utilization -file [file join $out_dir clock_utilization_snapshot.rpt]

if {[catch {report_high_fanout_nets -fanout_greater_than 20 -max_nets 50 -file [file join $out_dir high_fanout_nets.rpt]} err]} {
    set fd [open [file join $out_dir high_fanout_nets.rpt] w]
    puts $fd "report_high_fanout_nets failed: $err"
    close $fd
}

set top_paths_csv [file join $out_dir top20_setup_paths.csv]
write_top_paths_csv $top_paths_csv 20
write_region_summary [file join $out_dir top20_region_summary.csv] $top_paths_csv
write_control_net_csv [file join $out_dir control_net_fanout.csv]

set summary_fd [open [file join $out_dir diagnostic_summary.txt] w]
puts $summary_fd "Diagnostic pass for $design_name"
puts $summary_fd "Checkpoint: $checkpoint_path"
puts $summary_fd "Generated reports:"
puts $summary_fd "  timing_summary_deep.rpt"
puts $summary_fd "  top20_setup_paths.rpt"
puts $summary_fd "  top10_setup_paths_full_clock.rpt"
puts $summary_fd "  top20_setup_paths.csv"
puts $summary_fd "  top20_region_summary.csv"
puts $summary_fd "  high_fanout_nets.rpt"
puts $summary_fd "  control_net_fanout.csv"
puts $summary_fd "  utilization_snapshot.rpt"
puts $summary_fd "  power_snapshot.rpt"
close $summary_fd

puts "Diagnostic reports written to $out_dir"
close_design
