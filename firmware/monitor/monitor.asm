        .msfirst

NUL                    .equ    $00             ; null character
TAB                    .equ    $09             ; horizontal tab
LF                     .equ    $0a             ; line feed
CR                     .equ    $0d             ; carriage return
ESC                    .equ    $1b             ; escape

monitor_stack_top      .equ    $7f
reset_cc               .equ    $08

stop_reset             .equ    $01
stop_test              .equ    $02

memory_focus_hex       .equ    $00
memory_focus_ascii     .equ    $01

key_tab                .equ    TAB
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

scratch                .equ    $20
scratch_end            .equ    scratch + $03

timer_wait_vector_hi   .equ    $17
timer_wait_vector_lo   .equ    $18
timer_vector_hi        .equ    $19
timer_vector_lo        .equ    $1a
external_vector_hi     .equ    $1b
external_vector_lo     .equ    $1c
int_jump_opcode        .equ    $1d
int_jump_hi            .equ    $1e
int_jump_lo            .equ    $1f
memory_page_hi         .equ    $23
memory_page_lo         .equ    $24
memory_read_opcode     .equ    $25
memory_read_hi         .equ    $26
memory_read_lo         .equ    $27
memory_read_rts        .equ    $28
memory_cursor_hi       .equ    $29
memory_cursor_lo       .equ    $2a
memory_focus           .equ    $2b
memory_hex_phase       .equ    $2c
memory_write_opcode    .equ    $2d
memory_write_hi        .equ    $2e
memory_write_lo        .equ    $2f
memory_write_rts       .equ    $30
disasm_pc_hi           .equ    $31
disasm_pc_lo           .equ    $32

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

; Reset entry initializes the monitor-owned machine image.
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
        sta     saved_cc                ; Saved registers are a monitor snapshot, not live CPU state
        lda     #stop_reset
        sta     stop_reason
        lda     #timer_wait_default_handler/100h
        sta     timer_wait_vector_hi    ; IRQ RAM vectors default to ROM handlers after reset
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
        lda     #jmp_extended           ; Shared IRQ thunk holds an absolute jump target
        sta     int_jump_opcode
        lda     #lda_extended_indexed   ; Read thunk opcode is fixed; callers patch address bytes
        sta     memory_read_opcode
        lda     #rts_instruction
        sta     memory_read_rts
        lda     #sta_extended_indexed   ; Write thunk opcode is fixed; cursor state patches address bytes
        sta     memory_write_opcode
        lda     #rts_instruction
        sta     memory_write_rts
        jsr     init_memory_panel
        jsr     init_console
        jsr     draw_boot_screen
        jmp     monitor_idle

        .module interrupt_dispatch

swi_entry:
        jmp     monitor_idle            ; SWI is the current user-code return path

; Interrupt dispatch vectors through RAM so user code can intercept IRQs.
timer_wait_dispatch:
        lda     timer_wait_vector_hi
        sta     int_jump_hi             ; Dispatcher copies the chosen RAM vector into the shared thunk
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

; Console I/O owns the ACIA setup and byte-at-a-time transmit path.
init_console:
        lda     #acia_master_reset      ; ACIA reset and mode bytes are separate writes
        sta     acia_control
        lda     #acia_default_control
        sta     acia_control
        rts

chrout:
                                        ; Polling keeps the early ROM serial path small
        brclr   acia_tdre_bit,acia_status,chrout
        sta     acia_data
        rts

        .module draw_boot_screen

; Boot drawing positions the terminal with compact ANSI text.
draw_boot_screen:
        ldx     #0                      ; Boot text leans on terminal state instead of filling rows

_loop:
        lda     boot_screen_text,x
        beq     _done
        jsr     chrout
        inx
        bra     _loop

_done:
        jmp     draw_cpu_row

        .module draw_cpu_row

; CPU status rendering formats the saved user context as one row.
draw_cpu_row:
                                        ; Text fragments keep labels local while sharing one emitter
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
        jsr     emit_flag_h             ; Unset flags become blanks so set flags stand out
        jsr     emit_flag_i
        jsr     emit_flag_n
        jsr     emit_flag_z
        jsr     emit_flag_c
        ldx     #cpu_row_stopped_text-cpu_row_text
        jsr     emit_cpu_row_text
        jsr     emit_stop_reason        ; Stop reason maps internal causes to display text
        ldx     #cpu_row_crlf_text-cpu_row_text
        jsr     emit_cpu_row_text
        rts

emit_cpu_row_text:
        lda     cpu_row_text,x
        beq     _done
        jsr     chrout
        inx
        bra     emit_cpu_row_text

_done:
        rts

        .module screen_output

_save                  .equ    scratch         ; saved A across spacing output

emit_spaces:
        sta     _save
        lda     #$20

_loop:
        jsr     chrout
        decx
        bne     _loop
        lda     _save
        rts

        .module disasm_output

_cnt                   .equ    scratch         ; mnemonic character count
_op                    .equ    scratch + $01  ; opcode being decoded

; Disassembler output decodes one opcode into local assembly style.
emit_disasm_mnemonic:
        sta     _op
        clrx                            ; Table scan stops at a zero opcode sentinel

_scan:
        lda     disasm_inherent_table,x
        beq     emit_disasm_fcb
        cmp     _op
        beq     _found
        inx
        inx
        bra     _scan

_found:
        inx
        lda     disasm_inherent_table,x
        tax
        jsr     emit_disasm_text
        rts

emit_disasm_fcb:
                                        ; Unknown opcodes are emitted as fcb with literal byte
        ldx     #disasm_fcb_text-disasm_text
        jsr     emit_disasm_text
        ldx     #$04
        jsr     emit_spaces
        lda     #$24
        jsr     chrout
        lda     _op
        jsr     emit_hex_byte
        rts

emit_disasm_text:
        lda     #$04                    ; Each mnemonic is fixed at four characters
        sta     _cnt

_loop:
        lda     disasm_text,x
        jsr     chrout
        inx
        dec     _cnt
        bne     _loop
        rts

        .module hex_output

_byte                  .equ    scratch         ; byte being formatted as hex

emit_hex_byte:
        sta     _byte
        lsra
        lsra
        lsra
        lsra
        jsr     emit_hex_nibble
        lda     _byte
        and     #$0f
        jsr     emit_hex_nibble
        lda     _byte
        rts

emit_hex_nibble:
        and     #$0f
        tax
        lda     hex_digits,x
        jsr     chrout
        rts

emit_flag_h:
        brset   cc_h_bit,saved_cc,_h_set
        lda     #$20
        bra     _h_wr

_h_set:
        lda     #$48

_h_wr:
        jsr     chrout
        rts

emit_flag_i:
        brset   cc_i_bit,saved_cc,_i_set
        lda     #$20
        bra     _i_wr

_i_set:
        lda     #$49

_i_wr:
        jsr     chrout
        rts

emit_flag_n:
        brset   cc_n_bit,saved_cc,_n_set
        lda     #$20
        bra     _n_wr

_n_set:
        lda     #$4e

_n_wr:
        jsr     chrout
        rts

emit_flag_z:
        brset   cc_z_bit,saved_cc,_z_set
        lda     #$20
        bra     _z_wr

_z_set:
        lda     #$5a

_z_wr:
        jsr     chrout
        rts

emit_flag_c:
        brset   cc_c_bit,saved_cc,_c_set
        lda     #$20
        bra     _c_wr

_c_set:
        lda     #$43

_c_wr:
        jsr     chrout
        rts

emit_stop_reason:
        lda     stop_reason
        cmp     #stop_reset
        beq     _reset
        cmp     #stop_test
        beq     _test
        ldx     #stop_unknown_text-cpu_row_text
        bra     _write

_reset:
        ldx     #stop_reset_text-cpu_row_text
        bra     _write

_test:
        ldx     #stop_test_text-cpu_row_text

_write:
        jsr     emit_cpu_row_text
        rts

        .module draw_memory_row

_idx                   .equ    scratch + $01  ; memory row byte offset

; Memory row rendering uses the generated read thunk for addressable RAM.
draw_memory_row:
        lda     memory_page_hi          ; The row address patches the read thunk before output
        sta     memory_read_hi
        jsr     emit_hex_byte
        lda     memory_page_lo
        sta     memory_read_lo
        jsr     emit_hex_byte
        ldx     #memory_row_address_suffix_text-cpu_row_text
        jsr     emit_cpu_row_text
        clrx
        stx     _idx

_hexlp:
        ldx     _idx
        jsr     memory_read_opcode
        jsr     emit_hex_byte
        lda     #$20
        jsr     chrout
        ldx     _idx
        inx
        stx     _idx
        cpx     #$10
        bne     _hexlp
        lda     #$20
        jsr     chrout
        clrx

_asclp:
        jsr     memory_read_opcode      ; The ASCII pass rereads the same row from byte zero
        jsr     emit_memory_ascii
        inx
        cpx     #$10
        bne     _asclp
        ldx     #cpu_row_crlf_text-cpu_row_text
        jsr     emit_cpu_row_text
        rts

        .module draw_disassembly_row

; Disassembly row rendering advances a separate PC from the memory panel.
draw_disassembly_row:
        lda     #$20                    ; Disassembly has its own PC so rows need not align
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
        jsr     emit_hex_byte
        ldx     #$0a
        jsr     emit_spaces
        jsr     emit_disasm_mnemonic

_done:
        ldx     #cpu_row_crlf_text-cpu_row_text
        jsr     emit_cpu_row_text
        inc     disasm_pc_lo
        bne     _return
        inc     disasm_pc_hi

_return:
        rts

        .module memory_ascii

emit_memory_ascii:
        cmp     #$20                    ; Control and high-bit bytes collapse to dot for scanability
        blo     _dot
        cmp     #$7f
        blo     _write

_dot:
        lda     #$2e

_write:
        jsr     chrout
        rts

        .module memory_panel

; Memory panel state starts on the first RAM page with hex focus.
init_memory_panel:
        clra                            ; Page and cursor track the same window at initialization
        sta     memory_page_hi
        sta     memory_cursor_hi
        sta     memory_focus
        sta     memory_hex_phase
        lda     #$80
        sta     memory_page_lo
        sta     memory_cursor_lo
        rts

        .module memory_editing

_ch                    .equ    scratch         ; key byte during dispatch
_nib                   .equ    scratch         ; parsed hex nibble
_tmp                   .equ    scratch + $01  ; preserved high nibble

; Memory key handling updates panel state without redrawing here.
memory_key_input:
        jsr     _key
        jmp     monitor_idle

_key:
        sta     _ch
        cmp     #key_tab
        beq     _tab
        cmp     #key_ctrl_n
        beq     _next
        cmp     #key_ctrl_p
        beq     _prev
        cmp     #key_left
        beq     _left
        cmp     #key_right
        beq     _right
        cmp     #key_up
        beq     _up
        cmp     #key_down
        beq     _down
        lda     memory_focus
        beq     _hexgo
        lda     _ch
        jmp     _ascii

_hexgo:
        lda     _ch
        jmp     _hex

_tab:
        lda     memory_focus            ; Tab changes which view accepts edits
        eor     #memory_focus_ascii
        sta     memory_focus
        clra
        sta     memory_hex_phase
        rts

_next:
        inc     memory_page_hi          ; Page motion keeps cursor and page together
        inc     memory_cursor_hi
        jmp     memory_cursor_done

_prev:
        dec     memory_page_hi
        dec     memory_cursor_hi
        jmp     memory_cursor_done

_left:
        jsr     memory_cursor_left
        rts

_right:
        jsr     memory_cursor_right
        rts

_up:
        jsr     memory_cursor_up
        rts

_down:
        jsr     memory_cursor_down
        rts

_ascii:
        cmp     #$20                    ; ASCII editing accepts printable bytes only
        blo     _done
        cmp     #$7f
        bhs     _done
        jsr     memory_write_cursor
        jsr     memory_cursor_right

_done:
        rts

_hex:
        cmp     #$30                    ; Hex editing converts ASCII digits into nibbles
        blo     _done
        cmp     #$3a
        blo     _digit
        cmp     #$41
        blo     _done
        cmp     #$47
        blo     _upper
        cmp     #$61
        blo     _done
        cmp     #$67
        blo     _lower
        rts

_digit:
        sub     #$30
        bra     _nibl

_upper:
        sub     #$37
        bra     _nibl

_lower:
        sub     #$57

_nibl:
        sta     _nib                    ; The first hex digit writes the high nibble and waits
        lda     memory_hex_phase
        bne     _low
        lda     _nib
        lsla
        lsla
        lsla
        lsla
        jsr     memory_write_cursor
        lda     #$01
        sta     memory_hex_phase
        rts

_low:
        jsr     memory_read_cursor      ; The second hex digit merges with the saved high nibble
        and     #$f0
        sta     _tmp
        lda     _nib
        ora     _tmp
        jsr     memory_write_cursor
        clra
        sta     memory_hex_phase
        jsr     memory_cursor_right
        rts

        .module memory_cursor

_byte                  .equ    scratch         ; byte held while patching write thunk

; Cursor helpers patch generated access thunks around the current address.
memory_select_cursor:
        lda     memory_cursor_hi        ; Cursor selection patches both thunks from one address
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
        sta     _byte
        jsr     memory_select_cursor
        lda     _byte
        jsr     memory_write_opcode
        rts

memory_cursor_left:
        lda     memory_cursor_lo
        bne     _dec
        dec     memory_cursor_hi

_dec:
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
        clra                            ; Cursor movement clears the pending nibble after navigation
        sta     memory_hex_phase
        rts

        .module test_hooks

_cnt                   .equ    scratch + $02  ; test loop count across callee scratch use

; MAME test hooks expose stable ROM entry points for focused checks.
test_console_output:
        lda     #$4f                    ; Hooks stop by branching to monitor_idle after emitting fixture data
        jsr     chrout
        lda     #$4b
        jsr     chrout
        lda     #CR
        jsr     chrout
        lda     #LF
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
        sta     memory_page_hi
        lda     #$80
        sta     memory_page_lo
        jsr     draw_memory_row
        bra     monitor_idle

test_disassembler_output:
        clra
        sta     disasm_pc_hi
        lda     #$80
        sta     disasm_pc_lo
        lda     #$29
        sta     _cnt

_loop:
        jsr     draw_disassembly_row
        dec     _cnt
        bne     _loop
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
        .byte   NUL

cpu_row_pc_text:
        .text   "  PC "
        .byte   NUL

cpu_row_a_text:
        .text   "  A "
        .byte   NUL

cpu_row_x_text:
        .text   "  X "
        .byte   NUL

cpu_row_flags_text:
        .text   "  FLAGS 111"
        .byte   NUL

cpu_row_stopped_text:
        .text   "  STOPPED: "
        .byte   NUL

stop_reset_text:
        .text   "RESET"
        .byte   NUL

stop_test_text:
        .text   "TEST"
        .byte   NUL

stop_unknown_text:
        .text   "UNKNOWN"
        .byte   NUL

memory_row_address_suffix_text:
        .text   ": "
        .byte   NUL

cpu_row_crlf_text:
        .byte   CR,LF,NUL

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
                                        ; The table stores opcode then text offset for each match
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
        .byte   ESC                     ; Boot text emits escape sequences instead of blank-filled rows
        .text   "[2J"
        .byte   ESC
        .text   "[1;68H"
#include "monitor_version.inc"
        .byte   ESC
        .text   "[H"
        .byte   NUL

rom_code_end:

        .module interrupt_vectors

        .org    $1ff6                   ; Vectors remain at the CPU hardware locations
        .dw     timer_wait_dispatch     ; Timer from wait state
        .dw     timer_dispatch          ; Timer
        .dw     external_dispatch       ; External interrupt
        .dw     swi_entry               ; Software interrupt
        .dw     reset_entry             ; Reset

        .end
