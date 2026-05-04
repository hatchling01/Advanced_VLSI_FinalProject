set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
set out_dir [file join $root_dir reports clock_sweep]

file mkdir $out_dir
cd $root_dir

# Vivado checkpoints keep clock PERIOD read-only after route.  This script
# therefore characterizes Fmax by extracting the routed 100 MHz worst setup
# path and deriving equivalent WNS values across a frequency sweep.
set periods_ns {25.000 20.000 15.000 12.500 11.000 10.000 9.500 9.000 8.500 8.000 7.500}

set designs [list \
    [list baseline  [file join $root_dir reports baseline_impl lockin_baseline_routed.dcp]] \
    [list pipelined [file join $root_dir reports pipelined_impl lockin_pipelined_routed.dcp]] \
    [list pipelined_plus1 [file join $root_dir reports pipelined_plus1_impl lockin_pipelined_plus1_routed.dcp]] \
    [list pipelined_plus5 [file join $root_dir reports pipelined_plus5_impl lockin_pipelined_plus5_routed.dcp]] \
    [list pipelined_plus5_tracker [file join $root_dir reports pipelined_plus5_tracker_impl lockin_pipelined_plus5_tracker_routed.dcp]] \
    [list pipelined_plus5_firout [file join $root_dir reports pipelined_plus5_firout_impl lockin_pipelined_plus5_firout_routed.dcp]] \
    [list pipelined_plus5_firout_tracker [file join $root_dir reports pipelined_plus5_firout_tracker_impl lockin_pipelined_plus5_firout_tracker_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf [file join $root_dir reports pipelined_plus5_firout_accbuf_impl lockin_pipelined_plus5_firout_accbuf_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_magpipe [file join $root_dir reports pipelined_plus5_firout_accbuf_magpipe_impl lockin_pipelined_plus5_firout_accbuf_magpipe_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_trackercmp [file join $root_dir reports pipelined_plus5_firout_accbuf_trackercmp_impl lockin_pipelined_plus5_firout_accbuf_trackercmp_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_fanout [file join $root_dir reports pipelined_plus5_firout_accbuf_fanout_impl lockin_pipelined_plus5_firout_accbuf_fanout_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_energy64 [file join $root_dir reports pipelined_plus5_firout_accbuf_energy64_impl lockin_pipelined_plus5_firout_accbuf_energy64_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_energy62 [file join $root_dir reports pipelined_plus5_firout_accbuf_energy62_impl lockin_pipelined_plus5_firout_accbuf_energy62_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_energy62_fir29 [file join $root_dir reports e62_fir29_impl e62_fir29_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_energy62_fir29_fastround [file join $root_dir reports e62_fir29_fr_impl e62_fir29_fr_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_energy62_fir29_fastround_accstart [file join $root_dir reports e62_fir29_fr_accstart_impl e62_fir29_fr_accstart_routed.dcp]] \
    [list pipelined_plus5_firout_accbuf_energy62_fir29_fastround_alwayson_accstart [file join $root_dir reports e62_fir29_fr_ao_accstart_impl e62_fir29_fr_ao_accstart_routed.dcp]] \
]

proc prop_or_na {object prop_name} {
    if {[catch {set value [get_property $prop_name $object]}]} {
        return "NA"
    }
    if {$value eq ""} {
        return "NA"
    }
    return $value
}

proc fmt_or_na {value fmt} {
    if {$value eq "NA"} {
        return "NA"
    }
    return [format $fmt $value]
}

set csv_path [file join $out_dir post_route_clock_sweep.csv]
set summary_path [file join $out_dir post_route_clock_sweep_summary.txt]
set csv_fd [open $csv_path w]
set summary_fd [open $summary_path w]

puts $csv_fd "design,period_ns,frequency_mhz,derived_wns_ns,pass,derived_min_period_ns,derived_fmax_mhz,base_clock_period_ns,base_wns_ns,data_path_delay_ns,logic_levels,startpoint,endpoint"
puts $summary_fd "Post-route clock sweep derived from routed 100 MHz timing"
puts $summary_fd "Generated from: $root_dir"
puts $summary_fd ""

foreach design_info $designs {
    set design_name [lindex $design_info 0]
    set checkpoint_path [lindex $design_info 1]

    puts "Opening $design_name checkpoint: $checkpoint_path"
    open_checkpoint $checkpoint_path
    update_timing

    set clk_obj [get_clocks clk]
    set base_period [get_property PERIOD $clk_obj]
    set path [lindex [get_timing_paths -setup -max_paths 1 -nworst 1] 0]
    set base_wns [prop_or_na $path SLACK]
    set data_delay [prop_or_na $path DATAPATH_DELAY]
    set logic_levels [prop_or_na $path LOGIC_LEVELS]
    set startpoint [prop_or_na $path STARTPOINT_PIN]
    set endpoint [prop_or_na $path ENDPOINT_PIN]

    if {$base_wns eq "NA"} {
        set min_period "NA"
        set fmax "NA"
    } else {
        set min_period [expr {$base_period - $base_wns}]
        set fmax [expr {1000.0 / $min_period}]
    }

    puts $summary_fd "$design_name"
    puts $summary_fd "  routed checkpoint: $checkpoint_path"
    puts $summary_fd "  base clock period: [fmt_or_na $base_period %.3f] ns"
    puts $summary_fd "  base WNS: [fmt_or_na $base_wns %.3f] ns"
    puts $summary_fd "  derived min period: [fmt_or_na $min_period %.3f] ns"
    puts $summary_fd "  derived Fmax: [fmt_or_na $fmax %.3f] MHz"
    puts $summary_fd "  startpoint: $startpoint"
    puts $summary_fd "  endpoint: $endpoint"
    puts $summary_fd ""

    foreach period_ns $periods_ns {
        set freq_mhz [expr {1000.0 / $period_ns}]

        if {$min_period eq "NA"} {
            set derived_wns "NA"
            set pass "NA"
        } else {
            set derived_wns [expr {$period_ns - $min_period}]
            set pass [expr {$derived_wns >= 0.0 ? "PASS" : "FAIL"}]
        }

        puts $csv_fd [join [list \
            $design_name \
            [format "%.3f" $period_ns] \
            [format "%.3f" $freq_mhz] \
            [fmt_or_na $derived_wns "%.3f"] \
            $pass \
            [fmt_or_na $min_period "%.3f"] \
            [fmt_or_na $fmax "%.3f"] \
            [fmt_or_na $base_period "%.3f"] \
            [fmt_or_na $base_wns "%.3f"] \
            [fmt_or_na $data_delay "%.3f"] \
            $logic_levels \
            $startpoint \
            $endpoint \
        ] ","]

        puts [format "%s period=%0.3f ns freq=%0.3f MHz derived_WNS=%s pass=%s Fmax=%s MHz" \
            $design_name $period_ns $freq_mhz [fmt_or_na $derived_wns "%.3f"] $pass [fmt_or_na $fmax "%.3f"]]
    }

    close_design
}

close $csv_fd
close $summary_fd
puts "Clock sweep CSV written to $csv_path"
puts "Clock sweep summary written to $summary_path"
