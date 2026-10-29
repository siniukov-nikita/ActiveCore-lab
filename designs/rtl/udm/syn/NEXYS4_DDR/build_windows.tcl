# vivado -mode batch -source build_windows.tcl -tclargs multicycle
# Use "comb" instead of "multicycle" to build lab 2 for comparison.
# In the Tcl console: set lab_divider_mode multicycle; source <path>/build_windows.tcl

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir NEXYS4_DDR.xpr]
if {![info exists lab_divider_mode]} {
    set lab_divider_mode multicycle
    if {[info exists argv] && [llength $argv] > 0} {
        set lab_divider_mode [lindex $argv 0]
    }
}
if {$lab_divider_mode ni {comb multicycle}} {
    error "Expected divider mode: comb or multicycle"
}
if {[current_project -quiet] eq ""} {
    open_project $project_file
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $script_dir} {
    error "Open NEXYS4_DDR.xpr before running this script, or close the current project"
}
set_property part xc7a100tcsg324-1 [current_project]
set_property target_language Verilog [current_project]
set_property generic [list DIVIDER_MULTICYCLE=[expr {$lab_divider_mode eq "multicycle"}]] [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Regenerate Clocking Wizard products for the board's -1 speed grade.
if {[get_property IS_LOCKED [get_ips sys_clk]]} {
    upgrade_ip [get_ips sys_clk]
}
reset_target all [get_ips sys_clk]
generate_target all [get_ips sys_clk]
if {[llength [get_runs -quiet sys_clk_synth_1]]} {
    reset_run sys_clk_synth_1
}
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match "*Complete!" [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "*Complete!" [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation/bitstream generation failed: [get_property STATUS [get_runs impl_1]]"
}

set report_dir [file join $script_dir reports $lab_divider_mode]
file mkdir $report_dir
open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -file [file join $report_dir timing_summary.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization_hierarchical.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
set bitstream [file join $script_dir NEXYS4_DDR.runs impl_1 NEXYS4_DDR.bit]
file copy -force $bitstream [file join $report_dir NEXYS4_DDR.bit]
puts "Mode: $lab_divider_mode"
puts "Bitstream and reports: $report_dir"
close_project
unset lab_divider_mode
