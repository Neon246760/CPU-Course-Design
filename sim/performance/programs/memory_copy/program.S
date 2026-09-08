    addi x1, x0, 0
    addi x2, x0, 256
    addi x3, x0, 32
loop:
    lw x4, 0(x1)
    sw x4, 0(x2)
    addi x1, x1, 4
    addi x2, x2, 4
    addi x3, x3, -1
    beq x3, x0, done
    beq x0, x0, loop
done:
    beq x0, x0, done
