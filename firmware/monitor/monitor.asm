        .msfirst

monitor_stack_top      .equ    $7f
reset_cc               .equ    $08

stop_reset             .equ    $01
stop_test              .equ    $02

memory_focus_hex       .equ    $00
memory_focus_ascii     .equ    $01

key_tab                .equ    $09
key_ctrl_n             .equ    $0e
key_ctrl_p             .equ    $10
key_left               .equ    $80
key_right              .equ    $81
key_up                 .equ    $82
key_down               .equ    $83

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
memory_page_hi         .equ    $21
memory_page_lo         .equ    $22
memory_cursor_hi       .equ    $28
memory_cursor_lo       .equ    $29
memory_focus           .equ    $2a
memory_hex_phase       .equ    $2b
memory_write_opcode    .equ    $2c
memory_write_hi        .equ    $2d
memory_write_lo        .equ    $2e
memory_write_rts       .equ    $2f
disasm_pc_hi           .equ    $30
disasm_pc_lo           .equ    $31
disasm_opcode          .equ    $32
disasm_test_count      .equ    $33

acia_status            .equ    $06
acia_control           .equ    $06
acia_data              .equ    $07
acia_tdre_bit          .equ    1
acia_master_reset      .equ    $03
acia_default_control   .equ    $15

jmp_extended           .equ    $cc
lda_extended_indexed   .equ    $d6
sta_extended_indexed   .equ    $d7
rts_instruction        .equ    $81

        .org    $1000

        .module reset_entry

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
        lda     #sta_extended_indexed
        sta     memory_write_opcode
        lda     #rts_instruction
        sta     memory_write_rts
        jsr     init_memory_panel
        jsr     init_console
        jsr     draw_boot_screen
        jmp     monitor_idle

        .module interrupt_dispatch

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

        .module console_io

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

        .module draw_boot_screen

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

        .module draw_cpu_row

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

        .module screen_output

emit_spaces:
        lda     #$20

emit_spaces_loop:
        jsr     chrout
        decx
        bne     emit_spaces_loop
        rts

        .module disasm_output

emit_disasm_mnemonic:
        clrx

emit_disasm_inherent_loop:
        lda     disasm_inherent_table,x
        beq     emit_disasm_fcb
        cmp     disasm_opcode
        beq     emit_disasm_inherent_found
        inx
        inx
        bra     emit_disasm_inherent_loop

emit_disasm_inherent_found:
        inx
        lda     disasm_inherent_table,x
        tax
        jsr     emit_disasm_text
        rts

emit_disasm_fcb:
        ldx     #disasm_fcb_text-disasm_text
        jsr     emit_disasm_text
        ldx     #$04
        jsr     emit_spaces
        lda     #$24
        jsr     chrout
        lda     disasm_opcode
        jsr     emit_hex_byte
        rts

emit_disasm_text:
        lda     #$04
        sta     hex_value

emit_disasm_text_loop:
        lda     disasm_text,x
        jsr     chrout
        inx
        dec     hex_value
        bne     emit_disasm_text_loop
        rts

        .module hex_output

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

        .module draw_memory_row

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

        .module draw_disassembly_row

draw_disassembly_row:
        lda     #$20
        jsr     chrout
        lda     disasm_pc_hi
        sta     memory_read_hi
        jsr     emit_hex_byte
        lda     disasm_pc_lo
        sta     memory_read_lo
        jsr     emit_hex_byte
        ldx     #memory_row_address_suffix_text-cpu_row_text
        jsr     emit_cpu_row_text
        clrx
        jsr     memory_read_opcode
        sta     disasm_opcode
        jsr     emit_hex_byte
        ldx     #$0a
        jsr     emit_spaces
        jsr     emit_disasm_mnemonic

draw_disassembly_done:
        ldx     #cpu_row_crlf_text-cpu_row_text
        jsr     emit_cpu_row_text
        inc     disasm_pc_lo
        bne     draw_disassembly_return
        inc     disasm_pc_hi

draw_disassembly_return:
        rts

        .module memory_ascii

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

        .module memory_panel

init_memory_panel:
        clra
        sta     memory_page_hi
        sta     memory_cursor_hi
        sta     memory_focus
        sta     memory_hex_phase
        lda     #$80
        sta     memory_page_lo
        sta     memory_cursor_lo
        rts

        .module memory_editing

memory_key_input:
        jsr     handle_memory_key
        jmp     monitor_idle

handle_memory_key:
        sta     hex_value
        cmp     #key_tab
        beq     memory_key_tab
        cmp     #key_ctrl_n
        beq     memory_key_next_page
        cmp     #key_ctrl_p
        beq     memory_key_prev_page
        cmp     #key_left
        beq     memory_key_left
        cmp     #key_right
        beq     memory_key_right
        cmp     #key_up
        beq     memory_key_up
        cmp     #key_down
        beq     memory_key_down
        lda     memory_focus
        beq     memory_key_hex_dispatch
        lda     hex_value
        jmp     memory_key_ascii

memory_key_hex_dispatch:
        lda     hex_value
        jmp     memory_key_hex

memory_key_tab:
        lda     memory_focus
        eor     #memory_focus_ascii
        sta     memory_focus
        clra
        sta     memory_hex_phase
        rts

memory_key_next_page:
        inc     memory_page_hi
        inc     memory_cursor_hi
        jmp     memory_cursor_done

memory_key_prev_page:
        dec     memory_page_hi
        dec     memory_cursor_hi
        jmp     memory_cursor_done

memory_key_left:
        jsr     memory_cursor_left
        rts

memory_key_right:
        jsr     memory_cursor_right
        rts

memory_key_up:
        jsr     memory_cursor_up
        rts

memory_key_down:
        jsr     memory_cursor_down
        rts

memory_key_ascii:
        cmp     #$20
        blo     memory_key_done
        cmp     #$7f
        bhs     memory_key_done
        jsr     memory_write_cursor
        jsr     memory_cursor_right

memory_key_done:
        rts

memory_key_hex:
        cmp     #$30
        blo     memory_key_done
        cmp     #$3a
        blo     memory_hex_digit
        cmp     #$41
        blo     memory_key_done
        cmp     #$47
        blo     memory_hex_upper
        cmp     #$61
        blo     memory_key_done
        cmp     #$67
        blo     memory_hex_lower
        rts

memory_hex_digit:
        sub     #$30
        bra     memory_hex_nibble

memory_hex_upper:
        sub     #$37
        bra     memory_hex_nibble

memory_hex_lower:
        sub     #$57

memory_hex_nibble:
        sta     hex_value
        lda     memory_hex_phase
        bne     memory_hex_low
        lda     hex_value
        lsla
        lsla
        lsla
        lsla
        jsr     memory_write_cursor
        lda     #$01
        sta     memory_hex_phase
        rts

memory_hex_low:
        jsr     memory_read_cursor
        and     #$f0
        sta     memory_row_index
        lda     hex_value
        ora     memory_row_index
        jsr     memory_write_cursor
        clra
        sta     memory_hex_phase
        jsr     memory_cursor_right
        rts

        .module memory_cursor

memory_select_cursor:
        lda     memory_cursor_hi
        sta     memory_read_hi
        sta     memory_write_hi
        lda     memory_cursor_lo
        sta     memory_read_lo
        sta     memory_write_lo
        clrx
        rts

memory_read_cursor:
        jsr     memory_select_cursor
        jsr     memory_read_opcode
        rts

memory_write_cursor:
        sta     hex_value
        jsr     memory_select_cursor
        lda     hex_value
        jsr     memory_write_opcode
        rts

memory_cursor_left:
        lda     memory_cursor_lo
        bne     memory_cursor_left_dec
        dec     memory_cursor_hi

memory_cursor_left_dec:
        dec     memory_cursor_lo
        bra     memory_cursor_done

memory_cursor_right:
        inc     memory_cursor_lo
        bne     memory_cursor_done
        inc     memory_cursor_hi
        bra     memory_cursor_done

memory_cursor_up:
        lda     memory_cursor_lo
        sub     #$10
        sta     memory_cursor_lo
        bcc     memory_cursor_done
        dec     memory_cursor_hi
        bra     memory_cursor_done

memory_cursor_down:
        lda     memory_cursor_lo
        add     #$10
        sta     memory_cursor_lo
        bcc     memory_cursor_done
        inc     memory_cursor_hi

memory_cursor_done:
        clra
        sta     memory_hex_phase
        rts

        .module test_hooks

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

test_disassembler_output:
        clra
        sta     disasm_pc_hi
        lda     #$80
        sta     disasm_pc_lo
        lda     #$29
        sta     disasm_test_count

test_disassembler_output_loop:
        jsr     draw_disassembly_row
        dec     disasm_test_count
        bne     test_disassembler_output_loop
        bra     monitor_idle

        .module monitor_idle

monitor_idle:
        bra     monitor_idle

        .module data_tables

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

disasm_text:

disasm_asla_text:
        .text   "asla"

disasm_aslx_text:
        .text   "aslx"

disasm_asra_text:
        .text   "asra"

disasm_asrx_text:
        .text   "asrx"

disasm_clc_text:
        .text   "clc "

disasm_cli_text:
        .text   "cli "

disasm_clra_text:
        .text   "clra"

disasm_clrx_text:
        .text   "clrx"

disasm_coma_text:
        .text   "coma"

disasm_comx_text:
        .text   "comx"

disasm_deca_text:
        .text   "deca"

disasm_decx_text:
        .text   "decx"

disasm_inca_text:
        .text   "inca"

disasm_incx_text:
        .text   "incx"

disasm_lsra_text:
        .text   "lsra"

disasm_lsrx_text:
        .text   "lsrx"

disasm_mul_text:
        .text   "mul "

disasm_nega_text:
        .text   "nega"

disasm_negx_text:
        .text   "negx"

disasm_nop_text:
        .text   "nop "

disasm_rola_text:
        .text   "rola"

disasm_rolx_text:
        .text   "rolx"

disasm_rora_text:
        .text   "rora"

disasm_rorx_text:
        .text   "rorx"

disasm_rsp_text:
        .text   "rsp "

disasm_rti_text:
        .text   "rti "

disasm_rts_text:
        .text   "rts "

disasm_sec_text:
        .text   "sec "

disasm_sei_text:
        .text   "sei "

disasm_stop_text:
        .text   "stop"

disasm_swi_text:
        .text   "swi "

disasm_tax_text:
        .text   "tax "

disasm_tsta_text:
        .text   "tsta"

disasm_tstx_text:
        .text   "tstx"

disasm_txa_text:
        .text   "txa "

disasm_wait_text:
        .text   "wait"

disasm_fcb_text:
        .text   "fcb "

disasm_inherent_table:
        .byte   $40,disasm_nega_text-disasm_text
        .byte   $42,disasm_mul_text-disasm_text
        .byte   $43,disasm_coma_text-disasm_text
        .byte   $44,disasm_lsra_text-disasm_text
        .byte   $46,disasm_rora_text-disasm_text
        .byte   $47,disasm_asra_text-disasm_text
        .byte   $48,disasm_asla_text-disasm_text
        .byte   $49,disasm_rola_text-disasm_text
        .byte   $4a,disasm_deca_text-disasm_text
        .byte   $4c,disasm_inca_text-disasm_text
        .byte   $4d,disasm_tsta_text-disasm_text
        .byte   $4f,disasm_clra_text-disasm_text
        .byte   $50,disasm_negx_text-disasm_text
        .byte   $53,disasm_comx_text-disasm_text
        .byte   $54,disasm_lsrx_text-disasm_text
        .byte   $56,disasm_rorx_text-disasm_text
        .byte   $57,disasm_asrx_text-disasm_text
        .byte   $58,disasm_aslx_text-disasm_text
        .byte   $59,disasm_rolx_text-disasm_text
        .byte   $5a,disasm_decx_text-disasm_text
        .byte   $5c,disasm_incx_text-disasm_text
        .byte   $5d,disasm_tstx_text-disasm_text
        .byte   $5f,disasm_clrx_text-disasm_text
        .byte   $80,disasm_rti_text-disasm_text
        .byte   $81,disasm_rts_text-disasm_text
        .byte   $83,disasm_swi_text-disasm_text
        .byte   $8e,disasm_stop_text-disasm_text
        .byte   $8f,disasm_wait_text-disasm_text
        .byte   $97,disasm_tax_text-disasm_text
        .byte   $98,disasm_clc_text-disasm_text
        .byte   $99,disasm_sec_text-disasm_text
        .byte   $9a,disasm_cli_text-disasm_text
        .byte   $9b,disasm_sei_text-disasm_text
        .byte   $9c,disasm_rsp_text-disasm_text
        .byte   $9d,disasm_nop_text-disasm_text
        .byte   $9f,disasm_txa_text-disasm_text
        .byte   $00

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

        .module interrupt_vectors

        .org    $1ff6
        .dw     timer_wait_dispatch   ; Timer from wait state
        .dw     timer_dispatch        ; Timer
        .dw     external_dispatch     ; External interrupt
        .dw     swi_entry       ; Software interrupt
        .dw     reset_entry     ; Reset

        .end
