# 功能：对数据存储器地址0处开始的5个32位整数做冒泡排序
#
# 使用到的指令：lw, sw, add, sub, ori, beq, slt

        ori x2, x0, 0      # i = 0
        ori x3, x0, 4      # 常量4（同时作为 outer 终止值）
        ori x4, x0, 1      # 常量1
        add x1, x0, x0     # base = 0

outer:
        sub x5, x3, x2     # limit = 4 - i
        ori x6, x0, 0      # j = 0
        add x7, x1, x0     # p = base

inner:
        lw  x8, 0(x7)      # a = mem[p]
        lw  x9, 4(x7)      # b = mem[p+4]
        slt x10, x9, x8    # t = (b < a) ? 1 : 0
        beq x10, x0, no_swap
        sw  x9, 0(x7)      # mem[p]   = b
        sw  x8, 4(x7)      # mem[p+4] = a

no_swap:
        add x7, x7, x3     # p += 4
        add x6, x6, x4     # j += 1
        beq x6, x5, end_inner
        beq x0, x0, inner

end_inner:
        add x2, x2, x4     # i += 1
        beq x2, x3, done
        beq x0, x0, outer

done:
        beq x0, x0, done
