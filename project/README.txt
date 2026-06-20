Экспортированный Vivado-проект

Как восстановить проект:

1. Открыть Vivado.
2. В Tcl Console перейти в папку экспорта:
   cd путь/к/fir_project_export
3. Выполнить:
   source scripts/create_project.tcl

Для повторного экспорта проекта в консоли tcl выполнить:
source [file join [get_property DIRECTORY [current_project]] scripts export_project.tcl]

Структура:
rtl/          - RTL-исходники
tb/           - testbench-файлы
test_vectors/ - входные и эталонные данные
constraints/  - XDC constraints
scripts/      - Tcl-скрипты

Part: xc7z020clg400-1
Synthesis top: filter_cell
Simulation top: tb_params
