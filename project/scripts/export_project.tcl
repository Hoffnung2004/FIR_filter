# ============================================================
# export_project.tcl
# Экспортирует открытый Vivado-проект в переносимую папку
# ============================================================

if {[string equal [current_project -quiet] ""]} {
    error "No Vivado project is currently open."
}

set project_dir  [get_property DIRECTORY [current_project]]
set project_name [get_property NAME [current_project]]
set part_name    [get_property PART [current_project]]
set synth_top [get_property top [get_filesets sources_1]]
set sim_top   [get_property top [get_filesets sim_1]]

# Вариант 1: экспорт рядом с папкой проекта
set export_dir [file normalize [file join $project_dir ".." "${project_name}_export"]]

# Вариант 2: экспорт внутрь папки проекта
# set export_dir [file normalize [file join $project_dir "export"]]

puts "Project directory: $project_dir"
puts "Project name:      $project_name"
puts "Export directory:  $export_dir"

if {[file exists $export_dir]} {
    file delete -force $export_dir
}

file mkdir $export_dir
file mkdir [file join $export_dir rtl]
file mkdir [file join $export_dir tb]
file mkdir [file join $export_dir constraints]
file mkdir [file join $export_dir test_vectors]
file mkdir [file join $export_dir scripts]

# ============================================================
# Копирование RTL-файлов
# ============================================================

set rtl_files [get_files -of_objects [get_filesets sources_1]]

foreach f $rtl_files {
    set ext [file extension $f]

    if {$ext eq ".sv" || $ext eq ".v" || $ext eq ".vh" || $ext eq ".svh"} {
        file copy -force $f $export_dir/rtl/
        puts "RTL: $f"
    }
}

# ============================================================
# Копирование simulation-файлов
# ============================================================

set sim_files [get_files -of_objects [get_filesets sim_1]]

foreach f $sim_files {
    set ext [file extension $f]

    if {$ext eq ".sv" || $ext eq ".v" || $ext eq ".vh" || $ext eq ".svh"} {
        file copy -force $f $export_dir/tb/
        puts "TB: $f"
    }

    if {$ext eq ".txt" || $ext eq ".dat" || $ext eq ".mem" || $ext eq ".coe"} {
        file copy -force $f $export_dir/test_vectors/
        puts "Vector: $f"
    }
}

# ============================================================
# Копирование constraints
# ============================================================

set constr_files [get_files -of_objects [get_filesets constrs_1]]

foreach f $constr_files {
    set ext [file extension $f]

    if {$ext eq ".xdc"} {
        file copy -force $f $export_dir/constraints/
        puts "XDC: $f"
    }
}

# ============================================================
# Генерация create_project.tcl
# ============================================================

set create_script "$export_dir/scripts/create_project.tcl"
set fp [open $create_script "w"]

puts $fp "# ============================================================"
puts $fp "# create_project.tcl"
puts $fp "# Создаёт Vivado-проект из экспортированных исходников"
puts $fp "# ============================================================"
puts $fp ""
puts $fp "set project_name \"fir_filter_project\""
puts $fp "set script_dir \[file dirname \[file normalize \[info script\]\]\]"
puts $fp "set export_dir \[file dirname \$script_dir\]"
puts $fp "set project_dir \[file normalize \[file join \$export_dir \"..\" \"\${project_name}_restored\"\]\]"
puts $fp ""
puts $fp "create_project \$project_name \$project_dir -part $part_name -force"
puts $fp ""

puts $fp "# RTL sources"
puts $fp "add_files -fileset sources_1 \[glob ./rtl/*.{sv,v,vh,svh}\]"
puts $fp ""

puts $fp "# Simulation sources"
puts $fp "add_files -fileset sim_1 \[glob ./tb/*.{sv,v,vh,svh}\]"
puts $fp ""

puts $fp "# Test vectors"
puts $fp "if {\[llength \[glob -nocomplain ./test_vectors/*\]\] > 0} {"
puts $fp "    add_files -fileset sim_1 \[glob ./test_vectors/*\]"
puts $fp "}"
puts $fp ""

puts $fp "# Constraints"
puts $fp "if {\[llength \[glob -nocomplain ./constraints/*.xdc\]\] > 0} {"
puts $fp "    add_files -fileset constrs_1 \[glob ./constraints/*.xdc\]"
puts $fp "}"
puts $fp ""

if {$synth_top ne ""} {
    puts $fp "set_property top $synth_top \[get_filesets sources_1\]"
}

if {$sim_top ne ""} {
    puts $fp "set_property top $sim_top \[get_filesets sim_1\]"
}

puts $fp ""
puts $fp "# Copy export script into created Vivado project directory"
puts $fp "set created_project_dir \[get_property DIRECTORY \[current_project\]\]"
puts $fp "file mkdir \[file join \$created_project_dir scripts\]"
puts $fp ""
puts $fp "if {\[file exists ./scripts/export_project.tcl\]} {"
puts $fp "    file copy -force ./scripts/export_project.tcl \[file join \$created_project_dir scripts export_project.tcl\]"
puts $fp "}"

puts $fp ""
puts $fp "update_compile_order -fileset sources_1"
puts $fp "update_compile_order -fileset sim_1"
puts $fp ""
puts $fp "puts \"Project created successfully.\""
close $fp

puts "Generated: $create_script"

# ============================================================
# Генерация README
# ============================================================

set readme "$export_dir/README.txt"
set fp [open $readme "w"]

puts $fp "Экспортированный Vivado-проект"
puts $fp ""
puts $fp "Как восстановить проект:"
puts $fp ""
puts $fp "1. Открыть Vivado."
puts $fp "2. В Tcl Console перейти в папку экспорта:"
puts $fp "   cd путь/к/fir_project_export"
puts $fp "3. Выполнить:"
puts $fp "   source scripts/create_project.tcl"
puts $fp ""
puts $fp "Для повторного экспорта проекта в консоли tcl выполнить:"
puts $fp "source \[file join \[get_property DIRECTORY \[current_project\]\] scripts export_project.tcl\]"
puts $fp ""
puts $fp "Структура:"
puts $fp "rtl/          - RTL-исходники"
puts $fp "tb/           - testbench-файлы"
puts $fp "test_vectors/ - входные и эталонные данные"
puts $fp "constraints/  - XDC constraints"
puts $fp "scripts/      - Tcl-скрипты"
puts $fp ""
puts $fp "Part: $part_name"
puts $fp "Synthesis top: $synth_top"
puts $fp "Simulation top: $sim_top"

close $fp

puts "Generated: $readme"
puts "Export finished: $export_dir"

# ============================================================
# Добавление скрипта для экспорта
# ============================================================

set current_script [info script]

if {$current_script ne ""} {
    file copy -force $current_script [file join $export_dir scripts export_project.tcl]
    puts "Export script: $current_script"
} else {
    puts "Warning: cannot detect current export_project.tcl path"
}