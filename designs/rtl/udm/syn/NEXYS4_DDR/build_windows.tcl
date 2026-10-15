# Run from Vivado Tcl console or with:
# vivado -mode batch -source build_windows.tcl
#
# All paths are resolved relative to this script, so the repository can be
# copied to another Windows computer without editing the project file.

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir NEXYS4_DDR.xpr]

open_project $project_file
set_property target_language Verilog [current_project]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

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

puts "Bitstream: [file join $script_dir NEXYS4_DDR.runs impl_1 NEXYS4_DDR.bit]"
close_project
