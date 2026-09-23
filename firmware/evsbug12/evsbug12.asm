        .msfirst

acia_isra       .equ    $20
acia_iera       .equ    acia_isra
acia_csra       .equ    $21
acia_cra        .equ    acia_csra
acia_fra        .equ    acia_csra
acia_cdra       .equ    $22
acia_acra       .equ    acia_cdra
acia_rdra       .equ    $23
acia_tdra       .equ    acia_rdra
acia_isrb       .equ    $24
acia_ierb       .equ    acia_isrb
acia_csrb       .equ    $25
acia_crb        .equ    acia_csrb
acia_frb        .equ    acia_csrb
acia_cdrb       .equ    $26
acia_acrb       .equ    acia_cdrb
acia_rdrb       .equ    $27
acia_tdrb       .equ    acia_rdrb
map_switch      .equ    $50
scratch         .equ    $51
cmd_thunk       .equ    $9c
int_vecs        .equ    $1ff0

op_bset1        .equ    $12
op_jmp          .equ    $cc

        .org    $0000
        .byte   $00
        .org    $0800
sub_0800:
        sta     scratch+$5d
        lda     #$00
        sta     $fff0
        lda     scratch+$5d
        rts
read_console_char_echo:
        stx     scratch+$59
        jsr     sub_0800
        ldx     $ffe1
        stx     scratch+$60
        brset   2, scratch+$60, $850
        ldx     $ffe0
        stx     scratch+$60
        brclr   0, scratch+$60, $80c
        lda     $ffe3
        and     #$7f
        bra     $834
write_console_char:
        stx     scratch+$59
        ldx     $ffe0
        stx     scratch+$60
        brclr   0, scratch+$60, $834
        ldx     #$ff
        stx     scratch+$5c
        sta     $ffe3
        brset   1, scratch+$52, $84d
        jsr     sub_0800
        ldx     $ffe0
        stx     scratch+$60
        brclr   6, scratch+$60, $83a
        ldx     $ffe1
        stx     scratch+$60
        brset   2, scratch+$60, $850
        ldx     scratch+$59
        rts
        lda     $ffe3
        jsr     init_serial_or_timer
        clr     scratch+$52
        jmp     cmd_loop
write_hex_byte:
        sta     scratch+$33
        add     scratch+$56
        sta     scratch+$56
        lda     scratch+$33
        bsr     write_hi_nibl
        lda     scratch+$33
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
        bls     $877
        add     #$07
        jsr     write_console_char
        rts
write_hex_word_at_73:
        lda     scratch+$22
        and     #$ff
        jsr     write_hex_byte
        lda     scratch+$23
        jsr     write_hex_byte
        rts
write_eq_value:
        lda     #$3d
        jsr     write_console_char
        jsr     read_memory_byte
        tst     scratch+$31
        beq     $89f
        and     #$ff
        jsr     write_hex_byte
        jsr     increment_address
        jsr     read_memory_byte
        jsr     write_hex_byte
        rts
write_string:
        lda     message_text,x
        beq     $8a2
        jsr     write_console_char
        incx
        bra     $8a3
display_regs_msg:
        jsr     write_string
display_regs:
        jsr     write_crlf
        clrx
        jsr     stack_addr
        clr     scratch+$31
        jsr     write_sp
        incx
        stx     scratch+$33
        ldx     #msg_sp4
        jsr     write_string
        ldx     scratch+$33
        lda     register_fields,x
        beq     $932
        bsr     select_reg_addr
        jsr     write_console_char
        jsr     write_eq_value
        bra     $8bd
write_sp:
        lda     #$53
        jsr     write_console_char
        lda     #$3d
        jsr     write_console_char
        lda     scratch+$23
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
select_reg_addr:
        stx     scratch+$33
        tax
        lda     scratch+$53
        clr     scratch+$31
        clr     scratch+$22
        cpx     #$50
        bne     $91a
        inc     scratch+$31
        add     #$04
        cpx     #$58
        bne     $920
        add     #$03
        cpx     #$41
        bne     $926
        add     #$02
        cpx     #$43
        bne     $92c
        add     #$01
        sta     scratch+$23
        txa
        ldx     scratch+$33
        rts
        ldx     #msg_sp4
        jsr     write_string
        lda     scratch+$53
        add     #$01
        sta     scratch+$23
        clr     scratch+$22
        jsr     read_memory_byte
        sta     scratch+$33
        ldx     #$ff
        lda     #$08
        sta     scratch+$31
        incx
        lda     #$2e
        asl     scratch+$33
        bcc     $954
        lda     condition_bits,x
        jsr     write_console_char
        dec     scratch+$31
        bne     $94a
        rts
write_memory_byte:
        sta     scratch+$33
        jsr     sub_0800
        lda     #$c7
        bra     $96a
read_memory_byte:
        lda     #$c6
        jsr     sub_0800
        bclr    2, map_switch
        sta     cmd_thunk+$02
        lda     #op_bset1
        sta     cmd_thunk
        lda     #$50
        sta     cmd_thunk+$01
        lda     scratch+$22
        sta     cmd_thunk+$03
        lda     scratch+$23
        sta     cmd_thunk+$04
        lda     #$81
        sta     cmd_thunk+$05
        lda     scratch+$33
        jsr     cmd_thunk
        bclr    1, map_switch
        bset    2, map_switch
        rts
increment_address:
        lda     #$01
add_a_to_address:
        add     scratch+$23
        sta     scratch+$23
        clra
        adc     scratch+$22
        sta     scratch+$22
        rts
decrement_address:
        lda     #$01
subtract_a_from_address:
        sta     scratch+$33
        lda     scratch+$23
        sub     scratch+$33
        sta     scratch+$23
        lda     scratch+$22
        sbc     #$00
        bra     $994
address_in_range:
        lda     scratch+$24
        cmp     scratch+$22
        bcs     $9b8
        bhi     $9b7
        lda     scratch+$25
        cmp     scratch+$23
        bcs     $9b8
        lda     #$01
        rts
        clra
        bra     $9b7
stack_addr:
        clr     scratch+$22
        lda     scratch+$53
        sta     scratch+$23
        txa
        jsr     add_a_to_address
        rts
read_stack_word:
        jsr     stack_addr
read_mem_word:
        jsr     read_memory_byte
        and     #$ff
        sta     scratch+$24
read_next_byte:
        jsr     increment_address
        jsr     read_memory_byte
        sta     scratch+$25
        rts
read_swi_vector:
        lda     #$fc
read_vector_at_a:
        sta     scratch+$23
        lda     #$ff
        sta     scratch+$22
        bra     read_mem_word
        lda     #$f8
        bsr     read_vector_at_a
        bsr     restore_addr
        ldx     #scratch+$40
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
        lda     scratch+$24
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
        lda     scratch+$24
        jsr     write_memory_byte
        jsr     increment_address
        lda     scratch+$25
        jsr     write_memory_byte
        rts
save_addr:
        ldx     #scratch+$24
store_address_pair:
        lda     scratch+$22
        and     #$ff
        sta     ,x
        lda     scratch+$23
        sta     $01,x
        rts
restore_addr:
        ldx     #scratch+$24
load_address_pair:
        lda     ,x
        sta     scratch+$22
        lda     $01,x
        sta     scratch+$23
        rts
clear_breakpoints:
        clrx
clear_addr_slots:
        clr     scratch+$34,x
        incx
        cpx     #$0d
        bls     clear_addr_slots
        rts
load_breakpoint_address:
        ldx     scratch+$31
        inc     scratch+$31
        inc     scratch+$31
        lda     scratch+$35,x
        sta     scratch+$23
        lda     scratch+$34,x
        sta     scratch+$22
        bne     $a50
        lda     scratch+$35,x
        rts
find_br_slot:
        lda     #$08
find_address_slot:
        sta     scratch+$32
        clrx
        lda     scratch+$22
        cmp     scratch+$34,x
        bne     $a62
        lda     scratch+$23
        cmp     scratch+$35,x
        beq     $a50
        incx
        incx
        cpx     scratch+$32
        bls     $a56
        rts
arm_breaks:
        clrx
        lda     #$08
arm_break_range:
        sta     scratch+$32
        stx     scratch+$31
        bsr     load_breakpoint_address
        beq     $a81
        bset    3, map_switch
        jsr     read_memory_byte
        lsrx
        sta     scratch+$42,x
        lda     #$83
        jsr     write_memory_byte
        ldx     scratch+$31
        cpx     scratch+$32
        bls     $a70
        jmp     resume_user
restore_breaks:
        ldx     #$08
        clra
restore_break_range:
        stx     scratch+$31
        sta     scratch+$32
        bsr     load_breakpoint_address
        beq     $a9b
        lsrx
        lda     scratch+$42,x
        jsr     write_memory_byte
        lda     scratch+$31
        sub     #$04
        sta     scratch+$31
        cmp     scratch+$32
        bpl     $a91
        rts
        .module decode_inst
decode_inst:
        clr     scratch+$57
        clr     scratch+$58
        jsr     read_memory_byte
        sta     scratch+$33
        and     #$0f
        tax
        lda     scratch+$33
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
        inc     scratch+$01
        rts
_decode_30_up:
        cmp     #$30
        beq     _operand_byte
        cmp     #$40
        beq     _set_flag0
        cmp     #$50
        beq     _set_flag1
        bset    3, scratch+$58
        cmp     #$60
        beq     _operand_byte
        bra     _len1_addr
_set_flag0:
        bset    0, scratch+$58
_set_flag1:
        bset    1, scratch+$58
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
        bset    2, scratch+$58
_operand_byte:
        bra     _op_from_code
_decode_b0_up:
        cmp     #$b0
        beq     _op_from_code
        cmp     #$c0
        beq     _read_ext_addr
        bset    3, scratch+$58
        cmp     #$d0
        beq     _read_ext_addr
        cmp     #$e0
        beq     _op_from_code
        bsr     is_jmp_jsr
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
is_jmp_jsr:
        cpx     #$0c
        beq     _done
        cpx     #$0d
_done:
        rts
_read_ext_addr:
        inc     scratch+$57
        inc     scratch+$57
        bsr     is_jmp_jsr
        beq     _read_cur_ext
        lda     #$03
_add_to_addr:
        jsr     add_a_to_address
_save_target_addr:
        ldx     #scratch+$3e
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
        sta     scratch+$32
        jsr     restore_addr
        lda     scratch+$32
        bra     _add_to_addr
_op_from_code:
        inc     scratch+$57
        bsr     is_jmp_jsr
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
        clr     scratch+$24
        clr     scratch+$25
        bra     _restore_saved_addr
_read_next_word_lo:
        clr     scratch+$24
        ldx     #$03
        jsr     read_next_byte
        bra     _stack_or_zero
_set_len1:
        lda     #$01
        bra     _set_len
_set_len2:
        lda     #$02
_set_len:
        sta     scratch+$57
        inca
        jsr     add_a_to_address
_save_next_addr:
        ldx     #scratch+$40
        jsr     store_address_pair
_finish_rel_addr:
        jsr     decrement_address
        jsr     read_memory_byte
        tax
        jsr     increment_address
        txa
        tsta
        bpl     _add_to_addr
        dec     scratch+$22
        bra     _add_to_addr
        .module read_command_line
        jsr     write_crlf
read_command_line:
        lda     #$3e
        jsr     write_console_char
        clrx
        jsr     read_console_char_echo
        cmp     #$18
        beq     $beb
        cmp     #$08
        bne     $c06
        cpx     #$00
        beq     $c04
        decx
        bra     $bf4
        sta     scratch+$03,x
        incx
        cpx     #$1e
        beq     $c11
        cmp     #$0d
        bne     $bf4
        lda     #$0d
        sta     scratch+$03,x
        clr     scratch+$2e
        rts
read_command_char:
        stx     scratch+$33
        ldx     scratch+$2e
        lda     scratch+$03,x
        inc     scratch+$2e
        ldx     scratch+$33
        sta     scratch+$32
        rts
uppercase_command_char:
        cmp     #$60
        bls     $c2d
        sub     #$20
        sta     scratch+$32
        rts
parse_hex_word:
        clr     scratch+$2c
        clr     scratch+$2d
        jsr     read_command_char
        cmp     #$24
        bne     $c3c
        jsr     read_command_char
parse_hex_digit:
        jsr     uppercase_command_char
        clr     scratch+$59
        dec     scratch+$59
        sub     #$30
        bmi     $c72
        cmp     #$09
        bls     $c55
        sub     #$07
        cmp     #$09
        bls     $c72
        cmp     #$0f
        bhi     $c72
        sta     scratch+$59
        lda     scratch+$2c
        ldx     scratch+$2d
        aslx
        rola
        aslx
        rola
        aslx
        rola
        aslx
        rola
        sta     scratch+$2c
        txa
        ora     scratch+$59
        sta     scratch+$2d
        ldx     scratch+$33
        tst     scratch+$52
        bne     $c72
        bra     $c39
        inc     scratch+$02
        rts

        .module cmd_loop
_bad_cmd:
        inc     scratch+$01
cmd_loop:
        rsp
        jsr     write_crlf
        tst     scratch+$01
        beq     _read_line
        ldx     #msg_bad_entry
        jsr     write_string
        jsr     write_crlf
        clr     scratch+$01
_read_line:
        jsr     read_command_line
        clr     scratch+$02
        clr     scratch
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
        cmp     scratch+$32
        beq     _match_char
_no_match:
        clr     scratch+$2e
        inc     scratch
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
        lda     scratch
        cmp     #$04
        beq     _dispatch
_parse_arg:
        jsr     parse_hex_word
        ldx     scratch+$02
        aslx
        cpx     #$0a
        bhi     _bad_cmd
        lda     scratch+$2c
        sta     scratch+$20,x
        lda     scratch+$2d
        sta     scratch+$21,x
        lda     scratch+$32
        cmp     #$20
        beq     _parse_arg
        cmp     #$0d
        bne     _bad_cmd
_dispatch:
        lda     scratch
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
disassemble_line:
        ldx     #scratch+$54
        jsr     store_address_pair
        jsr     write_crlf
        jsr     write_hex_word_at_73
        lda     #$20
        ldx     #$1d
        sta     scratch+$03,x
        decx
        bpl     $d23
        jsr     decode_inst
        jsr     load_line_addr
        lda     scratch+$57
        sta     scratch+$33
        sta     scratch+$02
        ldx     #$02
        stx     scratch+$2e
        jsr     app_hex_byte
        inc     scratch+$2e
        jsr     increment_address
        dec     scratch+$33
        bpl     $d38
        jsr     load_line_addr
        tst     scratch+$01
        beq     $d54
        jsr     decrement_address
        inc     scratch+$57
        ldx     #$26
        bra     $d8c
        jsr     read_memory_byte
        and     #$0f
        tax
        jsr     read_memory_byte
        cmp     #$0f
        bhi     $d8e
        sta     scratch+$33
        ldx     #$17
        stx     scratch+$2e
        jsr     app_comma_dol
        jsr     app_hex_word
        clrx
        stx     scratch+$2f
        ldx     #$12
        stx     scratch+$2e
        lda     scratch+$33
        brclr   0, scratch+$33, $d7b
        inc     scratch+$2f
        lsra
        jsr     nibl_ascii
        jsr     app_comma_dol
        jsr     app_next_hex
        clr     scratch+$57
        ldx     scratch+$2f
        ldx     branch_bit_index,x
        bra     $dcf
        cmp     #$1f
        bhi     $d9a
        sub     #$10
        sta     scratch+$33
        ldx     #$02
        bra     $d6e
        cmp     #$2f
        bhi     $da3
        txa
        add     #$05
        bra     $dc1
        cmp     #$7f
        bhi     $dac
        ldx     opcode_30_7f_index,x
        bra     $dcf
        cmp     #$9f
        bhi     $dbb
        cmp     #$8f
        bne     $db6
        ldx     #$02
        ldx     opcode_80_9f_index,x
        bra     $dcf
        cmp     #$ad
        bne     $dcc
        lda     #$04
        sta     scratch+$2f
        ldx     #$12
        stx     scratch+$2e
        jsr     app_dol_word
        bra     $d85
        ldx     opcode_a0_af_index,x
        stx     scratch
        clr     scratch+$33
        clrx
        lda     mnemonic_modes,x
        cmp     #$0f
        bhi     $dde
        incx
        bra     $dd4
        and     #$0f
        sta     scratch+$2f
        lda     scratch+$33
        cmp     scratch
        beq     $dec
        inc     scratch+$33
        bra     $ddb
        lda     mnemonic_modes,x
        and     #$0f
        cmp     scratch+$2f
        bhi     $e0d
        lda     mnemonics,x
        and     #$7f
        stx     scratch+$31
        sta     scratch+$33
        lda     scratch+$2f
        add     #$0c
        tax
        lda     scratch+$33
        sta     scratch+$03,x
        dec     scratch+$2f
        bmi     $e10
        ldx     scratch+$31
        decx
        bra     $dec
        brset   0, scratch+$58, $e1a
        brclr   1, scratch+$58, $e1e
        lda     #$58
        bra     $e1c
        lda     #$41
        sta     scratch+$12
        ldx     #$12
        stx     scratch+$2e
        brclr   2, scratch+$58, $e29
        lda     #$23
        bsr     app_char
        tst     scratch+$57
        beq     $e3e
        bsr     app_dol
        jsr     read_next_byte
        dec     scratch+$57
        bmi     $e3e
        beq     $e3a
        and     #$ff
        bsr     app_hex_a
        bra     $e2f
        brclr   3, scratch+$58, $e49
        lda     #$2c
        bsr     app_char
        lda     #$58
        bsr     app_char
        clrx
        lda     scratch+$03,x
        jsr     write_console_char
        incx
        cpx     #$1d
        bls     $e4a
        ldx     #$0a
        jsr     clear_addr_slots
        clr     scratch+$01
load_line_addr:
        ldx     #scratch+$54
        jsr     load_address_pair
        rts
app_next_hex:
        jsr     increment_address
app_hex_byte:
        jsr     read_memory_byte
app_hex_a:
        ldx     scratch+$2e
        sta     scratch+$32
        bsr     app_hi_nibl
        lda     scratch+$32
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
        sta     scratch+$03,x
        incx
        stx     scratch+$2e
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
        lda     scratch+$3e
        and     #$ff
        bsr     app_hex_a
        lda     scratch+$3f
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
asm_cmd:
        dec     scratch+$02
        bne     _bad_entry
        clr     scratch+$5a
_show_line:
        jsr     disassemble_line
_again:
        clr     scratch+$57
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
        dec     scratch+$2e
        clr     scratch+$2f
        clr     scratch
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
        inc     scratch
_check_mode:
        cmp     scratch+$2f
        beq     _got_mnem
        bhi     _next_mnem
_bad_entry:
        inc     scratch+$01
_exit_cmd:
        jmp     cmd_loop
_got_mnem:
        lda     mnemonics,x
        beq     _bad_entry
        and     #$7f
        cmp     scratch+$32
        bhi     _bad_entry
        bne     _next_mnem
        lda     mnemonics,x
        bmi     _set_mode
        inc     scratch+$2f
        bra     _mnem_loop
_set_mode:
        lda     mnemonic_modes,x
        lsra
        lsra
        lsra
        lsra
        sta     scratch+$31
        ldx     scratch
        decx
        lda     opcode_table,x
        sta     scratch
        lda     scratch+$31
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
        add     scratch
        sta     scratch
        lda     #$01
        sta     scratch+$31
_read_suffix:
        jsr     read_command_char
_check_suffix:
        cmp     #$2e
        beq     _finish_no_arg
        cmp     #$0d
        bne     _need_space
_finish_no_arg:
        lda     scratch+$31
        deca
        bne     _bad_entry
        dec     scratch+$2e
        bra     _mode_jump
_need_space:
        cmp     #$20
        bne     _bad_entry
_mode_jump:
        lda     scratch+$31
        asla
        add     scratch+$31
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
        bsr     parse_bit_num
        jsr     parse_hex_word
        tst     scratch+$2c
        bne     _need_comma
        lda     scratch+$32
        cmp     #$2c
_need_comma:
        bne     _bad_jump
        lda     scratch+$2d
        sta     scratch+$31
        lda     #$02
        bra     _parse_operand
_rel_mode:
        lda     #$01
_parse_operand:
        sta     scratch+$57
        jsr     parse_hex_word
        lda     scratch+$57
        inca
        jsr     add_a_to_address
        lda     scratch+$2c
        sta     scratch+$24
        lda     scratch+$2d
        sta     scratch+$25
        jsr     address_in_range
        bne     _calc_rel
        lda     scratch+$25
        jsr     subtract_a_from_address
        lda     scratch+$24
        sub     scratch+$22
        bne     _bad_jump
        lda     scratch+$23
        nega
        bmi     _store_operand
_bad_jump:
        jmp     _bad_entry
_calc_rel:
        lda     scratch+$25
        sub     scratch+$23
        sta     scratch+$23
        lda     scratch+$24
        sbc     scratch+$22
        bne     _bad_jump
        lda     scratch+$23
        bmi     _bad_jump
_store_operand:
        sta     scratch+$2d
        lda     scratch+$31
        sta     scratch+$2c
        jmp     _check_end
_bit_then_abs:
        bsr     parse_bit_num
        jmp     _parse_zp
parse_bit_num:
        jsr     parse_hex_word
        lda     scratch+$2d
        and     #$0f
        cmp     #$00
        bcs     _bad_branch
        cmp     #$07
        bhi     _bad_branch
        asla
        add     scratch
        sta     scratch
        lda     scratch+$32
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
        inc     scratch+$57
        dec     scratch+$2e
        jsr     parse_hex_word
        tst     scratch+$2c
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
        inc     scratch+$57
        dec     scratch+$2e
        jsr     parse_hex_word
        lda     #$10
        tst     scratch+$2c
        beq     _add_opcode
        inc     scratch+$57
        add     #$10
_add_opcode:
        add     scratch
        sta     scratch
_set_mode10:
        lda     #$10
_store_mode:
        sta     scratch+$31
        lda     scratch+$32
        cmp     #$2c
        bne     _check_end
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$58
        bne     _bad_to_entry
        lda     scratch+$31
        brset   1, scratch+$57, _finish_opcode
        add     #$20
        brset   0, scratch+$57, _finish_opcode
        add     #$20
_finish_opcode:
        add     scratch
        sta     scratch
        bra     _read_next_char
_dot_suffix:
        dec     scratch+$5a
_read_next_char:
        jsr     read_command_char
_check_end:
        lda     scratch+$32
        cmp     #$0d
        beq     _write_bytes
        cmp     #$2e
        beq     _dot_suffix
_bad_to_entry:
        jmp     _bad_entry
_write_bytes:
        jsr     load_line_addr
        lda     scratch
_write_loop:
        jsr     write_memory_byte
        jsr     increment_address
        dec     scratch+$57
        bmi     _redisasm
        clrx
        brset   0, scratch+$57, _load_operand
        incx
_load_operand:
        lda     scratch+$2c,x
        bra     _write_loop
_redisasm:
        jsr     load_line_addr
        jsr     disassemble_line
        tst     scratch+$5a
        bne     _cmd_loop
        jmp     _next_line
_cmd_loop:
        jmp     cmd_loop
_bad_mode:
        bra     _bad_to_entry
_parse_zp:
        jsr     parse_hex_word
        tst     scratch+$2c
        bne     _bad_to_entry
        dec     scratch+$2e
        inc     scratch+$57
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
breakpoint_cmd:
        dec     scratch+$02
        bmi     $1238
        jsr     clear_breakpoints
        clrx
        lda     scratch+$22,x
        sta     scratch+$34,x
        lda     scratch+$23,x
        sta     scratch+$35,x
        incx
        incx
        dec     scratch+$02
        bpl     $122a
        jsr     write_crlf
        ldx     #msg_brkpt
        jsr     write_string
        lda     #$73
        jsr     write_console_char
        lda     #$3d
        jsr     write_console_char
        clr     scratch+$31
        jsr     load_breakpoint_address
        beq     $1259
        jsr     write_hex_word_at_73
        ldx     #msg_sp4
        jsr     write_string
        ldx     scratch+$31
        cpx     #$08
        bls     $124c
        jmp     cmd_loop
        inc     scratch+$01
        bra     $125f
nobr_cmd:
        dec     scratch+$02
        bmi     $1277
        bne     $1262
        jsr     find_br_slot
        bne     $1262
        clr     scratch+$34,x
        clr     scratch+$35,x
        bra     $1238
        jsr     clear_breakpoints
        bra     $1238
go_cmd:
        dec     scratch+$02
        bmi     $1292
        bne     $12cc
        jsr     save_addr
        ldx     #$04
        jsr     write_stack_byte
        jsr     increment_address
        lda     scratch+$25
        jsr     write_memory_byte
        jsr     load_stack_pc
        jsr     find_br_slot
        beq     $129d
        jmp     arm_breaks
        inc     scratch+$51
        bset    4, map_switch
        jsr     load_stack_pc
        jsr     decode_inst
        tst     scratch+$01
        bne     $12cc
        ldx     #$0a
        lda     #$0c
        jmp     arm_break_range
proceed_cmd:
        ldx     scratch+$02
        decx
        bmi     $12d3
        bne     $12cc
        ldx     scratch+$23
        stx     scratch+$4a
        beq     $12cc
        jsr     load_stack_pc
        ldx     #scratch+$54
        jsr     store_address_pair
        jsr     find_br_slot
        beq     $129d
        inc     scratch+$01
        clr     scratch+$4a
        jmp     cmd_loop
        incx
        incx
        bra     $12bb
trace_cmd:
        ldx     scratch+$02
        decx
        bmi     $12e6
        bne     $12cc
        ldx     scratch+$23
        stx     scratch+$49
        beq     $12cc
        bra     $129f
        incx
        incx
        bra     $12e0
mem_display_cmd:
        ldx     scratch+$02
        decx
        bmi     $1349
        decx
        beq     $12f7
        bpl     $1349
        jsr     save_addr
        jsr     address_in_range
        beq     $134b
        clr     scratch+$2e
        clr     scratch+$2f
        jsr     write_crlf
        jsr     write_hex_word_at_73
        ldx     #msg_sp4
        jsr     write_string
        bsr     check_display_pause
        jsr     read_memory_byte
        tsta
        bmi     $131b
        cmp     #$20
        bcs     $131b
        cmp     #$7f
        bcs     $131d
        lda     #$2e
        ldx     scratch+$2e
        jsr     app_char
        jsr     read_memory_byte
        jsr     write_hex_byte
        lda     #$20
        jsr     write_console_char
        jsr     increment_address
        inc     scratch+$2f
        brclr   4, scratch+$2f, $130b
        ldx     #msg_sp3
        jsr     write_string
        clrx
        bsr     check_display_pause
        lda     scratch+$03,x
        jsr     write_console_char
        incx
        cpx     #$0f
        bls     $133b
        bra     $12f7
        inc     scratch+$01
        jmp     cmd_loop
check_display_pause:
        jsr     sub_0800
        tst     scratch+$5c
        beq     $1374
        clr     scratch+$5c
        lda     $ffe3
        and     #$7f
        cmp     #$13
        bne     $1370
        jsr     sub_0800
        ldx     $ffe0
        stx     scratch+$60
        brclr   0, scratch+$60, $1360
        lda     $ffe3
        and     #$7f
        cmp     #$18
        beq     $137d
        rts
reg_display_cmd:
        jsr     write_crlf
        ldx     #$20
        jsr     display_regs_msg
        jmp     cmd_loop
        inc     scratch+$01
        bra     $137d
modify_value:
        jsr     write_eq_value
        jsr     read_command_line
        jsr     parse_hex_word
        dec     scratch+$2e
        beq     step_modify
        clrx
        lda     memory_modify_chars,x
        beq     $13c4
        incx
        cmp     scratch+$32
        bne     $1392
        lda     scratch+$2d
        jsr     write_memory_byte
        tst     scratch+$31
        beq     step_modify
        jsr     decrement_address
        lda     scratch+$2c
        jsr     write_memory_byte
        jsr     increment_address
step_modify:
        ldx     scratch+$2f
        lda     scratch+$32
        cmp     #$3d
        beq     $13de
        cmp     #$5e
        beq     $13c9
        cmp     #$0d
        beq     $13d3
        cmp     #$2e
        beq     $13c6
        inc     scratch+$01
        lda     scratch+$32
        rts
        jsr     decrement_address
        decx
        bpl     $13c6
        ldx     #$04
        bra     $13c6
        jsr     increment_address
        incx
        cpx     #$04
        bls     $13c6
        clrx
        bra     $13c6
        tst     scratch+$31
        beq     $13c6
        jsr     decrement_address
        bra     $13c6
memory_modify_chars:
        .byte   "^=.",$0d,$00
mem_modify_cmd:
        dec     scratch+$02
        bne     $1451
        clr     scratch+$31
        jsr     write_crlf
        jsr     write_hex_word_at_73
        bsr     modify_value
        tst     scratch+$01
        bne     $1453
        cmp     #$2e
        bne     $13f2
        bra     $1453
reg_modify_cmd:
        ldx     scratch+$02
        bne     $1451
        stx     scratch+$2f
        jsr     stack_addr
        tstx
        bne     $141a
        jsr     write_crlf
        jsr     write_sp
        bsr     step_modify
        bra     $1408
        cpx     #$04
        beq     $141f
        clrx
        stx     scratch+$31
        jsr     write_crlf
        ldx     scratch+$2f
        lda     register_fields,x
        jsr     select_reg_addr
        jsr     write_console_char
        jsr     modify_value
        tst     scratch+$01
        bne     $1453
        cmp     #$2e
        bne     $1408
        bra     $1453
block_fill_cmd:
        ldx     scratch+$02
        cpx     #$03
        bne     $1451
        jsr     address_in_range
        beq     $1453
        lda     scratch+$27
        jsr     write_memory_byte
        jsr     increment_address
        bra     $1442
        inc     scratch+$01
        jmp     cmd_loop

        .module load_cmd
_bad_cmd:
        inc     scratch+$01
        jmp     cmd_loop
load_cmd:
        jsr     write_crlf
        lda     scratch+$32
        cmp     #$0d
        beq     _bad_cmd
        cmp     #$20
        bne     _bad_cmd
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$54
        bne     _bad_cmd
        bset    0, scratch+$52
        bra     _init_srec
_init_srec:
        clr     scratch+$57
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
        inc     scratch+$57
_read_record:
        clr     scratch+$56
        bsr     read_srec_byte
        sub     #$03
        sta     scratch+$2f
        bsr     read_srec_byte
        sta     scratch+$22
        bsr     read_srec_byte
        sta     scratch+$23
_data_loop:
        dec     scratch+$2f
        bmi     _checksum
        bsr     read_srec_byte
        jsr     write_memory_byte
        jsr     increment_address
        bra     _data_loop
_checksum:
        ldx     scratch+$56
        stx     scratch+$2f
        bsr     read_srec_byte
        tst     scratch+$57
        bne     _done
        coma
        cmp     scratch+$2f
        beq     _wait_srec
_bad_srec:
        inc     scratch+$01
_done:
        clr     scratch+$52
        jmp     cmd_loop
read_srec_byte:
        clr     scratch+$2d
        bsr     read_srec_nibl
        bsr     read_srec_nibl
        add     scratch+$56
        sta     scratch+$56
        lda     scratch+$2d
        rts
read_srec_nibl:
        jsr     read_console_char_echo
        jsr     parse_hex_digit
        tst     scratch+$59
        bmi     _bad_srec
        rts

        .module resume_user
resume_user:
        lda     scratch+$53
        bclr    7, map_switch
        cmp     #$ff
        bne     $14e5
        bset    0, map_switch
        rti
        bit     #$01
        bne     $14ee
        add     #$03
        bset    7, map_switch
        swi
        bsr     resume_plus2
resume_plus2:
        add     #$02
        bra     $14dc
        inc     scratch+$01
        jmp     cmd_loop
        bra     resume_plus2
reset_handler:
        lda     #$ff
        sta     scratch+$5e
        clr     map_switch
        bset    2, map_switch
        lda     #$fa
        sta     scratch+$53
        clr     scratch+$22
        add     #$01
        sta     scratch+$23
        lda     #$e8
        jsr     write_memory_byte
        clr     scratch+$52
        clr     scratch+$5c
        jsr     clear_breakpoints
        lda     #$ff
        deca
        bne     $151b
        lda     #$0c
        sta     scratch+$5b
        jsr     init_serial_or_timer
        clrx
        jsr     write_crlf
        bclr    1, scratch+$52
        clr     scratch+$4a
        clr     scratch+$01
        clr     scratch+$49
        clr     scratch+$51
        clr     map_switch
        bset    2, map_switch
        jmp     $137a
init_serial_or_timer:
        lda     $ffe1
        ora     #$80
        sta     $ffe1
        lda     #$e0
        sta     $ffe1
        lda     $ffe1
        and     #$7f
        sta     $ffe1
        lda     #$40
        tax
        ora     scratch+$5b
        sta     $ffe1
        rts
swi_handler:
        bclr    0, map_switch
        brset   7, map_switch, $14f9
        lda     $ffe4
        deca
        sta     scratch+$53
        rsp
        jsr     load_stack_pc
        jsr     decrement_address
        jsr     save_addr
        lda     #$0c
        jsr     find_address_slot
        beq     $157d
        jsr     read_memory_byte
        cmp     #$83
        beq     $15f6
        bset    5, map_switch
        brclr   4, map_switch, $158e
        ldx     #$0c
        lda     #$0a
        jsr     restore_break_range
        ldx     #$0a
        jsr     clear_addr_slots
        bclr    3, map_switch
        brclr   3, map_switch, $1594
        jsr     restore_breaks
        jsr     write_stack_pc
        jsr     restore_addr
        brset   5, map_switch, $15ec
        clr     map_switch
        bset    2, map_switch
        jsr     find_br_slot
        bne     $15c6
        lda     scratch+$4a
        sub     #$01
        bcs     $15be
        lda     scratch+$54
        cmp     scratch+$22
        bne     $15ba
        lda     scratch+$55
        cmp     scratch+$23
        bne     $15ba
        dec     scratch+$4a
        tst     scratch+$4a
        bne     $15e9
        ldx     #$14
        jsr     write_crlf
        jmp     $1529
        tst     scratch+$51
        bne     $15d9
        lda     scratch+$49
        sub     #$01
        bcs     $15d2
        bne     $15de
        jsr     disassemble_line
        ldx     #$13
        bra     $15c3
        clr     scratch+$51
        jmp     arm_breaks
        dec     scratch+$49
        jsr     disassemble_line
        jsr     display_regs
        jmp     $129f
        jmp     $129d
        jsr     init_serial_or_timer
        jsr     write_crlf
        ldx     #$1a
        bra     $15c3
        lda     scratch+$53
        sub     #$05
        sta     scratch+$53
        ldx     #$06
        stx     scratch+$31
        jsr     read_stack_byte
        sta     scratch+$24
        txa
        sub     #$05
        tax
        jsr     write_stack_byte
        ldx     scratch+$31
        incx
        cpx     #$08
        bls     $15fe
        jsr     read_swi_vector
        jsr     write_stack_pc
        jmp     resume_user
        inc     scratch+$01
        jmp     cmd_loop
help_cmd:
        clrx
        jsr     write_crlf
        jsr     write_crlf
        lda     help_intro,x
        beq     $1633
        jsr     write_console_char
        incx
        bra     $1628
        clrx
        jsr     write_crlf
        lda     help_breakpoint,x
        beq     $1642
        jsr     write_console_char
        incx
        bra     $1637
        clrx
        jsr     write_crlf
        lda     help_go_load_md,x
        beq     $1651
        jsr     write_console_char
        incx
        bra     $1646
        clrx
        jsr     write_crlf
        lda     help_modify_nobr_proceed,x
        beq     $1660
        jsr     write_console_char
        incx
        bra     $1655
        clrx
        jsr     write_crlf
        lda     help_register_trace,x
        beq     $166f
        jsr     write_console_char
        incx
        bra     $1664
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
