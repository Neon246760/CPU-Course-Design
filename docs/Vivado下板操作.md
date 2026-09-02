# EES-338：从创建 Vivado 工程到下板

本文以 Vivado 2019.2 为例。代码仓库只保存 RTL、约束、固件和测试脚本，不保存
`.xpr`、`.runs`、`.cache`、`.Xil`、bitstream 等 Vivado 工程产物。

> **器件必须以 Hardware Manager 的实际识别结果为准。** 随仓库说明书描述的是
> `XC7A35TCSG324-1C` 标准版，但已有实板被 JTAG 识别为 `xc7a100t_0`。35T bitstream
> 不能下载到 100T。对于该 100T/CSG324 实板，工程 Part 应选择
> `xc7a100tcsg324-1`，并从综合开始重新生成 bitstream。

## 1. 准备路径

代码仓库位置：

```text
D:\2_files\2_academic\1_course\CPU-Course-Design
```

在仓库之外准备一个工程目录，例如：

```text
D:\VivadoProjects\CPU-Course-Design-EES338
```

不建议把 Vivado 工程建在代码仓库中，以免 `.runs`、缓存和日志污染源码目录。

## 2. 创建空工程

1. 启动 **Vivado 2019.2**。
2. 点击 **Create Project**，进入向导后点击 **Next**。
3. `Project name` 可填写 `CPU-Course-Design-EES338`。
4. `Project location` 选择仓库之外的目录，例如 `D:\VivadoProjects`。
5. 保持 **Create project subdirectory** 勾选，点击 **Next**。
6. 在 `Project Type` 页面选择 **RTL Project**。
7. 勾选 **Do not specify sources at this time**，点击 **Next**。
8. 在 `Default Part` 页面切换到 **Parts**，根据实板选择：

   | Hardware Manager / 芯片标识 | Vivado Project Part |
   |---|---|
   | `xc7a35t_0` / XC7A35T | `xc7a35tcsg324-1` |
   | `xc7a100t_0` / XC7A100T | `xc7a100tcsg324-1` |

   也可以按字段筛选：Family=`Artix-7`、Package=`csg324`、Speed=`-1`。
9. 确认器件完整名称正确后点击 **Next > Finish**。

不要选择 `cpg236` 封装。若 JTAG 已经识别为 `xc7a100t_0`，也不要继续选择 35T；
器件型号不一致的 bitstream 无法通过 `program_hw_devices` 校验。

## 3. 添加 SystemVerilog 设计源码

1. 在左侧 **Flow Navigator > Project Manager** 中点击 **Add Sources**。
2. 选择 **Add or create design sources**，点击 **Next**。
3. 点击 **Add Directories**，添加仓库中的 `rtl` 目录：

   ```text
   D:\2_files\2_academic\1_course\CPU-Course-Design\rtl
   ```

4. 确认下列子目录中的全部 `.sv` 文件都出现在列表中：

   ```text
   rtl/board
   rtl/cache
   rtl/core
   rtl/decode
   rtl/exception
   rtl/execute
   rtl/memory
   rtl/peripheral
   rtl/predictor
   rtl/regfile
   rtl/soc
   ```

5. 建议取消勾选 **Copy sources into project**。这样外部 Vivado 工程直接引用仓库源码，
   修改 RTL 后不需要再次复制文件。
6. 点击 **Finish**。
7. 在 **Sources > Design Sources** 中找到 `ees338_top`，右击并选择
   **Set as Top**。顶层设置成功后，模块名称应加粗。
8. 检查 `rtl/decode/control_word_pkg.sv` 的文件类型为 **SystemVerilog**；`.sv`
   文件通常会被 Vivado 自动识别。若出现包未找到错误，在 Sources 中右击该文件，
   进入 **Source File Properties**，将 `File Type` 改为 `SystemVerilog`。
9. 右击 **Design Sources**，选择 **Hierarchy Update > Automatic Update and Compile Order**，
   或在 Sources 窗口点击 **Update Compile Order**。

板级综合必须使用 `ees338_top`，不能把 `soc_top` 或测试平台设为综合顶层。

## 4. 添加上电程序 `bringup.mem`

1. 再次点击 **Add Sources**。
2. 选择 **Add or create design sources**。
3. 点击 **Add Files**，选择：

   ```text
   D:\2_files\2_academic\1_course\CPU-Course-Design\firmware\bringup.mem
   ```

4. 取消勾选 **Copy sources into project**，然后完成向导。
5. 在 Sources 中选中 `bringup.mem`，打开 **Source File Properties**，确认：

   - `File Type` 为 **Memory Initialization Files**；
   - `Used In` 至少包含 **Synthesis** 和 **Simulation**。

这一步不能遗漏，否则综合可能找不到 `$readmemh("bringup.mem")`，生成的 CPU 将没有正确的
上电程序。

## 5. 添加 EES-338 引脚约束

1. 点击 **Add Sources**。
2. 选择 **Add or create constraints**。
3. 点击 **Add Files**，选择：

   ```text
   D:\2_files\2_academic\1_course\CPU-Course-Design\constraints\ees338.xdc
   ```

4. 取消勾选 **Copy constraints files into project**，点击 **Finish**。
5. 在 **Sources > Constraints > constrs_1** 中确认 `ees338.xdc` 已启用，并用于
   Synthesis 和 Implementation。

该约束已经包含：

- 100 MHz 输入时钟 `T5`；
- 低有效复位 `P15`；
- 8 个拨码开关和 5 个按键；
- 8 个 LED；
- CP2102 USB-UART 的 `T4/N5`；
- ST7571 LCD 的 SPI/控制信号；
- `LVCMOS33`、配置电压和必要的异步输入时序例外。

## 6. 综合前检查

打开 **Project Manager > Settings > General**，确认：

- Project part：与实际 JTAG 器件一致；本次识别为 `xc7a100t_0` 时应为
  `xc7a100tcsg324-1`；
- Target language：`Verilog`；
- Top module：`ees338_top`。

在 **Sources** 中确认至少能看到：

- `ees338_top.sv`；
- `clock_reset.sv`；
- `soc_top.sv`；
- `uart_tx_phy.sv`；
- `lcd_controller.sv` 和 `lcd_spi_master.sv`；
- `bringup.mem`；
- `ees338.xdc`。

## 7. 运行综合

1. 点击 **Flow Navigator > Synthesis > Run Synthesis**。
2. 保持默认策略和并行任务数，点击 **OK**。
3. 综合完成后选择 **Open Synthesized Design**。
4. 点击 **Reports > Report Utilization**，预期约为：

   - Slice LUT：约 1900（百分比随 35T/100T 容量变化）；
   - Slice Register：约 1820；
   - Block RAM Tile：4；
   - Bonded IOB：37。

如果 Block RAM 为 0，应检查使用的是否是当前版本的
`instruction_memory.sv`、`data_memory.sv`，以及这两个文件中的同步读和
`ram_style="block"` 属性是否存在。

## 8. 运行实现并检查报告

1. 点击 **Flow Navigator > Implementation > Run Implementation**。
2. 完成后选择 **Open Implemented Design**。
3. 打开 **Reports > Report Timing Summary**，要求：

   - `WNS > 0`；
   - `WHS > 0`；
   - `TNS = 0`；
   - `THS = 0`。

   已验证的 35T 参考值为 WNS 约 `+24.96 ns`、WHS 约 `+0.085 ns`；
   100T/CSG324 参考值为 WNS 约 `+24.40 ns`、WHS 约 `+0.104 ns`。
4. 打开 **Reports > Report DRC**，要求 `Violations found = 0`。
5. 查看 **Report Route Status**，要求 `nets with routing errors = 0`。

出现 `NSTD-1` 或 `UCIO-1` 时不要强行降低严重性生成 bitstream，应先检查
`ees338.xdc` 是否添加成功以及顶层端口名称是否匹配。

## 9. 生成 bitstream

1. 点击 **Flow Navigator > Program and Debug > Generate Bitstream**。
2. 如果提示需要先运行综合或实现，选择允许 Vivado 自动完成。
3. 等待右上角状态显示 **write_bitstream Complete**。
4. bitstream 通常位于外部工程目录：

   ```text
   <工程目录>\CPU-Course-Design-EES338.runs\impl_1\ees338_top.bit
   ```

也可以在 Vivado 的 Tcl Console 中执行下面的命令确认实现目录：

```tcl
get_property PROGRESS [get_runs impl_1]
get_property DIRECTORY [get_runs impl_1]
```

## 10. 连接开发板

1. 关闭开发板电源。
2. 按开发板说明书连接供电和板载 JTAG 下载接口。
3. 连接板载 CP2102 USB-UART，后续用于观察自检输出。
4. 打开开发板电源。
5. 在 Windows **设备管理器 > 端口 (COM 和 LPT)** 中记下 CP2102 对应的 COM 号。

下载前不要改动 LCD、UART 或 JTAG 跳线；若板上设有启动模式选择，JTAG 临时下载时按
说明书选择支持 JTAG 的模式。

## 11. 通过 JTAG 下载到 FPGA

1. 在 Vivado 左侧点击 **Open Hardware Manager**。
2. 点击顶部提示条或左侧入口中的 **Open Target > Auto Connect**。
3. Hardware 窗口中应出现 `xc7a35t_0` 或 `xc7a100t_0`。如果没有出现：

   - 检查开发板供电；
   - 检查 JTAG USB 线和驱动；
   - 点击 **Open Target > Open New Target** 手动重新扫描。

4. 选中实际显示的 FPGA，右击选择 **Program Device**。
5. `Bitstream file` 选择第 9 节生成的 `ees338_top.bit`。
6. `Debug probes file` 留空，本版本没有插入 ILA。
7. 点击 **Program**。

JTAG 下载写入的是 FPGA 易失配置存储，开发板断电后会丢失；再次上电需要重新下载。
在 JTAG 验证完全通过前，不建议直接烧写板载 SPI Flash。

## 12. 打开串口并验收

用任意串口终端打开 CP2102 对应 COM 口，设置：

```text
115200 baud
8 data bits
no parity
1 stop bit
no flow control
```

下载或按下低有效复位键后，应先收到：

```text
BOOT
```

约 0.6 秒后，LCD 完成初始化和清屏，第一页写入 `0xAA` 测试条纹，然后串口输出：

```text
PASS
```

板上现象：

- `SW7=0`：自检成功后 8 个 LED 全亮；
- LCD：出现测试条纹；
- `SW7=1`：切换为调试显示；
  - LED7：`TOHOST=PASS`；
  - LED6：失败；
  - LED5：LCD 初始化完成；
  - LED4：UART 正忙；
  - LED3：CPU 复位；
  - LED2：MMCM 锁定；
  - LED1：PB0 同步值；
  - LED0：慢速心跳。

按下复位键后，上述 `BOOT`、LCD 初始化、`PASS` 流程应重新执行。

## 13. 常见问题

### 报 `Incorrect bitstream assigned to device`

这是器件型号不一致，不是 JTAG 或启动状态问题。执行：

```tcl
get_hw_devices
get_property PART [current_project]
```

如果硬件为 `xc7a100t_0` 而工程为 `xc7a35tcsg324-1`，回到 Project Manager，执行：

```tcl
set_property PART xc7a100tcsg324-1 [current_project]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

等待实现完成后，重新选择新生成的 `ees338_top.bit`。不能通过改文件名、重新关联旧 bit
或清空 `PROBES.FILE` 修复；必须针对 100T 重新综合、实现并生成 bitstream。

### 综合报 `bringup.mem` 找不到

重新执行第 4 节，把该文件作为 **Design Source** 添加，并设置为
**Memory Initialization Files**，同时启用 Synthesis。

### 综合顶层有大量未约束端口

大概率误把 `soc_top` 或 testbench 设成了顶层。把 `ees338_top` 设置为 Top，并重新运行
综合和实现。

### Hardware Manager 找不到 FPGA

检查供电、JTAG 线、下载驱动和启动模式；关闭占用同一下载器的其他 Vivado/下载工具后
重新 Auto Connect。

### 没有串口输出

确认使用的是 CP2102 对应 COM 口，参数为 115200 8N1，并确认约束使用 USB-UART 的
T4/N5，而不是示例文件中属于蓝牙串口的 N2/L3。

### 有 `BOOT`，但一直没有 `PASS`

CPU 已经运行，通常卡在等待 LCD 初始化。检查 LCD 接口、LCD 供电/排线和约束；将
`SW7` 置 1，观察 LED5 是否点亮。

## 14. 修改代码后的重新生成流程

外部工程引用仓库源码时，保存 RTL 或 `bringup.mem` 后回到 Vivado：

1. 点击 **Refresh Changed Modules**；
2. 若已经有旧结果，右击 `synth_1` 选择 **Reset Runs**；
3. 重新依次运行 Synthesis、Implementation、Generate Bitstream；
4. 在 Hardware Manager 中再次 Program Device。

需要在创建工程前验证代码时，可在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_all_tests.ps1
```

该脚本会临时创建已被 `.gitignore` 忽略的 `build/`，完成后可以安全删除。
