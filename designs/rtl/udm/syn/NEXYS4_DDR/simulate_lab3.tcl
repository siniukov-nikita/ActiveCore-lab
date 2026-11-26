# vivado -mode batch -source simulate_lab3.tcl
# Add -tclargs pipeline to simulate Lab 4.
# In the Vivado Tcl console, source this script by its full path.
set sim_divider_mode multicycle
if {[info exists argv] && [llength $argv] > 0} {
    set sim_divider_mode [lindex $argv 0]
}
if {$sim_divider_mode ni {multicycle pipeline}} {
    error "Expected simulation mode: multicycle or pipeline"
}
set script_dir [file dirname [file normalize [info script]]]
if {[current_project -quiet] eq ""} {
    open_project [file join $script_dir NEXYS4_DDR.xpr]
} elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $script_dir} {
    error "Open NEXYS4_DDR.xpr before running this script, or close the current project"
}
if {[get_property IS_LOCKED [get_ips sys_clk]]} {
    upgrade_ip [get_ips sys_clk]
}
generate_target all [get_ips sys_clk]
set divider_dir [file normalize [file join $script_dir ../../../const_divider]]
set divider_simset sim_divider_${sim_divider_mode}
set divider_tb const_divider_${sim_divider_mode}_tb
if {![llength [get_filesets -quiet $divider_simset]]} {
    create_fileset -simset $divider_simset
    add_files -norecurse -fileset $divider_simset [file join $divider_dir tb ${divider_tb}.sv]
}
set_property top $divider_tb [get_filesets $divider_simset]
set_property SOURCE_SET sources_1 [get_filesets $divider_simset]
set_property xsim.simulate.runtime 0ns [get_filesets $divider_simset]
launch_simulation -simset $divider_simset -mode behavioral
run all
close_sim

set_property top tb [get_filesets sim_1]
set_property generic [list DIVIDER_MULTICYCLE=[expr {$sim_divider_mode eq "multicycle"}] \
    DIVIDER_PIPELINE=[expr {$sim_divider_mode eq "pipeline"}]] [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
puts "$sim_divider_mode simulations finished; check both PASS messages in the simulation logs."
