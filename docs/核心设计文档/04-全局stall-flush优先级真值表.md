# 全局 stall/flush 优先级真值表

## 1. 输入事件

| 信号 | 含义 |
|---|---|
| `reset` | 同步复位 |
| `redirect` | EX 级有效 branch taken、JAL 或 JALR 请求重定向 |
| `dmem_wait` | EX/MEM 中有效访存指令已发请求但 `ready=0` |
| `imem_wait` | IF 取指请求尚未完成 |
| `load_use` | ID 指令立即使用 ID/EX 中 load 的 rd |

基础版优先级：`reset > redirect > dmem_wait > imem_wait > load_use > normal`。

`redirect` 只允许由 `id_ex.valid=1` 的控制转移指令产生。若 `dmem_wait=1`，EX 级及更年轻状态被冻结，因此实现上应保证冻结期间 `redirect` 不重复提交；推荐以 EX 级允许推进作为重定向接受条件。

## 2. 输出动作表

`W`=写入下一值，`H`=保持，`F`=清 valid/冲刷，`R`=写复位值，`B`=写入但 `valid=0` 的气泡。

| 命中事件 | PC | IF/ID | ID/EX | EX/MEM | MEM/WB | next PC |
|---|---|---|---|---|---|---|
| reset | R | R | R | R | R | reset vector |
| redirect | W | F | F | W | W | `redirect_pc` |
| dmem_wait | H | H | H | H | B | 保持 |
| imem_wait | H | H | W | W | W | 保持 |
| load_use | H | H | B | W | W | 保持 |
| normal | W | W | W | W | W | `PC+4` |

`imem_wait` 行中，若 ID 当前已有有效指令，IF/ID 在被 ID 消费后应变为空，而不是永久保持并重复发射。推荐将取指响应缓冲与 IF/ID 解耦，或用 `if_id_consumed` 将该行细化为：ID 可推进时 IF/ID 写气泡、ID 不可推进时保持。

## 3. load-use 判定

```text
load_use = id_ex.valid && id_ex.mem_read && (id_ex.rd_idx != 0) &&
           if_id.valid &&
           ((dec_uses_rs1 && id_ex.rd_idx == dec_rs1) ||
            (dec_uses_rs2 && id_ex.rd_idx == dec_rs2));
```

`uses_rs1/uses_rs2` 规则：

| 指令类 | uses_rs1 | uses_rs2 |
|---|---:|---:|
| R 型 ALU | 1 | 1 |
| I 型 ALU、load、JALR | 1 | 0 |
| store | 1 | 1 |
| branch | 1 | 1 |
| LUI、AUIPC、JAL | 0 | 0 |

## 4. 前递优先级

对 EX 操作数 A、B 和 store_data 分别判断：

1. `EX/MEM.valid && reg_write && rd!=0 && rd==rs`：选择 EX/MEM；
2. 否则若 `MEM/WB.valid && reg_write && rd!=0 && rd==rs`：选择 MEM/WB；
3. 否则选择 ID/EX 保存的寄存器值。

EX/MEM 中的 load 数据尚不可用，因此当 `EX/MEM.mem_read=1` 时不得从 `alu_result` 前递加载值；紧邻 load 的消费者已由 load-use 气泡保证下一周期从 MEM/WB 前递。

## 5. 重定向规则

| 指令 | redirect 条件 | redirect_pc |
|---|---|---|
| BEQ/BNE/BLT/BGE | EX 判定 taken | `id_ex.pc + id_ex.imm` |
| JAL | 恒为真 | `id_ex.pc + id_ex.imm` |
| JALR | 恒为真 | `(forwarded_rs1 + id_ex.imm) & 32'hFFFF_FFFE` |

基础版静态预测“不跳转”，所以不跳转分支不冲刷；taken 分支与所有跳转冲刷 IF/ID、ID/EX 两条年轻指令。
