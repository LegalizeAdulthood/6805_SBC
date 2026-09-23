        .msfirst

sub_9c  .equ    $9c

        .org    $0000
        .byte   $00
        .org    $0800
sub_0800:
        sta     $ae
        lda     #$00
        sta     $fff0
        lda     $ae
        rts
read_console_char_echo:
        stx     $aa
        jsr     sub_0800
        ldx     $ffe1
        stx     $b1
        brset   2, $b1, $850
        ldx     $ffe0
        stx     $b1
        brclr   0, $b1, $80c
        lda     $ffe3
        and     #$7f
        bra     $834
write_console_char:
        stx     $aa
        ldx     $ffe0
        stx     $b1
        brclr   0, $b1, $834
        ldx     #$ff
        stx     $ad
        sta     $ffe3
        brset   1, $a3, $84d
        jsr     sub_0800
        ldx     $ffe0
        stx     $b1
        brclr   6, $b1, $83a
        ldx     $ffe1
        stx     $b1
        brset   2, $b1, $850
        ldx     $aa
        rts
        lda     $ffe3
        jsr     init_serial_or_timer
        clr     $a3
        jmp     $0c77
write_hex_byte:
        sta     $84
        add     $a7
        sta     $a7
        lda     $84
        bsr     $86b
        lda     $84
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
        lda     $73
        and     #$ff
        jsr     write_hex_byte
        lda     $74
        jsr     write_hex_byte
        rts
sub_0888:
        lda     #$3d
        jsr     write_console_char
        jsr     read_memory_byte
        tst     $82
        beq     $89f
        and     #$ff
        jsr     write_hex_byte
        jsr     increment_address
        jsr     read_memory_byte
        jsr     write_hex_byte
        rts
write_string:
        lda     $1691,x
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
        clr     $82
        jsr     sub_08d6
        incx
        stx     $84
        ldx     #$41
        jsr     write_string
        ldx     $84
        lda     $08e8,x
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
        lda     $74
        add     #$05
        jsr     write_hex_byte
        rts

; register display field table
        .byte   "SPAXC",$00
write_crlf:
        lda     #$0d
        jsr     write_console_char
        lda     #$0a
        jsr     write_console_char
        rts

; condition-code display table
        .fill   $0008,$00
        .byte   "111HINZC"
sub_0909:
        stx     $84
        tax
        lda     $a4
        clr     $82
        clr     $73
        cpx     #$50
        bne     $91a
        inc     $82
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
        sta     $74
        txa
        ldx     $84
        rts
        ldx     #$41
        jsr     write_string
        lda     $a4
        add     #$01
        sta     $74
        clr     $73
        jsr     read_memory_byte
        sta     $84
        ldx     #$ff
        lda     #$08
        sta     $82
        incx
        lda     #$2e
        asl     $84
        bcc     $954
        lda     $0901,x
        jsr     write_console_char
        dec     $82
        bne     $94a
        rts
write_memory_byte:
        sta     $84
        jsr     sub_0800
        lda     #$c7
        bra     $96a
read_memory_byte:
        lda     #$c6
        jsr     sub_0800
        bclr    2, $50
        sta     $9e
        lda     #$12
        sta     $9c
        lda     #$50
        sta     $9d
        lda     $73
        sta     $9f
        lda     $74
        sta     $a0
        lda     #$81
        sta     $a1
        lda     $84
        jsr     sub_9c
        bclr    1, $50
        bset    2, $50
        rts
increment_address:
        lda     #$01
add_a_to_address:
        add     $74
        sta     $74
        clra
        adc     $73
        sta     $73
        rts
decrement_address:
        lda     #$01
subtract_a_from_address:
        sta     $84
        lda     $74
        sub     $84
        sta     $74
        lda     $73
        sbc     #$00
        bra     $994
address_in_range:
        lda     $75
        cmp     $73
        bcs     $9b8
        bhi     $9b7
        lda     $76
        cmp     $74
        bcs     $9b8
        lda     #$01
        rts
        clra
        bra     $9b7
sub_09bb:
        clr     $73
        lda     $a4
        sta     $74
        txa
        jsr     add_a_to_address
        rts
        jsr     sub_09bb
sub_09c9:
        jsr     read_memory_byte
        and     #$ff
        sta     $75
sub_09d0:
        jsr     increment_address
        jsr     read_memory_byte
        sta     $76
        rts
sub_09d9:
        lda     #$fc
        sta     $74
        lda     #$ff
        sta     $73
        bra     $9c9
        lda     #$f8
        bsr     $9db
        bsr     $a2b
        ldx     #$91
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
        lda     $75
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
        lda     $75
        jsr     write_memory_byte
        jsr     increment_address
        lda     $76
        jsr     write_memory_byte
        rts
sub_0a1f:
        ldx     #$75
store_address_pair:
        lda     $73
        and     #$ff
        sta     ,x
        lda     $74
        sta     $01,x
        rts
sub_0a2b:
        ldx     #$75
load_address_pair:
        lda     ,x
        sta     $73
        lda     $01,x
        sta     $74
        rts
clear_breakpoints:
        clrx
sub_0a36:
        clr     $85,x
        incx
        cpx     #$0d
        bls     $a36
        rts
load_breakpoint_address:
        ldx     $82
        inc     $82
        inc     $82
        lda     $86,x
        sta     $74
        lda     $85,x
        sta     $73
        bne     $a50
        lda     $86,x
        rts
sub_0a51:
        lda     #$08
find_address_slot:
        sta     $83
        clrx
        lda     $73
        cmp     $85,x
        bne     $a62
        lda     $74
        cmp     $86,x
        beq     $a50
        incx
        incx
        cpx     $83
        bls     $a56
        rts
        clrx
        lda     #$08
        sta     $83
        stx     $82
        bsr     $a3e
        beq     $a81
        bset    3, $50
        jsr     read_memory_byte
        lsrx
        sta     $93,x
        lda     #$83
        jsr     write_memory_byte
        ldx     $82
        cpx     $83
        bls     $a70
        jmp     $14da
sub_0a8a:
        ldx     #$08
        clra
sub_0a8d:
        stx     $82
        sta     $83
        bsr     $a3e
        beq     $a9b
        lsrx
        lda     $93,x
        jsr     write_memory_byte
        lda     $82
        sub     #$04
        sta     $82
        cmp     $83
        bpl     $a91
        rts
sub_0aa6:
        clr     $a8
        clr     $a9
        jsr     read_memory_byte
        sta     $84
        and     #$0f
        tax
        lda     $84
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
        inc     $52
        rts
        cmp     #$30
        beq     $b2c
        cmp     #$40
        beq     $afc
        cmp     #$50
        beq     $afe
        bset    3, $a9
        cmp     #$60
        beq     $b2c
        bra     $b12
        bset    0, $a9
        bset    1, $a9
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
        bset    2, $a9
        bra     $ba2
        cmp     #$b0
        beq     $ba2
        cmp     #$c0
        beq     $b72
        bset    3, $a9
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
        inc     $a8
        inc     $a8
        bsr     $b6b
        beq     $b85
        lda     #$03
        jsr     add_a_to_address
        ldx     #$8f
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
        sta     $83
        jsr     sub_0a2b
        lda     $83
        bra     $b7c
        inc     $a8
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
        clr     $75
        clr     $76
        bra     $b99
        clr     $75
        ldx     #$03
        jsr     sub_09d0
        bra     $b92
        lda     #$01
        bra     $bce
        lda     #$02
        sta     $a8
        inca
        jsr     add_a_to_address
        ldx     #$91
        jsr     store_address_pair
        jsr     decrement_address
        jsr     read_memory_byte
        tax
        jsr     increment_address
        txa
        tsta
        bpl     $b7c
        dec     $73
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
        sta     $54,x
        incx
        cpx     #$1e
        beq     $c11
        cmp     #$0d
        bne     $bf4
        lda     #$0d
        sta     $54,x
        clr     $7f
        rts
read_command_char:
        stx     $84
        ldx     $7f
        lda     $54,x
        inc     $7f
        ldx     $84
        sta     $83
        rts
uppercase_command_char:
        cmp     #$60
        bls     $c2d
        sub     #$20
        sta     $83
        rts
parse_hex_word:
        clr     $7d
        clr     $7e
        jsr     read_command_char
        cmp     #$24
        bne     $c3c
        jsr     read_command_char
parse_hex_digit:
        jsr     uppercase_command_char
        clr     $aa
        dec     $aa
        sub     #$30
        bmi     $c72
        cmp     #$09
        bls     $c55
        sub     #$07
        cmp     #$09
        bls     $c72
        cmp     #$0f
        bhi     $c72
        sta     $aa
        lda     $7d
        ldx     $7e
        aslx
        rola
        aslx
        rola
        aslx
        rola
        aslx
        rola
        sta     $7d
        txa
        ora     $aa
        sta     $7e
        ldx     $84
        tst     $a3
        bne     $c72
        bra     $c39
        inc     $53
        rts
        inc     $52
        rsp
        jsr     write_crlf
        tst     $52
        beq     $c89
        ldx     #$26
        jsr     write_string
        jsr     write_crlf
        clr     $52
        jsr     read_command_line
        clr     $53
        clr     $51
        ldx     #$ff
        jsr     read_command_char
        cmp     #$0d
        beq     $c77
        jsr     uppercase_command_char
        incx
        lda     $1672,x
        beq     $c75
        and     #$7f
        cmp     $83
        beq     $cb4
        clr     $7f
        inc     $51
        lda     $1672,x
        bmi     $c92
        incx
        bra     $cac
        lda     $1672,x
        bpl     $c92
        jsr     read_command_char
        cmp     #$0d
        beq     $ce6
        cmp     #$20
        bne     $ca8
        lda     $51
        cmp     #$04
        beq     $ce6
        jsr     parse_hex_word
        ldx     $53
        aslx
        cpx     #$0a
        bhi     $c75
        lda     $7d
        sta     $71,x
        lda     $7e
        sta     $72,x
        lda     $83
        cmp     #$20
        beq     $cca
        cmp     #$0d
        bne     $c75
        lda     $51
        asla
        tax
        lda     #$cc
        sta     $9c
        lda     $0cfa,x
        sta     $9d
        lda     $0cfb,x
        sta     $9e
        jmp     $9c
        brset   7, $e0, $d11
        inc     $12
        bhi     $d13
        inc     ,x
        bset    2, $5b
        bset    1, $ea
        bclr    1, $ec
        bset    1, $66
        bset    1, $b2
        bclr    1, $75
        bset    2, $04
        bset    1, $d7
        bset    3, $21
disassemble_line:
        ldx     #$a5
        jsr     store_address_pair
        jsr     write_crlf
        jsr     write_hex_word_at_73
        lda     #$20
        ldx     #$1d
        sta     $54,x
        decx
        bpl     $d23
        jsr     sub_0aa6
        jsr     sub_0e5b
        lda     $a8
        sta     $84
        sta     $53
        ldx     #$02
        stx     $7f
        jsr     sub_0e64
        inc     $7f
        jsr     increment_address
        dec     $84
        bpl     $d38
        jsr     sub_0e5b
        tst     $52
        beq     $d54
        jsr     decrement_address
        inc     $a8
        ldx     #$26
        bra     $d8c
        jsr     read_memory_byte
        and     #$0f
        tax
        jsr     read_memory_byte
        cmp     #$0f
        bhi     $d8e
        sta     $84
        ldx     #$17
        stx     $7f
        jsr     append_comma_dollar
        jsr     append_hex_word
        clrx
        stx     $80
        ldx     #$12
        stx     $7f
        lda     $84
        brclr   0, $84, $d7b
        inc     $80
        lsra
        jsr     hex_nibble_to_ascii
        jsr     append_comma_dollar
        jsr     sub_0e61
        clr     $a8
        ldx     $80
        ldx     $0ebb,x
        bra     $dcf
        cmp     #$1f
        bhi     $d9a
        sub     #$10
        sta     $84
        ldx     #$02
        bra     $d6e
        cmp     #$2f
        bhi     $da3
        txa
        add     #$05
        bra     $dc1
        cmp     #$7f
        bhi     $dac
        ldx     $0e9b,x
        bra     $dcf
        cmp     #$9f
        bhi     $dbb
        cmp     #$8f
        bne     $db6
        ldx     #$02
        ldx     $0ed0,x
        bra     $dcf
        cmp     #$ad
        bne     $dcc
        lda     #$04
        sta     $80
        ldx     #$12
        stx     $7f
        jsr     sub_0e8e
        bra     $d85
        ldx     $0eab,x
        stx     $51
        clr     $84
        clrx
        lda     $1155,x
        cmp     #$0f
        bhi     $dde
        incx
        bra     $dd4
        and     #$0f
        sta     $80
        lda     $84
        cmp     $51
        beq     $dec
        inc     $84
        bra     $ddb
        lda     $1155,x
        and     #$0f
        cmp     $80
        bhi     $e0d
        lda     $10cd,x
        and     #$7f
        stx     $82
        sta     $84
        lda     $80
        add     #$0c
        tax
        lda     $84
        sta     $54,x
        dec     $80
        bmi     $e10
        ldx     $82
        decx
        bra     $dec
        brset   0, $a9, $e1a
        brclr   1, $a9, $e1e
        lda     #$58
        bra     $e1c
        lda     #$41
        sta     $63
        ldx     #$12
        stx     $7f
        brclr   2, $a9, $e29
        lda     #$23
        bsr     $e7f
        tst     $a8
        beq     $e3e
        bsr     $e89
        jsr     sub_09d0
        dec     $a8
        bmi     $e3e
        beq     $e3a
        and     #$ff
        bsr     $e67
        bra     $e2f
        brclr   3, $a9, $e49
        lda     #$2c
        bsr     $e7f
        lda     #$58
        bsr     $e7f
        clrx
        lda     $54,x
        jsr     write_console_char
        incx
        cpx     #$1d
        bls     $e4a
        ldx     #$0a
        jsr     sub_0a36
        clr     $52
sub_0e5b:
        ldx     #$a5
        jsr     load_address_pair
        rts
sub_0e61:
        jsr     increment_address
sub_0e64:
        jsr     read_memory_byte
        ldx     $7f
        sta     $83
        bsr     $e73
        lda     $83
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
        sta     $54,x
        incx
        stx     $7f
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
        lda     $8f
        and     #$ff
        bsr     $e67
        lda     $90
        bsr     $e67
        rts

; assembler/disassembler decode tables
        .byte   $30,$00,$2f,$21,$2e,$00,$35,$04,$2d,$34,$23,$00,$27,$42,$00,$1f
        .byte   $3f,$20,$39,$22,$02,$0f,$2b,$3c,$25,$00,$32,$01,$29,$2a,$2c,$3e
        .byte   $1a,$18,$1b,$06,$1c,$17,$19,$0b,$11,$05,$07,$15,$08,$09,$0a,$16
        .byte   $13,$12,$14,$0e,$0d,$37,$38,$44,$40,$00,$00,$00,$41,$1d,$3a,$1e
        .byte   $3b,$36,$31,$3d,$43,$3a,$53,$26,$3d,$3f,$ab
        jsr     disassemble_line
        clr     $a8
        jsr     read_command_line
        jsr     read_command_char
        cmp     #$0d
        bne     $efd
        lda     $53
        inca
        jsr     add_a_to_address
        bra     $ee6
        cmp     #$2e
        beq     $f23
        dec     $7f
        clr     $80
        clr     $51
        ldx     #$ff
        jsr     read_command_char
        jsr     uppercase_command_char
        incx
        lda     $1155,x
        cmp     #$0f
        bls     $f1b
        and     #$0f
        inc     $51
        cmp     $80
        beq     $f26
        bhi     $f0f
        inc     $52
        jmp     $0c77
        lda     $10cd,x
        beq     $f21
        and     #$7f
        cmp     $83
        bhi     $f21
        bne     $f0f
        lda     $10cd,x
        bmi     $f3c
        inc     $80
        bra     $f09
        lda     $1155,x
        lsra
        lsra
        lsra
        lsra
        sta     $82
        ldx     $51
        decx
        lda     $11dd,x
        sta     $51
        lda     $82
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
        add     $51
        sta     $51
        lda     #$01
        sta     $82
        jsr     read_command_char
        cmp     #$2e
        beq     $f7a
        cmp     #$0d
        bne     $f83
        lda     $82
        deca
        bne     $f21
        dec     $7f
        bra     $f87
        cmp     #$20
        bne     $f21
        lda     $82
        asla
        add     $82
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
        tst     $7d
        bne     $fb2
        lda     $83
        cmp     #$2c
        bne     $fe6
        lda     $7e
        sta     $82
        lda     #$02
        bra     $fbe
        lda     #$01
        sta     $a8
        jsr     parse_hex_word
        lda     $a8
        inca
        jsr     add_a_to_address
        lda     $7d
        sta     $75
        lda     $7e
        sta     $76
        jsr     address_in_range
        bne     $fe9
        lda     $76
        jsr     subtract_a_from_address
        lda     $75
        sub     $73
        bne     $fe6
        lda     $74
        nega
        bmi     $ff9
        jmp     $0f21
        lda     $76
        sub     $74
        sta     $74
        lda     $75
        sbc     $73
        bne     $fe6
        lda     $74
        bmi     $fe6
        sta     $7e
        lda     $82
        sta     $7d
        jmp     $1089
        bsr     $1007
        jmp     $10c0
        jsr     parse_hex_word
        lda     $7e
        and     #$0f
        cmp     #$00
        bcs     $1037
        cmp     #$07
        bhi     $1037
        asla
        add     $51
        sta     $51
        lda     $83
        cmp     #$2c
        bne     $1093
        rts
        jsr     read_command_char
        cmp     #$2c
        bne     $102c
        clra
        bra     $1060
        inc     $a8
        dec     $7f
        jsr     parse_hex_word
        tst     $7d
        beq     $105e
        bra     $1093
        jsr     read_command_char
        bra     $1045
        jsr     read_command_char
        cmp     #$23
        beq     $10c0
        cmp     #$2c
        beq     $105e
        inc     $a8
        dec     $7f
        jsr     parse_hex_word
        lda     #$10
        tst     $7d
        beq     $105a
        inc     $a8
        add     #$10
        add     $51
        sta     $51
        lda     #$10
        sta     $82
        lda     $83
        cmp     #$2c
        bne     $1089
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$58
        bne     $1093
        lda     $82
        brset   1, $a8, $107e
        add     #$20
        brset   0, $a8, $107e
        add     #$20
        add     $51
        sta     $51
        bra     $1086
        dec     $ab
        jsr     read_command_char
        lda     $83
        cmp     #$0d
        beq     $1096
        cmp     #$2e
        beq     $1084
        jmp     $0f21
        jsr     sub_0e5b
        lda     $51
        jsr     write_memory_byte
        jsr     increment_address
        dec     $a8
        bmi     $10ae
        clrx
        brset   0, $a8, $10aa
        incx
        lda     $7d,x
        bra     $109b
        jsr     sub_0e5b
        jsr     disassemble_line
        tst     $ab
        bne     $10bb
        jmp     $0ef5
        jmp     $0c77
        bra     $1093
        jsr     parse_hex_word
        tst     $7d
        bne     $1093
        dec     $7f
        inc     $a8
        bra     $1086

; mnemonic text table; high bit marks token end
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
        .byte   $a9,$ab,$a4,$38,$37,$24,$11,$25,$27,$28,$29,$22,$24,$2f,$2e,$a5
        .byte   $25,$23,$2c,$2b,$2d,$26,$2a,$20,$01,$21,$00,$10,$ad,$98,$9a,$3f
        .byte   $a1,$33,$a3,$3a,$5a,$a8,$01,$3c,$5c,$ac,$ad,$a6,$ae,$38,$34,$42
        .byte   $30,$9d,$aa,$00,$39,$36,$9c,$80,$81,$a2,$99,$9b,$a7,$8e,$af,$a0
        .byte   $83,$97,$3d,$9f,$8f
        dec     $53
        bmi     $1238
        jsr     clear_breakpoints
        clrx
        lda     $73,x
        sta     $85,x
        lda     $74,x
        sta     $86,x
        incx
        incx
        dec     $53
        bpl     $122a
        jsr     write_crlf
        ldx     #$14
        jsr     write_string
        lda     #$73
        jsr     write_console_char
        lda     #$3d
        jsr     write_console_char
        clr     $82
        jsr     load_breakpoint_address
        beq     $1259
        jsr     write_hex_word_at_73
        ldx     #$41
        jsr     write_string
        ldx     $82
        cpx     #$08
        bls     $124c
        jmp     $0c77
        inc     $52
        bra     $125f
        dec     $53
        bmi     $1277
        bne     $1262
        jsr     sub_0a51
        bne     $1262
        clr     $85,x
        clr     $86,x
        bra     $1238
        jsr     clear_breakpoints
        bra     $1238
        dec     $53
        bmi     $1292
        bne     $12cc
        jsr     sub_0a1f
        ldx     #$04
        jsr     sub_09fc
        jsr     increment_address
        lda     $76
        jsr     write_memory_byte
        jsr     sub_0a05
        jsr     sub_0a51
        beq     $129d
        jmp     $0a69
        inc     $a2
        bset    4, $50
        jsr     sub_0a05
        jsr     sub_0aa6
        tst     $52
        bne     $12cc
        ldx     #$0a
        lda     #$0c
        jmp     $0a6c
        ldx     $53
        decx
        bmi     $12d3
        bne     $12cc
        ldx     $74
        stx     $9b
        beq     $12cc
        jsr     sub_0a05
        ldx     #$a5
        jsr     store_address_pair
        jsr     sub_0a51
        beq     $129d
        inc     $52
        clr     $9b
        jmp     $0c77
        incx
        incx
        bra     $12bb
        ldx     $53
        decx
        bmi     $12e6
        bne     $12cc
        ldx     $74
        stx     $9a
        beq     $12cc
        bra     $129f
        incx
        incx
        bra     $12e0
        ldx     $53
        decx
        bmi     $1349
        decx
        beq     $12f7
        bpl     $1349
        jsr     sub_0a1f
        jsr     address_in_range
        beq     $134b
        clr     $7f
        clr     $80
        jsr     write_crlf
        jsr     write_hex_word_at_73
        ldx     #$41
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
        ldx     $7f
        jsr     append_disasm_char
        jsr     read_memory_byte
        jsr     write_hex_byte
        lda     #$20
        jsr     write_console_char
        jsr     increment_address
        inc     $80
        brclr   4, $80, $130b
        ldx     #$42
        jsr     write_string
        clrx
        bsr     $134e
        lda     $54,x
        jsr     write_console_char
        incx
        cpx     #$0f
        bls     $133b
        bra     $12f7
        inc     $52
        jmp     $0c77
        jsr     sub_0800
        tst     $ad
        beq     $1374
        clr     $ad
        lda     $ffe3
        and     #$7f
        cmp     #$13
        bne     $1370
        jsr     sub_0800
        ldx     $ffe0
        stx     $b1
        brclr   0, $b1, $1360
        lda     $ffe3
        and     #$7f
        cmp     #$18
        beq     $137d
        rts
        jsr     write_crlf
        ldx     #$20
        jsr     sub_08ae
        jmp     $0c77
        inc     $52
        bra     $137d
sub_1384:
        jsr     sub_0888
        jsr     read_command_line
        jsr     parse_hex_word
        dec     $7f
        beq     $13b0
        clrx
        lda     $13e7,x
        beq     $13c4
        incx
        cmp     $83
        bne     $1392
        lda     $7e
        jsr     write_memory_byte
        tst     $82
        beq     $13b0
        jsr     decrement_address
        lda     $7d
        jsr     write_memory_byte
        jsr     increment_address
        ldx     $80
        lda     $83
        cmp     #$3d
        beq     $13de
        cmp     #$5e
        beq     $13c9
        cmp     #$0d
        beq     $13d3
        cmp     #$2e
        beq     $13c6
        inc     $52
        lda     $83
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
        tst     $82
        beq     $13c6
        jsr     decrement_address
        bra     $13c6
        .byte   $5e
        tst     $2e
        brclr   6, $00, $1427
        comx
        bne     $1451
        clr     $82
        jsr     write_crlf
        jsr     write_hex_word_at_73
        bsr     $1384
        tst     $52
        bne     $1453
        cmp     #$2e
        bne     $13f2
        bra     $1453
        ldx     $53
        bne     $1451
        stx     $80
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
        stx     $82
        jsr     write_crlf
        ldx     $80
        lda     $08e8,x
        jsr     sub_0909
        jsr     write_console_char
        jsr     sub_1384
        tst     $52
        bne     $1453
        cmp     #$2e
        bne     $1408
        bra     $1453
        ldx     $53
        cpx     #$03
        bne     $1451
        jsr     address_in_range
        beq     $1453
        lda     $78
        jsr     write_memory_byte
        jsr     increment_address
        bra     $1442
        inc     $52
        jmp     $0c77
        inc     $52
        jmp     $0c77
        jsr     write_crlf
        lda     $83
        cmp     #$0d
        beq     $1456
        cmp     #$20
        bne     $1456
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #$54
        bne     $1456
        bset    0, $a3
        bra     $1476
        clr     $a8
        jsr     read_console_char_echo
        cmp     #$53
        bne     $1478
        jsr     read_console_char_echo
        cmp     #$39
        beq     $148c
        cmp     #$31
        bne     $1478
        bra     $148e
        inc     $a8
        clr     $a7
        bsr     $14c2
        sub     #$03
        sta     $80
        bsr     $14c2
        sta     $73
        bsr     $14c2
        sta     $74
        dec     $80
        bmi     $14ac
        bsr     $14c2
        jsr     write_memory_byte
        jsr     increment_address
        bra     $149e
        ldx     $a7
        stx     $80
        bsr     $14c2
        tst     $a8
        bne     $14bd
        coma
        cmp     $80
        beq     $1478
        inc     $52
        clr     $a3
        jmp     $0c77
        clr     $7e
        bsr     $14cf
        bsr     $14cf
        add     $a7
        sta     $a7
        lda     $7e
        rts
        jsr     read_console_char_echo
        jsr     parse_hex_digit
        tst     $aa
        bmi     $14bb
        rts
        lda     $a4
        bclr    7, $50
        cmp     #$ff
        bne     $14e5
        bset    0, $50
        rti
        bit     #$01
        bne     $14ee
        add     #$03
        bset    7, $50
        swi
        bsr     $14f0
        add     #$02
        bra     $14dc
        inc     $52
        jmp     $0c77
        bra     $14f0
reset_handler:
        lda     #$ff
        sta     $af
        clr     $50
        bset    2, $50
        lda     #$fa
        sta     $a4
        clr     $73
        add     #$01
        sta     $74
        lda     #$e8
        jsr     write_memory_byte
        clr     $a3
        clr     $ad
        jsr     clear_breakpoints
        lda     #$ff
        deca
        bne     $151b
        lda     #$0c
        sta     $ac
        jsr     init_serial_or_timer
        clrx
        jsr     write_crlf
        bclr    1, $a3
        clr     $9b
        clr     $52
        clr     $9a
        clr     $a2
        clr     $50
        bset    2, $50
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
        ora     $ac
        sta     $ffe1
        rts
swi_handler:
        bclr    0, $50
        brset   7, $50, $14f9
        lda     $ffe4
        deca
        sta     $a4
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
        bset    5, $50
        brclr   4, $50, $158e
        ldx     #$0c
        lda     #$0a
        jsr     sub_0a8d
        ldx     #$0a
        jsr     sub_0a36
        bclr    3, $50
        brclr   3, $50, $1594
        jsr     sub_0a8a
        jsr     sub_0a0c
        jsr     sub_0a2b
        brset   5, $50, $15ec
        clr     $50
        bset    2, $50
        jsr     sub_0a51
        bne     $15c6
        lda     $9b
        sub     #$01
        bcs     $15be
        lda     $a5
        cmp     $73
        bne     $15ba
        lda     $a6
        cmp     $74
        bne     $15ba
        dec     $9b
        tst     $9b
        bne     $15e9
        ldx     #$14
        jsr     write_crlf
        jmp     $1529
        tst     $a2
        bne     $15d9
        lda     $9a
        sub     #$01
        bcs     $15d2
        bne     $15de
        jsr     disassemble_line
        ldx     #$13
        bra     $15c3
        clr     $a2
        jmp     $0a69
        dec     $9a
        jsr     disassemble_line
        jsr     sub_08b1
        jmp     $129f
        jmp     $129d
        jsr     init_serial_or_timer
        jsr     write_crlf
        ldx     #$1a
        bra     $15c3
        lda     $a4
        sub     #$05
        sta     $a4
        ldx     #$06
        stx     $82
        jsr     sub_09f5
        sta     $75
        txa
        sub     #$05
        tax
        jsr     sub_09fc
        ldx     $82
        incx
        cpx     #$08
        bls     $15fe
        jsr     sub_09d9
        jsr     sub_0a0c
        jmp     $14da
        inc     $52
        jmp     $0c77
        clrx
        jsr     write_crlf
        jsr     write_crlf
        lda     $16d7,x
        beq     $1633
        jsr     write_console_char
        incx
        bra     $1628
        clrx
        jsr     write_crlf
        lda     $1785,x
        beq     $1642
        jsr     write_console_char
        incx
        bra     $1637
        clrx
        jsr     write_crlf
        lda     $17b2,x
        beq     $1651
        jsr     write_console_char
        incx
        bra     $1646
        clrx
        jsr     write_crlf
        lda     $182e,x
        beq     $1660
        jsr     write_console_char
        incx
        bra     $1655
        clrx
        jsr     write_crlf
        lda     $18c2,x
        beq     $166f
        jsr     write_console_char
        incx
        bra     $1664
        jmp     $0c77

; command token table; high bit marks token end
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
        .byte   "EVSbug-HC05 REV 1.2",$00
        .byte   "Brkpt",$00
        .byte   "Abort",$00
        .byte   "Regs ",$00
        .byte   "ILLEGAL/INSUFFICIENT ENTRY",$00
        .byte   "    ",$00
        .byte   "BREAK = Abort command, ",$0d,$0a
        .byte   "CTRL-S = Freeze screen, CTRL-X = Cancel command line",$0d,$0a
        .byte   "ASM <START ADDR>- Assembler/disassembler",$0d,$0a
        .byte   "BF <START ADDR> <END ADDR> <DATA>- Block fill memory",$00
        .byte   "BR [<ADDR1 - ADDR5>]- Set 1 to 5 breakpoints",$00
        .byte   "G [<START ADDR>]- Execute user program",$0d,$0a
        .byte   "LOAD T - Download from port to memory",$0d,$0a
        .byte   "MD <START ADDR> [<END ADDR>]- Display memory",$00
        .byte   "MM <ADDRESS>- Modify memory",$0d,$0a
        .byte   "NOBR [<ADDR1 - ADDR5>]- Remove breakpoints",$0d,$0a
        .byte   "P [<COUNT>]- Proceed 1-FF times through a breakpoint",$0d,$0a
        .byte   "RD- Register display",$00
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
