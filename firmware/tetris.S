# Interactive 10x20 Tetris for the implemented RV32I teaching subset.
# SW0 starts/restarts. D-pad: left/right move, up rotates, down soft-drops.
# The board is uploaded to the LCD accelerator through MMIO.

        .text
        .globl _start

_start:
game_start:
        li      sp, 0x10001FF0
        li      s0, 0x20000000          # MMIO
        li      s1, 0x10000000          # settled board: 20 words
        li      s2, 0x10000100          # render board: 20 words
        li      s3, 0x10000200          # 7 pieces x 4 rotations

wait_lcd:
        lw      t0, 40(s0)
        andi    t0, t0, 2
        beq     t0, x0, wait_lcd

        jal     ra, init_shapes

wait_start:
        lw      t0, 4(s0)
        andi    t0, t0, 1              # SW0
        beq     t0, x0, wait_start

new_game:
        jal     ra, clear_board
        sw      x0, 0(s0)                # clear the game-over LED pattern
        addi    s6, x0, 0               # deterministic 0..6 sequence
        addi    s11, x0, 0              # score / cleared line count
        addi    s8, x0, 0               # previous key state

spawn_piece:
        addi    s4, x0, 3               # x
        addi    s5, x0, 0               # y
        addi    s7, x0, 0               # rotation
        jal     ra, load_shape
        addi    a0, s4, 0
        addi    a1, s5, 0
        addi    a2, s10, 0
        jal     ra, collision
        bne     a0, x0, game_over
        jal     ra, render_frame
        li      s9, 200000              # calibrated for about 0.5 s on this core

# Do not carry a held soft-drop key into the newly spawned piece. The new
# piece is already visible, but game time resumes only after D-pad down lifts.
spawn_wait_down_release:
        lw      t0, 4(s0)
        andi    t0, t0, 0x100
        bne     t0, x0, spawn_wait_down_release
        addi    s8, x0, 0

game_loop:
        lw      t0, 4(s0)
        li      t1, 0x1B00              # down/left/up/right; center excluded
        and     t0, t0, t1
        xori    t2, s8, -1
        and     t2, t2, t0              # rising edges
        addi    s8, t0, 0

        li      t3, 0x0200              # S1/PB1: D-pad left
        and     t4, t2, t3
        bne     t4, x0, try_left
        li      t3, 0x1000              # S4/PB4: D-pad right
        and     t4, t2, t3
        bne     t4, x0, try_right
        li      t3, 0x0800              # S3/PB3: D-pad up / rotate
        and     t4, t2, t3
        bne     t4, x0, try_rotate
        li      t3, 0x0100              # S0/PB0: D-pad down / soft drop
        and     t4, t0, t3
        bne     t4, x0, gravity_step

        addi    s9, s9, -1
        bne     s9, x0, game_loop
        jal     x0, gravity_step

try_left:
        addi    a0, s4, -1
        addi    a1, s5, 0
        addi    a2, s10, 0
        jal     ra, collision
        bne     a0, x0, input_done
        addi    s4, s4, -1
        jal     x0, moved

try_right:
        addi    a0, s4, 1
        addi    a1, s5, 0
        addi    a2, s10, 0
        jal     ra, collision
        bne     a0, x0, input_done
        addi    s4, s4, 1
        jal     x0, moved

try_rotate:
        addi    t0, s7, 1
        andi    t0, t0, 3
        addi    t5, x0, 2
        sll     t1, s6, t5
        add     t1, t1, t0
        sll     t1, t1, t5
        add     t1, s3, t1
        lw      t1, 0(t1)
        addi    sp, sp, -8
        sw      t0, 0(sp)
        sw      t1, 4(sp)
        addi    a0, s4, 0
        addi    a1, s5, 0
        addi    a2, t1, 0
        jal     ra, collision
        beq     a0, x0, rotate_accept

        addi    a0, s4, -1              # simple wall kick to the left
        addi    a1, s5, 0
        lw      a2, 4(sp)
        jal     ra, collision
        beq     a0, x0, rotate_kick_left

        addi    a0, s4, 1               # then try a right wall kick
        addi    a1, s5, 0
        lw      a2, 4(sp)
        jal     ra, collision
        beq     a0, x0, rotate_kick_right

        addi    sp, sp, 8
        jal     x0, input_done

rotate_kick_left:
        addi    s4, s4, -1
        jal     x0, rotate_accept

rotate_kick_right:
        addi    s4, s4, 1

rotate_accept:
        lw      t0, 0(sp)
        lw      t1, 4(sp)
        addi    sp, sp, 8
        addi    s7, t0, 0
        addi    s10, t1, 0
        jal     x0, moved

input_done:
        jal     x0, game_loop

moved:
        jal     ra, render_frame
        jal     x0, game_loop

gravity_step:
        addi    a0, s4, 0
        addi    a1, s5, 1
        addi    a2, s10, 0
        jal     ra, collision
        bne     a0, x0, lock_piece
        addi    s5, s5, 1
        jal     ra, render_frame
        li      s9, 200000
        jal     x0, game_loop

lock_piece:
        jal     ra, place_piece
        jal     ra, clear_lines
        addi    s6, s6, 1
        addi    t0, x0, 7
        blt     s6, t0, spawn_piece
        addi    s6, x0, 0
        jal     x0, spawn_piece

game_over:
        jal     ra, render_frame
        addi    t0, x0, 0x55
        sw      t0, 0(s0)
wait_restart_off:
        lw      t0, 4(s0)
        andi    t0, t0, 1
        bne     t0, x0, wait_restart_off
wait_restart_on:
        lw      t0, 4(s0)
        andi    t0, t0, 1
        beq     t0, x0, wait_restart_on
        jal     x0, new_game

# Clear settled and render boards.
clear_board:
        addi    t0, x0, 0
        addi    t1, x0, 20
clear_board_loop:
        addi    t4, x0, 2
        sll     t2, t0, t4
        add     t3, s1, t2
        sw      x0, 0(t3)
        add     t3, s2, t2
        sw      x0, 0(t3)
        addi    t0, t0, 1
        blt     t0, t1, clear_board_loop
        jalr    x0, 0(ra)

# Load s10 = shapes[piece * 4 + rotation].
load_shape:
        addi    t1, x0, 2
        sll     t0, s6, t1
        add     t0, t0, s7
        sll     t0, t0, t1
        add     t0, s3, t0
        lw      s10, 0(t0)
        jalr    x0, 0(ra)

# a0=x, a1=y, a2=mask. Return a0=1 if blocked, otherwise 0.
collision:
        addi    t0, x0, 0               # cy
        addi    t1, x0, 0               # cx
        addi    t6, x0, 1
collision_cell:
        andi    t2, a2, 1
        beq     t2, x0, collision_next
        add     t3, a0, t1
        blt     t3, x0, collision_blocked
        addi    t4, x0, 10
        bge     t3, t4, collision_blocked
        add     t4, a1, t0
        blt     t4, x0, collision_next
        addi    t5, x0, 20
        bge     t4, t5, collision_blocked
        addi    t5, x0, 2
        sll     t5, t4, t5
        add     t5, s1, t5
        lw      t5, 0(t5)
        sll     t2, t6, t3
        and     t5, t5, t2
        bne     t5, x0, collision_blocked
collision_next:
        srl     a2, a2, t6
        addi    t1, t1, 1
        addi    t2, x0, 4
        blt     t1, t2, collision_cell
        addi    t1, x0, 0
        addi    t0, t0, 1
        blt     t0, t2, collision_cell
        addi    a0, x0, 0
        jalr    x0, 0(ra)
collision_blocked:
        addi    a0, x0, 1
        jalr    x0, 0(ra)

# Merge active piece into settled board.
place_piece:
        addi    a2, s10, 0
        addi    t0, x0, 0
        addi    t1, x0, 0
        addi    t6, x0, 1
place_cell:
        andi    t2, a2, 1
        beq     t2, x0, place_next
        add     t3, s4, t1
        add     t4, s5, t0
        addi    t5, x0, 2
        sll     t5, t4, t5
        add     t5, s1, t5
        lw      a3, 0(t5)
        sll     t2, t6, t3
        or      a3, a3, t2
        sw      a3, 0(t5)
place_next:
        srl     a2, a2, t6
        addi    t1, t1, 1
        addi    t2, x0, 4
        blt     t1, t2, place_cell
        addi    t1, x0, 0
        addi    t0, t0, 1
        blt     t0, t2, place_cell
        jalr    x0, 0(ra)

# Remove every full 10-bit row, compacting the board downward.
clear_lines:
        addi    a5, x0, 0               # one beep per locking/clear event
        addi    t0, x0, 19
        li      t6, 0x3FF
clear_check:
        blt     t0, x0, clear_done
        addi    a4, x0, 2
        sll     t1, t0, a4
        add     t2, s1, t1
        lw      t3, 0(t2)
        and     t3, t3, t6
        bne     t3, t6, clear_not_full
        addi    a5, x0, 1
        addi    s11, s11, 1
        addi    t3, t0, 0
clear_shift:
        beq     t3, x0, clear_top
        addi    t4, t3, -1
        sll     t4, t4, a4
        add     t4, s1, t4
        lw      t5, 0(t4)
        sw      t5, 4(t4)
        addi    t3, t3, -1
        jal     x0, clear_shift
clear_top:
        sw      x0, 0(s1)
        jal     x0, clear_check
clear_not_full:
        addi    t0, t0, -1
        jal     x0, clear_check
clear_done:
        beq     a5, x0, clear_return
        addi    t0, x0, 1
        sw      t0, 56(s0)              # BUZZER_TRIGGER at 0x2000_0038
clear_return:
        jalr    x0, 0(ra)

# Copy settled board, overlay active piece, then upload 20 rows.
render_frame:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        addi    t0, x0, 0
        addi    t1, x0, 20
render_copy:
        addi    a4, x0, 2
        sll     t2, t0, a4
        add     t3, s1, t2
        lw      t4, 0(t3)
        add     t3, s2, t2
        sw      t4, 0(t3)
        addi    t0, t0, 1
        blt     t0, t1, render_copy

        addi    a2, s10, 0
        addi    t0, x0, 0
        addi    t1, x0, 0
        addi    t6, x0, 1
overlay_cell:
        andi    t2, a2, 1
        beq     t2, x0, overlay_next
        add     t3, s4, t1
        add     t4, s5, t0
        blt     t4, x0, overlay_next
        addi    t5, x0, 20
        bge     t4, t5, overlay_next
        addi    t5, x0, 2
        sll     t5, t4, t5
        add     t5, s2, t5
        lw      a3, 0(t5)
        sll     t2, t6, t3
        or      a3, a3, t2
        sw      a3, 0(t5)
overlay_next:
        srl     a2, a2, t6
        addi    t1, t1, 1
        addi    t2, x0, 4
        blt     t1, t2, overlay_cell
        addi    t1, x0, 0
        addi    t0, t0, 1
        blt     t0, t2, overlay_cell

        addi    t0, x0, 0
        addi    t1, x0, 20
        addi    t6, x0, 16
upload_rows:
        addi    a4, x0, 2
        sll     t2, t0, a4
        add     t3, s2, t2
        lw      t4, 0(t3)
        sll     t5, t0, t6
        or      t4, t4, t5
        sw      t4, 48(s0)             # LCD_GAME_ROW
        addi    t0, t0, 1
        blt     t0, t1, upload_rows
        addi    t0, x0, 1
        sw      t0, 52(s0)             # LCD_GAME_REFRESH
        lw      ra, 0(sp)
        addi    sp, sp, 4
        jalr    x0, 0(ra)

# Build the 28-entry rotation table in DMEM.
init_shapes:
        li t0, 0x00F0
        sw t0, 0(s3)
        li t0, 0x2222
        sw t0, 4(s3)
        li t0, 0x00F0
        sw t0, 8(s3)
        li t0, 0x2222
        sw t0, 12(s3)
        li t0, 0x0066
        sw t0, 16(s3)
        sw t0, 20(s3)
        sw t0, 24(s3)
        sw t0, 28(s3)
        li t0, 0x0072
        sw t0, 32(s3)
        li t0, 0x0262
        sw t0, 36(s3)
        li t0, 0x0270
        sw t0, 40(s3)
        li t0, 0x0232
        sw t0, 44(s3)
        li t0, 0x0036
        sw t0, 48(s3)
        li t0, 0x0462
        sw t0, 52(s3)
        li t0, 0x0036
        sw t0, 56(s3)
        li t0, 0x0462
        sw t0, 60(s3)
        li t0, 0x0063
        sw t0, 64(s3)
        li t0, 0x0264
        sw t0, 68(s3)
        li t0, 0x0063
        sw t0, 72(s3)
        li t0, 0x0264
        sw t0, 76(s3)
        li t0, 0x0071
        sw t0, 80(s3)
        li t0, 0x0226
        sw t0, 84(s3)
        li t0, 0x0470
        sw t0, 88(s3)
        li t0, 0x0322
        sw t0, 92(s3)
        li t0, 0x0074
        sw t0, 96(s3)
        li t0, 0x0622
        sw t0, 100(s3)
        li t0, 0x0170
        sw t0, 104(s3)
        li t0, 0x0223
        sw t0, 108(s3)
        jalr x0, 0(ra)
