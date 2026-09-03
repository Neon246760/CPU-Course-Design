# IP 核生成、使用与验证指南(LCD 控制器)

> 适用课程:汇编与接口课程设计"基础团队任务——测试后并形成 IP 核"。
> 适用版本:本机 Vivado 2025.2;旧版本(2019.2~2023.x)差异见 [附录 A](#附录-a旧版本差异)。
> 本文操作对象:`rtl/peripheral/lcd_controller.sv`(顶层,内部例化 `lcd_spi_master.sv`)。
> 仓库内配套脚本:`sim/package_lcd_ip.tcl`(打包)、`sim/create_lcd_ip_verify.tcl`(自动搭建验证工程)。

## 1. IP 核产物内容

打包完成后,IP 核是一个独立文件夹(本工程为 `ip/lcd_controller_v1_0/`),内容如下:

```text
ip/lcd_controller_v1_0/
├─ component.xml                 IP 的描述文件(IP-XACT 格式),IP 的"身份证"
├─ src/
│  ├─ lcd_controller.sv          顶层源码副本(打包时从 rtl/peripheral/ 复制)
│  └─ lcd_spi_master.sv          子模块源码副本
└─ xgui/
   └─ lcd_controller_v1_0.tcl    参数定制界面脚本(双击 IP 时弹出的参数对话框)
```

各部分含义:

| 文件 | 作用 | 是否可以修改 |
|---|---|---|
| `component.xml` | 声明 IP 身份(VLNV)、端口列表、参数列表、综合/仿真文件组。Vivado 靠它把 IP 列入 Catalog | 一般由工具维护;手工改风险高 |
| `src/` | 实际参与综合/仿真的 RTL。**与 `rtl/peripheral/` 中源码应逐字节一致** | 改 RTL 后必须重新打包(见 §4),不要直接改这里 |
| `xgui/` | 图形化参数界面,9 个时序参数(RESET_LOW_CYCLES 等)在这里可视化配置 | 工具生成,无需手工维护 |

IP 当前接口概览(以 `component.xml` 为准):

- VLNV:`local:user:lcd_controller:1.0`(vendor:library:name:version);
- 端口:19 个(12 个输入:clk、reset、tx_valid、tx_rs、tx_data[7:0]、reinit_req、clear_req、demo_req、game_row_write、game_row_index[4:0]、game_row_data[9:0]、game_refresh_req;7 个输出:tx_ready、initialized、lcd_cs_n、lcd_rst_n、lcd_sck、lcd_mosi、lcd_rs);
- 参数:9 个,均有默认值;
- 打包时 Vivado 自动识别接口:clk → clock 接口,reset、lcd_rst_n → reset 接口(低有效)。

> 注:俄罗斯方块功能(commit `535c605`)为 lcd_controller 增加了
> `demo_req/game_row_*/game_refresh_req` 等端口,本文档所对应的 `ip/` 产物已随之重新打包。

## 2. 从零生成 IP 核(GUI 向导)

### 2.1 前置条件

1. 控制器 RTL 完成且**独立测试通过**:`sim/unit/tb_lcd_controller.sv` 输出 `PASS`;
2. 明确打包对象:**只打包 lcd_controller + lcd_spi_master 两个文件**,不要打包整个工程
   (把整个 CPU 工程打包会把 cpu_core、soc_top 甚至 .xdc 约束都收进 IP,是常见错误)。

### 2.2 打包步骤

1. **准备"干净"的原料目录**(资源管理器操作):

   ```text
   新建文件夹,例如 E:\...\IP\lcd_src
   复制 rtl/peripheral/lcd_controller.sv 和 lcd_spi_master.sv 到该目录
   ```

2. Vivado 菜单 **Tools → Create and Package New IP…**;
3. 欢迎页点 **Next**;
4. 打包方式页选 **Package a specified directory**(打包指定目录),目录填上面新建的
   `lcd_src`,点 Next;
   > 不要选 "Package current project"(会打包当前打开的整个工程)。
5. 等待分析完成,确认 Top module 自动识别为 `lcd_controller`,Next;
6. 填写 IP 身份信息(VLNV),例如:

   | 字段 | 建议值 |
   |---|---|
   | Vendor | `local`(正式提交可用学校标识,如 `cn.edu.xxx`) |
   | Library | `user` |
   | Name | `lcd_controller` |
   | Version | `1.0` |
   | 输出目录 | `ip/lcd_controller_v1_0`(自定义目录亦可) |

7. 端口页:检查 clk/reset 被自动识别(日志出现
   `Inferred bus interface 'clk' of definition 'xilinx.com:signal:clock:1.0'` 即正常),
   其余端口保持普通端口,不需要手工改;
8. 参数页:9 个参数已带默认值,可改显示名或加描述,不改也行;
9. **Review and Package → Finish**;
10. **成功检查点**:输出目录出现 `component.xml`、`src/`、`xgui/` 三样东西;
    向导若询问 "Edit and Package New IP",选 No/关闭。

### 2.3 脚本等价做法(推荐,可复现)

仓库脚本 `sim/package_lcd_ip.tcl` 与上述向导等价(底层都是 `ipx::*` 命令),运行:

```powershell
E:\Vivado\2025.2\Vivado\bin\vivado.bat -mode batch -source sim/package_lcd_ip.tcl
```

要点:脚本只 `add_files` 两个源文件、`set_property top lcd_controller`、
`ipx::package_project -import_files` 后 `ipx::save_core`;VLNV 与输出目录在脚本顶部变量中
修改;带 `-force`,重复运行会覆盖旧产物。

## 3. 使用 IP 核

"使用"分两步:告诉工程"我的 IP 在哪"(注册仓库),再"取一个实例"放进设计。

### 3.1 注册仓库(每个需要用到该 IP 的工程做一次)

1. Vivado 菜单 **Tools → Settings → IP → Repository**;
2. **Add…** 选择**包含 component.xml 的那一层文件夹**(即 `ip/lcd_controller_v1_0/`);
3. OK。IP Catalog 自动刷新。

### 3.2 检查 Catalog

打开 **IP Catalog**(Flow Navigator 中),搜索 `lcd_controller`,
应看到 `local:user:lcd_controller:1.0`(分类 User Repository)。

### 3.3 在 Block Design 中使用(图形化)

1. 新建/打开 Block Design;
2. 画布空白处双击(或点 +)→ 搜索 `lcd_controller` → 双击加入,图上出现 IP 实例;
3. 接线:每个端口右键 → **Make External** 做成外部端口;`clk` 右键 Make External 后
   端口自动是时钟端口(图标带小三角);
4. **时钟注意**:如果弹出 Run Connection Automation,选择创建时钟端口/外部端口,
   **不要新建 Clocking Wizard(clk_wiz)**——本控制器单时钟直连即可,clk_wiz 反而会引入
   "clk_in1 无时钟源"(BD 41-758)类问题;
5. 校验:右键画布 → **Validate Design**。若出现 **BD 41-759** 警告(输入脚未连接、工具
   自动 tie-off 为 0),属于正常提示:把未用输入右键 Make External 可消除,不处理也能通过;
6. 右键 BD → **Generate Output Products**;
7. (可选)右键 BD → **Create HDL Wrapper**(选 Let Vivado manage),让 BD 成为可综合模块;
   需要综合验证时把 wrapper Set as Top 后 Run Synthesis,完事记得把顶层改回 `ees338_top`。

### 3.4 在纯 HDL 工程中使用

打包产物本质仍是可综合 RTL,两种等价用法:

- 把 `ip/lcd_controller_v1_0/src/` 下两个文件作为设计源直接引用,HDL 中按模块名
  `lcd_controller` 例化(端口见 §1);
- 或在 Catalog 中右键该 IP 走工程 IP 流程生成 `.xci` 后再按例化模板使用。

> 本项目 CPU 工程(board 顶层 `ees338_top`)已在 SoC 中直接例化控制器,不必改为引用 IP;
> IP 核是独立交付物与"可复用组件"证据,不要为"使用"而重构现有下板设计。

## 4. 修改 RTL 后重新打包

`lcd_controller.sv` 被修改(如本次俄罗斯方块扩展)后,**打包产物不会自动更新**,
必须重新打包:

```powershell
E:\Vivado\2025.2\Vivado\bin\vivado.bat -mode batch -source sim/package_lcd_ip.tcl
```

1. 脚本 `-force` 覆盖 `ip/lcd_controller_v1_0/`;
2. 用哈希核对源码一致性:

   ```bash
   sha256sum rtl/peripheral/lcd_controller.sv ip/lcd_controller_v1_0/src/lcd_controller.sv
   ```

   两行哈希相同即为打包内容与仓库 RTL 一致;
3. 端口变化时,已在 BD 中例化的旧实例不会自动更新:删除旧实例重新从 Catalog 拖入
   (或对 BD 执行 Refresh),再 Validate、重新 Generate Output Products。

## 5. 验证"我们做了"

### 5.1 功能验证(控制器行为正确)

- 单元测试:`sim/unit/tb_lcd_controller.sv` 输出 `PASS tb_lcd_controller`;
- 系统测试:仓库提供 `tb_bringup_system.sv`、`tb_tetris_system.sv` 等,全部 PASS;
- 打包前后无需重写测试:打包只是复制源码,`src/` 与 `rtl/peripheral/` 哈希一致即为
  同一份代码(见 §4 第 2 步)。

### 5.2 消费性验证(IP 能被工程正常使用)

1. 注册仓库(Settings → IP → Repository)→ IP Catalog 可见;
2. BD 例化 + 连线 + **Validate Design 通过**(无 error;41-759 类警告可接受);
3. Generate Output Products 成功;
4. (可选)Create HDL Wrapper 后 Run Synthesis 通过;
5. 自动化样板:运行 `sim/create_lcd_ip_verify.tcl` 可一键生成已通过 Validate 的
   独立验证工程(`E:\My_Files\VivadoProjects\lcd_ip_verify`),原理图可直接截图。

### 5.3 报告证据清单与措辞

建议截图:① `tb_lcd_controller` PASS 日志;② 打包日志(含 Inferred bus interface 行);
③ 产物目录(component.xml/src/xgui);④ IP Catalog 中 `local:user:lcd_controller:1.0`;
⑤ BD 原理图;⑥ Validate Design 结果。

报告措辞参考:"LCD 控制器经独立测试后封装为用户 IP(`local:user:lcd_controller:1.0`),
注册 IP 仓库并在 Block Design 中例化、Validate 通过,形成 设计→测试→封装→复用 闭环。"

## 6. 常见问题

| 问题 | 处理 |
|---|---|
| Tools 菜单找不到 Create and Package New IP | 2025.2 可能无此菜单项;直接使用脚本方法(§2.3),产物相同 |
| 打出了整个 CPU 工程 | 误选 "Package current project";改用"指定目录"或脚本,原料目录只放两个文件 |
| src/ 与 rtl/ 哈希不一致 | 未重打包;执行 §4 |
| Catalog 看不到 IP | 仓库路径层级选错(应指到含 component.xml 的目录);点 Refresh |
| Validate 报 BD 41-758(时钟无源) | clk 未接合法时钟源;删掉多余 clk_wiz,clk 直接 Make External |
| Validate 报 BD 41-759(输入未接) | 警告不是错误,工具自动 tie-off 为 0;要消除就 Make External |
| 想改参数默认值 | 双击 IP 实例/或 Catalog 中 IP 打开定制界面,改后重新生成产物 |
| IP 版本管理 | 发布过 1.0 后再改接口,应升 Version 为 1.1 重新打包,避免旧工程静默失效 |

