    addi x1, x0, 0
    addi x4, x0, 4
pass:
    addi x2, x0, 0
    addi x3, x0, 32
loop:
    lw x5, 0(x2)
    add x1, x1, x5
    addi x2, x2, 4
    addi x3, x3, -1
    beq x3, x0, end_pass
    beq x0, x0, loop
end_pass:
    addi x4, x4, -1
    beq x4, x0, done
    beq x0, x0, pass
done:
    beq x0, x0, done
