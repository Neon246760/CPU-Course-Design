/* EES-338 first-stage bring-up program for the implemented RV32 subset. */

        .section .text
        .globl _start

_start:
        lui     x10, 0x20000          /* MMIO base */
        addi    x1, x0, 1
        sw      x1, 0(x10)            /* LED0: CPU is running */

        addi    x1, x0, 'B'
        sw      x1, 16(x10)
        addi    x1, x0, 'O'
        sw      x1, 16(x10)
        sw      x1, 16(x10)
        addi    x1, x0, 'T'
        sw      x1, 16(x10)
        addi    x1, x0, 10
        sw      x1, 16(x10)

        lui     x11, 0x10000          /* DMEM base */
        addi    x2, x0, 5
        addi    x3, x0, 7
        add     x4, x2, x3
        sw      x4, 0(x11)
        lw      x5, 0(x11)
        bne     x5, x4, fail

        addi    x1, x0, 15
        sw      x1, 0(x10)            /* Basic CPU/BRAM test passed */

wait_lcd:
        lw      x12, 40(x10)          /* LCD_STATUS */
        andi    x12, x12, 2
        beq     x12, x0, wait_lcd

        addi    x13, x0, 0xB0         /* Page zero */
        sw      x13, 32(x10)          /* LCD_CMD */
        addi    x13, x0, 0x10         /* Column high nibble */
        sw      x13, 32(x10)
        addi    x13, x0, 0x00         /* Column low nibble */
        sw      x13, 32(x10)
        addi    x13, x0, -86          /* 0xAA test pattern */
        addi    x14, x0, 256

lcd_pattern:
        sw      x13, 36(x10)          /* LCD_DATA */
        addi    x14, x14, -1
        bne     x14, x0, lcd_pattern

        addi    x1, x0, 255
        sw      x1, 0(x10)            /* All LEDs on */

        addi    x1, x0, 'P'
        sw      x1, 16(x10)
        addi    x1, x0, 'A'
        sw      x1, 16(x10)
        addi    x1, x0, 'S'
        sw      x1, 16(x10)
        sw      x1, 16(x10)
        addi    x1, x0, 10
        sw      x1, 16(x10)

        addi    x15, x0, -16          /* TOHOST = 0xFFFF_FFF0 */
        addi    x1, x0, 1
        sw      x1, 0(x15)

pass_loop:
        lw      x12, 4(x10)           /* GPIO_IN: SW0 is bit 0 */
        andi    x12, x12, 1
        beq     x12, x0, pass_loop

        addi    x1, x0, 4             /* LCD_CTRL.bit2: name demo */
        sw      x1, 44(x10)

wait_sw0_release:
        lw      x12, 4(x10)
        andi    x12, x12, 1
        bne     x12, x0, wait_sw0_release
        jal     x0, pass_loop          /* allow the next 0 -> 1 action */

fail:
        addi    x1, x0, 0x55
        sw      x1, 0(x10)
        addi    x15, x0, -16
        addi    x1, x0, 2
        sw      x1, 0(x15)

fail_loop:
        jal     x0, fail_loop

        .org    0x100
irq_handler:
        mret
