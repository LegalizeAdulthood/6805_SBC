#define adca adc
#define adda add
#define anda and
#define cmpa cmp
#define eora eor
#define sbca sbc
#define suba sub
#define fcb .byte

        .org    $0000
        .byte   $00
        .org    $0800
        sta     $ae
        lda     #$00
        sta     $fff0
        lda     $ae
        rts
        stx     $aa
        jsr     $0800
        ldx     $ffe1
        stx     $b1
        brset   2, $b1, $850
        ldx     $ffe0
        stx     $b1
        brclr   0, $b1, $80c
        lda     $ffe3
        anda    #$7f
        bra     $834
        stx     $aa
        ldx     $ffe0
        stx     $b1
        brclr   0, $b1, $834
        ldx     #$ff
        stx     $ad
        sta     $ffe3
        brset   1, $a3, $84d
        jsr     $0800
        ldx     $ffe0
        stx     $b1
        brclr   6, $b1, $83a
        ldx     $ffe1
        stx     $b1
        brset   2, $b1, $850
        ldx     $aa
        rts
        lda     $ffe3
        jsr     $153a
        clr     $a3
        jmp     $0c77
        sta     $84
        adda    $a7
        sta     $a7
        lda     $84
        bsr     $86b
        lda     $84
        anda    #$0f
        bra     $86f
        lsra
        lsra
        lsra
        lsra
        adda    #$30
        cmpa    #$39
        bls     $877
        adda    #$07
        jsr     $0826
        rts
        lda     $73
        anda    #$ff
        jsr     $085b
        lda     $74
        jsr     $085b
        rts
        lda     #$3d
        jsr     $0826
        jsr     $0965
        tst     $82
        beq     $89f
        anda    #$ff
        jsr     $085b
        jsr     $098b
        jsr     $0965
        jsr     $085b
        rts
        lda     $1691,x
        beq     $8a2
        jsr     $0826
        incx
        bra     $8a3
        jsr     $08a3
        jsr     $08ee
        clrx
        jsr     $09bb
        clr     $82
        jsr     $08d6
        incx
        stx     $84
        ldx     #$41
        jsr     $08a3
        ldx     $84
        lda     $08e8,x
        beq     $932
        bsr     $909
        jsr     $0826
        jsr     $0888
        bra     $8bd
        lda     #$53
        jsr     $0826
        lda     #$3d
        jsr     $0826
        lda     $74
        adda    #$05
        jsr     $085b
        rts
        comx
        negx
        fcb     $41
        aslx
        coma
        brset   0, $a6, $8fd
        jsr     $0826
        lda     #$0a
        jsr     $0826
        rts
        brset   0, $00, $8fc
        brset   0, $00, $8ff
        brset   0, $00, $933
        fcb     $31
        fcb     $31
        asla
        rola
        fcb     $4e
        decx
        coma
        stx     $84
        tax
        lda     $a4
        clr     $82
        clr     $73
        cpx     #$50
        bne     $91a
        inc     $82
        adda    #$04
        cpx     #$58
        bne     $920
        adda    #$03
        cpx     #$41
        bne     $926
        adda    #$02
        cpx     #$43
        bne     $92c
        adda    #$01
        sta     $74
        txa
        ldx     $84
        rts
        ldx     #$41
        jsr     $08a3
        lda     $a4
        adda    #$01
        sta     $74
        clr     $73
        jsr     $0965
        sta     $84
        ldx     #$ff
        lda     #$08
        sta     $82
        incx
        lda     #$2e
        asl     $84
        bcc     $954
        lda     $0901,x
        jsr     $0826
        dec     $82
        bne     $94a
        rts
        sta     $84
        jsr     $0800
        lda     #$c7
        bra     $96a
        lda     #$c6
        jsr     $0800
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
        jsr     $9c
        bclr    1, $50
        bset    2, $50
        rts
        lda     #$01
        adda    $74
        sta     $74
        clra
        adca    $73
        sta     $73
        rts
        lda     #$01
        sta     $84
        lda     $74
        suba    $84
        sta     $74
        lda     $73
        sbca    #$00
        bra     $994
        lda     $75
        cmpa    $73
        bcs     $9b8
        bhi     $9b7
        lda     $76
        cmpa    $74
        bcs     $9b8
        lda     #$01
        rts
        clra
        bra     $9b7
        clr     $73
        lda     $a4
        sta     $74
        txa
        jsr     $098d
        rts
        jsr     $09bb
        jsr     $0965
        anda    #$ff
        sta     $75
        jsr     $098b
        jsr     $0965
        sta     $76
        rts
        lda     #$fc
        sta     $74
        lda     #$ff
        sta     $73
        bra     $9c9
        lda     #$f8
        bsr     $9db
        bsr     $a2b
        ldx     #$91
        jsr     $0a21
        lda     #$fa
        bsr     $9db
        bsr     $a2b
        rts
        jsr     $09bb
        jsr     $0965
        rts
        jsr     $09bb
        lda     $75
        jsr     $095c
        rts
        ldx     #$04
        bsr     $9c6
        bsr     $a2b
        rts
        ldx     #$04
        jsr     $09bb
        lda     $75
        jsr     $095c
        jsr     $098b
        lda     $76
        jsr     $095c
        rts
        ldx     #$75
        lda     $73
        anda    #$ff
        sta     ,x
        lda     $74
        sta     $01,x
        rts
        ldx     #$75
        lda     ,x
        sta     $73
        lda     $01,x
        sta     $74
        rts
        clrx
        clr     $85,x
        incx
        cpx     #$0d
        bls     $a36
        rts
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
        lda     #$08
        sta     $83
        clrx
        lda     $73
        cmpa    $85,x
        bne     $a62
        lda     $74
        cmpa    $86,x
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
        jsr     $0965
        lsrx
        sta     $93,x
        lda     #$83
        jsr     $095c
        ldx     $82
        cpx     $83
        bls     $a70
        jmp     $14da
        ldx     #$08
        clra
        stx     $82
        sta     $83
        bsr     $a3e
        beq     $a9b
        lsrx
        lda     $93,x
        jsr     $095c
        lda     $82
        suba    #$04
        sta     $82
        cmpa    $83
        bpl     $a91
        rts
        clr     $a8
        clr     $a9
        jsr     $0965
        sta     $84
        anda    #$0f
        tax
        lda     $84
        anda    #$f0
        bne     $abb
        jmp     $0bcc
        cmpa    #$10
        beq     $b2c
        cmpa    #$20
        bne     $ac6
        jmp     $0bc8
        cmpa    #$70
        bhi     $b02
        tstx
        beq     $ae8
        cmpa    #$40
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
        cmpa    #$30
        beq     $b2c
        cmpa    #$40
        beq     $afc
        cmpa    #$50
        beq     $afe
        bset    3, $a9
        cmpa    #$60
        beq     $b2c
        bra     $b12
        bset    0, $a9
        bset    1, $a9
        bra     $b12
        cmpa    #$80
        beq     $b4b
        cmpa    #$90
        bne     $b16
        cpx     #$06
        bls     $ae5
        cpx     #$0e
        beq     $ae5
        lda     #$01
        bra     $b7c
        cmpa    #$a0
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
        cmpa    #$b0
        beq     $ba2
        cmpa    #$c0
        beq     $b72
        bset    3, $a9
        cmpa    #$d0
        beq     $b72
        cmpa    #$e0
        beq     $ba2
        bsr     $b6b
        bne     $b12
        ldx     #$03
        jsr     $09f5
        bra     $bb9
        decx
        bmi     $b60
        beq     $b64
        cpx     #$02
        bne     $b5a
        jsr     $09d9
        clrx
        bra     $b92
        cpx     #$0c
        bls     $ae5
        bra     $b12
        ldx     #$09
        bra     $b66
        ldx     #$06
        jsr     $0a07
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
        jsr     $098d
        ldx     #$8f
        jsr     $0a21
        rts
        clrx
        cmpa    #$c0
        beq     $b8c
        ldx     #$03
        jsr     $098b
        jsr     $09c9
        clra
        tstx
        beq     $b99
        jsr     $09f5
        sta     $83
        jsr     $0a2b
        lda     $83
        bra     $b7c
        inc     $a8
        bsr     $b6b
        bne     $bae
        cmpa    #$a0
        beq     $bc8
        bhi     $bb2
        lda     #$02
        bra     $b7c
        cmpa    #$b0
        bne     $bbf
        jsr     $09d0
        clr     $75
        clr     $76
        bra     $b99
        clr     $75
        ldx     #$03
        jsr     $09d0
        bra     $b92
        lda     #$01
        bra     $bce
        lda     #$02
        sta     $a8
        inca
        jsr     $098d
        ldx     #$91
        jsr     $0a21
        jsr     $0997
        jsr     $0965
        tax
        jsr     $098b
        txa
        tsta
        bpl     $b7c
        dec     $73
        bra     $b7c
        jsr     $08ee
        lda     #$3e
        jsr     $0826
        clrx
        jsr     $080a
        cmpa    #$18
        beq     $beb
        cmpa    #$08
        bne     $c06
        cpx     #$00
        beq     $c04
        decx
        bra     $bf4
        sta     $54,x
        incx
        cpx     #$1e
        beq     $c11
        cmpa    #$0d
        bne     $bf4
        lda     #$0d
        sta     $54,x
        clr     $7f
        rts
        stx     $84
        ldx     $7f
        lda     $54,x
        inc     $7f
        ldx     $84
        sta     $83
        rts
        cmpa    #$60
        bls     $c2d
        suba    #$20
        sta     $83
        rts
        clr     $7d
        clr     $7e
        jsr     $0c18
        cmpa    #$24
        bne     $c3c
        jsr     $0c18
        jsr     $0c25
        clr     $aa
        dec     $aa
        suba    #$30
        bmi     $c72
        cmpa    #$09
        bls     $c55
        suba    #$07
        cmpa    #$09
        bls     $c72
        cmpa    #$0f
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
        jsr     $08ee
        tst     $52
        beq     $c89
        ldx     #$26
        jsr     $08a3
        jsr     $08ee
        clr     $52
        jsr     $0bee
        clr     $53
        clr     $51
        ldx     #$ff
        jsr     $0c18
        cmpa    #$0d
        beq     $c77
        jsr     $0c25
        incx
        lda     $1672,x
        beq     $c75
        anda    #$7f
        cmpa    $83
        beq     $cb4
        clr     $7f
        inc     $51
        lda     $1672,x
        bmi     $c92
        incx
        bra     $cac
        lda     $1672,x
        bpl     $c92
        jsr     $0c18
        cmpa    #$0d
        beq     $ce6
        cmpa    #$20
        bne     $ca8
        lda     $51
        cmpa    #$04
        beq     $ce6
        jsr     $0c2e
        ldx     $53
        aslx
        cpx     #$0a
        bhi     $c75
        lda     $7d
        sta     $71,x
        lda     $7e
        sta     $72,x
        lda     $83
        cmpa    #$20
        beq     $cca
        cmpa    #$0d
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
        ldx     #$a5
        jsr     $0a21
        jsr     $08ee
        jsr     $087b
        lda     #$20
        ldx     #$1d
        sta     $54,x
        decx
        bpl     $d23
        jsr     $0aa6
        jsr     $0e5b
        lda     $a8
        sta     $84
        sta     $53
        ldx     #$02
        stx     $7f
        jsr     $0e64
        inc     $7f
        jsr     $098b
        dec     $84
        bpl     $d38
        jsr     $0e5b
        tst     $52
        beq     $d54
        jsr     $0997
        inc     $a8
        ldx     #$26
        bra     $d8c
        jsr     $0965
        anda    #$0f
        tax
        jsr     $0965
        cmpa    #$0f
        bhi     $d8e
        sta     $84
        ldx     #$17
        stx     $7f
        jsr     $0e85
        jsr     $0e90
        clrx
        stx     $80
        ldx     #$12
        stx     $7f
        lda     $84
        brclr   0, $84, $d7b
        inc     $80
        lsra
        jsr     $0e77
        jsr     $0e85
        jsr     $0e61
        clr     $a8
        ldx     $80
        ldx     $0ebb,x
        bra     $dcf
        cmpa    #$1f
        bhi     $d9a
        suba    #$10
        sta     $84
        ldx     #$02
        bra     $d6e
        cmpa    #$2f
        bhi     $da3
        txa
        adda    #$05
        bra     $dc1
        cmpa    #$7f
        bhi     $dac
        ldx     $0e9b,x
        bra     $dcf
        cmpa    #$9f
        bhi     $dbb
        cmpa    #$8f
        bne     $db6
        ldx     #$02
        ldx     $0ed0,x
        bra     $dcf
        cmpa    #$ad
        bne     $dcc
        lda     #$04
        sta     $80
        ldx     #$12
        stx     $7f
        jsr     $0e8e
        bra     $d85
        ldx     $0eab,x
        stx     $51
        clr     $84
        clrx
        lda     $1155,x
        cmpa    #$0f
        bhi     $dde
        incx
        bra     $dd4
        anda    #$0f
        sta     $80
        lda     $84
        cmpa    $51
        beq     $dec
        inc     $84
        bra     $ddb
        lda     $1155,x
        anda    #$0f
        cmpa    $80
        bhi     $e0d
        lda     $10cd,x
        anda    #$7f
        stx     $82
        sta     $84
        lda     $80
        adda    #$0c
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
        jsr     $09d0
        dec     $a8
        bmi     $e3e
        beq     $e3a
        anda    #$ff
        bsr     $e67
        bra     $e2f
        brclr   3, $a9, $e49
        lda     #$2c
        bsr     $e7f
        lda     #$58
        bsr     $e7f
        clrx
        lda     $54,x
        jsr     $0826
        incx
        cpx     #$1d
        bls     $e4a
        ldx     #$0a
        jsr     $0a36
        clr     $52
        ldx     #$a5
        jsr     $0a2d
        rts
        jsr     $098b
        jsr     $0965
        ldx     $7f
        sta     $83
        bsr     $e73
        lda     $83
        anda    #$0f
        bra     $e77
        lsra
        lsra
        lsra
        lsra
        adda    #$30
        cmpa    #$39
        bls     $e7f
        adda    #$07
        sta     $54,x
        incx
        stx     $7f
        rts
        lda     #$2c
        bsr     $e7f
        lda     #$24
        bsr     $e7f
        rts
        bsr     $e89
        lda     $8f
        anda    #$ff
        bsr     $e67
        lda     $90
        bsr     $e67
        rts
        neg     $00
        bih     $ec0
        bil     $ea1
        fcb     $35
        brset   2, $2d, $ed9
        bls     $ea7
        beq     $eeb
        brset   0, $1f, $eeb
        bra     $ee7
        bhi     $eb2
        brclr   7, $2b, $eef
        bcs     $eb5
        fcb     $32
        brclr   0, $29, $ee3
        bmc     $ef9
        bset    5, $18
        bclr    5, $06
        bset    6, $17
        bclr    4, $0b
        bclr    0, $05
        brclr   3, $15, $ed0
        brclr   4, $0a, $ee1
        bclr    1, $12
        bset    2, $0e
        brclr   6, $37, $f0a
        lsra
        nega
        brset   0, $00, $ed7
        fcb     $41
        bclr    6, $3a
        bset    7, $3b
        ror     $31
        tst     $43
        dec     $53
        bne     $f21
        clr     $ab
        jsr     $0d14
        clr     $a8
        jsr     $0bee
        jsr     $0c18
        cmpa    #$0d
        bne     $efd
        lda     $53
        inca
        jsr     $098d
        bra     $ee6
        cmpa    #$2e
        beq     $f23
        dec     $7f
        clr     $80
        clr     $51
        ldx     #$ff
        jsr     $0c18
        jsr     $0c25
        incx
        lda     $1155,x
        cmpa    #$0f
        bls     $f1b
        anda    #$0f
        inc     $51
        cmpa    $80
        beq     $f26
        bhi     $f0f
        inc     $52
        jmp     $0c77
        lda     $10cd,x
        beq     $f21
        anda    #$7f
        cmpa    $83
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
        cmpa    #$04
        bne     $f6f
        jsr     $0c18
        jsr     $0c25
        cmpa    #$41
        beq     $f65
        cmpa    #$58
        bne     $f72
        lda     #$20
        bra     $f67
        lda     #$10
        adda    $51
        sta     $51
        lda     #$01
        sta     $82
        jsr     $0c18
        cmpa    #$2e
        beq     $f7a
        cmpa    #$0d
        bne     $f83
        lda     $82
        deca
        bne     $f21
        dec     $7f
        bra     $f87
        cmpa    #$20
        bne     $f21
        lda     $82
        asla
        adda    $82
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
        jsr     $0c2e
        tst     $7d
        bne     $fb2
        lda     $83
        cmpa    #$2c
        bne     $fe6
        lda     $7e
        sta     $82
        lda     #$02
        bra     $fbe
        lda     #$01
        sta     $a8
        jsr     $0c2e
        lda     $a8
        inca
        jsr     $098d
        lda     $7d
        sta     $75
        lda     $7e
        sta     $76
        jsr     $09a7
        bne     $fe9
        lda     $76
        jsr     $0999
        lda     $75
        suba    $73
        bne     $fe6
        lda     $74
        nega
        bmi     $ff9
        jmp     $0f21
        lda     $76
        suba    $74
        sta     $74
        lda     $75
        sbca    $73
        bne     $fe6
        lda     $74
        bmi     $fe6
        sta     $7e
        lda     $82
        sta     $7d
        jmp     $1089
        bsr     $1007
        jmp     $10c0
        jsr     $0c2e
        lda     $7e
        anda    #$0f
        cmpa    #$00
        bcs     $1037
        cmpa    #$07
        bhi     $1037
        asla
        adda    $51
        sta     $51
        lda     $83
        cmpa    #$2c
        bne     $1093
        rts
        jsr     $0c18
        cmpa    #$2c
        bne     $102c
        clra
        bra     $1060
        inc     $a8
        dec     $7f
        jsr     $0c2e
        tst     $7d
        beq     $105e
        bra     $1093
        jsr     $0c18
        bra     $1045
        jsr     $0c18
        cmpa    #$23
        beq     $10c0
        cmpa    #$2c
        beq     $105e
        inc     $a8
        dec     $7f
        jsr     $0c2e
        lda     #$10
        tst     $7d
        beq     $105a
        inc     $a8
        adda    #$10
        adda    $51
        sta     $51
        lda     #$10
        sta     $82
        lda     $83
        cmpa    #$2c
        bne     $1089
        jsr     $0c18
        jsr     $0c25
        cmpa    #$58
        bne     $1093
        lda     $82
        brset   1, $a8, $107e
        adda    #$20
        brset   0, $a8, $107e
        adda    #$20
        adda    $51
        sta     $51
        bra     $1086
        dec     $ab
        jsr     $0c18
        lda     $83
        cmpa    #$0d
        beq     $1096
        cmpa    #$2e
        beq     $1084
        jmp     $0f21
        jsr     $0e5b
        lda     $51
        jsr     $095c
        jsr     $098b
        dec     $a8
        bmi     $10ae
        clrx
        brset   0, $a8, $10aa
        incx
        lda     $7d,x
        bra     $109b
        jsr     $0e5b
        jsr     $0d14
        tst     $ab
        bne     $10bb
        jmp     $0ef5
        jmp     $0c77
        bra     $1093
        jsr     $0c2e
        tst     $7d
        bne     $1093
        dec     $7f
        inc     $a8
        bra     $1086
        fcb     $41
        lsra
        cpx     $c44e
        anda    $53cc
        sbca    $4243,x
        cpx     $4cd2
        cpx     $45d1,x
        asla
        coma
        cpx     $d3c9
        cpx     $49c8,x
        jmp     $d44c
        stx     $d34d
        cpx     $c9d3
        fcb     $4e
        bit     $50cc
        fcb     $52
        cmpa    $434c
        sbca    $ce53,x
        fcb     $45
        anda    $5345,x
        anda    $d243,x
        inca
        cpx     $c9d2
        tsta
        suba    $4fcd,x
        negx
        eora    $4445,x
        cpx     $d845
        clra
        sbca    $4643,x
        sbca    $494e
        cpx     $d84a
        tsta
        suba    $53d2,x
        inca
        lsra
        cmpa    $d853
        jmp     $d24d
        fcb     $55
        jmp     $4e45
        sta     $4fd0
        clra
        fcb     $52
        cmpa    $c752
        clra
        jmp     $d253
        suba    $54c9,x
        cpx     $5342,x
        cpx     $45c3
        adca    $54c1
        clra
        suba    $d855,x
        sbca    $57c9
        lsrx
        fcb     $41
        eora    $53d4,x
        aslx
        cmpa    $5741
        rola
        anda    $10000,x
        brclr   0, $72, $11cb
        brclr   0, $72, $115d
        mul
        mul
        brset   0, $01, $1193
        brset   1, $23, $1196
        brclr   0, $32, $1168
        brset   1, $33, $119d
        fcb     $32
        fcb     $32
        brclr   0, $32, $11a1
        fcb     $72
        brclr   0, $32, $11a5
        brclr   0, $32, $11a8
        fcb     $32
        brclr   0, $32, $117b
        fcb     $32
        brclr   0, $32, $1180
        brclr   1, $84, $11b3
        brset   1, $03, $1108
        brclr   0, $02, $11aa
        fcb     $32
        brset   0, $01, $119d
        bset    1, $42
        brclr   0, $72, $1191
        mul
        brclr   0, $72, $1194
        brclr   0, $42, $11a9
        brset   0, $01, $120c
        brset   0, $01, $11ef
        brset   0, $01, $11e2
        bset    1, $00
        brclr   0, $62, $11a6
        fcb     $62
        brset   0, $01, $121b
        fcb     $72
        brclr   0, $42, $11ef
        brset   0, $01, $11c2
        brset   0, $01, $11f5
        brclr   0, $12, $11b6
        brclr   0, $72, $120b
        brset   0, $01, $11fe
        mul
        brclr   0, $12, $11c1
        bset    1, $12
        brset   0, $01, $1237
        brclr   0, $12, $11da
        brclr   0, $62, $11cd
        bclr    1, $62
        brclr   0, $72, $11d1
        bset    1, $00
        brclr   0, $12, $11d6
        mul
        brclr   0, $12, $11d9
        brclr   0, $02, $11ef
        brset   0, $a9, $118a
        anda    #$38
        asr     $24
        bclr    0, $25
        beq     $120f
        bhcs    $120b
        bcc     $121a
        bil     $1192
        bcs     $1212
        bmc     $121c
        bms     $1219
        bpl     $1215
        brclr   0, $21, $11f8
        bset    0, $ad
        clc
        cli
        clr     $a1
        com     $a3
        dec     $5a
        eora    #$01
        inc     $5c
        fcb     $ac
        bsr     $11af
        ldx     #$38
        lsr     $42
        neg     $9d
        ora     #$00
        rol     $36
        rsp
        rti
        rts
        sbca    #$99
        sei
        fcb     $a7
        stop
        fcb     $af
        suba    #$83
        tax
        tst     $9f
        wait
        dec     $53
        bmi     $1238
        jsr     $0a35
        clrx
        lda     $73,x
        sta     $85,x
        lda     $74,x
        sta     $86,x
        incx
        incx
        dec     $53
        bpl     $122a
        jsr     $08ee
        ldx     #$14
        jsr     $08a3
        lda     #$73
        jsr     $0826
        lda     #$3d
        jsr     $0826
        clr     $82
        jsr     $0a3e
        beq     $1259
        jsr     $087b
        ldx     #$41
        jsr     $08a3
        ldx     $82
        cpx     #$08
        bls     $124c
        jmp     $0c77
        inc     $52
        bra     $125f
        dec     $53
        bmi     $1277
        bne     $1262
        jsr     $0a51
        bne     $1262
        clr     $85,x
        clr     $86,x
        bra     $1238
        jsr     $0a35
        bra     $1238
        dec     $53
        bmi     $1292
        bne     $12cc
        jsr     $0a1f
        ldx     #$04
        jsr     $09fc
        jsr     $098b
        lda     $76
        jsr     $095c
        jsr     $0a05
        jsr     $0a51
        beq     $129d
        jmp     $0a69
        inc     $a2
        bset    4, $50
        jsr     $0a05
        jsr     $0aa6
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
        jsr     $0a05
        ldx     #$a5
        jsr     $0a21
        jsr     $0a51
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
        jsr     $0a1f
        jsr     $09a7
        beq     $134b
        clr     $7f
        clr     $80
        jsr     $08ee
        jsr     $087b
        ldx     #$41
        jsr     $08a3
        bsr     $134e
        jsr     $0965
        tsta
        bmi     $131b
        cmpa    #$20
        bcs     $131b
        cmpa    #$7f
        bcs     $131d
        lda     #$2e
        ldx     $7f
        jsr     $0e7f
        jsr     $0965
        jsr     $085b
        lda     #$20
        jsr     $0826
        jsr     $098b
        inc     $80
        brclr   4, $80, $130b
        ldx     #$42
        jsr     $08a3
        clrx
        bsr     $134e
        lda     $54,x
        jsr     $0826
        incx
        cpx     #$0f
        bls     $133b
        bra     $12f7
        inc     $52
        jmp     $0c77
        jsr     $0800
        tst     $ad
        beq     $1374
        clr     $ad
        lda     $ffe3
        anda    #$7f
        cmpa    #$13
        bne     $1370
        jsr     $0800
        ldx     $ffe0
        stx     $b1
        brclr   0, $b1, $1360
        lda     $ffe3
        anda    #$7f
        cmpa    #$18
        beq     $137d
        rts
        jsr     $08ee
        ldx     #$20
        jsr     $08ae
        jmp     $0c77
        inc     $52
        bra     $137d
        jsr     $0888
        jsr     $0bee
        jsr     $0c2e
        dec     $7f
        beq     $13b0
        clrx
        lda     $13e7,x
        beq     $13c4
        incx
        cmpa    $83
        bne     $1392
        lda     $7e
        jsr     $095c
        tst     $82
        beq     $13b0
        jsr     $0997
        lda     $7d
        jsr     $095c
        jsr     $098b
        ldx     $80
        lda     $83
        cmpa    #$3d
        beq     $13de
        cmpa    #$5e
        beq     $13c9
        cmpa    #$0d
        beq     $13d3
        cmpa    #$2e
        beq     $13c6
        inc     $52
        lda     $83
        rts
        jsr     $0997
        decx
        bpl     $13c6
        ldx     #$04
        bra     $13c6
        jsr     $098b
        incx
        cpx     #$04
        bls     $13c6
        clrx
        bra     $13c6
        tst     $82
        beq     $13c6
        jsr     $0997
        bra     $13c6
        fcb     $5e
        tst     $2e
        brclr   6, $00, $1427
        comx
        bne     $1451
        clr     $82
        jsr     $08ee
        jsr     $087b
        bsr     $1384
        tst     $52
        bne     $1453
        cmpa    #$2e
        bne     $13f2
        bra     $1453
        ldx     $53
        bne     $1451
        stx     $80
        jsr     $09bb
        tstx
        bne     $141a
        jsr     $08ee
        jsr     $08d6
        bsr     $13b0
        bra     $1408
        cpx     #$04
        beq     $141f
        clrx
        stx     $82
        jsr     $08ee
        ldx     $80
        lda     $08e8,x
        jsr     $0909
        jsr     $0826
        jsr     $1384
        tst     $52
        bne     $1453
        cmpa    #$2e
        bne     $1408
        bra     $1453
        ldx     $53
        cpx     #$03
        bne     $1451
        jsr     $09a7
        beq     $1453
        lda     $78
        jsr     $095c
        jsr     $098b
        bra     $1442
        inc     $52
        jmp     $0c77
        inc     $52
        jmp     $0c77
        jsr     $08ee
        lda     $83
        cmpa    #$0d
        beq     $1456
        cmpa    #$20
        bne     $1456
        jsr     $0c18
        jsr     $0c25
        cmpa    #$54
        bne     $1456
        bset    0, $a3
        bra     $1476
        clr     $a8
        jsr     $080a
        cmpa    #$53
        bne     $1478
        jsr     $080a
        cmpa    #$39
        beq     $148c
        cmpa    #$31
        bne     $1478
        bra     $148e
        inc     $a8
        clr     $a7
        bsr     $14c2
        suba    #$03
        sta     $80
        bsr     $14c2
        sta     $73
        bsr     $14c2
        sta     $74
        dec     $80
        bmi     $14ac
        bsr     $14c2
        jsr     $095c
        jsr     $098b
        bra     $149e
        ldx     $a7
        stx     $80
        bsr     $14c2
        tst     $a8
        bne     $14bd
        coma
        cmpa    $80
        beq     $1478
        inc     $52
        clr     $a3
        jmp     $0c77
        clr     $7e
        bsr     $14cf
        bsr     $14cf
        adda    $a7
        sta     $a7
        lda     $7e
        rts
        jsr     $080a
        jsr     $0c3c
        tst     $aa
        bmi     $14bb
        rts
        lda     $a4
        bclr    7, $50
        cmpa    #$ff
        bne     $14e5
        bset    0, $50
        rti
        bit     #$01
        bne     $14ee
        adda    #$03
        bset    7, $50
        swi
        bsr     $14f0
        adda    #$02
        bra     $14dc
        inc     $52
        jmp     $0c77
        bra     $14f0
        lda     #$ff
        sta     $af
        clr     $50
        bset    2, $50
        lda     #$fa
        sta     $a4
        clr     $73
        adda    #$01
        sta     $74
        lda     #$e8
        jsr     $095c
        clr     $a3
        clr     $ad
        jsr     $0a35
        lda     #$ff
        deca
        bne     $151b
        lda     #$0c
        sta     $ac
        jsr     $153a
        clrx
        jsr     $08ee
        bclr    1, $a3
        clr     $9b
        clr     $52
        clr     $9a
        clr     $a2
        clr     $50
        bset    2, $50
        jmp     $137a
        lda     $ffe1
        ora     #$80
        sta     $ffe1
        lda     #$e0
        sta     $ffe1
        lda     $ffe1
        anda    #$7f
        sta     $ffe1
        lda     #$40
        tax
        ora     $ac
        sta     $ffe1
        rts
        bclr    0, $50
        brset   7, $50, $14f9
        lda     $ffe4
        deca
        sta     $a4
        rsp
        jsr     $0a05
        jsr     $0997
        jsr     $0a1f
        lda     #$0c
        jsr     $0a53
        beq     $157d
        jsr     $0965
        cmpa    #$83
        beq     $15f6
        bset    5, $50
        brclr   4, $50, $158e
        ldx     #$0c
        lda     #$0a
        jsr     $0a8d
        ldx     #$0a
        jsr     $0a36
        bclr    3, $50
        brclr   3, $50, $1594
        jsr     $0a8a
        jsr     $0a0c
        jsr     $0a2b
        brset   5, $50, $15ec
        clr     $50
        bset    2, $50
        jsr     $0a51
        bne     $15c6
        lda     $9b
        suba    #$01
        bcs     $15be
        lda     $a5
        cmpa    $73
        bne     $15ba
        lda     $a6
        cmpa    $74
        bne     $15ba
        dec     $9b
        tst     $9b
        bne     $15e9
        ldx     #$14
        jsr     $08ee
        jmp     $1529
        tst     $a2
        bne     $15d9
        lda     $9a
        suba    #$01
        bcs     $15d2
        bne     $15de
        jsr     $0d14
        ldx     #$13
        bra     $15c3
        clr     $a2
        jmp     $0a69
        dec     $9a
        jsr     $0d14
        jsr     $08b1
        jmp     $129f
        jmp     $129d
        jsr     $153a
        jsr     $08ee
        ldx     #$1a
        bra     $15c3
        lda     $a4
        suba    #$05
        sta     $a4
        ldx     #$06
        stx     $82
        jsr     $09f5
        sta     $75
        txa
        suba    #$05
        tax
        jsr     $09fc
        ldx     $82
        incx
        cpx     #$08
        bls     $15fe
        jsr     $09d9
        jsr     $0a0c
        jmp     $14da
        inc     $52
        jmp     $0c77
        clrx
        jsr     $08ee
        jsr     $08ee
        lda     $16d7,x
        beq     $1633
        jsr     $0826
        incx
        bra     $1628
        clrx
        jsr     $08ee
        lda     $1785,x
        beq     $1642
        jsr     $0826
        incx
        bra     $1637
        clrx
        jsr     $08ee
        lda     $17b2,x
        beq     $1651
        jsr     $0826
        incx
        bra     $1646
        clrx
        jsr     $08ee
        lda     $182e,x
        beq     $1660
        jsr     $0826
        incx
        bra     $1655
        clrx
        jsr     $08ee
        lda     $18c2,x
        beq     $166f
        jsr     $0826
        incx
        bra     $1664
        jmp     $0c77
        fcb     $41
        comx
        jsr     $42c6
        mul
        sbca    $c74c,x
        clra
        fcb     $41
        anda    $4dc4
        tsta
        jsr     $4e4f
        mul
        sbca    $d052,x
        anda    $52cd
        anda    $4845,x
        inca
        suba    $10045,x
        rorx
        comx
        fcb     $62
        fcb     $75
        asr     $2d,x
        asla
        coma
        neg     $35
        bra     $16f0
        fcb     $45
        rorx
        bra     $16d3
        bil     $16d6
        brset   0, $42, $1719
        fcb     $6b
        neg     ,x
        lsr     ,x
        brset   0, $41, $170f
        clr     $72,x
        lsr     ,x
        brset   0, $52, $1718
        asr     $73,x
        bra     $16b7
        rola
        inca
        inca
        fcb     $45
        asra
        fcb     $41
        inca
        bih     $1709
        fcb     $4e
        comx
        fcb     $55
        rora
        rora
        rola
        coma
        rola
        fcb     $45
        fcb     $4e
        lsrx
        bra     $1712
        fcb     $4e
        lsrx
        fcb     $52
        rolx
        brset   0, $20, $16f4
        bra     $16f6
        brset   0, $42, $172b
        fcb     $45
        fcb     $41
        fcb     $4b
        bra     $171b
        bra     $1721
        fcb     $62
        clr     $72,x
        lsr     ,x
        bra     $1749
        clr     $6d,x
        tst     $61,x
        fcb     $6e,$64
        bmc     $170e
        brclr   6, $0a, $1734
        lsrx
        fcb     $52
        inca
        bms     $1749
        bra     $1735
        bra     $1740
        fcb     $72
        fcb     $65
        fcb     $65
        dec     ,x
        fcb     $65
        bra     $1774
        com     $72,x
        fcb     $65
        fcb     $65
        fcb     $6e,$2c
        bra     $174c
        lsrx
        fcb     $52
        inca
        bms     $1766
        bra     $174d
        bra     $1755
        fcb     $61
        fcb     $6e,$63
        fcb     $65
        inc     $20,x
        com     $6f,x
        tst     $6d,x
        fcb     $61
        fcb     $6e,$64
        bra     $178d
        rol     $6e,x
        fcb     $65
        brclr   6, $0a, $1768
        comx
        tsta
        bra     $1767
        comx
        lsrx
        fcb     $41
        fcb     $52
        lsrx
        bra     $1773
        lsra
        lsra
        fcb     $52
        fcb     $3e
        bms     $1758
        fcb     $41
        com     ,x
        com     ,x
        fcb     $65
        tst     $62,x
        inc     $65,x
        fcb     $72
        bih     $17a7
        rol     $73,x
        fcb     $61
        com     ,x
        com     ,x
        fcb     $65
        tst     $62,x
        inc     $65,x
        fcb     $72
        brclr   6, $0a, $1793
        rora
        bra     $1790
        comx
        lsrx
        fcb     $41
        fcb     $52
        lsrx
        bra     $179c
        lsra
        lsra
        fcb     $52
        fcb     $3e
        bra     $179d
        fcb     $45
        fcb     $4e
        lsra
        bra     $17a7
        lsra
        lsra
        fcb     $52
        fcb     $3e
        bra     $17a8
        lsra
        fcb     $41
        lsrx
        fcb     $41
        fcb     $3e
        bms     $1793
        mul
        inc     $6f,x
        com     $6b,x
        bra     $17e0
        rol     $6c,x
        inc     $20,x
        tst     $65,x
        tst     $6f,x
        fcb     $72
        rol     ,x
        brset   0, $42, $17d9
        bra     $17e4
        inc     $41
        lsra
        lsra
        fcb     $52
        fcb     $31
        bra     $17be
        bra     $17d4
        lsra
        lsra
        fcb     $52
        fcb     $35
        fcb     $3e
        tstx
        bms     $17bb
        comx
        fcb     $65
        lsr     ,x
        bra     $17d1
        bra     $1816
        clr     $20,x
        fcb     $35
        bra     $1809
        fcb     $72
        fcb     $65
        fcb     $61
        fcb     $6b
        neg     ,x
        clr     $69,x
        fcb     $6e,$74
        com     ,x
        brset   0, $47, $17d4
        fcb     $5b
        inc     $53
        lsrx
        fcb     $41
        fcb     $52
        lsrx
        bra     $17fe
        lsra
        lsra
        fcb     $52
        fcb     $3e
        tstx
        bms     $17e4
        fcb     $45
        asl     ,x
        fcb     $65
        com     $75,x
        lsr     ,x
        fcb     $65
        bra     $1842
        com     ,x
        fcb     $65
        fcb     $72
        bra     $1842
        fcb     $72
        clr     $67,x
        fcb     $72
        fcb     $61
        tst     $0d,x
        brset   5, $4c, $182b
        fcb     $41
        lsra
        bra     $1834
        bra     $180f
        bra     $1828
        clr     $77,x
        fcb     $6e,$6c
        clr     $61,x
        lsr     $20,x
        ror     $72,x
        clr     $6d,x
        bra     $1862
        clr     $72,x
        lsr     ,x
        bra     $186b
        clr     $20,x
        tst     $65,x
        tst     $6f,x
        fcb     $72
        rol     ,x
        brclr   6, $0a, $184f
        lsra
        bra     $1841
        comx
        lsrx
        fcb     $41
        fcb     $52
        lsrx
        bra     $184d
        lsra
        lsra
        fcb     $52
        fcb     $3e
        bra     $186d
        inc     $45
        fcb     $4e
        lsra
        bra     $1859
        lsra
        lsra
        fcb     $52
        fcb     $3e
        tstx
        bms     $183f
        lsra
        rol     $73,x
        neg     ,x
        inc     $61,x
        rol     ,x
        bra     $1895
        fcb     $65
        tst     $6f,x
        fcb     $72
        rol     ,x
        brset   0, $4d, $187d
        bra     $186e
        fcb     $41
        lsra
        lsra
        fcb     $52
        fcb     $45
        comx
        comx
        fcb     $3e
        bms     $185c
        tsta
        clr     $64,x
        rol     $66,x
        rol     ,x
        bra     $18b1
        fcb     $65
        tst     $6f,x
        fcb     $72
        rol     ,x
        brclr   6, $0a, $189a
        clra
        mul
        fcb     $52
        bra     $18ac
        inc     $41
        lsra
        lsra
        fcb     $52
        fcb     $31
        bra     $1886
        bra     $189c
        lsra
        lsra
        fcb     $52
        fcb     $35
        fcb     $3e
        tstx
        bms     $1883
        fcb     $52
        fcb     $65
        tst     $6f,x
        ror     ,x
        fcb     $65
        bra     $18cd
        fcb     $72
        fcb     $65
        fcb     $61
        fcb     $6b
        neg     ,x
        clr     $69,x
        fcb     $6e,$74
        com     ,x
        brclr   6, $0a, $18c8
        bra     $18d5
        inc     $43
        clra
        fcb     $55
        fcb     $4e
        lsrx
        fcb     $3e
        tstx
        bms     $18a4
        negx
        fcb     $72
        clr     $63,x
        fcb     $65
        fcb     $65
        lsr     $20,x
        fcb     $31
        bms     $18d5
        rora
        bra     $1906
        rol     $6d,x
        fcb     $65
        com     ,x
        bra     $190c
        asl     $72,x
        clr     $75,x
        asr     $68,x
        bra     $1901
        bra     $1904
        fcb     $72
        fcb     $65
        fcb     $61
        fcb     $6b
        neg     ,x
        clr     $69,x
        fcb     $6e,$74
        brclr   6, $0a, $1900
        lsra
        bms     $18d1
        fcb     $52
        fcb     $65
        asr     $69,x
        com     ,x
        lsr     ,x
        fcb     $65
        fcb     $72
        bra     $191f
        rol     $73,x
        neg     ,x
        inc     $61,x
        rol     ,x
        brset   0, $52, $1911
        bms     $18e6
        fcb     $52
        fcb     $65
        asr     $69,x
        com     ,x
        lsr     ,x
        fcb     $65
        fcb     $72
        bra     $193d
        clr     $64,x
        rol     $66,x
        rol     ,x
        brclr   6, $0a, $192c
        bra     $1935
        inc     $43
        clra
        fcb     $55
        fcb     $4e
        lsrx
        fcb     $3e
        tstx
        bms     $1904
        lsrx
        fcb     $72
        fcb     $61
        com     $65,x
        bra     $191c
        bms     $1933
        rora
        bra     $1959
        fcb     $6e,$73
        lsr     ,x
        fcb     $72
        fcb     $75
        com     $74,x
        rol     $6f,x
        fcb     $6e,$73
        brset   0, $06, $18f2
        brset   0, $00, $1901
        brset   0, $00, $1904
        brset   0, $00, $1907
        brset   0, $00, $190a
        brset   0, $00, $190d
        brset   0, $00, $1910
        brset   0, $00, $1913
        brset   0, $00, $1916
        brset   0, $00, $1919
        brset   0, $00, $191c
        brset   0, $00, $191f
        brset   0, $00, $1922
        brset   0, $00, $1925
        brset   0, $00, $1928
        brset   0, $00, $192b
        brset   0, $00, $192e
        brset   0, $00, $1931
        brset   0, $00, $1934
        brset   0, $00, $1937
        brset   0, $00, $193a
        brset   0, $00, $193d
        brset   0, $00, $1940
        brset   0, $00, $1943
        brset   0, $00, $1946
        brset   0, $00, $1949
        brset   0, $00, $194c
        brset   0, $00, $194f
        brset   0, $00, $1952
        brset   0, $00, $1955
        brset   0, $00, $1958
        brset   0, $00, $195b
        brset   0, $00, $195e
        brset   0, $00, $1961
        brset   0, $00, $1964
        brset   0, $00, $1967
        brset   0, $00, $196a
        brset   0, $00, $196d
        brset   0, $00, $1970
        brset   0, $00, $1973
        brset   0, $00, $1976
        brset   0, $00, $1979
        brset   0, $00, $197c
        brset   0, $00, $197f
        brset   0, $00, $1982
        brset   0, $00, $1985
        brset   0, $00, $1988
        brset   0, $00, $198b
        brset   0, $00, $198e
        brset   0, $00, $1991
        brset   0, $00, $1994
        brset   0, $00, $1997
        brset   0, $00, $199a
        brset   0, $00, $199d
        brset   0, $00, $19a0
        brset   0, $00, $19a3
        brset   0, $00, $19a6
        brset   0, $00, $19a9
        brset   0, $00, $19ac
        brset   0, $00, $19af
        brset   0, $00, $19b2
        brset   0, $00, $19b5
        brset   0, $00, $19b8
        brset   0, $00, $19bb
        brset   0, $00, $19be
        brset   0, $00, $19c1
        brset   0, $00, $19c4
        brset   0, $00, $19c7
        brset   0, $00, $19ca
        brset   0, $00, $19cd
        brset   0, $00, $19d0
        brset   0, $00, $19d3
        brset   0, $00, $19d6
        brset   0, $00, $19d9
        brset   0, $00, $19dc
        brset   0, $00, $19df
        brset   0, $00, $19e2
        brset   0, $00, $19e5
        brset   0, $00, $19e8
        brset   0, $00, $19eb
        brset   0, $00, $19ee
        brset   0, $00, $19f1
        brset   0, $00, $19f4
        brset   0, $00, $19f7
        brset   0, $00, $19fa
        brset   0, $00, $19fd
        brset   0, $00, $1a00
        brset   0, $00, $1a03
        brset   0, $00, $1a06
        brset   0, $00, $1a09
        brset   0, $00, $1a0c
        brset   0, $00, $1a0f
        brset   0, $00, $1a12
        brset   0, $00, $1a15
        brset   0, $00, $1a18
        brset   0, $00, $1a1b
        brset   0, $00, $1a1e
        brset   0, $00, $1a21
        brset   0, $00, $1a24
        brset   0, $00, $1a27
        brset   0, $00, $1a2a
        brset   0, $00, $1a2d
        brset   0, $00, $1a30
        brset   0, $00, $1a33
        brset   0, $00, $1a36
        brset   0, $00, $1a39
        brset   0, $00, $1a3c
        brset   0, $00, $1a3f
        brset   0, $00, $1a42
        brset   0, $00, $1a45
        brset   0, $00, $1a48
        brset   0, $00, $1a4b
        brset   0, $00, $1a4e
        brset   0, $00, $1a51
        brset   0, $00, $1a54
        brset   0, $00, $1a57
        brset   0, $00, $1a5a
        brset   0, $00, $1a5d
        brset   0, $00, $1a60
        brset   0, $00, $1a63
        brset   0, $00, $1a66
        brset   0, $00, $1a69
        brset   0, $00, $1a6c
        brset   0, $00, $1a6f
        brset   0, $00, $1a72
        brset   0, $00, $1a75
        brset   0, $00, $1a78
        brset   0, $00, $1a7b
        brset   0, $00, $1a7e
        brset   0, $00, $1a81
        brset   0, $00, $1a84
        brset   0, $00, $1a87
        brset   0, $00, $1a8a
        brset   0, $00, $1a8d
        brset   0, $00, $1a90
        brset   0, $00, $1a93
        brset   0, $00, $1a96
        brset   0, $00, $1a99
        brset   0, $00, $1a9c
        brset   0, $00, $1a9f
        brset   0, $00, $1aa2
        brset   0, $00, $1aa5
        brset   0, $00, $1aa8
        brset   0, $00, $1aab
        brset   0, $00, $1aae
        brset   0, $00, $1ab1
        brset   0, $00, $1ab4
        brset   0, $00, $1ab7
        brset   0, $00, $1aba
        brset   0, $00, $1abd
        brset   0, $00, $1ac0
        brset   0, $00, $1ac3
        brset   0, $00, $1ac6
        brset   0, $00, $1ac9
        brset   0, $00, $1acc
        brset   0, $00, $1acf
        brset   0, $00, $1ad2
        brset   0, $00, $1ad5
        brset   0, $00, $1ad8
        brset   0, $00, $1adb
        brset   0, $00, $1ade
        brset   0, $00, $1ae1
        brset   0, $00, $1ae4
        brset   0, $00, $1ae7
        brset   0, $00, $1aea
        brset   0, $00, $1aed
        brset   0, $00, $1af0
        brset   0, $00, $1af3
        brset   0, $00, $1af6
        brset   0, $00, $1af9
        brset   0, $00, $1afc
        brset   0, $00, $1aff
        brset   0, $00, $1b02
        brset   0, $00, $1b05
        brset   0, $00, $1b08
        brset   0, $00, $1b0b
        brset   0, $00, $1b0e
        brset   0, $00, $1b11
        brset   0, $00, $1b14
        brset   0, $00, $1b17
        brset   0, $00, $1b1a
        brset   0, $00, $1b1d
        brset   0, $00, $1b20
        brset   0, $00, $1b23
        brset   0, $00, $1b26
        brset   0, $00, $1b29
        brset   0, $00, $1b2c
        brset   0, $00, $1b2f
        brset   0, $00, $1b32
        brset   0, $00, $1b35
        brset   0, $00, $1b38
        brset   0, $00, $1b3b
        brset   0, $00, $1b3e
        brset   0, $00, $1b41
        brset   0, $00, $1b44
        brset   0, $00, $1b47
        brset   0, $00, $1b4a
        brset   0, $00, $1b4d
        brset   0, $00, $1b50
        brset   0, $00, $1b53
        brset   0, $00, $1b56
        brset   0, $00, $1b59
        brset   0, $00, $1b5c
        brset   0, $00, $1b5f
        brset   0, $00, $1b62
        brset   0, $00, $1b65
        brset   0, $00, $1b68
        brset   0, $00, $1b6b
        brset   0, $00, $1b6e
        brset   0, $00, $1b71
        brset   0, $00, $1b74
        brset   0, $00, $1b77
        brset   0, $00, $1b7a
        brset   0, $00, $1b7d
        brset   0, $00, $1b80
        brset   0, $00, $1b83
        brset   0, $00, $1b86
        brset   0, $00, $1b89
        brset   0, $00, $1b8c
        brset   0, $00, $1b8f
        brset   0, $00, $1b92
        brset   0, $00, $1b95
        brset   0, $00, $1b98
        brset   0, $00, $1b9b
        brset   0, $00, $1b9e
        brset   0, $00, $1ba1
        brset   0, $00, $1ba4
        brset   0, $00, $1ba7
        brset   0, $00, $1baa
        brset   0, $00, $1bad
        brset   0, $00, $1bb0
        brset   0, $00, $1bb3
        brset   0, $00, $1bb6
        brset   0, $00, $1bb9
        brset   0, $00, $1bbc
        brset   0, $00, $1bbf
        brset   0, $00, $1bc2
        brset   0, $00, $1bc5
        brset   0, $00, $1bc8
        brset   0, $00, $1bcb
        brset   0, $00, $1bce
        brset   0, $00, $1bd1
        brset   0, $00, $1bd4
        brset   0, $00, $1bd7
        brset   0, $00, $1bda
        brset   0, $00, $1bdd
        brset   0, $00, $1be0
        brset   0, $00, $1be3
        brset   0, $00, $1be6
        brset   0, $00, $1be9
        brset   0, $00, $1bec
        brset   0, $00, $1bef
        brset   0, $00, $1bf2
        brset   0, $00, $1bf5
        brset   0, $00, $1bf8
        brset   0, $00, $1bfb
        brset   0, $00, $1bfe
        brset   0, $00, $1c01
        brset   0, $00, $1c04
        brset   0, $00, $1c07
        brset   0, $00, $1c0a
        brset   0, $00, $1c0d
        brset   0, $00, $1c10
        brset   0, $00, $1c13
        brset   0, $00, $1c16
        brset   0, $00, $1c19
        brset   0, $00, $1c1c
        brset   0, $00, $1c1f
        brset   0, $00, $1c22
        brset   0, $00, $1c25
        brset   0, $00, $1c28
        brset   0, $00, $1c2b
        brset   0, $00, $1c2e
        brset   0, $00, $1c31
        brset   0, $00, $1c34
        brset   0, $00, $1c37
        brset   0, $00, $1c3a
        brset   0, $00, $1c3d
        brset   0, $00, $1c40
        brset   0, $00, $1c43
        brset   0, $00, $1c46
        brset   0, $00, $1c49
        brset   0, $00, $1c4c
        brset   0, $00, $1c4f
        brset   0, $00, $1c52
        brset   0, $00, $1c55
        brset   0, $00, $1c58
        brset   0, $00, $1c5b
        brset   0, $00, $1c5e
        brset   0, $00, $1c61
        brset   0, $00, $1c64
        brset   0, $00, $1c67
        brset   0, $00, $1c6a
        brset   0, $00, $1c6d
        brset   0, $00, $1c70
        brset   0, $00, $1c73
        brset   0, $00, $1c76
        brset   0, $00, $1c79
        brset   0, $00, $1c7c
        brset   0, $00, $1c7f
        brset   0, $00, $1c82
        brset   0, $00, $1c85
        brset   0, $00, $1c88
        brset   0, $00, $1c8b
        brset   0, $00, $1c8e
        brset   0, $00, $1c91
        brset   0, $00, $1c94
        brset   0, $00, $1c97
        brset   0, $00, $1c9a
        brset   0, $00, $1c9d
        brset   0, $00, $1ca0
        brset   0, $00, $1ca3
        brset   0, $00, $1ca6
        brset   0, $00, $1ca9
        brset   0, $00, $1cac
        brset   0, $00, $1caf
        brset   0, $00, $1cb2
        brset   0, $00, $1cb5
        brset   0, $00, $1cb8
        brset   0, $00, $1cbb
        brset   0, $00, $1cbe
        brset   0, $00, $1cc1
        brset   0, $00, $1cc4
        brset   0, $00, $1cc7
        brset   0, $00, $1cca
        brset   0, $00, $1ccd
        brset   0, $00, $1cd0
        brset   0, $00, $1cd3
        brset   0, $00, $1cd6
        brset   0, $00, $1cd9
        brset   0, $00, $1cdc
        brset   0, $00, $1cdf
        brset   0, $00, $1ce2
        brset   0, $00, $1ce5
        brset   0, $00, $1ce8
        brset   0, $00, $1ceb
        brset   0, $00, $1cee
        brset   0, $00, $1cf1
        brset   0, $00, $1cf4
        brset   0, $00, $1cf7
        brset   0, $00, $1cfa
        brset   0, $00, $1cfd
        brset   0, $00, $1d00
        brset   0, $00, $1d03
        brset   0, $00, $1d06
        brset   0, $00, $1d09
        brset   0, $00, $1d0c
        brset   0, $00, $1d0f
        brset   0, $00, $1d12
        brset   0, $00, $1d15
        brset   0, $00, $1d18
        brset   0, $00, $1d1b
        brset   0, $00, $1d1e
        brset   0, $00, $1d21
        brset   0, $00, $1d24
        brset   0, $00, $1d27
        brset   0, $00, $1d2a
        brset   0, $00, $1d2d
        brset   0, $00, $1d30
        brset   0, $00, $1d33
        brset   0, $00, $1d36
        brset   0, $00, $1d39
        brset   0, $00, $1d3c
        brset   0, $00, $1d3f
        brset   0, $00, $1d42
        brset   0, $00, $1d45
        brset   0, $00, $1d48
        brset   0, $00, $1d4b
        brset   0, $00, $1d4e
        brset   0, $00, $1d51
        brset   0, $00, $1d54
        brset   0, $00, $1d57
        brset   0, $00, $1d5a
        brset   0, $00, $1d5d
        brset   0, $00, $1d60
        brset   0, $00, $1d63
        brset   0, $00, $1d66
        brset   0, $00, $1d69
        brset   0, $00, $1d6c
        brset   0, $00, $1d6f
        brset   0, $00, $1d72
        brset   0, $00, $1d75
        brset   0, $00, $1d78
        brset   0, $00, $1d7b
        brset   0, $00, $1d7e
        brset   0, $00, $1d81
        brset   0, $00, $1d84
        brset   0, $00, $1d87
        brset   0, $00, $1d8a
        brset   0, $00, $1d8d
        brset   0, $00, $1d90
        brset   0, $00, $1d93
        brset   0, $00, $1d96
        brset   0, $00, $1d99
        brset   0, $00, $1d9c
        brset   0, $00, $1d9f
        brset   0, $00, $1da2
        brset   0, $00, $1da5
        brset   0, $00, $1da8
        brset   0, $00, $1dab
        brset   0, $00, $1dae
        brset   0, $00, $1db1
        brset   0, $00, $1db4
        brset   0, $00, $1db7
        brset   0, $00, $1dba
        brset   0, $00, $1dbd
        brset   0, $00, $1dc0
        brset   0, $00, $1dc3
        brset   0, $00, $1dc6
        brset   0, $00, $1dc9
        brset   0, $00, $1dcc
        brset   0, $00, $1dcf
        brset   0, $00, $1dd2
        brset   0, $00, $1dd5
        brset   0, $00, $1dd8
        brset   0, $00, $1ddb
        brset   0, $00, $1dde
        brset   0, $00, $1de1
        brset   0, $00, $1de4
        brset   0, $00, $1de7
        brset   0, $00, $1dea
        brset   0, $00, $1ded
        brset   0, $00, $1df0
        brset   0, $00, $1df3
        brset   0, $00, $1df6
        brset   0, $00, $1df9
        brset   0, $00, $1dfc
        brset   0, $00, $1dff
        brset   0, $00, $1e02
        brset   0, $00, $1e05
        brset   0, $00, $1e08
        brset   0, $00, $1e0b
        brset   0, $00, $1e0e
        brset   0, $00, $1e11
        brset   0, $00, $1e14
        brset   0, $00, $1e17
        brset   0, $00, $1e1a
        brset   0, $00, $1e1d
        brset   0, $00, $1e20
        brset   0, $00, $1e23
        brset   0, $00, $1e26
        brset   0, $00, $1e29
        brset   0, $00, $1e2c
        brset   0, $00, $1e2f
        brset   0, $00, $1e32
        brset   0, $00, $1e35
        brset   0, $00, $1e38
        brset   0, $00, $1e3b
        brset   0, $00, $1e3e
        brset   0, $00, $1e41
        brset   0, $00, $1e44
        brset   0, $00, $1e47
        brset   0, $00, $1e4a
        brset   0, $00, $1e4d
        brset   0, $00, $1e50
        brset   0, $00, $1e53
        brset   0, $00, $1e56
        brset   0, $00, $1e59
        brset   0, $00, $1e5c
        brset   0, $00, $1e5f
        brset   0, $00, $1e62
        brset   0, $00, $1e65
        brset   0, $00, $1e68
        brset   0, $00, $1e6b
        brset   0, $00, $1e6e
        brset   0, $00, $1e71
        brset   0, $00, $1e74
        brset   0, $00, $1e77
        brset   0, $00, $1e7a
        brset   0, $00, $1e7d
        brset   0, $00, $1e80
        brset   0, $00, $1e83
        brset   0, $00, $1e86
        brset   0, $00, $1e89
        brset   0, $00, $1e8c
        brset   0, $00, $1e8f
        brset   0, $00, $1e92
        brset   0, $00, $1e95
        brset   0, $00, $1e98
        brset   0, $00, $1e9b
        brset   0, $00, $1e9e
        brset   0, $00, $1ea1
        brset   0, $00, $1ea4
        brset   0, $00, $1ea7
        brset   0, $00, $1eaa
        brset   0, $00, $1ead
        brset   0, $00, $1eb0
        brset   0, $00, $1eb3
        brset   0, $00, $1eb6
        brset   0, $00, $1eb9
        brset   0, $00, $1ebc
        brset   0, $00, $1ebf
        brset   0, $00, $1ec2
        brset   0, $00, $1ec5
        brset   0, $00, $1ec8
        brset   0, $00, $1ecb
        brset   0, $00, $1ece
        brset   0, $00, $1ed1
        brset   0, $00, $1ed4
        brset   0, $00, $1ed7
        brset   0, $00, $1eda
        brset   0, $00, $1edd
        brset   0, $00, $1ee0
        brset   0, $00, $1ee3
        brset   0, $00, $1ee6
        brset   0, $00, $1ee9
        brset   0, $00, $1eec
        brset   0, $00, $1eef
        brset   0, $00, $1ef2
        brset   0, $00, $1ef5
        brset   0, $00, $1ef8
        brset   0, $00, $1efb
        brset   0, $00, $1efe
        brset   0, $00, $1f01
        brset   0, $00, $1f04
        brset   0, $00, $1f07
        brset   0, $00, $1f0a
        brset   0, $00, $1f0d
        brset   0, $00, $1f10
        brset   0, $00, $1f13
        brset   0, $00, $1f16
        brset   0, $00, $1f19
        brset   0, $00, $1f1c
        brset   0, $00, $1f1f
        brset   0, $00, $1f22
        brset   0, $00, $1f25
        brset   0, $00, $1f28
        brset   0, $00, $1f2b
        brset   0, $00, $1f2e
        brset   0, $00, $1f31
        brset   0, $00, $1f34
        brset   0, $00, $1f37
        brset   0, $00, $1f3a
        brset   0, $00, $1f3d
        brset   0, $00, $1f40
        brset   0, $00, $1f43
        brset   0, $00, $1f46
        brset   0, $00, $1f49
        brset   0, $00, $1f4c
        brset   0, $00, $1f4f
        brset   0, $00, $1f52
        brset   0, $00, $1f55
        brset   0, $00, $1f58
        brset   0, $00, $1f5b
        brset   0, $00, $1f5e
        brset   0, $00, $1f61
        brset   0, $00, $1f64
        brset   0, $00, $1f67
        brset   0, $00, $1f6a
        brset   0, $00, $1f6d
        brset   0, $00, $1f70
        brset   0, $00, $1f73
        brset   0, $00, $1f76
        brset   0, $00, $1f79
        brset   0, $00, $1f7c
        brset   0, $00, $1f7f
        brset   0, $00, $1f82
        brset   0, $00, $1f85
        brset   0, $00, $1f88
        brset   0, $00, $1f8b
        brset   0, $00, $1f8e
        brset   0, $00, $1f91
        brset   0, $00, $1f94
        brset   0, $00, $1f97
        brset   0, $00, $1f9a
        brset   0, $00, $1f9d
        brset   0, $00, $1fa0
        brset   0, $00, $1fa3
        brset   0, $00, $1fa6
        brset   0, $00, $1fa9
        brset   0, $00, $1fac
        brset   0, $00, $1faf
        brset   0, $00, $1fb2
        brset   0, $00, $1fb5
        brset   0, $00, $1fb8
        brset   0, $00, $1fbb
        brset   0, $00, $1fbe
        brset   0, $00, $1fc1
        brset   0, $00, $1fc4
        brset   0, $00, $1fc7
        brset   0, $00, $1fca
        brset   0, $00, $1fcd
        brset   0, $00, $1fd0
        brset   0, $00, $1fd3
        brset   0, $00, $1fd6
        brset   0, $00, $1fd9
        brset   0, $00, $1fdc
        brset   0, $00, $1fdf
        brset   0, $00, $1fe2
        brset   0, $00, $1fe5
        brset   0, $00, $1fe8
        brset   0, $00, $1feb
        brset   0, $00, $1fee
        brset   0, $00, $2005
        adda    ,x
        bset    2, $fb
        bset    2, $fb
        bset    2, $fb
        bset    2, $fb
        bset    2, $fb
        bclr    2, $58
        bset    2, $fb
        .end
