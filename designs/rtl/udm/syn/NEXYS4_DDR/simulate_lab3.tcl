# vivado -mode batch -source simulate_lab3.tcl
# In the Vivado Tcl console, source this script by its full path.
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
if {![llength [get_filesets -quiet sim_divider_multicycle]]} {
    create_fileset -simset sim_divider_multicycle
}
add_files -norecurse -fileset sim_divider_multicycle [file join $divider_dir tb const_divider_multicycle_tb.sv]
set_property top const_divider_multicycle_tb [get_filesets sim_divider_multicycle]
set_property SOURCE_SET sources_1 [get_filesets sim_divider_multicycle]
set_property xsim.simulate.runtime 0ns [get_filesets sim_divider_multicycle]
launch_simulation -simset sim_divider_multicycle -mode behavioral
run all
close_sim

set_property top tb [get_filesets sim_1]
set_property generic {DIVIDER_MULTICYCLE=1} [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
puts "Lab 3 simulations finished; check both PASS messages in the simulation logs."
