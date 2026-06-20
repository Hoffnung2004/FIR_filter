# ============================================================
# create_project.tcl
# Создаёт Vivado-проект из экспортированных исходников
# ============================================================

set project_name "fir_filter_project"
set script_dir [file dirname [file normalize [info script]]]
set export_dir [file dirname $script_dir]
set project_dir [file normalize [file join $export_dir ".." "${project_name}_restored"]]

create_project $project_name $project_dir -part xc7z020clg400-1 -force

# RTL sources
add_files -fileset sources_1 [glob ./rtl/*.{sv,v,vh,svh}]

# Simulation sources
add_files -fileset sim_1 [glob ./tb/*.{sv,v,vh,svh}]

# Test vectors
if {[llength [glob -nocomplain ./test_vectors/*]] > 0} {
    add_files -fileset sim_1 [glob ./test_vectors/*]
}

# Constraints
if {[llength [glob -nocomplain ./constraints/*.xdc]] > 0} {
    add_files -fileset constrs_1 [glob ./constraints/*.xdc]
}

set_property top filter_cell [get_filesets sources_1]
set_property top tb_params [get_filesets sim_1]

# Copy export script into created Vivado project directory
set created_project_dir [get_property DIRECTORY [current_project]]
file mkdir [file join $created_project_dir scripts]

if {[file exists ./scripts/export_project.tcl]} {
    file copy -force ./scripts/export_project.tcl [file join $created_project_dir scripts export_project.tcl]
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created successfully."
