# CPU Course Design

本仓库实现 `docs/核心设计文档` 规定的五级流水 CPU，并已加入四项附加功能：

- 27 条 RV32I 教学子集指令；
- ID 级水平微码控制；
- EX/MEM、MEM/WB 数据前递；
- load-use 停顿；
- EX 级分支/跳转判定和流水线冲刷；
- 字/字节加载存储；
- 指令、数据存储器握手接口；
- GPIO、UART 发送、LCD SPI 和仿真 `TOHOST` MMIO；
- 启动自检后拨动 `SW0` 可在 LCD 显示 `WJL ZXH QBA`；
- 10×20 俄罗斯方块：CPU 汇编实现移动、旋转、碰撞、锁定与消行，LCD 硬件加速绘制，
  消行时由板载蜂鸣器播放约 120 ms 提示音；
- 周期、退休、数据停顿、取指等待、数据存储等待和控制冲刷计数器。
- `ADD/SUB/ADDI` 有符号溢出检测与异常入口；
- 外部中断同步、pending、屏蔽、`mepc/mcause/mtvec` 和 `MRET`；
- 1 KiB 直接映射 I-Cache 与 D-Cache；
- 16 项 BTB + 2 位饱和计数器 BHT 动态分支预测。

详细语义和验证矩阵见 `docs/附加功能设计与测试.md`。EES-338 下板设计与操作分别见
`docs/EES-338下板方案.md` 和 `docs/Vivado下板操作.md`。

## 目录

```text
rtl/       可综合 SystemVerilog RTL
sim/       自检 testbench 与 Vivado 仿真脚本
docs/      设计规格
```

## Vivado 2019.2 仿真

在 Vivado Tcl Shell 中从仓库根目录执行：

```tcl
vivado -mode batch -source sim/vivado_sim.tcl
```

上述命令默认运行四项附加功能联合系统测试。运行全部 12 组测试：

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_all_tests.ps1
```

运行单项测试：

```tcl
vivado -mode batch -source sim/run_test.tcl -tclargs tb_cache sim/unit/tb_cache.sv
```

## 俄罗斯方块固件

板级顶层默认加载 `firmware/tetris.mem`。操作方式：`SW0` 开始/重新开始；游戏手柄
左/右键移动，上键旋转，下键加速下落。物理映射为下=`PB0`、左=`PB1`、中=`PB2`、
上=`PB3`、右=`PB4`；中键 `PB2` 保留给外部中断。
每次锁定若消除一行或多行，板载蜂鸣器都会播放一次约 2 kHz、120 ms 的短音。

修改 `firmware/tetris.S` 后，使用本机 RARS 重新生成内存镜像：

```powershell
powershell -ExecutionPolicy Bypass -File firmware/build_tetris.ps1
```

如 RARS 位于其他位置，可传入 `-RarsJar <路径>`。诊断固件 `bringup.mem` 仍保留，
系统仿真会显式选择它，不受板级默认固件变化影响。

脚本默认使用说明书标准版 EES-338 的 `xc7a35tcsg324-1`。若 Hardware Manager
识别到的是 100T 版本，生成 bitstream 时必须显式指定 `xc7a100tcsg324-1`：

```powershell
vivado -mode batch -source sim/implement_ees338.tcl
vivado -mode batch -source sim/implement_ees338.tcl -tclargs xc7a100tcsg324-1
```

输出位于临时目录 `build/ees338/ees338_top.bit`（`build/` 已被 Git 忽略）。仓库不保存
Vivado `.xpr`、`.runs`、`.cache` 等工程产物；请按照 `docs/Vivado下板操作.md`
在仓库之外创建工程，并将综合顶层设置为 `ees338_top`。
