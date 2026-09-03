# 将 lcd_controller(+lcd_spi_master)打包为 Vivado 用户 IP
# 对应文档: docs/IP核生成与验证指南.md
#
# 用法(任选其一):
#   1) 批处理(推荐,不影响当前打开的 GUI 工程):
#        E:\Vivado\2025.2\Vivado\bin\vivado.bat -mode batch -source sim/package_lcd_ip.tcl
#   2) GUI Tcl Console: source <仓库绝对路径>/sim/package_lcd_ip.tcl
#      (注意: 会关闭当前打开的工程,先保存;打包不修改任何 RTL 源码)
#
# 产物: <仓库>/ip/lcd_controller_v1_0/{component.xml, src/, xgui/}

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set proj_dir   [file join $root_dir build ip_pkg_proj]
set out_dir    [file join $root_dir ip lcd_controller_v1_0]
set part       xc7a100tcsg324-1

# VLNV 标识(提交前可按需改为学校/团队标识)
set ip_vendor  local
set ip_library user
set ip_name    lcd_controller
set ip_version 1.0

file delete -force $proj_dir
file mkdir [file dirname $out_dir]

create_project lcd_controller_pkg $proj_dir -part $part -force
add_files -norecurse [list \
  [file join $root_dir rtl peripheral lcd_spi_master.sv] \
  [file join $root_dir rtl peripheral lcd_controller.sv]]
set_property top lcd_controller [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $out_dir -vendor $ip_vendor -library $ip_library \
  -name $ip_name -version $ip_version -taxonomy /UserIP -import_files -force
ipx::save_core [ipx::current_core]

puts "\n======================================================"
puts "IP 打包完成: $out_dir/component.xml"
puts "下一步(GUI): Settings -> IP -> Repository 添加 $out_dir"
puts "======================================================"
close_project
exit
