        .msfirst

monitor_stack_top      .equ    $7f
reset_cc               .equ    $08

stop_reset             .equ    $01
stop_test              .equ    $02

cc_c_bit               .equ    0
cc_z_bit               .equ    1
cc_n_bit               .equ    2
cc_i_bit               .equ    3
cc_h_bit               .equ    4

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
hex_value              .equ    $20
memory_row_hi          .equ    $21
memory_row_lo          .equ    $22
memory_row_index       .equ    $23
memory_read_opcode     .equ    $24
memory_read_hi         .equ    $25
memory_read_lo         .equ    $26
memory_read_rts        .equ    $27

acia_status            .equ    $06
acia_control           .equ    $06
acia_data              .equ    $07
acia_tdre_bit          .equ    1
acia_master_reset      .equ    $03
acia_default_control   .equ    $15

jmp_extended           .equ    $cc
lda_extended_indexed   .equ    $d6
rts_instruction        .equ    $81

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
        lda     #lda_extended_indexed
        sta     memory_read_opcode
        lda     #rts_instruction
        sta     memory_read_rts
        jsr     init_console
        jsr     draw_boot_screen
        jmp     monitor_idle

swi_entry:
        jmp     monitor_idle

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
        jmp     monitor_idle

timer_default_handler:
        jmp     monitor_idle

external_default_handler:
        jmp     monitor_idle

init_console:
        lda     #acia_master_reset
        sta     acia_control
        lda     #acia_default_control
        sta     acia_control
        rts

chrout:
        brclr   acia_tdre_bit,acia_status,chrout
        sta     acia_data
        rts

draw_boot_screen:
        ldx     #0
draw_boot_screen_loop:
        lda     boot_screen_text,x
        beq     draw_boot_screen_done
        jsr     chrout
        inx
        bra     draw_boot_screen_loop
draw_boot_screen_done:
        jmp     draw_cpu_row

draw_cpu_row:
        ldx     #cpu_row_sp_text-cpu_row_text
        jsr     emit_cpu_row_text
        clra
        jsr     emit_hex_byte
        lda     saved_sp
        jsr     emit_hex_byte
        ldx     #cpu_row_pc_text-cpu_row_text
        jsr     emit_cpu_row_text
        lda     saved_pc_hi
        jsr     emit_hex_byte
        lda     saved_pc_lo
        jsr     emit_hex_byte
        ldx     #cpu_row_a_text-cpu_row_text
        jsr     emit_cpu_row_text
        lda     saved_a
        jsr     emit_hex_byte
        ldx     #cpu_row_x_text-cpu_row_text
        jsr     emit_cpu_row_text
        lda     saved_x
        jsr     emit_hex_byte
        ldx     #cpu_row_flags_text-cpu_row_text
        jsr     emit_cpu_row_text
        jsr     emit_flag_h
        jsr     emit_flag_i
        jsr     emit_flag_n
        jsr     emit_flag_z
        jsr     emit_flag_c
        ldx     #cpu_row_stopped_text-cpu_row_text
        jsr     emit_cpu_row_text
        jsr     emit_stop_reason
        ldx     #cpu_row_crlf_text-cpu_row_text
        jsr     emit_cpu_row_text
        rts

emit_cpu_row_text:
        lda     cpu_row_text,x
        beq     emit_cpu_row_text_done
        jsr     chrout
        inx
        bra     emit_cpu_row_text
emit_cpu_row_text_done:
        rts

emit_hex_byte:
        sta     hex_value
        lsra
        lsra
        lsra
        lsra
        jsr     emit_hex_nibble
        lda     hex_value
        and     #$0f
        jsr     emit_hex_nibble
        rts

emit_hex_nibble:
        and     #$0f
        tax
        lda     hex_digits,x
        jsr     chrout
        rts

emit_flag_h:
        brset   cc_h_bit,saved_cc,emit_flag_h_set
        lda     #$20
        bra     emit_flag_h_write
emit_flag_h_set:
        lda     #$48
emit_flag_h_write:
        jsr     chrout
        rts

emit_flag_i:
        brset   cc_i_bit,saved_cc,emit_flag_i_set
        lda     #$20
        bra     emit_flag_i_write
emit_flag_i_set:
        lda     #$49
emit_flag_i_write:
        jsr     chrout
        rts

emit_flag_n:
        brset   cc_n_bit,saved_cc,emit_flag_n_set
        lda     #$20
        bra     emit_flag_n_write
emit_flag_n_set:
        lda     #$4e
emit_flag_n_write:
        jsr     chrout
        rts

emit_flag_z:
        brset   cc_z_bit,saved_cc,emit_flag_z_set
        lda     #$20
        bra     emit_flag_z_write
emit_flag_z_set:
        lda     #$5a
emit_flag_z_write:
        jsr     chrout
        rts

emit_flag_c:
        brset   cc_c_bit,saved_cc,emit_flag_c_set
        lda     #$20
        bra     emit_flag_c_write
emit_flag_c_set:
        lda     #$43
emit_flag_c_write:
        jsr     chrout
        rts

emit_stop_reason:
        lda     stop_reason
        cmp     #stop_reset
        beq     emit_stop_reason_reset
        cmp     #stop_test
        beq     emit_stop_reason_test
        ldx     #stop_unknown_text-cpu_row_text
        bra     emit_stop_reason_write
emit_stop_reason_reset:
        ldx     #stop_reset_text-cpu_row_text
        bra     emit_stop_reason_write
emit_stop_reason_test:
        ldx     #stop_test_text-cpu_row_text
emit_stop_reason_write:
        jsr     emit_cpu_row_text
        rts

draw_memory_row:
        lda     memory_row_hi
        sta     memory_read_hi
        jsr     emit_hex_byte
        lda     memory_row_lo
        sta     memory_read_lo
        jsr     emit_hex_byte
        ldx     #memory_row_address_suffix_text-cpu_row_text
        jsr     emit_cpu_row_text
        clrx
        stx     memory_row_index
draw_memory_row_hex_loop:
        ldx     memory_row_index
        jsr     memory_read_opcode
        jsr     emit_hex_byte
        lda     #$20
        jsr     chrout
        ldx     memory_row_index
        inx
        stx     memory_row_index
        cpx     #$10
        bne     draw_memory_row_hex_loop
        lda     #$20
        jsr     chrout
        clrx
draw_memory_row_ascii_loop:
        jsr     memory_read_opcode
        jsr     emit_memory_ascii
        inx
        cpx     #$10
        bne     draw_memory_row_ascii_loop
        ldx     #cpu_row_crlf_text-cpu_row_text
        jsr     emit_cpu_row_text
        rts

emit_memory_ascii:
        cmp     #$20
        blo     emit_memory_ascii_dot
        cmp     #$7f
        blo     emit_memory_ascii_write
emit_memory_ascii_dot:
        lda     #$2e
emit_memory_ascii_write:
        jsr     chrout
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

test_cpu_row_output:
        lda     #$7f
        sta     saved_sp
        lda     #$12
        sta     saved_pc_hi
        lda     #$34
        sta     saved_pc_lo
        lda     #$a5
        sta     saved_a
        lda     #$5a
        sta     saved_x
        lda     #$1f
        sta     saved_cc
        lda     #stop_test
        sta     stop_reason
        jsr     draw_cpu_row
        bra     monitor_idle

test_memory_row_output:
        clra
        sta     memory_row_hi
        lda     #$80
        sta     memory_row_lo
        jsr     draw_memory_row
        bra     monitor_idle

monitor_idle:
        bra     monitor_idle

hex_digits:
        .text   "0123456789ABCDEF"

cpu_row_text:
cpu_row_sp_text:
        .text   "SP "
        .byte   $00
cpu_row_pc_text:
        .text   "  PC "
        .byte   $00
cpu_row_a_text:
        .text   "  A "
        .byte   $00
cpu_row_x_text:
        .text   "  X "
        .byte   $00
cpu_row_flags_text:
        .text   "  FLAGS 111"
        .byte   $00
cpu_row_stopped_text:
        .text   "  STOPPED: "
        .byte   $00
stop_reset_text:
        .text   "RESET"
        .byte   $00
stop_test_text:
        .text   "TEST"
        .byte   $00
stop_unknown_text:
        .text   "UNKNOWN"
        .byte   $00
memory_row_address_suffix_text:
        .text   ": "
        .byte   $00
cpu_row_crlf_text:
        .byte   $0d,$0a,$00

boot_screen_text:
        .byte   $1b
        .text   "[2J"
        .byte   $1b
        .text   "[1;68H"
#include "monitor_version.inc"
        .byte   $1b
        .text   "[H"
        .byte   $00

rom_code_end:

        .org    $1ff6
        .dw     timer_wait_dispatch   ; Timer from wait state
        .dw     timer_dispatch        ; Timer
        .dw     external_dispatch     ; External interrupt
        .dw     swi_entry       ; Software interrupt
        .dw     reset_entry     ; Reset

        .end
