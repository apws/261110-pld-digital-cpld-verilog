# Run with the Quartus installation appropriate for the target family.
# quartus_sh -t tools/create_quartus_project.tcl "MAX3000A" EPM3064ATC44-10 output/q3064
# Creates an UNCONSTRAINED study project: no programming file is board-approved.
package require ::quartus::project
if {[llength $quartus(args)] != 3} {
    error {Usage: quartus_sh -t tools/create_quartus_project.tcl FAMILY DEVICE NEW_DIRECTORY}
}
set family [lindex $quartus(args) 0]
set device [lindex $quartus(args) 1]
set destination [file normalize [lindex $quartus(args) 2]]
set source_file [file normalize [file join [file dirname [info script]] .. examples verilog glue.v]]
if {[file exists $destination]} {
    error "Destination already exists: $destination. Choose a new study directory."
}
file mkdir $destination
cd $destination
project_new glue
set_global_assignment -name FAMILY $family
set_global_assignment -name DEVICE $device
set_global_assignment -name TOP_LEVEL_ENTITY glue
set_global_assignment -name VERILOG_FILE $source_file
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY build
export_assignments
project_close
set note [open UNCONSTRAINED.txt w]
puts $note "Study project only. Add reviewed package pin, I/O voltage and timing constraints before hardware use."
close $note
puts "Created $destination/glue.qpf (UNCONSTRAINED; not board-ready)."
