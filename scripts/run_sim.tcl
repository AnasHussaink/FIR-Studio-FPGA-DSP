# Requires the project created by create_project.tcl to be open.
# Usage: set testbench tb_fir_python; source scripts/run_sim.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
if {![info exists testbench]} {set testbench tb_fir_python}
set allowed {tb_fir_moving_average tb_fir_fixed_point tb_fir_compare tb_fir_python tb_fir_programmable tb_uart_loopback}
if {[lsearch -exact $allowed $testbench] < 0} {error "Unknown testbench: $testbench"}
catch {close_sim}
set_property top $testbench [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
set simdir [file join [get_property DIRECTORY [current_project]] fir_studio.sim sim_1 behav xsim]
file mkdir $simdir
file copy -force [file join $root sim data fir_vectors.txt] [file join $simdir fir_vectors.txt]
launch_simulation
run all
