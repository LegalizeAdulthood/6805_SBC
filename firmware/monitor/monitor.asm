        .msfirst

monitor_stack_top      .equ    $7f
reset_cc               .equ    $08

stop_reset             .equ    $01

saved_sp               .equ    $10
saved_pc_hi            .equ    $11
saved_pc_lo            .equ    $12
saved_a                .equ    $13
saved_x                .equ    $14
saved_cc               .equ    $15
stop_reason            .equ    $16

timer_wait_vector_hi   .equ    $17
timer_wait_vector_lo   .equ    $18
timer_vector_hi        .equ    $19
timer_vector_lo        .equ    $1a
external_vector_hi     .equ    $1b
external_vector_lo     .equ    $1c
int_jump_opcode        .equ    $1d
int_jump_hi            .equ    $1e
int_jump_lo            .equ    $1f

acia_status            .equ    $06
acia_data              .equ    $07
acia_tdre_bit          .equ    1

jmp_extended           .equ    $cc

        .org    $1000
reset_entry:
        rsp
        lda     #monitor_stack_top
        sta     saved_sp
        lda     #reset_entry/100h
        sta     saved_pc_hi
        lda     #reset_entry-(reset_entry/100h*100h)
        sta     saved_pc_lo
        clra
        sta     saved_a
        clrx
        stx     saved_x
        lda     #reset_cc
        sta     saved_cc
        lda     #stop_reset
        sta     stop_reason
        lda     #timer_wait_default_handler/100h
        sta     timer_wait_vector_hi
        lda     #timer_wait_default_handler-(timer_wait_default_handler/100h*100h)
        sta     timer_wait_vector_lo
        lda     #timer_default_handler/100h
        sta     timer_vector_hi
        lda     #timer_default_handler-(timer_default_handler/100h*100h)
        sta     timer_vector_lo
        lda     #external_default_handler/100h
        sta     external_vector_hi
        lda     #external_default_handler-(external_default_handler/100h*100h)
        sta     external_vector_lo
        lda     #jmp_extended
        sta     int_jump_opcode
        bra     monitor_idle

swi_entry:
        bra     monitor_idle

timer_wait_dispatch:
        lda     timer_wait_vector_hi
        sta     int_jump_hi
        lda     timer_wait_vector_lo
        sta     int_jump_lo
        jmp     int_jump_opcode

timer_dispatch:
        lda     timer_vector_hi
        sta     int_jump_hi
        lda     timer_vector_lo
        sta     int_jump_lo
        jmp     int_jump_opcode

external_dispatch:
        lda     external_vector_hi
        sta     int_jump_hi
        lda     external_vector_lo
        sta     int_jump_lo
        jmp     int_jump_opcode

timer_wait_default_handler:
        bra     monitor_idle

timer_default_handler:
        bra     monitor_idle

external_default_handler:
        bra     monitor_idle

chrout:
        brclr   acia_tdre_bit,acia_status,chrout
        sta     acia_data
        rts

test_console_output:
        lda     #$4f
        jsr     chrout
        lda     #$4b
        jsr     chrout
        lda     #$0d
        jsr     chrout
        lda     #$0a
        jsr     chrout
        bra     monitor_idle

monitor_idle:
        bra     monitor_idle

rom_code_end:

        .org    $1ff6
        .dw     timer_wait_dispatch   ; Timer from wait state
        .dw     timer_dispatch        ; Timer
        .dw     external_dispatch     ; External interrupt
        .dw     swi_entry       ; Software interrupt
        .dw     reset_entry     ; Reset

        .end
