        .msfirst

map_switch  .equ    $50
scratch  .equ    $51
user_mem_trampoline  .equ    $9c

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
        jmp     $0c77
write_hex_byte:
        sta     scratch+$33
        add     scratch+$56
        sta     scratch+$56
        lda     scratch+$33
        bsr     $86b
        lda     scratch+$33
        and     #$0f
        bra     $86f
        lsra
        lsra
        lsra
        lsra
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
sub_0888:
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
sub_08ae:
        jsr     write_string
sub_08b1:
        jsr     write_crlf
        clrx
        jsr     sub_09bb
        clr     scratch+$31
        jsr     sub_08d6
        incx
        stx     scratch+$33
        ldx     #msg_sp4
        jsr     write_string
        ldx     scratch+$33
        lda     register_fields,x
        beq     $932
        bsr     $909
        jsr     write_console_char
        jsr     sub_0888
        bra     $8bd
sub_08d6:
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
sub_0909:
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
        sta     scratch+$4d
        lda     #$12
        sta     scratch+$4b
        lda     #$50
        sta     scratch+$4c
        lda     scratch+$22
        sta     scratch+$4e
        lda     scratch+$23
        sta     scratch+$4f
        lda     #$81
        sta     scratch+$50
        lda     scratch+$33
        jsr     user_mem_trampoline
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
sub_09bb:
        clr     scratch+$22
        lda     scratch+$53
        sta     scratch+$23
        txa
        jsr     add_a_to_address
        rts
        jsr     sub_09bb
sub_09c9:
        jsr     read_memory_byte
        and     #$ff
        sta     scratch+$24
sub_09d0:
        jsr     increment_address
        jsr     read_memory_byte
        sta     scratch+$25
        rts
sub_09d9:
        lda     #$fc
        sta     scratch+$23
        lda     #$ff
        sta     scratch+$22
        bra     $9c9
        lda     #$f8
        bsr     $9db
        bsr     $a2b
        ldx     #scratch+$40
        jsr     store_address_pair
        lda     #$fa
        bsr     $9db
        bsr     $a2b
        rts
sub_09f5:
        jsr     sub_09bb
        jsr     read_memory_byte
        rts
sub_09fc:
        jsr     sub_09bb
        lda     scratch+$24
        jsr     write_memory_byte
        rts
sub_0a05:
        ldx     #$04
sub_0a07:
        bsr     $9c6
        bsr     $a2b
        rts
sub_0a0c:
        ldx     #$04
        jsr     sub_09bb
        lda     scratch+$24
        jsr     write_memory_byte
        jsr     increment_address
        lda     scratch+$25
        jsr     write_memory_byte
        rts
sub_0a1f:
        ldx     #scratch+$24
store_address_pair:
        lda     scratch+$22
        and     #$ff
        sta     ,x
        lda     scratch+$23
        sta     $01,x
        rts
sub_0a2b:
        ldx     #scratch+$24
load_address_pair:
        lda     ,x
        sta     scratch+$22
        lda     $01,x
        sta     scratch+$23
        rts
clear_breakpoints:
        clrx
sub_0a36:
        clr     scratch+$34,x
        incx
        cpx     #$0d
        bls     $a36
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
sub_0a51:
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
        clrx
        lda     #$08
        sta     scratch+$32
        stx     scratch+$31
        bsr     $a3e
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
        jmp     $14da
sub_0a8a:
        ldx     #$08
        clra
sub_0a8d:
        stx     scratch+$31
        sta     scratch+$32
        bsr     $a3e
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
sub_0aa6:
        clr     scratch+$57
        clr     scratch+$58
        jsr     read_memory_byte
        sta     scratch+$33
        and     #$0f
        tax
        lda     scratch+$33
        and     #$f0
        bne     $abb
        jmp     $0bcc
        cmp     #$10
        beq     $b2c
        cmp     #$20
        bne     $ac6
        jmp     $0bc8
        cmp     #$70
        bhi     $b02
        tstx
        beq     $ae8
        cmp     #$40
        bne     $ad5
        cpx     #$02
        beq     $b12
        cpx     #$02
        bls     $ae5
        cpx     #$05
        beq     $ae5
        cpx     #$0b
        beq     $ae5
        cpx     #$0e
        bne     $ae8
        inc     scratch+$01
        rts
        cmp     #$30
        beq     $b2c
        cmp     #$40
        beq     $afc
        cmp     #$50
        beq     $afe
        bset    3, scratch+$58
        cmp     #$60
        beq     $b2c
        bra     $b12
        bset    0, scratch+$58
        bset    1, scratch+$58
        bra     $b12
        cmp     #$80
        beq     $b4b
        cmp     #$90
        bne     $b16
        cpx     #$06
        bls     $ae5
        cpx     #$0e
        beq     $ae5
        lda     #$01
        bra     $b7c
        cmp     #$a0
        bne     $b2e
        cpx     #$0d
        beq     $b2c
        cpx     #$07
        beq     $ae5
        cpx     #$0c
        beq     $ae5
        cpx     #$0f
        beq     $ae5
        bset    2, scratch+$58
        bra     $ba2
        cmp     #$b0
        beq     $ba2
        cmp     #$c0
        beq     $b72
        bset    3, scratch+$58
        cmp     #$d0
        beq     $b72
        cmp     #$e0
        beq     $ba2
        bsr     $b6b
        bne     $b12
        ldx     #$03
        jsr     sub_09f5
        bra     $bb9
        decx
        bmi     $b60
        beq     $b64
        cpx     #$02
        bne     $b5a
        jsr     sub_09d9
        clrx
        bra     $b92
        cpx     #$0c
        bls     $ae5
        bra     $b12
        ldx     #$09
        bra     $b66
        ldx     #$06
        jsr     sub_0a07
        bra     $b7f
        cpx     #$0c
        beq     $b71
        cpx     #$0d
        rts
        inc     scratch+$57
        inc     scratch+$57
        bsr     $b6b
        beq     $b85
        lda     #$03
        jsr     add_a_to_address
        ldx     #scratch+$3e
        jsr     store_address_pair
        rts
        clrx
        cmp     #$c0
        beq     $b8c
        ldx     #$03
        jsr     increment_address
        jsr     sub_09c9
        clra
        tstx
        beq     $b99
        jsr     sub_09f5
        sta     scratch+$32
        jsr     sub_0a2b
        lda     scratch+$32
        bra     $b7c
        inc     scratch+$57
        bsr     $b6b
        bne     $bae
        cmp     #$a0
        beq     $bc8
        bhi     $bb2
        lda     #$02
        bra     $b7c
        cmp     #$b0
        bne     $bbf
        jsr     sub_09d0
        clr     scratch+$24
        clr     scratch+$25
        bra     $b99
        clr     scratch+$24
        ldx     #$03
        jsr     sub_09d0
        bra     $b92
        lda     #$01
        bra     $bce
        lda     #$02
        sta     scratch+$57
        inca
        jsr     add_a_to_address
        ldx     #scratch+$40
        jsr     store_address_pair
        jsr     decrement_address
        jsr     read_memory_byte
        tax
        jsr     increment_address
        txa
        tsta
        bpl     $b7c
        dec     scratch+$22
        bra     $b7c
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
        inc     scratch+$01
        rsp
        jsr     write_crlf
        tst     scratch+$01
        beq     $c89
        ldx     #msg_bad_entry
        jsr     write_string
        jsr     write_crlf
        clr     scratch+$01
        jsr     read_command_line
        clr     scratch+$02
        clr     scratch
        ldx     #$ff
        jsr     read_command_char
        cmp     #$0d
        beq     $c77
        jsr     uppercase_command_char
        incx
        lda     cmd_tokens,x
        beq     $c75
        and     #$7f
        cmp     scratch+$32
        beq     $cb4
        clr     scratch+$2e
        inc     scratch
        lda     cmd_tokens,x
        bmi     $c92
        incx
        bra     $cac
        lda     cmd_tokens,x
        bpl     $c92
        jsr     read_command_char
        cmp     #$0d
        beq     $ce6
        cmp     #$20
        bne     $ca8
        lda     scratch
        cmp     #$04
        beq     $ce6
        jsr     parse_hex_word
        ldx     scratch+$02
        aslx
        cpx     #$0a
        bhi     $c75
        lda     scratch+$2c
        sta     scratch+$20,x
        lda     scratch+$2d
        sta     scratch+$21,x
        lda     scratch+$32
        cmp     #$20
        beq     $cca
        cmp     #$0d
        bne     $c75
        lda     scratch
        asla
        tax
        lda     #$cc
        sta     scratch+$4b
        lda     cmd_handlers,x
        sta     scratch+$4c
        lda     cmd_handlers+1,x
        sta     scratch+$4d
        jmp     scratch+$4b

; command handler table
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
        jsr     sub_0aa6
        jsr     sub_0e5b
        lda     scratch+$57
        sta     scratch+$33
        sta     scratch+$02
        ldx     #$02
        stx     scratch+$2e
        jsr     sub_0e64
        inc     scratch+$2e
        jsr     increment_address
        dec     scratch+$33
        bpl     $d38
        jsr     sub_0e5b
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
        jsr     append_comma_dollar
        jsr     append_hex_word
        clrx
        stx     scratch+$2f
        ldx     #$12
        stx     scratch+$2e
        lda     scratch+$33
        brclr   0, scratch+$33, $d7b
        inc     scratch+$2f
        lsra
        jsr     hex_nibble_to_ascii
        jsr     append_comma_dollar
        jsr     sub_0e61
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
        jsr     sub_0e8e
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
        bsr     $e7f
        tst     scratch+$57
        beq     $e3e
        bsr     $e89
        jsr     sub_09d0
        dec     scratch+$57
        bmi     $e3e
        beq     $e3a
        and     #$ff
        bsr     $e67
        bra     $e2f
        brclr   3, scratch+$58, $e49
        lda     #$2c
        bsr     $e7f
        lda     #$58
        bsr     $e7f
        clrx
        lda     scratch+$03,x
        jsr     write_console_char
        incx
        cpx     #$1d
        bls     $e4a
        ldx     #$0a
        jsr     sub_0a36
        clr     scratch+$01
sub_0e5b:
        ldx     #scratch+$54
        jsr     load_address_pair
        rts
sub_0e61:
        jsr     increment_address
sub_0e64:
        jsr     read_memory_byte
        ldx     scratch+$2e
        sta     scratch+$32
        bsr     $e73
        lda     scratch+$32
        and     #$0f
        bra     $e77
        lsra
        lsra
        lsra
        lsra
hex_nibble_to_ascii:
        add     #$30
        cmp     #$39
        bls     $e7f
        add     #$07
append_disasm_char:
        sta     scratch+$03,x
        incx
        stx     scratch+$2e
        rts
append_comma_dollar:
        lda     #$2c
        bsr     $e7f
        lda     #$24
        bsr     $e7f
        rts
sub_0e8e:
        bsr     $e89
append_hex_word:
        lda     scratch+$3e
        and     #$ff
        bsr     $e67
        lda     scratch+$3f
        bsr     $e67
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
asm_cmd:
        dec     scratch+$02
        bne     $0f21
        clr     scratch+$5a
        jsr     disassemble_line
        clr     scratch+$57
        jsr     read_command_line
        jsr     read_command_char
        cmp     #$0d
        bne     $efd
        lda     scratch+$02
        inca
        jsr     add_a_to_address
        bra     $ee6
        cmp     #$2e
        beq     $f23
        dec     scratch+$2e
        clr     scratch+$2f
        clr     scratch
        ldx     #$ff
        jsr     read_command_char
        jsr     uppercase_command_char
        incx
        lda     mnemonic_modes,x
        cmp     #$0f
        bls     $f1b
        and     #$0f
        inc     scratch
        cmp     scratch+$2f
        beq     $f26
        bhi     $f0f
        inc     scratch+$01
        jmp     $0c77
        lda     mnemonics,x
        beq     $f21
        and     #$7f
        cmp     scratch+$32
        bhi     $f21
        bne     $f0f
        lda     mnemonics,x
        bmi     $f3c
        inc     scratch+$2f
        bra     $f09
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
        bne     $f6f
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$41
        beq     $f65
        cmp     #$58
        bne     $f72
        lda     #$20
        bra     $f67
        lda     #$10
        add     scratch
        sta     scratch
        lda     #$01
        sta     scratch+$31
        jsr     read_command_char
        cmp     #$2e
        beq     $f7a
        cmp     #$0d
        bne     $f83
        lda     scratch+$31
        deca
        bne     $f21
        dec     scratch+$2e
        bra     $f87
        cmp     #$20
        bne     $f21
        lda     scratch+$31
        asla
        add     scratch+$31
        tax
        jmp     $0f8d,x
        jmp     $1086
        jmp     $1002
        jmp     $0fbc
        jmp     $1022
        jmp     $10be
        jmp     $1039
        jmp     $103e
        bsr     $1007
        jsr     parse_hex_word
        tst     scratch+$2c
        bne     $fb2
        lda     scratch+$32
        cmp     #$2c
        bne     $fe6
        lda     scratch+$2d
        sta     scratch+$31
        lda     #$02
        bra     $fbe
        lda     #$01
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
        bne     $fe9
        lda     scratch+$25
        jsr     subtract_a_from_address
        lda     scratch+$24
        sub     scratch+$22
        bne     $fe6
        lda     scratch+$23
        nega
        bmi     $ff9
        jmp     $0f21
        lda     scratch+$25
        sub     scratch+$23
        sta     scratch+$23
        lda     scratch+$24
        sbc     scratch+$22
        bne     $fe6
        lda     scratch+$23
        bmi     $fe6
        sta     scratch+$2d
        lda     scratch+$31
        sta     scratch+$2c
        jmp     $1089
        bsr     $1007
        jmp     $10c0
        jsr     parse_hex_word
        lda     scratch+$2d
        and     #$0f
        cmp     #$00
        bcs     $1037
        cmp     #$07
        bhi     $1037
        asla
        add     scratch
        sta     scratch
        lda     scratch+$32
        cmp     #$2c
        bne     $1093
        rts
        jsr     read_command_char
        cmp     #$2c
        bne     $102c
        clra
        bra     $1060
        inc     scratch+$57
        dec     scratch+$2e
        jsr     parse_hex_word
        tst     scratch+$2c
        beq     $105e
        bra     $1093
        jsr     read_command_char
        bra     $1045
        jsr     read_command_char
        cmp     #$23
        beq     $10c0
        cmp     #$2c
        beq     $105e
        inc     scratch+$57
        dec     scratch+$2e
        jsr     parse_hex_word
        lda     #$10
        tst     scratch+$2c
        beq     $105a
        inc     scratch+$57
        add     #$10
        add     scratch
        sta     scratch
        lda     #$10
        sta     scratch+$31
        lda     scratch+$32
        cmp     #$2c
        bne     $1089
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$58
        bne     $1093
        lda     scratch+$31
        brset   1, scratch+$57, $107e
        add     #$20
        brset   0, scratch+$57, $107e
        add     #$20
        add     scratch
        sta     scratch
        bra     $1086
        dec     scratch+$5a
        jsr     read_command_char
        lda     scratch+$32
        cmp     #$0d
        beq     $1096
        cmp     #$2e
        beq     $1084
        jmp     $0f21
        jsr     sub_0e5b
        lda     scratch
        jsr     write_memory_byte
        jsr     increment_address
        dec     scratch+$57
        bmi     $10ae
        clrx
        brset   0, scratch+$57, $10aa
        incx
        lda     scratch+$2c,x
        bra     $109b
        jsr     sub_0e5b
        jsr     disassemble_line
        tst     scratch+$5a
        bne     $10bb
        jmp     $0ef5
        jmp     $0c77
        bra     $1093
        jsr     parse_hex_word
        tst     scratch+$2c
        bne     $1093
        dec     scratch+$2e
        inc     scratch+$57
        bra     $1086

; mnemonic text table; high bit marks token end
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
        jmp     $0c77
        inc     scratch+$01
        bra     $125f
nobr_cmd:
        dec     scratch+$02
        bmi     $1277
        bne     $1262
        jsr     sub_0a51
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
        jsr     sub_0a1f
        ldx     #$04
        jsr     sub_09fc
        jsr     increment_address
        lda     scratch+$25
        jsr     write_memory_byte
        jsr     sub_0a05
        jsr     sub_0a51
        beq     $129d
        jmp     $0a69
        inc     scratch+$51
        bset    4, map_switch
        jsr     sub_0a05
        jsr     sub_0aa6
        tst     scratch+$01
        bne     $12cc
        ldx     #$0a
        lda     #$0c
        jmp     $0a6c
proceed_cmd:
        ldx     scratch+$02
        decx
        bmi     $12d3
        bne     $12cc
        ldx     scratch+$23
        stx     scratch+$4a
        beq     $12cc
        jsr     sub_0a05
        ldx     #scratch+$54
        jsr     store_address_pair
        jsr     sub_0a51
        beq     $129d
        inc     scratch+$01
        clr     scratch+$4a
        jmp     $0c77
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
        jsr     sub_0a1f
        jsr     address_in_range
        beq     $134b
        clr     scratch+$2e
        clr     scratch+$2f
        jsr     write_crlf
        jsr     write_hex_word_at_73
        ldx     #msg_sp4
        jsr     write_string
        bsr     $134e
        jsr     read_memory_byte
        tsta
        bmi     $131b
        cmp     #$20
        bcs     $131b
        cmp     #$7f
        bcs     $131d
        lda     #$2e
        ldx     scratch+$2e
        jsr     append_disasm_char
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
        bsr     $134e
        lda     scratch+$03,x
        jsr     write_console_char
        incx
        cpx     #$0f
        bls     $133b
        bra     $12f7
        inc     scratch+$01
        jmp     $0c77
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
        jsr     sub_08ae
        jmp     $0c77
        inc     scratch+$01
        bra     $137d
sub_1384:
        jsr     sub_0888
        jsr     read_command_line
        jsr     parse_hex_word
        dec     scratch+$2e
        beq     $13b0
        clrx
        lda     memory_modify_chars,x
        beq     $13c4
        incx
        cmp     scratch+$32
        bne     $1392
        lda     scratch+$2d
        jsr     write_memory_byte
        tst     scratch+$31
        beq     $13b0
        jsr     decrement_address
        lda     scratch+$2c
        jsr     write_memory_byte
        jsr     increment_address
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
        bsr     $1384
        tst     scratch+$01
        bne     $1453
        cmp     #$2e
        bne     $13f2
        bra     $1453
reg_modify_cmd:
        ldx     scratch+$02
        bne     $1451
        stx     scratch+$2f
        jsr     sub_09bb
        tstx
        bne     $141a
        jsr     write_crlf
        jsr     sub_08d6
        bsr     $13b0
        bra     $1408
        cpx     #$04
        beq     $141f
        clrx
        stx     scratch+$31
        jsr     write_crlf
        ldx     scratch+$2f
        lda     register_fields,x
        jsr     sub_0909
        jsr     write_console_char
        jsr     sub_1384
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
        jmp     $0c77
        inc     scratch+$01
        jmp     $0c77
load_cmd:
        jsr     write_crlf
        lda     scratch+$32
        cmp     #$0d
        beq     $1456
        cmp     #$20
        bne     $1456
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$54
        bne     $1456
        bset    0, scratch+$52
        bra     $1476
        clr     scratch+$57
        jsr     read_console_char_echo
        cmp     #$53
        bne     $1478
        jsr     read_console_char_echo
        cmp     #$39
        beq     $148c
        cmp     #$31
        bne     $1478
        bra     $148e
        inc     scratch+$57
        clr     scratch+$56
        bsr     $14c2
        sub     #$03
        sta     scratch+$2f
        bsr     $14c2
        sta     scratch+$22
        bsr     $14c2
        sta     scratch+$23
        dec     scratch+$2f
        bmi     $14ac
        bsr     $14c2
        jsr     write_memory_byte
        jsr     increment_address
        bra     $149e
        ldx     scratch+$56
        stx     scratch+$2f
        bsr     $14c2
        tst     scratch+$57
        bne     $14bd
        coma
        cmp     scratch+$2f
        beq     $1478
        inc     scratch+$01
        clr     scratch+$52
        jmp     $0c77
        clr     scratch+$2d
        bsr     $14cf
        bsr     $14cf
        add     scratch+$56
        sta     scratch+$56
        lda     scratch+$2d
        rts
        jsr     read_console_char_echo
        jsr     parse_hex_digit
        tst     scratch+$59
        bmi     $14bb
        rts
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
        bsr     $14f0
        add     #$02
        bra     $14dc
        inc     scratch+$01
        jmp     $0c77
        bra     $14f0
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
        jsr     sub_0a05
        jsr     decrement_address
        jsr     sub_0a1f
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
        jsr     sub_0a8d
        ldx     #$0a
        jsr     sub_0a36
        bclr    3, map_switch
        brclr   3, map_switch, $1594
        jsr     sub_0a8a
        jsr     sub_0a0c
        jsr     sub_0a2b
        brset   5, map_switch, $15ec
        clr     map_switch
        bset    2, map_switch
        jsr     sub_0a51
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
        jmp     $0a69
        dec     scratch+$49
        jsr     disassemble_line
        jsr     sub_08b1
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
        jsr     sub_09f5
        sta     scratch+$24
        txa
        sub     #$05
        tax
        jsr     sub_09fc
        ldx     scratch+$31
        incx
        cpx     #$08
        bls     $15fe
        jsr     sub_09d9
        jsr     sub_0a0c
        jmp     $14da
        inc     scratch+$01
        jmp     $0c77
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
        jmp     $0c77

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

; banner and help text
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
        .byte   $06,$f4
        .org    $1ff0
        .dw     reset_handler              ; Reserved
        .dw     reset_handler              ; Wait timer erratum mirror
        .dw     reset_handler              ; Reserved
        .dw     reset_handler              ; Timer from wait state
        .dw     reset_handler              ; Timer
        .dw     reset_handler              ; External interrupt
        .dw     swi_handler                ; Software interrupt
        .dw     reset_handler              ; Reset
        .end
