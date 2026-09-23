; EVSBUG12 source provenance:
;
; - Disassembled the binary dump with unidasm to produce evsbug12.lst.
; - Extracted the initial evsbug12.asm source from the listing file.
; - Assembled with TASM until the output matched the binary byte for byte.
; - Revised the source to identify routines, tables, and related symbols.
;
        .msfirst

acia_base       .equ    $ffe0
acia_isra       .equ    acia_base + $00
acia_iera       .equ    acia_base + $00
acia_csra       .equ    acia_base + $01
acia_cra        .equ    acia_base + $01
acia_fra        .equ    acia_base + $01
acia_cdra       .equ    acia_base + $02
acia_acra       .equ    acia_base + $02
acia_rdra       .equ    acia_base + $03
acia_tdra       .equ    acia_base + $03
acia_isrb       .equ    acia_base + $04
acia_ierb       .equ    acia_base + $04
acia_csrb       .equ    acia_base + $05
acia_crb        .equ    acia_base + $05
acia_frb        .equ    acia_base + $05
acia_cdrb       .equ    acia_base + $06
acia_acrb       .equ    acia_base + $06
acia_rdrb       .equ    acia_base + $07
acia_tdrb       .equ    acia_base + $07
map_switch      .equ    $50
scratch         .equ    $51
cmd_thunk       .equ    $9c
int_vecs        .equ    $1ff0

cmd_err         .equ    scratch+$01   ; command error flag
cmd_args        .equ    scratch+$02   ; command argument count
line_buf        .equ    scratch+$03   ; command line buffer
cmd_arg_hi      .equ    scratch+$20   ; command arg table high
cmd_arg_lo      .equ    scratch+$21   ; command arg table low
addr_hi         .equ    scratch+$22   ; active address high
addr_lo         .equ    scratch+$23   ; active address low
word_hi         .equ    scratch+$24   ; secondary word high
word_lo         .equ    scratch+$25   ; secondary word low
parse_hi        .equ    scratch+$2c   ; parsed word high
parse_lo        .equ    scratch+$2d   ; parsed word low
line_pos        .equ    scratch+$2e   ; line buffer index
mod_idx         .equ    scratch+$2f   ; modify register field index
mod_len         .equ    scratch+$31   ; modify value byte count
brk_idx         .equ    scratch+$31   ; breakpoint slot index
cmd_char        .equ    scratch+$32   ; command input character
brk_addr_hi     .equ    scratch+$34   ; breakpoint table: high first
brk_addr_lo     .equ    scratch+$35   ; breakpoint table: low next
inst_target_hi  .equ    scratch+$3e   ; decoded target high
inst_target_lo  .equ    scratch+$3f   ; decoded target low
inst_next       .equ    scratch+$40   ; decoded next address
brk_ops         .equ    scratch+$42   ; saved breakpoint opcodes
trace_cnt       .equ    scratch+$49   ; trace instruction count
proceed_cnt     .equ    scratch+$4a   ; proceed breakpoint count
step_flag       .equ    scratch+$51   ; step-over pending flag
mon_flags       .equ    scratch+$52   ; monitor control flags
user_sp         .equ    scratch+$53   ; captured user SP
saved_addr_hi   .equ    scratch+$54   ; saved address high
saved_addr_lo   .equ    scratch+$55   ; saved address low
checksum        .equ    scratch+$56   ; checksum accumulator
op_len          .equ    scratch+$57   ; operand byte count
decode_flags    .equ    scratch+$58   ; decode attribute flags
hex_digit       .equ    scratch+$59   ; parsed hex digit
asm_once        .equ    scratch+$5a   ; assembler one-shot flag
serial_ctl      .equ    scratch+$5b   ; serial control bits
poll_flag       .equ    scratch+$5c   ; pause poll pending
tmp_a           .equ    scratch+$5d   ; temporary A save
io_stat         .equ    scratch+$60   ; I/O status scratch

op_bset1        .equ    $12
op_jmp          .equ    $cc

        .org    $0000
        .byte   $00
        .org    $0800

        .module console_io
_save_x         .equ    scratch+$59   ; saved X register

sub_0800:
        sta     tmp_a
        lda     #$00
        sta     $fff0
        lda     tmp_a
        rts

read_console_char_echo:
        stx     _save_x

_read_poll:
        jsr     sub_0800
        ldx     acia_csra
        stx     io_stat
        brset   2, io_stat, _serial_event
        ldx     acia_isra
        stx     io_stat
        brclr   0, io_stat, _read_poll
        lda     acia_rdra
        and     #$7f
        bra     _write_char

write_console_char:
        stx     _save_x
        ldx     acia_isra
        stx     io_stat
        brclr   0, io_stat, _write_char
        ldx     #$ff
        stx     poll_flag

_write_char:
        sta     acia_tdra
        brset   1, mon_flags, _return

_tx_poll:
        jsr     sub_0800
        ldx     acia_isra
        stx     io_stat
        brclr   6, io_stat, _tx_poll
        ldx     acia_csra
        stx     io_stat
        brset   2, io_stat, _serial_event

_return:
        ldx     _save_x
        rts

_serial_event:
        lda     acia_rdra
        jsr     init_serial_or_timer
        clr     mon_flags
        jmp     cmd_loop

        .module write_hex_byte
_save_a         .equ    scratch+$33   ; saved byte for output

write_hex_byte:
        sta     _save_a
        add     checksum
        sta     checksum
        lda     _save_a
        bsr     write_hi_nibl
        lda     _save_a
        and     #$0f
        bra     write_lo_nibl

write_hi_nibl:
        lsra
        lsra
        lsra
        lsra

write_lo_nibl:
        add     #$30
        cmp     #$39
        bls     _emit
        add     #$07

_emit:
        jsr     write_console_char
        rts

write_hex_word_at_73:
        lda     addr_hi
        and     #$ff
        jsr     write_hex_byte
        lda     addr_lo
        jsr     write_hex_byte
        rts

        .module write_values
write_eq_value:
        lda     #$3d
        jsr     write_console_char
        jsr     read_memory_byte
        tst     mod_len
        beq     _write_byte
        and     #$ff
        jsr     write_hex_byte
        jsr     increment_address
        jsr     read_memory_byte

_write_byte:
        jsr     write_hex_byte

_return:
        rts

write_string:
        lda     message_text,x
        beq     _return
        jsr     write_console_char
        incx
        bra     write_string

        .module display_regs_msg
_reg_idx        .equ    scratch+$33   ; register field index

display_regs_msg:
        jsr     write_string

display_regs:
        jsr     write_crlf
        clrx
        jsr     stack_addr
        clr     mod_len
        jsr     write_sp

_next_reg:
        incx
        stx     _reg_idx
        ldx     #msg_sp4
        jsr     write_string
        ldx     _reg_idx
        lda     register_fields,x
        beq     display_cc
        bsr     select_reg_addr
        jsr     write_console_char
        jsr     write_eq_value
        bra     _next_reg

write_sp:
        lda     #$53
        jsr     write_console_char
        lda     #$3d
        jsr     write_console_char
        lda     addr_lo
        add     #$05
        jsr     write_hex_byte
        rts

; register display field table

register_fields:
        .byte   "SPAXC",$00

write_crlf:
        lda     #$0d
        jsr     write_console_char
        lda     #$0a
        jsr     write_console_char
        rts

; condition-code display table
        .fill   $0008,$00

condition_bits:
        .byte   "111HINZC"

        .module select_reg_addr
_cnt            .equ    scratch+$31   ; offset/flag count
_tmp            .equ    scratch+$33   ; X save/flags byte

select_reg_addr:
        stx     _tmp
        tax
        lda     user_sp
        clr     _cnt
        clr     addr_hi
        cpx     #$50
        bne     _check_x
        inc     _cnt
        add     #$04

_check_x:
        cpx     #$58
        bne     _check_a
        add     #$03

_check_a:
        cpx     #$41
        bne     _check_cc
        add     #$02

_check_cc:
        cpx     #$43
        bne     _store_addr
        add     #$01

_store_addr:
        sta     addr_lo
        txa
        ldx     _tmp
        rts

display_cc:
        ldx     #msg_sp4
        jsr     write_string
        lda     user_sp
        add     #$01
        sta     addr_lo
        clr     addr_hi
        jsr     read_memory_byte
        sta     _tmp
        ldx     #$ff
        lda     #$08
        sta     _cnt

_flag_loop:
        incx
        lda     #$2e
        asl     _tmp
        bcc     _write_flag
        lda     condition_bits,x

_write_flag:
        jsr     write_console_char
        dec     _cnt
        bne     _flag_loop
        rts

        .module write_memory_byte
_byte           .equ    scratch+$33   ; memory write byte

write_memory_byte:
        sta     _byte
        jsr     sub_0800
        lda     #$c7
        bra     _access_user

read_memory_byte:
        lda     #$c6
        jsr     sub_0800

_access_user:
        bclr    2, map_switch
        sta     cmd_thunk+$02
        lda     #op_bset1
        sta     cmd_thunk
        lda     #$50
        sta     cmd_thunk+$01
        lda     addr_hi
        sta     cmd_thunk+$03
        lda     addr_lo
        sta     cmd_thunk+$04
        lda     #$81
        sta     cmd_thunk+$05
        lda     _byte
        jsr     cmd_thunk
        bclr    1, map_switch
        bset    2, map_switch
        rts

        .module address_math
_delta          .equ    scratch+$33     ; address delta byte

increment_address:
        lda     #$01

add_a_to_address:
        add     addr_lo
        sta     addr_lo
        clra
        adc     addr_hi

_store_hi:
        sta     addr_hi
        rts

decrement_address:
        lda     #$01

subtract_a_from_address:
        sta     _delta
        lda     addr_lo
        sub     _delta
        sta     addr_lo
        lda     addr_hi
        sbc     #$00
        bra     _store_hi

address_in_range:
        lda     word_hi
        cmp     addr_hi
        bcs     _out_of_range
        bhi     _return
        lda     word_lo
        cmp     addr_lo
        bcs     _out_of_range
        lda     #$01

_return:
        rts

_out_of_range:
        clra
        bra     _return

stack_addr:
        clr     addr_hi
        lda     user_sp
        sta     addr_lo
        txa
        jsr     add_a_to_address
        rts

read_stack_word:
        jsr     stack_addr

read_mem_word:
        jsr     read_memory_byte
        and     #$ff
        sta     word_hi

read_next_byte:
        jsr     increment_address
        jsr     read_memory_byte
        sta     word_lo
        rts

read_swi_vector:
        lda     #$fc

read_vector_at_a:
        sta     addr_lo
        lda     #$ff
        sta     addr_hi
        bra     read_mem_word
        lda     #$f8
        bsr     read_vector_at_a
        bsr     restore_addr
        ldx     #inst_next
        jsr     store_address_pair
        lda     #$fa
        bsr     read_vector_at_a
        bsr     restore_addr
        rts

read_stack_byte:
        jsr     stack_addr
        jsr     read_memory_byte
        rts

write_stack_byte:
        jsr     stack_addr
        lda     word_hi
        jsr     write_memory_byte
        rts

load_stack_pc:
        ldx     #$04

load_stack_addr:
        bsr     read_stack_word
        bsr     restore_addr
        rts

write_stack_pc:
        ldx     #$04
        jsr     stack_addr
        lda     word_hi
        jsr     write_memory_byte
        jsr     increment_address
        lda     word_lo
        jsr     write_memory_byte
        rts

save_addr:
        ldx     #word_hi

store_address_pair:
        lda     addr_hi
        and     #$ff
        sta     ,x
        lda     addr_lo
        sta     $01,x
        rts

restore_addr:
        ldx     #word_hi

load_address_pair:
        lda     ,x
        sta     addr_hi
        lda     $01,x
        sta     addr_lo
        rts

clear_breakpoints:
        clrx

clear_addr_slots:
        clr     brk_addr_hi,x
        incx
        cpx     #$0d
        bls     clear_addr_slots
        rts

        .module brk_helpers
_end            .equ    scratch+$32   ; breakpoint range limit

load_breakpoint_address:
        ldx     brk_idx
        inc     brk_idx
        inc     brk_idx
        lda     brk_addr_lo,x
        sta     addr_lo
        lda     brk_addr_hi,x
        sta     addr_hi
        bne     _return
        lda     brk_addr_lo,x

_return:
        rts

find_br_slot:
        lda     #$08

find_address_slot:
        sta     _end
        clrx

_find_slot:
        lda     addr_hi
        cmp     brk_addr_hi,x
        bne     _next_slot
        lda     addr_lo
        cmp     brk_addr_lo,x
        beq     _return

_next_slot:
        incx
        incx
        cpx     _end
        bls     _find_slot
        rts

arm_breaks:
        clrx
        lda     #$08

arm_break_range:
        sta     _end
        stx     brk_idx

_arm_slot:
        bsr     load_breakpoint_address
        beq     _next_arm
        bset    3, map_switch
        jsr     read_memory_byte
        lsrx
        sta     brk_ops,x
        lda     #$83
        jsr     write_memory_byte

_next_arm:
        ldx     brk_idx
        cpx     _end
        bls     _arm_slot
        jmp     resume_user

restore_breaks:
        ldx     #$08
        clra

restore_break_range:
        stx     brk_idx
        sta     _end

_restore_slot:
        bsr     load_breakpoint_address
        beq     _next_restore
        lsrx
        lda     brk_ops,x
        jsr     write_memory_byte

_next_restore:
        lda     brk_idx
        sub     #$04
        sta     brk_idx
        cmp     _end
        bpl     _restore_slot
        rts

        .module decode_inst
_op             .equ    scratch+$33     ; opcode byte
_addr_adj       .equ    scratch+$32     ; target address adjust

decode_inst:
        clr     op_len
        clr     decode_flags
        jsr     read_memory_byte
        sta     _op
        and     #$0f
        tax
        lda     _op
        and     #$f0
        bne     _nonzero_op
        jmp     _set_len2

_nonzero_op:
        cmp     #$10
        beq     _operand_byte
        cmp     #$20
        bne     _decode_20_up
        jmp     _set_len1

_decode_20_up:
        cmp     #$70
        bhi     _decode_80_up
        tstx
        beq     _decode_30_up
        cmp     #$40
        bne     _check_low_nibl
        cpx     #$02
        beq     _len1_addr

_check_low_nibl:
        cpx     #$02
        bls     _bad_opcode
        cpx     #$05
        beq     _bad_opcode
        cpx     #$0b
        beq     _bad_opcode
        cpx     #$0e
        bne     _decode_30_up

_bad_opcode:
        inc     cmd_err
        rts

_decode_30_up:
        cmp     #$30
        beq     _operand_byte
        cmp     #$40
        beq     _set_flag0
        cmp     #$50
        beq     _set_flag1
        bset    3, decode_flags
        cmp     #$60
        beq     _operand_byte
        bra     _len1_addr

_set_flag0:
        bset    0, decode_flags

_set_flag1:
        bset    1, decode_flags
        bra     _len1_addr

_decode_80_up:
        cmp     #$80
        beq     _decode_80
        cmp     #$90
        bne     _decode_a0_up
        cpx     #$06
        bls     _bad_opcode
        cpx     #$0e
        beq     _bad_opcode

_len1_addr:
        lda     #$01
        bra     _add_to_addr

_decode_a0_up:
        cmp     #$a0
        bne     _decode_b0_up
        cpx     #$0d
        beq     _operand_byte
        cpx     #$07
        beq     _bad_opcode
        cpx     #$0c
        beq     _bad_opcode
        cpx     #$0f
        beq     _bad_opcode
        bset    2, decode_flags

_operand_byte:
        bra     _op_from_code

_decode_b0_up:
        cmp     #$b0
        beq     _op_from_code
        cmp     #$c0
        beq     _read_ext_addr
        bset    3, decode_flags
        cmp     #$d0
        beq     _read_ext_addr
        cmp     #$e0
        beq     _op_from_code
        bsr     _is_jmp_jsr
        bne     _len1_addr
        ldx     #$03
        jsr     read_stack_byte
        bra     _clear_word

_decode_80:
        decx
        bmi     _stack_x9
        beq     _stack_x6
        cpx     #$02
        bne     _check_c_d
        jsr     read_swi_vector
        clrx
        bra     _stack_or_zero

_check_c_d:
        cpx     #$0c
        bls     _bad_opcode
        bra     _len1_addr

_stack_x9:
        ldx     #$09
        bra     _load_stack_x

_stack_x6:
        ldx     #$06

_load_stack_x:
        jsr     load_stack_addr
        bra     _save_target_addr

_is_jmp_jsr:
        cpx     #$0c
        beq     _done
        cpx     #$0d

_done:
        rts

_read_ext_addr:
        inc     op_len
        inc     op_len
        bsr     _is_jmp_jsr
        beq     _read_cur_ext
        lda     #$03

_add_to_addr:
        jsr     add_a_to_address

_save_target_addr:
        ldx     #inst_target_hi
        jsr     store_address_pair
        rts

_read_cur_ext:
        clrx
        cmp     #$c0
        beq     _read_next_word
        ldx     #$03

_read_next_word:
        jsr     increment_address
        jsr     read_mem_word

_stack_or_zero:
        clra
        tstx
        beq     _restore_saved_addr
        jsr     read_stack_byte

_restore_saved_addr:
        sta     _addr_adj
        jsr     restore_addr
        lda     _addr_adj
        bra     _add_to_addr

_op_from_code:
        inc     op_len
        bsr     _is_jmp_jsr
        bne     _len2_addr
        cmp     #$a0
        beq     _set_len1
        bhi     _decode_b0_operand

_len2_addr:
        lda     #$02
        bra     _add_to_addr

_decode_b0_operand:
        cmp     #$b0
        bne     _read_next_word_lo
        jsr     read_next_byte

_clear_word:
        clr     word_hi
        clr     word_lo
        bra     _restore_saved_addr

_read_next_word_lo:
        clr     word_hi
        ldx     #$03
        jsr     read_next_byte
        bra     _stack_or_zero

_set_len1:
        lda     #$01
        bra     _set_len

_set_len2:
        lda     #$02

_set_len:
        sta     op_len
        inca
        jsr     add_a_to_address

_save_next_addr:
        ldx     #inst_next
        jsr     store_address_pair

_finish_rel_addr:
        jsr     decrement_address
        jsr     read_memory_byte
        tax
        jsr     increment_address
        txa
        tsta
        bpl     _add_to_addr
        dec     addr_hi
        bra     _add_to_addr

        .module read_command_line
_save_x         .equ    scratch+$33   ; saved X register

_restart:
        jsr     write_crlf

read_command_line:
        lda     #$3e
        jsr     write_console_char
        clrx

_read_char:
        jsr     read_console_char_echo
        cmp     #$18
        beq     _restart
        cmp     #$08
        bne     _store_char
        cpx     #$00
        beq     _skip_back
        decx

_skip_back:
        bra     _read_char

_store_char:
        sta     line_buf,x
        incx
        cpx     #$1e
        beq     _finish_line
        cmp     #$0d
        bne     _read_char

_finish_line:
        lda     #$0d
        sta     line_buf,x
        clr     line_pos
        rts

read_command_char:
        stx     _save_x
        ldx     line_pos
        lda     line_buf,x
        inc     line_pos
        ldx     _save_x
        sta     cmd_char
        rts

uppercase_command_char:
        cmp     #$60
        bls     _return
        sub     #$20
        sta     cmd_char

_return:
        rts

        .module parse_hex_word
_flags          .equ    mon_flags     ; parser control flags
_save_x         .equ    scratch+$33   ; saved X register

parse_hex_word:
        clr     parse_hi
        clr     parse_lo
        jsr     read_command_char
        cmp     #$24
        bne     parse_hex_digit

_next_digit:
        jsr     read_command_char

parse_hex_digit:
        jsr     uppercase_command_char
        clr     hex_digit
        dec     hex_digit
        sub     #$30
        bmi     _finish
        cmp     #$09
        bls     _valid_digit
        sub     #$07
        cmp     #$09
        bls     _finish
        cmp     #$0f
        bhi     _finish

_valid_digit:
        sta     hex_digit
        lda     parse_hi
        ldx     parse_lo
        aslx
        rola
        aslx
        rola
        aslx
        rola
        aslx
        rola
        sta     parse_hi
        txa
        ora     hex_digit
        sta     parse_lo
        ldx     _save_x
        tst     _flags
        bne     _finish
        bra     _next_digit

_finish:
        inc     cmd_args
        rts

        .module cmd_loop
_cmd_idx        .equ    scratch       ; command handler index

_bad_cmd:
        inc     cmd_err

cmd_loop:
        rsp
        jsr     write_crlf
        tst     cmd_err
        beq     _read_line
        ldx     #msg_bad_entry
        jsr     write_string
        jsr     write_crlf
        clr     cmd_err

_read_line:
        jsr     read_command_line
        clr     cmd_args
        clr     _cmd_idx
        ldx     #$ff

_scan_char:
        jsr     read_command_char
        cmp     #$0d
        beq     cmd_loop
        jsr     uppercase_command_char
        incx
        lda     cmd_tokens,x
        beq     _bad_cmd
        and     #$7f
        cmp     cmd_char
        beq     _match_char

_no_match:
        clr     line_pos
        inc     _cmd_idx

_skip_token:
        lda     cmd_tokens,x
        bmi     _scan_char
        incx
        bra     _skip_token

_match_char:
        lda     cmd_tokens,x
        bpl     _scan_char
        jsr     read_command_char
        cmp     #$0d
        beq     _dispatch
        cmp     #$20
        bne     _no_match
        lda     _cmd_idx
        cmp     #$04
        beq     _dispatch

_parse_arg:
        jsr     parse_hex_word
        ldx     cmd_args
        aslx
        cpx     #$0a
        bhi     _bad_cmd
        lda     parse_hi
        sta     cmd_arg_hi,x
        lda     parse_lo
        sta     cmd_arg_lo,x
        lda     cmd_char
        cmp     #$20
        beq     _parse_arg
        cmp     #$0d
        bne     _bad_cmd

_dispatch:
        lda     _cmd_idx
        asla
        tax
        lda     #op_jmp
        sta     cmd_thunk
        lda     cmd_handlers,x
        sta     cmd_thunk+$01
        lda     cmd_handlers+1,x
        sta     cmd_thunk+$02
        jmp     cmd_thunk

; command handler table

        .module cmd_handlers
cmd_handlers:
        .dw     asm_cmd,block_fill_cmd,breakpoint_cmd,go_cmd
        .dw     load_cmd,mem_display_cmd,mem_modify_cmd,nobr_cmd
        .dw     proceed_cmd,reg_display_cmd,reg_modify_cmd,trace_cmd
        .dw     help_cmd

        .module disassemble_line
_mnem           .equ    scratch       ; mnemonic index
_ret_len        .equ    scratch+$02   ; operand count result
_reg_ch         .equ    scratch+$12   ; A/X suffix slot
_mode           .equ    scratch+$2f   ; mode/index temp
_mnem_x         .equ    scratch+$31   ; mnemonic scan index
_tmp            .equ    scratch+$33   ; shared temp byte

disassemble_line:
        ldx     #saved_addr_hi
        jsr     store_address_pair
        jsr     write_crlf
        jsr     write_hex_word_at_73
        lda     #$20
        ldx     #$1d

_clear_line:
        sta     line_buf,x
        decx
        bpl     _clear_line
        jsr     decode_inst
        jsr     load_line_addr
        lda     op_len
        sta     _tmp
        sta     _ret_len
        ldx     #$02
        stx     line_pos

_byte_loop:
        jsr     app_hex_byte
        inc     line_pos
        jsr     increment_address
        dec     _tmp
        bpl     _byte_loop
        jsr     load_line_addr
        tst     cmd_err
        beq     _class_op
        jsr     decrement_address
        inc     op_len
        ldx     #$26
        bra     _to_mnem

_class_op:
        jsr     read_memory_byte
        and     #$0f
        tax
        jsr     read_memory_byte
        cmp     #$0f
        bhi     _chk_10
        sta     _tmp
        ldx     #$17
        stx     line_pos
        jsr     app_comma_dol
        jsr     app_hex_word
        clrx

_set_bit:
        stx     _mode
        ldx     #$12
        stx     line_pos
        lda     _tmp
        brclr   0, _tmp, _bit_arg
        inc     _mode

_bit_arg:
        lsra
        jsr     nibl_ascii
        jsr     app_comma_dol
        jsr     app_next_hex

_br_idx:
        clr     op_len
        ldx     _mode
        ldx     branch_bit_index,x
_to_mnem:
        bra     _store_mnem

_chk_10:
        cmp     #$1f
        bhi     _chk_20
        sub     #$10
        sta     _tmp
        ldx     #$02
        bra     _set_bit

_chk_20:
        cmp     #$2f
        bhi     _chk_30
        txa
        add     #$05
        bra     _set_mode

_chk_30:
        cmp     #$7f
        bhi     _chk_80
        ldx     opcode_30_7f_index,x
        bra     _store_mnem

_chk_80:
        cmp     #$9f
        bhi     _chk_a0
        cmp     #$8f
        bne     _idx_80
        ldx     #$02

_idx_80:
        ldx     opcode_80_9f_index,x
        bra     _store_mnem

_chk_a0:
        cmp     #$ad
        bne     _idx_a0
        lda     #$04

_set_mode:
        sta     _mode
        ldx     #$12
        stx     line_pos
        jsr     app_dol_word
        bra     _br_idx

_idx_a0:
        ldx     opcode_a0_af_index,x

_store_mnem:
        stx     _mnem
        clr     _tmp
        clrx

_scan_mode:
        lda     mnemonic_modes,x
        cmp     #$0f
        bhi     _chk_mnem

_next_mode:
        incx
        bra     _scan_mode

_chk_mnem:
        and     #$0f
        sta     _mode
        lda     _tmp
        cmp     _mnem
        beq     _emit_mnem
        inc     _tmp
        bra     _next_mode

_emit_mnem:
        lda     mnemonic_modes,x
        and     #$0f
        cmp     _mode
        bhi     _prev_ch
        lda     mnemonics,x
        and     #$7f
        stx     _mnem_x
        sta     _tmp
        lda     _mode
        add     #$0c
        tax
        lda     _tmp
        sta     line_buf,x
        dec     _mode
        bmi     _append_reg
        ldx     _mnem_x

_prev_ch:
        decx
        bra     _emit_mnem

_append_reg:
        brset   0, decode_flags, _reg_a
        brclr   1, decode_flags, _op_pos
        lda     #$58
        bra     _store_reg

_reg_a:
        lda     #$41

_store_reg:
        sta     _reg_ch

_op_pos:
        ldx     #$12
        stx     line_pos
        brclr   2, decode_flags, _operand
        lda     #$23
        bsr     app_char

_operand:
        tst     op_len
        beq     _append_index
        bsr     app_dol

_operand_loop:
        jsr     read_next_byte
        dec     op_len
        bmi     _append_index
        beq     _op_byte
        and     #$ff

_op_byte:
        bsr     app_hex_a
        bra     _operand_loop

_append_index:
        brclr   3, decode_flags, _write_line
        lda     #$2c
        bsr     app_char
        lda     #$58
        bsr     app_char

_write_line:
        clrx

_write_loop:
        lda     line_buf,x
        jsr     write_console_char
        incx
        cpx     #$1d
        bls     _write_loop
        ldx     #$0a
        jsr     clear_addr_slots
        clr     cmd_err

        .module load_line_addr
_hex_byte       .equ    scratch+$32     ; byte for hex output

load_line_addr:
        ldx     #saved_addr_hi
        jsr     load_address_pair
        rts

app_next_hex:
        jsr     increment_address

app_hex_byte:
        jsr     read_memory_byte

app_hex_a:
        ldx     line_pos
        sta     _hex_byte
        bsr     app_hi_nibl
        lda     _hex_byte
        and     #$0f
        bra     nibl_ascii

app_hi_nibl:
        lsra
        lsra
        lsra
        lsra

nibl_ascii:
        add     #$30
        cmp     #$39
        bls     app_char
        add     #$07

app_char:
        sta     line_buf,x
        incx
        stx     line_pos
        rts

app_comma_dol:
        lda     #$2c
        bsr     app_char

app_dol:
        lda     #$24
        bsr     app_char
        rts

app_dol_word:
        bsr     app_dol

app_hex_word:
        lda     inst_target_hi
        and     #$ff
        bsr     app_hex_a
        lda     inst_target_lo
        bsr     app_hex_a
        rts

; assembler/disassembler mnemonic index tables

opcode_30_7f_index:
        .byte   $30,$00,$2f,$21,$2e,$00,$35,$04,$2d,$34,$23,$00,$27,$42,$00,$1f

opcode_a0_af_index:
        .byte   $3f,$20,$39,$22,$02,$0f,$2b,$3c,$25,$00,$32,$01,$29,$2a,$2c,$3e

branch_bit_index:
        .byte   $1a,$18,$1b,$06,$1c,$17,$19,$0b,$11,$05,$07,$15,$08,$09,$0a,$16
        .byte   $13,$12,$14,$0e,$0d

opcode_80_9f_index:
        .byte   $37,$38,$44,$40,$00,$00,$00,$41,$1d,$3a,$1e
        .byte   $3b,$36,$31,$3d,$43

        .module asm_cmd
_op             .equ    scratch         ; assembled opcode byte
_mpos           .equ    scratch+$2f     ; mnemonic match position
_mode           .equ    scratch+$31     ; mode/operand temp

asm_cmd:
        dec     cmd_args
        bne     _bad_entry
        clr     asm_once

_show_line:
        jsr     disassemble_line

_again:
        clr     op_len
        jsr     read_command_line
        jsr     read_command_char
        cmp     #$0d
        bne     _parse_mnem

_next_line:
        lda     scratch+$02
        inca
        jsr     add_a_to_address
        bra     _show_line

_parse_mnem:
        cmp     #$2e
        beq     _exit_cmd
        dec     line_pos
        clr     _mpos
        clr     _op
        ldx     #$ff

_mnem_loop:
        jsr     read_command_char
        jsr     uppercase_command_char

_next_mnem:
        incx
        lda     mnemonic_modes,x
        cmp     #$0f
        bls     _check_mode
        and     #$0f
        inc     _op

_check_mode:
        cmp     _mpos
        beq     _got_mnem
        bhi     _next_mnem

_bad_entry:
        inc     cmd_err

_exit_cmd:
        jmp     cmd_loop

_got_mnem:
        lda     mnemonics,x
        beq     _bad_entry
        and     #$7f
        cmp     cmd_char
        bhi     _bad_entry
        bne     _next_mnem
        lda     mnemonics,x
        bmi     _set_mode
        inc     _mpos
        bra     _mnem_loop

_set_mode:
        lda     mnemonic_modes,x
        lsra
        lsra
        lsra
        lsra
        sta     _mode
        ldx     _op
        decx
        lda     opcode_table,x
        sta     _op
        lda     _mode
        cmp     #$04
        bne     _read_suffix
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$41
        beq     _reg_a
        cmp     #$58
        bne     _check_suffix
        lda     #$20
        bra     _add_reg

_reg_a:
        lda     #$10

_add_reg:
        add     _op
        sta     _op
        lda     #$01
        sta     _mode

_read_suffix:
        jsr     read_command_char

_check_suffix:
        cmp     #$2e
        beq     _finish_no_arg
        cmp     #$0d
        bne     _need_space

_finish_no_arg:
        lda     _mode
        deca
        bne     _bad_entry
        dec     line_pos
        bra     _mode_jump

_need_space:
        cmp     #$20
        bne     _bad_entry

_mode_jump:
        lda     _mode
        asla
        add     _mode
        tax

_mode_table:
        jmp     _mode_table,x
        jmp     _read_next_char
        jmp     _bit_then_abs
        jmp     _rel_mode
        jmp     _parse_index
        jmp     _bad_mode
        jmp     _read_comma
        jmp     _imm_or_comma
        bsr     _parse_bit_num
        jsr     parse_hex_word
        tst     parse_hi
        bne     _need_comma
        lda     cmd_char
        cmp     #$2c

_need_comma:
        bne     _bad_jump
        lda     parse_lo
        sta     _mode
        lda     #$02
        bra     _parse_operand

_rel_mode:
        lda     #$01

_parse_operand:
        sta     op_len
        jsr     parse_hex_word
        lda     op_len
        inca
        jsr     add_a_to_address
        lda     parse_hi
        sta     word_hi
        lda     parse_lo
        sta     word_lo
        jsr     address_in_range
        bne     _calc_rel
        lda     word_lo
        jsr     subtract_a_from_address
        lda     word_hi
        sub     addr_hi
        bne     _bad_jump
        lda     addr_lo
        nega
        bmi     _store_operand

_bad_jump:
        jmp     _bad_entry

_calc_rel:
        lda     word_lo
        sub     addr_lo
        sta     addr_lo
        lda     word_hi
        sbc     addr_hi
        bne     _bad_jump
        lda     addr_lo
        bmi     _bad_jump

_store_operand:
        sta     parse_lo
        lda     _mode
        sta     parse_hi
        jmp     _check_end

_bit_then_abs:
        bsr     _parse_bit_num
        jmp     _parse_zp

_parse_bit_num:
        jsr     parse_hex_word
        lda     parse_lo
        and     #$0f
        cmp     #$00
        bcs     _bad_branch
        cmp     #$07
        bhi     _bad_branch
        asla
        add     _op
        sta     _op
        lda     cmd_char
        cmp     #$2c
        bne     _bad_to_entry
        rts

_parse_index:
        jsr     read_command_char
        cmp     #$2c
        bne     _parse_offset
        clra
        bra     _store_mode

_parse_offset:
        inc     op_len
        dec     line_pos
        jsr     parse_hex_word
        tst     parse_hi
        beq     _set_mode10

_bad_branch:
        bra     _bad_to_entry

_read_comma:
        jsr     read_command_char
        bra     _check_comma

_imm_or_comma:
        jsr     read_command_char
        cmp     #$23
        beq     _parse_zp

_check_comma:
        cmp     #$2c
        beq     _set_mode10
        inc     op_len
        dec     line_pos
        jsr     parse_hex_word
        lda     #$10
        tst     parse_hi
        beq     _add_opcode
        inc     op_len
        add     #$10

_add_opcode:
        add     _op
        sta     _op

_set_mode10:
        lda     #$10

_store_mode:
        sta     _mode
        lda     cmd_char
        cmp     #$2c
        bne     _check_end
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$58
        bne     _bad_to_entry
        lda     _mode
        brset   1, op_len, _finish_opcode
        add     #$20
        brset   0, op_len, _finish_opcode
        add     #$20

_finish_opcode:
        add     _op
        sta     _op
        bra     _read_next_char

_dot_suffix:
        dec     asm_once

_read_next_char:
        jsr     read_command_char

_check_end:
        lda     cmd_char
        cmp     #$0d
        beq     _write_bytes
        cmp     #$2e
        beq     _dot_suffix

_bad_to_entry:
        jmp     _bad_entry

_write_bytes:
        jsr     load_line_addr
        lda     _op

_write_loop:
        jsr     write_memory_byte
        jsr     increment_address
        dec     op_len
        bmi     _redisasm
        clrx
        brset   0, op_len, _load_operand
        incx

_load_operand:
        lda     parse_hi,x
        bra     _write_loop

_redisasm:
        jsr     load_line_addr
        jsr     disassemble_line
        tst     asm_once
        bne     _cmd_loop
        jmp     _next_line

_cmd_loop:
        jmp     cmd_loop

_bad_mode:
        bra     _bad_to_entry

_parse_zp:
        jsr     parse_hex_word
        tst     parse_hi
        bne     _bad_to_entry
        dec     line_pos
        inc     op_len
        bra     _read_next_char

; mnemonic text table; high bit marks token end

        .module mnemonics
mnemonics:
        .byte   "AD",('C' | $80)
        .byte   ('D' | $80)
        .byte   "N",('D' | $80)
        .byte   "S",('L' | $80)
        .byte   ('R' | $80)
        .byte   "BC",('C' | $80)
        .byte   "L",('R' | $80)
        .byte   ('S' | $80)
        .byte   "E",('Q' | $80)
        .byte   "HC",('C' | $80)
        .byte   ('S' | $80)
        .byte   ('I' | $80)
        .byte   ('S' | $80)
        .byte   "I",('H' | $80)
        .byte   ('L' | $80)
        .byte   ('T' | $80)
        .byte   "L",('O' | $80)
        .byte   ('S' | $80)
        .byte   "M",('C' | $80)
        .byte   ('I' | $80)
        .byte   ('S' | $80)
        .byte   "N",('E' | $80)
        .byte   "P",('L' | $80)
        .byte   "R",('A' | $80)
        .byte   "CL",('R' | $80)
        .byte   ('N' | $80)
        .byte   "SE",('T' | $80)
        .byte   "SE",('T' | $80)
        .byte   ('R' | $80)
        .byte   "CL",('C' | $80)
        .byte   ('I' | $80)
        .byte   ('R' | $80)
        .byte   "M",('P' | $80)
        .byte   "O",('M' | $80)
        .byte   "P",('X' | $80)
        .byte   "DE",('C' | $80)
        .byte   ('X' | $80)
        .byte   "EO",('R' | $80)
        .byte   "FC",('B' | $80)
        .byte   "IN",('C' | $80)
        .byte   ('X' | $80)
        .byte   "JM",('P' | $80)
        .byte   "S",('R' | $80)
        .byte   "LD",('A' | $80)
        .byte   ('X' | $80)
        .byte   "S",('L' | $80)
        .byte   ('R' | $80)
        .byte   "MU",('L' | $80)
        .byte   "NE",('G' | $80)
        .byte   "O",('P' | $80)
        .byte   "OR",('A' | $80)
        .byte   ('G' | $80)
        .byte   "RO",('L' | $80)
        .byte   ('R' | $80)
        .byte   "S",('P' | $80)
        .byte   "T",('I' | $80)
        .byte   ('S' | $80)
        .byte   "SB",('C' | $80)
        .byte   "E",('C' | $80)
        .byte   ('I' | $80)
        .byte   "T",('A' | $80)
        .byte   "O",('P' | $80)
        .byte   ('X' | $80)
        .byte   "U",('B' | $80)
        .byte   "W",('I' | $80)
        .byte   "TA",('X' | $80)
        .byte   "S",('T' | $80)
        .byte   "X",('A' | $80)
        .byte   "WAI",('T' | $80)
        .byte   $00

; mnemonic addressing-mode table

mnemonic_modes:
        .byte   $00,$01,$72,$72,$01,$72,$01,$42,$42,$00,$01,$32,$02,$23,$32,$01
        .byte   $32,$01,$02,$33,$33,$32,$32,$01,$32,$32,$72,$01,$32,$32,$01,$32
        .byte   $32,$32,$01,$32,$01,$32,$01,$32,$02,$03,$84,$32,$02,$03,$84,$01
        .byte   $02,$23,$32,$00,$01,$12,$12,$42,$01,$72,$01,$42,$01,$72,$00,$01
        .byte   $42,$12,$00,$01,$72,$00,$01,$52,$00,$01,$42,$12,$00,$01,$62,$01
        .byte   $62,$00,$01,$72,$72,$01,$42,$42,$00,$01,$12,$00,$01,$42,$01,$12
        .byte   $00,$01,$72,$52,$00,$01,$42,$42,$01,$12,$01,$12,$12,$00,$01,$72
        .byte   $01,$12,$12,$01,$62,$02,$13,$62,$01,$72,$01,$12,$00,$01,$12,$01
        .byte   $42,$01,$12,$00,$01,$02,$13,$00

; opcode table

opcode_table:
        .byte   $a9,$ab,$a4,$38,$37,$24,$11,$25,$27,$28,$29,$22,$24,$2f,$2e,$a5
        .byte   $25,$23,$2c,$2b,$2d,$26,$2a,$20,$01,$21,$00,$10,$ad,$98,$9a,$3f
        .byte   $a1,$33,$a3,$3a,$5a,$a8,$01,$3c,$5c,$ac,$ad,$a6,$ae,$38,$34,$42
        .byte   $30,$9d,$aa,$00,$39,$36,$9c,$80,$81,$a2,$99,$9b,$a7,$8e,$af,$a0
        .byte   $83,$97,$3d,$9f,$8f

        .module exec_cmds
_save_lo        .equ    word_lo       ; saved addr low byte

breakpoint_cmd:
        dec     cmd_args
        bmi     _show_brks
        jsr     clear_breakpoints
        clrx

_save_brk:
        lda     addr_hi,x
        sta     brk_addr_hi,x
        lda     addr_lo,x
        sta     brk_addr_lo,x
        incx
        incx
        dec     cmd_args
        bpl     _save_brk

_show_brks:
        jsr     write_crlf
        ldx     #msg_brkpt
        jsr     write_string
        lda     #$73
        jsr     write_console_char
        lda     #$3d
        jsr     write_console_char
        clr     brk_idx

_disp_brk:
        jsr     load_breakpoint_address
        beq     _next_brk
        jsr     write_hex_word_at_73
        ldx     #msg_sp4
        jsr     write_string

_next_brk:
        ldx     brk_idx
        cpx     #$08
        bls     _disp_brk

_cmd_loop:
        jmp     cmd_loop

_bad_brk:
        inc     cmd_err
        bra     _cmd_loop

nobr_cmd:
        dec     cmd_args
        bmi     _clear_brks
        bne     _bad_brk
        jsr     find_br_slot
        bne     _bad_brk
        clr     brk_addr_hi,x
        clr     brk_addr_lo,x
        bra     _show_brks

_clear_brks:
        jsr     clear_breakpoints
        bra     _show_brks

go_cmd:
        dec     cmd_args
        bmi     _go_saved_pc
        bne     _bad_run
        jsr     save_addr
        ldx     #$04
        jsr     write_stack_byte
        jsr     increment_address
        lda     _save_lo
        jsr     write_memory_byte

_go_saved_pc:
        jsr     load_stack_pc
        jsr     find_br_slot
        beq     step_over_brk
        jmp     arm_breaks

step_over_brk:
        inc     step_flag

arm_step_breaks:
        bset    4, map_switch
        jsr     load_stack_pc
        jsr     decode_inst
        tst     cmd_err
        bne     _bad_run
        ldx     #$0a
        lda     #$0c
        jmp     arm_break_range

proceed_cmd:
        ldx     cmd_args
        decx
        bmi     _def_proceed
        bne     _bad_run
        ldx     addr_lo

_set_proceed:
        stx     proceed_cnt
        beq     _bad_run
        jsr     load_stack_pc
        ldx     #saved_addr_hi
        jsr     store_address_pair
        jsr     find_br_slot
        beq     step_over_brk

_bad_run:
        inc     cmd_err
        clr     proceed_cnt
        jmp     cmd_loop

_def_proceed:
        incx
        incx
        bra     _set_proceed

trace_cmd:
        ldx     cmd_args
        decx
        bmi     _def_trace
        bne     _bad_run
        ldx     addr_lo

_set_trace:
        stx     trace_cnt
        beq     _bad_run
        bra     arm_step_breaks

_def_trace:
        incx
        incx
        bra     _set_trace

        .module mem_display_cmd
_col            .equ    scratch+$2f     ; display column count

mem_display_cmd:
        ldx     cmd_args
        decx
        bmi     _bad_cmd
        decx
        beq     _display_loop
        bpl     _bad_cmd
        jsr     save_addr

_display_loop:
        jsr     address_in_range
        beq     _done
        clr     line_pos
        clr     _col
        jsr     write_crlf
        jsr     write_hex_word_at_73
        ldx     #msg_sp4
        jsr     write_string

_byte_loop:
        bsr     _check_pause
        jsr     read_memory_byte
        tsta
        bmi     _dot_char
        cmp     #$20
        bcs     _dot_char
        cmp     #$7f
        bcs     _save_char

_dot_char:
        lda     #$2e

_save_char:
        ldx     line_pos
        jsr     app_char
        jsr     read_memory_byte
        jsr     write_hex_byte
        lda     #$20
        jsr     write_console_char
        jsr     increment_address
        inc     _col
        brclr   4, _col, _byte_loop
        ldx     #msg_sp3
        jsr     write_string
        clrx

_ascii_loop:
        bsr     _check_pause
        lda     line_buf,x
        jsr     write_console_char
        incx
        cpx     #$0f
        bls     _ascii_loop
        bra     _display_loop

_bad_cmd:
        inc     cmd_err

_done:
        jmp     cmd_loop

_check_pause:
        jsr     sub_0800
        tst     poll_flag
        beq     _return
        clr     poll_flag
        lda     acia_rdra
        and     #$7f
        cmp     #$13
        bne     _check_cancel

_wait_resume:
        jsr     sub_0800
        ldx     acia_isra
        stx     io_stat
        brclr   0, io_stat, _wait_resume
        lda     acia_rdra
        and     #$7f

_check_cancel:
        cmp     #$18
        beq     cmd_exit

_return:
        rts

        .module reg_display_cmd
reg_display_cmd:
        jsr     write_crlf
        ldx     #$20

show_msg_regs:
        jsr     display_regs_msg

cmd_exit:
        jmp     cmd_loop
        inc     cmd_err
        bra     cmd_exit

        .module modify_value
modify_value:
        jsr     write_eq_value
        jsr     read_command_line
        jsr     parse_hex_word
        dec     line_pos
        beq     step_modify
        clrx

_scan_chars:
        lda     _modify_chars,x
        beq     _bad_cmd
        incx
        cmp     cmd_char
        bne     _scan_chars
        lda     parse_lo
        jsr     write_memory_byte
        tst     mod_len
        beq     step_modify
        jsr     decrement_address
        lda     parse_hi
        jsr     write_memory_byte
        jsr     increment_address

step_modify:
        ldx     mod_idx
        lda     cmd_char
        cmp     #$3d
        beq     _eq_addr
        cmp     #$5e
        beq     _prev_addr
        cmp     #$0d
        beq     _next_addr
        cmp     #$2e
        beq     _return_char

_bad_cmd:
        inc     cmd_err

_return_char:
        lda     cmd_char
        rts

_prev_addr:
        jsr     decrement_address
        decx
        bpl     _return_char
        ldx     #$04
        bra     _return_char

_next_addr:
        jsr     increment_address
        incx
        cpx     #$04
        bls     _return_char
        clrx
        bra     _return_char

_eq_addr:
        tst     mod_len
        beq     _return_char
        jsr     decrement_address
        bra     _return_char

_modify_chars:
        .byte   "^=.",$0d,$00

        .module mem_modify_cmd
_fill_byte      .equ    scratch+$27   ; fill byte argument

mem_modify_cmd:
        dec     cmd_args
        bne     _bad_cmd
        clr     mod_len

_mem_loop:
        jsr     write_crlf
        jsr     write_hex_word_at_73
        bsr     modify_value
        tst     cmd_err
        bne     _cmd_exit
        cmp     #$2e
        bne     _mem_loop
        bra     _cmd_exit

reg_modify_cmd:
        ldx     cmd_args
        bne     _bad_cmd

_reg_loop:
        stx     mod_idx
        jsr     stack_addr
        tstx
        bne     _reg_value
        jsr     write_crlf
        jsr     write_sp
        bsr     step_modify
        bra     _reg_loop

_reg_value:
        cpx     #$04
        beq     _save_reg_len
        clrx

_save_reg_len:
        stx     mod_len
        jsr     write_crlf
        ldx     mod_idx
        lda     register_fields,x
        jsr     select_reg_addr
        jsr     write_console_char
        jsr     modify_value
        tst     cmd_err
        bne     _cmd_exit
        cmp     #$2e
        bne     _reg_loop
        bra     _cmd_exit

block_fill_cmd:
        ldx     cmd_args
        cpx     #$03
        bne     _bad_cmd

_fill_loop:
        jsr     address_in_range
        beq     _cmd_exit
        lda     _fill_byte
        jsr     write_memory_byte
        jsr     increment_address
        bra     _fill_loop

_bad_cmd:
        inc     cmd_err

_cmd_exit:
        jmp     cmd_loop

        .module load_cmd
_s9_flag        .equ    scratch+$57     ; S9/end record flag
_rec_cnt        .equ    scratch+$2f     ; S-record byte count
_rec_sum        .equ    scratch+$2f     ; checksum compare save

_bad_cmd:
        inc     cmd_err
        jmp     cmd_loop

load_cmd:
        jsr     write_crlf
        lda     cmd_char
        cmp     #$0d
        beq     _bad_cmd
        cmp     #$20
        bne     _bad_cmd
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$54
        bne     _bad_cmd
        bset    0, mon_flags
        bra     _init_srec

_init_srec:
        clr     _s9_flag

_wait_srec:
        jsr     read_console_char_echo
        cmp     #$53
        bne     _wait_srec
        jsr     read_console_char_echo
        cmp     #$39
        beq     _s9_record
        cmp     #$31
        bne     _wait_srec
        bra     _read_record

_s9_record:
        inc     _s9_flag

_read_record:
        clr     checksum
        bsr     _read_srec_byte
        sub     #$03
        sta     _rec_cnt
        bsr     _read_srec_byte
        sta     addr_hi
        bsr     _read_srec_byte
        sta     addr_lo

_data_loop:
        dec     _rec_cnt
        bmi     _checksum
        bsr     _read_srec_byte
        jsr     write_memory_byte
        jsr     increment_address
        bra     _data_loop

_checksum:
        ldx     checksum
        stx     _rec_sum
        bsr     _read_srec_byte
        tst     _s9_flag
        bne     _done
        coma
        cmp     _rec_sum
        beq     _wait_srec

_bad_srec:
        inc     cmd_err

_done:
        clr     mon_flags
        jmp     cmd_loop

_read_srec_byte:
        clr     parse_lo
        bsr     _read_srec_nibl
        bsr     _read_srec_nibl
        add     checksum
        sta     checksum
        lda     parse_lo
        rts

_read_srec_nibl:
        jsr     read_console_char_echo
        jsr     parse_hex_digit
        tst     hex_digit
        bmi     _bad_srec
        rts

        .module resume_user
resume_user:
        lda     user_sp

_resume_sp:
        bclr    7, map_switch
        cmp     #$ff
        bne     _check_sp
        bset    0, map_switch
        rti

_check_sp:
        bit     #$01
        bne     _push_pc
        add     #$03
        bset    7, map_switch
        swi

_push_pc:
        bsr     _resume_plus2

_resume_plus2:
        add     #$02
        bra     _resume_sp
        inc     cmd_err
        jmp     cmd_loop

resume_from_swi:
        bra     _resume_plus2

reset_handler:
        lda     #$ff
        sta     scratch+$5e
        clr     map_switch
        bset    2, map_switch
        lda     #$fa
        sta     user_sp
        clr     addr_hi
        add     #$01
        sta     addr_lo
        lda     #$e8
        jsr     write_memory_byte
        clr     mon_flags
        clr     poll_flag
        jsr     clear_breakpoints
        lda     #$ff

_reset_delay:
        deca
        bne     _reset_delay
        lda     #$0c
        sta     serial_ctl
        jsr     init_serial_or_timer
        clrx
        jsr     write_crlf

enter_monitor:
        bclr    1, mon_flags
        clr     proceed_cnt
        clr     cmd_err
        clr     trace_cnt
        clr     step_flag
        clr     map_switch
        bset    2, map_switch
        jmp     show_msg_regs

init_serial_or_timer:
        lda     acia_csra
        ora     #$80
        sta     acia_cra
        lda     #$e0
        sta     acia_fra
        lda     acia_csra
        and     #$7f
        sta     acia_cra
        lda     #$40
        tax
        ora     serial_ctl
        sta     acia_cra
        rts

        .module swi_handler
_stk_idx        .equ    scratch+$31     ; stack copy index

swi_handler:
        bclr    0, map_switch
        brset   7, map_switch, resume_from_swi
        lda     acia_isrb
        deca
        sta     user_sp
        rsp
        jsr     load_stack_pc
        jsr     decrement_address
        jsr     save_addr
        lda     #$0c
        jsr     find_address_slot
        beq     _breaks_ready
        jsr     read_memory_byte
        cmp     #$83
        beq     _adjust_swi_stack
        bset    5, map_switch

_breaks_ready:
        brclr   4, map_switch, _restore_trace
        ldx     #$0c
        lda     #$0a
        jsr     restore_break_range
        ldx     #$0a
        jsr     clear_addr_slots
        bclr    3, map_switch

_restore_trace:
        brclr   3, map_switch, _restore_user_pc
        jsr     restore_breaks

_restore_user_pc:
        jsr     write_stack_pc
        jsr     restore_addr
        brset   5, map_switch, _step_break
        clr     map_switch
        bset    2, map_switch
        jsr     find_br_slot
        bne     _trace_break
        lda     proceed_cnt
        sub     #$01
        bcs     _show_break
        lda     saved_addr_hi
        cmp     addr_hi
        bne     _check_break_count
        lda     saved_addr_lo
        cmp     addr_lo
        bne     _check_break_count
        dec     proceed_cnt

_check_break_count:
        tst     proceed_cnt
        bne     _resume_display

_show_break:
        ldx     #$14
        jsr     write_crlf

_reset_msg:
        jmp     enter_monitor

_trace_break:
        tst     step_flag
        bne     _run_armed_breaks
        lda     trace_cnt
        sub     #$01
        bcs     _show_trace
        bne     _step_trace

_show_trace:
        jsr     disassemble_line
        ldx     #$13
        bra     _reset_msg

_run_armed_breaks:
        clr     step_flag
        jmp     arm_breaks

_step_trace:
        dec     trace_cnt
        jsr     disassemble_line
        jsr     display_regs
        jmp     arm_step_breaks

_resume_display:
        jmp     step_over_brk

_step_break:
        jsr     init_serial_or_timer
        jsr     write_crlf
        ldx     #$1a
        bra     _reset_msg

_adjust_swi_stack:
        lda     user_sp
        sub     #$05
        sta     user_sp
        ldx     #$06

_copy_stack_byte:
        stx     _stk_idx
        jsr     read_stack_byte
        sta     word_hi
        txa
        sub     #$05
        tax
        jsr     write_stack_byte
        ldx     _stk_idx
        incx
        cpx     #$08
        bls     _copy_stack_byte
        jsr     read_swi_vector
        jsr     write_stack_pc
        jmp     resume_user
        inc     cmd_err
        jmp     cmd_loop

        .module help_cmd
help_cmd:
        clrx
        jsr     write_crlf
        jsr     write_crlf

_intro_loop:
        lda     help_intro,x
        beq     _brk
        jsr     write_console_char
        incx
        bra     _intro_loop

_brk:
        clrx
        jsr     write_crlf

_brk_loop:
        lda     help_breakpoint,x
        beq     _go_load_md
        jsr     write_console_char
        incx
        bra     _brk_loop

_go_load_md:
        clrx
        jsr     write_crlf

_go_load_md_loop:
        lda     help_go_load_md,x
        beq     _mod_nobr_proc
        jsr     write_console_char
        incx
        bra     _go_load_md_loop

_mod_nobr_proc:
        clrx
        jsr     write_crlf

_mod_nobr_proc_loop:
        lda     help_modify_nobr_proceed,x
        beq     _reg_trace
        jsr     write_console_char
        incx
        bra     _mod_nobr_proc_loop

_reg_trace:
        clrx
        jsr     write_crlf

_reg_trace_loop:
        lda     help_register_trace,x
        beq     _done
        jsr     write_console_char
        incx
        bra     _reg_trace_loop

_done:
        jmp     cmd_loop

; command token table; high bit marks token end

cmd_tokens:
        .byte   "AS",('M' | $80)
        .byte   "B",('F' | $80)
        .byte   "B",('R' | $80)
        .byte   ('G' | $80)
        .byte   "LOA",('D' | $80)
        .byte   "M",('D' | $80)
        .byte   "M",('M' | $80)
        .byte   "NOB",('R' | $80)
        .byte   ('P' | $80)
        .byte   "R",('D' | $80)
        .byte   "R",('M' | $80)
        .byte   ('T' | $80)
        .byte   "HEL",('P' | $80)
        .byte   $00

; banner text

message_text:
msg_banner  .equ    ($ - message_text)
        .byte   "EVSbug-HC05 REV 1.2",$00
msg_brkpt  .equ    ($ - message_text)
        .byte   "Brkpt",$00
msg_abort  .equ    ($ - message_text)
        .byte   "Abort",$00
msg_regs  .equ    ($ - message_text)
        .byte   "Regs ",$00
msg_bad_entry  .equ    ($ - message_text)
        .byte   "ILLEGAL/INSUFFICIENT ENTRY",$00
msg_sp4  .equ    ($ - message_text)
        .byte   " "
msg_sp3  .equ    ($ - message_text)
        .byte   "   ",$00

; help text

help_intro:
        .byte   "BREAK = Abort command, ",$0d,$0a
        .byte   "CTRL-S = Freeze screen, CTRL-X = Cancel command line",$0d,$0a
        .byte   "ASM <START ADDR>- Assembler/disassembler",$0d,$0a
        .byte   "BF <START ADDR> <END ADDR> <DATA>- Block fill memory",$00

help_breakpoint:
        .byte   "BR [<ADDR1 - ADDR5>]- Set 1 to 5 breakpoints",$00

help_go_load_md:
        .byte   "G [<START ADDR>]- Execute user program",$0d,$0a
        .byte   "LOAD T - Download from port to memory",$0d,$0a
        .byte   "MD <START ADDR> [<END ADDR>]- Display memory",$00

help_modify_nobr_proceed:
        .byte   "MM <ADDRESS>- Modify memory",$0d,$0a
        .byte   "NOBR [<ADDR1 - ADDR5>]- Remove breakpoints",$0d,$0a
        .byte   "P [<COUNT>]- Proceed 1-FF times through a breakpoint",$0d,$0a
        .byte   "RD- Register display",$00

help_register_trace:
        .byte   "RM- Register modify",$0d,$0a
        .byte   "T [<COUNT>]- Trace 1-FF instructions",$00

; padding and interrupt vectors
        .dw     (int_vecs - $)
        .org    int_vecs
        .dw     reset_handler              ; Reserved
        .dw     reset_handler              ; Wait timer erratum mirror
        .dw     reset_handler              ; Reserved
        .dw     reset_handler              ; Timer from wait state
        .dw     reset_handler              ; Timer
        .dw     reset_handler              ; External interrupt
        .dw     swi_handler                ; Software interrupt
        .dw     reset_handler              ; Reset
        .end
