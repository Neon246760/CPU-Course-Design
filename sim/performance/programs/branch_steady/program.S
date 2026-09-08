    addi x1, x0, 0
    addi x2, x0, 2000
loop:
    addi x1, x1, 1
    beq x1, x2, done
    beq x0, x0, loop
done:
    beq x0, x0, done
