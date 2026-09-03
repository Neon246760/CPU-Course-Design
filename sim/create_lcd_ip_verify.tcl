# 自动创建 "lcd_controller IP 使用验证工程"
# 作用: 演示打包好的 IP 如何被消费——注册仓库 -> 在 Block Design 中例化 -> 连线 -> 校验
# 用法:
#   E:\Vivado\2025.2\Vivado\bin\vivado.bat -mode batch -source sim/create_lcd_ip_verify.tcl
#   (可用第 1 个参数覆盖工程位置: ... -tclargs E:/somewhere/lcd_ip_verify)
# 产物: <工程位置>/lcd_ip_verify.xpr(内含 lcd_ctrl_bd,已 Validate 通过)

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set ip_repo    [file join $root_dir ip lcd_controller_v1_0]
set part_name  xc7a100tcsg324-1

set proj_loc [file join E:/My_Files VivadoProjects lcd_ip_verify]
if {$argc >= 1} { set proj_loc [lindex $argv 0] }

puts "==> IP repository: $ip_repo"
puts "==> Project      : $proj_loc"

# 1. 新建独立工程(不动 CPU 工程)
create_project -force lcd_ip_verify $proj_loc -part $part_name

# 2. 注册 IP 仓库并刷新 Catalog(等价于 GUI: Settings -> IP -> Repository)
set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog

# 3. 新建 Block Design 并放入打包好的 lcd_controller(等价于 GUI 从 Catalog 拖入)
create_bd_design lcd_ctrl_bd
create_bd_cell -type ip -vlnv local:user:lcd_controller:1.0 lcd_ctrl

# 4. 把 IP 的全部端口做成外部端口
create_bd_port -dir I -type clk clk
create_bd_port -dir I -type rst reset
create_bd_port -dir I tx_valid
create_bd_port -dir I tx_rs
create_bd_port -dir I -from 7 -to 0 tx_data
create_bd_port -dir I reinit_req
create_bd_port -dir I clear_req
foreach p {tx_ready initialized lcd_cs_n lcd_rst_n lcd_sck lcd_mosi lcd_rs} {
  create_bd_port -dir O $p
}

# 5. 连线
connect_bd_net [get_bd_ports clk]        [get_bd_pins lcd_ctrl/clk]
connect_bd_net [get_bd_ports reset]      [get_bd_pins lcd_ctrl/reset]
connect_bd_net [get_bd_ports tx_valid]   [get_bd_pins lcd_ctrl/tx_valid]
connect_bd_net [get_bd_ports tx_rs]      [get_bd_pins lcd_ctrl/tx_rs]
connect_bd_net [get_bd_ports tx_data]    [get_bd_pins lcd_ctrl/tx_data]
connect_bd_net [get_bd_ports reinit_req] [get_bd_pins lcd_ctrl/reinit_req]
connect_bd_net [get_bd_ports clear_req]  [get_bd_pins lcd_ctrl/clear_req]
connect_bd_net [get_bd_pins lcd_ctrl/tx_ready]    [get_bd_ports tx_ready]
connect_bd_net [get_bd_pins lcd_ctrl/initialized] [get_bd_ports initialized]
connect_bd_net [get_bd_pins lcd_ctrl/lcd_cs_n]    [get_bd_ports lcd_cs_n]
connect_bd_net [get_bd_pins lcd_ctrl/lcd_rst_n]   [get_bd_ports lcd_rst_n]
connect_bd_net [get_bd_pins lcd_ctrl/lcd_sck]     [get_bd_ports lcd_sck]
connect_bd_net [get_bd_pins lcd_ctrl/lcd_mosi]    [get_bd_ports lcd_mosi]
connect_bd_net [get_bd_pins lcd_ctrl/lcd_rs]      [get_bd_ports lcd_rs]

# 6. 声明时钟/复位属性(解决 BD 41-758 类报错的关键)
set_property FREQ_HZ 25000000 [get_bd_ports clk]
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports reset]
set_property CONFIG.ASSOCIATED_RESET reset [get_bd_ports clk]

# 7. 校验并保存
if {[catch {validate_bd_design} result]} {
  puts "VALIDATE_FAILED: $result"
  exit 1
}
save_bd_design
puts "======================================================"
puts "验证工程创建完成并已通过 Validate Design"
puts "工程位置: $proj_loc/lcd_ip_verify.xpr"
puts "下一步(GUI): 打开该工程 -> Sources 中双击 lcd_ctrl_bd 查看原理图"
puts "======================================================"
close_project
exit
