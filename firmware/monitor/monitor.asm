        .msfirst

NUL             .equ    $00             ; null character
TAB             .equ    $09             ; horizontal tab
LF              .equ    $0a             ; line feed
CR              .equ    $0d             ; carriage return
ESC             .equ    $1b             ; escape
SP              .equ    $20             ; space
DEL             .equ    $7f             ; delete
char_mask       .equ    $7f             ; strip char high bit
msg_end         .equ    $80             ; high-bit string terminator

stack_top       .equ    $7f
reset_cc        .equ    $08

stop_rst        .equ    $01
stop_tst        .equ    $02

mem_focus_asc   .equ    $01

key_tab         .equ    TAB
key_ctrl_n      .equ    $0e
key_ctrl_p      .equ    $10
key_left        .equ    $80
key_right       .equ    $81
key_up          .equ    $82
key_down        .equ    $83

cc_c_bit        .equ    0
cc_z_bit        .equ    1
cc_n_bit        .equ    2
cc_i_bit        .equ    3
cc_h_bit        .equ    4

saved_sp        .equ    $10
saved_pc_hi     .equ    $11
saved_pc_lo     .equ    $12
saved_a         .equ    $13
saved_x         .equ    $14
saved_cc        .equ    $15
stop_rsn        .equ    $16

mem_page_hi     .equ    $20
mem_page_lo     .equ    $21
mem_thunk_op    .equ    $22
mem_thunk_hi    .equ    $23
mem_thunk_lo    .equ    $24
mem_thunk_rts   .equ    $25
mem_cur_hi      .equ    $26
mem_cur_lo      .equ    $27
mem_focus       .equ    $28
mem_hex_phs     .equ    $29
disasm_pc_hi    .equ    $2a
disasm_pc_lo    .equ    $2b
scratch         .equ    $2c
dline_buf       .equ    scratch + $03
dline_tmp       .equ    dline_buf + $0e

tmr_wt_vec_hi   .equ    $17
tmr_wt_vec_lo   .equ    $18
tmr_vec_hi      .equ    $19
tmr_vec_lo      .equ    $1a
ext_vec_hi      .equ    $1b
ext_vec_lo      .equ    $1c
int_jmp_op      .equ    $1d
int_jmp_hi      .equ    $1e
int_jmp_lo      .equ    $1f

acia_stat       .equ    $06
acia_ctl        .equ    $06
acia_data       .equ    $07
acia_tdre       .equ    1
acia_rst        .equ    $03
acia_def_ctl    .equ    $15

op_jmp_ext      .equ    $cc
op_lda_ext_idx  .equ    $d6
op_rts          .equ    $81

; Zero Page Usage
;
; Address   Role    Description
; $06-$07   hw      ACIA control, status, and data registers.
; $10-$16   state   saved user CPU frame and monitor stop reason.
; $17-$1c   state   RAM interrupt vectors initialized by reset.
; $1d-$1f   thunk   generated interrupt jump target.
; $20-$21   state   memory panel page address.
; $22-$25   thunk   generated indexed memory access routine.
; $26-$29   state   memory cursor address, focus, and edit phase.
; $2a-$2b   state   disassembly panel start address.
; $2c-$3e   scratch shared temps, disassembly text buffer, and target temps.

        .org    $1000

        .module reset

; Reset entry initializes the monitor-owned machine image.
reset:
        rsp
        lda     #stack_top
        sta     saved_sp
        lda     #reset/100h
        sta     saved_pc_hi
        lda     #reset-(reset/100h*100h)
        sta     saved_pc_lo
        clra
        sta     saved_a
        clrx
        stx     saved_x
        lda     #reset_cc
        sta     saved_cc                ; Saved registers are a monitor snapshot, not live CPU state
        lda     #stop_rst
        sta     stop_rsn
        lda     #tmr_wt_def_hdlr/100h
        sta     tmr_wt_vec_hi           ; IRQ RAM vectors default to ROM handlers after reset
        lda     #tmr_wt_def_hdlr-(tmr_wt_def_hdlr/100h*100h)
        sta     tmr_wt_vec_lo
        lda     #tmr_def_hdlr/100h
        sta     tmr_vec_hi
        lda     #tmr_def_hdlr-(tmr_def_hdlr/100h*100h)
        sta     tmr_vec_lo
        lda     #ext_def_hdlr/100h
        sta     ext_vec_hi
        lda     #ext_def_hdlr-(ext_def_hdlr/100h*100h)
        sta     ext_vec_lo
        lda     #op_jmp_ext             ; Shared IRQ thunk holds an absolute jump target
        sta     int_jmp_op
        lda     #op_lda_ext_idx         ; Memory access thunk opcode is patched by callers
        sta     mem_thunk_op
        lda     #op_rts
        sta     mem_thunk_rts
        jsr     init_mem_pnl
        jsr     init_con
        jsr     draw_boot
        jmp     idle

        .module int_disp

swi:
        jmp     idle                    ; SWI is the current user-code return path

; Interrupt dispatch vectors through RAM so user code can intercept IRQs.
tmr_wt_disp:
        lda     tmr_wt_vec_hi
        sta     int_jmp_hi              ; Dispatcher copies the chosen RAM vector into the shared thunk
        lda     tmr_wt_vec_lo
        sta     int_jmp_lo
        jmp     int_jmp_op

tmr_disp:
        lda     tmr_vec_hi
        sta     int_jmp_hi
        lda     tmr_vec_lo
        sta     int_jmp_lo
        jmp     int_jmp_op

ext_disp:
        lda     ext_vec_hi
        sta     int_jmp_hi
        lda     ext_vec_lo
        sta     int_jmp_lo
        jmp     int_jmp_op

tmr_wt_def_hdlr .equ    swi
tmr_def_hdlr    .equ    swi
ext_def_hdlr    .equ    swi

        .module con_io

; Console I/O owns the ACIA setup and byte-at-a-time transmit path.
init_con:
        lda     #acia_rst               ; ACIA reset and mode bytes are separate writes
        sta     acia_ctl
        lda     #acia_def_ctl
        sta     acia_ctl
        rts

chrout:
                                        ; Polling keeps the early ROM serial path small
        brclr   acia_tdre,acia_stat,chrout
        sta     acia_data
        rts

        .module draw_boot

; Boot drawing positions the terminal with compact ANSI text.
draw_boot:
        ldx     #0                      ; Boot text leans on terminal state instead of filling rows

_loop:
        lda     boot_txt,x
        beq     _done
        jsr     chrout
        inx
        bra     _loop

_done:
        jmp     draw_cpu

        .module draw_cpu

; CPU status rendering formats the saved user context as one row.
draw_cpu:
                                        ; Text fragments keep labels local while sharing one emitter
        ldx     #cpu_sp_txt-cpu_txt
        jsr     emit_cpu_txt
        clra
        jsr     hex_byte
        lda     saved_sp
        jsr     hex_byte
        ldx     #cpu_pc_txt-cpu_txt
        jsr     emit_cpu_txt
        lda     saved_pc_hi
        jsr     hex_byte
        lda     saved_pc_lo
        jsr     hex_byte
        ldx     #cpu_a_txt-cpu_txt
        jsr     emit_cpu_txt
        lda     saved_a
        jsr     hex_byte
        ldx     #cpu_x_txt-cpu_txt
        jsr     emit_cpu_txt
        lda     saved_x
        jsr     hex_byte
        ldx     #cpu_flags_txt-cpu_txt
        jsr     emit_cpu_txt
        jsr     flag_h                  ; Unset flags become blanks so set flags stand out
        jsr     flag_i
        jsr     flag_n
        jsr     flag_z
        jsr     flag_c
        ldx     #cpu_stop_txt-cpu_txt
        jsr     emit_cpu_txt
        jsr     emit_stop               ; Stop reason maps internal causes to display text
        ldx     #cpu_crlf_txt-cpu_txt
        jsr     emit_cpu_txt
        rts

emit_cpu_txt:
        lda     cpu_txt,x
        bmi     _last
        jsr     chrout
        inx
        bra     emit_cpu_txt

_last:
        and     #char_mask
        jsr     chrout
        rts

        .module scr_out

_save   .equ    scratch                 ; saved A across spacing output

emit_spcs:
        sta     _save
        lda     #SP

_loop:
        jsr     chrout
        decx
        bne     _loop
        lda     _save
        rts

        .module dasm_out

_op     .equ    scratch                 ; opcode byte being decoded
_hex    .equ    scratch                 ; byte being formatted as buffered hex
_len    .equ    scratch + $01           ; decoded instruction byte count
_mnem   .equ    scratch + $02           ; mnemonic table index
_pos    .equ    scratch + $02           ; text buffer write offset after decode
_mctr   .equ    dline_tmp               ; mnemonic scan count or saved X
_mpos   .equ    dline_tmp + $01         ; mnemonic copy offset
_rhi    .equ    dline_tmp               ; relative target high byte
_rlo    .equ    dline_tmp + $01         ; relative target low byte

; Disassembly first classifies the opcode, then renders buffered text.
dec_inst:
        sta     _op
        lda     #$01
        sta     _len
        lda     #op_fcb_idx
        sta     _mnem
        lda     _op
        cmp     #$10
        bhs     _chk20
        jmp     _done

_chk20:
        cmp     #$20
        blo     _bit
        cmp     #$30
        blo     _br
        cmp     #$80
        blo     _uop
        cmp     #$a0
        blo     _inh
        cmp     #op_bsr
        beq     _bsr
        cmp     #$b0
        blo     _imm
        cmp     #$c0
        blo     _dir
        cmp     #$d0
        blo     _ext
        cmp     #$e0
        blo     _xext
        cmp     #$f0
        blo     _xdir
        jmp     _x0

_bit:
        lda     #$02
        sta     _len
        lda     _op
        and     #$01
        add     #$02
        tax
        lda     brbit_idx,x
        sta     _mnem
        rts

_br:
        lda     #$02
        sta     _len
        lda     _op
        and     #$0f
        add     #$05
        tax
        lda     brbit_idx,x
        sta     _mnem
        rts

_uop:
        lda     _op
        and     #$0f
        tax
        lda     op30_idx,x
        beq     _bad
        cmp     #op_lsl_idx
        bne     _ustor
        lda     #op_asl_idx

_ustor:
        sta     _mnem
        lda     _op
        cmp     #$40
        blo     _len2
        cmp     #$60
        blo     _done
        cmp     #$70
        blo     _len2
        rts

_inh:
        lda     _op
        cmp     #op_wait
        bne     _inhx
        ldx     #$02
        bra     _inhop

_inhx:
        lda     _op
        and     #$0f
        tax

_inhop:
        lda     op80_idx,x
        beq     _bad
        sta     _mnem
        rts

_bsr:
        lda     #$02
        sta     _len
        lda     #op_bsr_idx
        sta     _mnem
        rts

_imm:
        lda     #$02
        sta     _len
        bra     _alu

_dir:
        lda     #$02
        sta     _len
        bra     _alu

_ext:
        lda     #$03
        sta     _len
        bra     _alu

_xext:
        lda     #$03
        sta     _len
        bra     _alu

_xdir:
        lda     #$02
        sta     _len
        bra     _alu

_x0:
        bra     _alu

_len2:
        lda     #$02
        sta     _len
        rts

_alu:
        lda     _op
        and     #$0f
        tax
        lda     opa0_idx,x
        sta     _mnem
        rts

_bad:
        lda     #$01
        sta     _len
        lda     #op_fcb_idx
        sta     _mnem

_done:
        rts

dasm_line:
        lda     _mnem
        cmp     #op_fcb_idx
        bne     _nfcb
        jsr     _mnem4
        jmp     _fcb

_nfcb:
        jsr     _mnem4
        lda     _op
        cmp     #op_bsr
        bne     _nbsr
        jmp     _relop

_nbsr:
        cmp     #$10
        bhs     _n10
        jmp     _line

_n10:
        cmp     #$20
        bhs     _n20
        jmp     _bitop

_n20:
        cmp     #$30
        bhs     _n30
        jmp     _relop

_n30:
        cmp     #$40
        bhs     _n40
        jmp     _dirop

_n40:
        cmp     #$60
        bhs     _n60
        jmp     _line

_n60:
        cmp     #$70
        bhs     _n70
        jmp     _dirop

_n70:
        cmp     #$80
        bhs     _n80
        jmp     _idxop

_n80:
        cmp     #$a0
        bhs     _na0
        jmp     _line

_na0:
        cmp     #$b0
        bhs     _nb0
        jmp     _immop

_nb0:
        cmp     #$c0
        bhs     _nc0
        jmp     _dirop

_nc0:
        cmp     #$d0
        bhs     _nd0
        jmp     _extop

_nd0:
        cmp     #$e0
        bhs     _ne0
        jmp     _extop

_ne0:
        cmp     #$f0
        bhs     _nf0
        jmp     _dirop

_nf0:
        jmp     _idxop

_mnem4:
        lda     #SP
        sta     dline_buf
        sta     dline_buf+$01
        sta     dline_buf+$02
        sta     dline_buf+$03
        clr     _mctr
        clrx

_mscan:
        lda     mnemonic_modes,x
        cmp     #$0f
        bls     _mnext
        lda     _mctr
        cmp     _mnem
        beq     _mgot
        inc     _mctr

_mnext:
        incx
        bra     _mscan

_mgot:
        lda     mnemonic_modes,x
        and     #$0f
        sta     _mpos

_mcopy:
        lda     mnemonic_modes,x
        and     #$0f
        cmp     _mpos
        bhi     _mprev
        lda     mnemonics,x
        and     #char_mask
        stx     _mctr
        ldx     _mpos
        sta     dline_buf,x
        ldx     _mctr
        dec     _mpos
        bmi     _reg

_mprev:
        decx
        bra     _mcopy

_reg:
        lda     _op
        cmp     #$40
        blo     _mterm
        cmp     #$60
        bhs     _mterm
        lda     _mnem
        cmp     #op_mul_idx
        beq     _mterm
        lda     _op
        cmp     #$50
        bhs     _regx
        lda     #'a'
        bra     _streg

_regx:
        lda     #'x'

_streg:
        sta     dline_buf+$03

_mterm:
        lda     #$04
        sta     _pos
        rts

_fcb:
        jsr     _gap
        jsr     _dol
        lda     _op
        jsr     _apphx
        jmp     _line

_immop:
        jsr     _gap
        lda     #'#'
        jsr     _app
        jsr     _dol
        ldx     #$01
        jsr     mem_thunk_read
        jsr     _apphx
        jmp     _line

_dirop:
        jsr     _gap
        jsr     _dol
        ldx     #$01
        jsr     mem_thunk_read
        jsr     _apphx
        jmp     _line

_extop:
        jsr     _gap
        jsr     _dol
        ldx     #$01
        jsr     mem_thunk_read
        jsr     _apphx
        ldx     #$02
        jsr     mem_thunk_read
        jsr     _apphx
        jmp     _line

_idxop:
        jsr     _gap
        lda     #','
        jsr     _app
        lda     #'x'
        jsr     _app
        jmp     _line

_bitop:
        jsr     _gap
        lda     _op
        and     #$0e
        lsra
        add     #'0'
        jsr     _app
        lda     #','
        jsr     _app
        jsr     _dol
        ldx     #$01
        jsr     mem_thunk_read
        jsr     _apphx
        jmp     _line

_relop:
        jsr     _gap
        jsr     _dol
        lda     disasm_pc_lo
        add     #$02
        sta     _rlo
        lda     disasm_pc_hi
        adc     #$00
        sta     _rhi
        ldx     #$01
        jsr     mem_thunk_read
        sta     _hex
        add     _rlo
        sta     _rlo
        lda     _rhi
        adc     #$00
        sta     _rhi
        lda     _hex
        bpl     _relhx
        dec     _rhi

_relhx:
        lda     _rhi
        jsr     _apphx
        lda     _rlo
        jsr     _apphx
        jmp     _line

_gap:
        lda     #SP
        jsr     _app
        lda     #SP
        jsr     _app
        lda     #SP
        jsr     _app
        lda     #SP
        jsr     _app
        rts

_dol:
        lda     #'$'
        jmp     _app

_apphx:
        sta     _hex
        lsra
        lsra
        lsra
        lsra
        tax
        lda     hex_digits,x
        jsr     _app
        lda     _hex
        and     #$0f
        tax
        lda     hex_digits,x
        jmp     _app

_app:
        ldx     _pos
        sta     dline_buf,x
        inc     _pos
        rts

_line:
        clra
        ldx     _pos
        sta     dline_buf,x
        clrx

_olp:
        lda     dline_buf,x
        beq     _ret
        jsr     chrout
        incx
        bra     _olp

_ret:
        rts

        .module hex_out

_byte   .equ    scratch                 ; byte being formatted as hex

hex_byte:
        sta     _byte
        lsra
        lsra
        lsra
        lsra
        jsr     hex_nib
        lda     _byte
        and     #$0f
        jsr     hex_nib
        lda     _byte
        rts

hex_nib:
        and     #$0f
        tax
        lda     hex_digits,x
        jsr     chrout
        rts

flag_h:
        brset   cc_h_bit,saved_cc,_h_set
        lda     #SP
        bra     _h_wr

_h_set:
        lda     #'H'

_h_wr:
        jsr     chrout
        rts

flag_i:
        brset   cc_i_bit,saved_cc,_i_set
        lda     #SP
        bra     _i_wr

_i_set:
        lda     #'I'

_i_wr:
        jsr     chrout
        rts

flag_n:
        brset   cc_n_bit,saved_cc,_n_set
        lda     #SP
        bra     _n_wr

_n_set:
        lda     #'N'

_n_wr:
        jsr     chrout
        rts

flag_z:
        brset   cc_z_bit,saved_cc,_z_set
        lda     #SP
        bra     _z_wr

_z_set:
        lda     #'Z'

_z_wr:
        jsr     chrout
        rts

flag_c:
        brset   cc_c_bit,saved_cc,_c_set
        lda     #SP
        bra     _c_wr

_c_set:
        lda     #'C'

_c_wr:
        jsr     chrout
        rts

emit_stop:
        lda     stop_rsn
        cmp     #stop_rst
        beq     _reset
        cmp     #stop_tst
        beq     _test
        ldx     #stop_unk_txt-cpu_txt
        bra     _write

_reset:
        ldx     #stop_rst_txt-cpu_txt
        bra     _write

_test:
        ldx     #stop_tst_txt-cpu_txt

_write:
        jsr     emit_cpu_txt
        rts

        .module draw_mem_row

_idx    .equ    scratch + $01           ; memory row byte offset

; Memory row rendering uses the generated access thunk for addressable RAM.
draw_mem_row:
        lda     mem_page_hi             ; The row address patches the shared thunk before output
        sta     mem_thunk_hi
        jsr     hex_byte
        lda     mem_page_lo
        sta     mem_thunk_lo
        jsr     hex_byte
        ldx     #mem_addr_sfx_txt-cpu_txt
        jsr     emit_cpu_txt
        clrx
        stx     _idx

_hexlp:
        ldx     _idx
        jsr     mem_thunk_read
        jsr     hex_byte
        lda     #SP
        jsr     chrout
        ldx     _idx
        inx
        stx     _idx
        cpx     #$10
        bne     _hexlp
        lda     #SP
        jsr     chrout
        clrx

_asclp:
        jsr     mem_thunk_read          ; The ASCII pass rereads the same row from byte zero
        jsr     emit_mem_asc
        inx
        cpx     #$10
        bne     _asclp
        ldx     #cpu_crlf_txt-cpu_txt
        jsr     emit_cpu_txt
        rts

        .module draw_dasm_row

_len    .equ    scratch + $01           ; decoded instruction byte count

; Disassembly row rendering advances a separate PC from the memory panel.
draw_dasm_row:
        lda     #SP                     ; Disassembly has its own PC so rows need not align
        jsr     chrout
        lda     disasm_pc_hi
        sta     mem_thunk_hi
        jsr     hex_byte
        lda     disasm_pc_lo
        sta     mem_thunk_lo
        jsr     hex_byte
        ldx     #mem_addr_sfx_txt-cpu_txt
        jsr     emit_cpu_txt
        clrx
        jsr     mem_thunk_read
        jsr     dec_inst

_bytes:
        clrx
        jsr     mem_thunk_read
        jsr     hex_byte
        lda     _len
        cmp     #$01
        beq     _spc10
        lda     #SP
        jsr     chrout
        ldx     #$01
        jsr     mem_thunk_read
        jsr     hex_byte
        lda     _len
        cmp     #$02
        beq     _spc7
        lda     #SP
        jsr     chrout
        ldx     #$02
        jsr     mem_thunk_read
        jsr     hex_byte
        ldx     #$04
        bra     _spc

_spc10:
        ldx     #$0a
        bra     _spc

_spc7:
        ldx     #$07

_spc:
        jsr     emit_spcs
        clrx
        jsr     mem_thunk_read
        jsr     dec_inst
        jsr     dasm_line

_done:
        ldx     #cpu_crlf_txt-cpu_txt
        jsr     emit_cpu_txt
        lda     disasm_pc_lo
        add     _len
        sta     disasm_pc_lo
        bne     _return
        inc     disasm_pc_hi

_return:
        rts

        .module mem_asc

emit_mem_asc:
        cmp     #SP                     ; Control and high-bit bytes collapse to dot for scanability
        blo     _dot
        cmp     #$7f
        blo     _write

_dot:
        lda     #'.'

_write:
        jsr     chrout
        rts

        .module mem_pnl

; Memory panel state starts on the first RAM page with hex focus.
init_mem_pnl:
        clra                            ; Page and cursor track the same window at initialization
        sta     mem_page_hi
        sta     mem_cur_hi
        sta     mem_focus
        sta     mem_hex_phs
        lda     #$80
        sta     mem_page_lo
        sta     mem_cur_lo
        rts

        .module mem_edit

_ch     .equ    scratch                 ; key byte during dispatch
_nib    .equ    scratch                 ; parsed hex nibble
_tmp    .equ    scratch + $01           ; preserved high nibble

; Memory key handling updates panel state without redrawing here.
mem_key_in:
        jsr     _key
        jmp     idle

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
        lda     mem_focus
        beq     _hexgo
        lda     _ch
        jmp     _ascii

_hexgo:
        lda     _ch
        jmp     _hex

_tab:
        lda     mem_focus               ; Tab changes which view accepts edits
        eor     #mem_focus_asc
        sta     mem_focus
        clra
        sta     mem_hex_phs
        rts

_next:
        inc     mem_page_hi             ; Page motion keeps cursor and page together
        inc     mem_cur_hi
        jmp     mem_cur_done

_prev:
        dec     mem_page_hi
        dec     mem_cur_hi
        jmp     mem_cur_done

_left:
        jsr     mem_cur_lft
        rts

_right:
        jsr     mem_cur_rgt
        rts

_up:
        jsr     mem_cur_up
        rts

_down:
        jsr     mem_cur_dwn
        rts

_ascii:
        cmp     #SP                     ; ASCII editing accepts printable bytes only
        blo     _done
        cmp     #DEL
        bhs     _done
        bsr     mem_wr_cur
        bsr     mem_cur_rgt

_done:
        rts

_hex:
        cmp     #'0'                    ; Hex editing converts ASCII digits into nibbles
        blo     _done
        cmp     #':'
        blo     _digit
        cmp     #'A'
        blo     _done
        cmp     #'G'
        blo     _upper
        cmp     #'a'
        blo     _done
        cmp     #'g'
        blo     _lower
        rts

_digit:
        sub     #'0'
        bra     _nibl

_upper:
        sub     #('A' - 10)
        bra     _nibl

_lower:
        sub     #('a' - 10)

_nibl:
        sta     _nib                    ; The first hex digit writes the high nibble and waits
        lda     mem_hex_phs
        bne     _low
        lda     _nib
        lsla
        lsla
        lsla
        lsla
        bsr     mem_wr_cur
        lda     #$01
        sta     mem_hex_phs
        rts

_low:
        bsr     mem_rd_cur              ; The second hex digit merges with the saved high nibble
        and     #$f0
        sta     _tmp
        lda     _nib
        ora     _tmp
        bsr     mem_wr_cur
        clra
        sta     mem_hex_phs
        bsr     mem_cur_rgt
        rts

        .module mem_cur

_byte   .equ    scratch                 ; byte held while patching write thunk

; Memory helpers patch one generated access thunk around the current address.
mem_sel_cur:
        lda     mem_cur_hi              ; Cursor selection patches the shared memory thunk
        sta     mem_thunk_hi
        lda     mem_cur_lo
        sta     mem_thunk_lo
        clrx
        rts

mem_rd_cur:
        bsr     mem_sel_cur

mem_thunk_read:
        bclr    0,mem_thunk_op          ; LDA/STA indexed differ only in opcode bit 0
        jmp     mem_thunk_op

mem_wr_cur:
        sta     _byte
        bsr     mem_sel_cur
        lda     _byte

mem_thunk_write:
        bset    0,mem_thunk_op
        jmp     mem_thunk_op

mem_cur_lft:
        lda     mem_cur_lo
        bne     _dec
        dec     mem_cur_hi

_dec:
        dec     mem_cur_lo
        bra     mem_cur_done

mem_cur_rgt:
        inc     mem_cur_lo
        bne     mem_cur_done
        inc     mem_cur_hi
        bra     mem_cur_done

mem_cur_up:
        lda     mem_cur_lo
        sub     #$10
        sta     mem_cur_lo
        bcc     mem_cur_done
        dec     mem_cur_hi
        bra     mem_cur_done

mem_cur_dwn:
        lda     mem_cur_lo
        add     #$10
        sta     mem_cur_lo
        bcc     mem_cur_done
        inc     mem_cur_hi

mem_cur_done:
        clra                            ; Cursor movement clears the pending nibble after navigation
        sta     mem_hex_phs
        rts

        .module test_hooks

_cnt    .equ    saved_a                 ; test loop count while renderer owns scratch

; MAME test hooks expose stable ROM entry points for focused checks.
test_con_out:
        lda     #'O'                    ; Hooks stop by branching to idle after emitting fixture data
        jsr     chrout
        lda     #'K'
        jsr     chrout
        lda     #CR
        jsr     chrout
        lda     #LF
        jsr     chrout
        bra     idle

test_cpu_out:
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
        lda     #stop_tst
        sta     stop_rsn
        jsr     draw_cpu
        bra     idle

test_mem_out:
        clra
        sta     mem_page_hi
        lda     #$80
        sta     mem_page_lo
        jsr     draw_mem_row
        bra     idle

test_dasm_out:
        clra
        sta     disasm_pc_hi
        lda     #$80
        sta     disasm_pc_lo
        lda     #$2f
        sta     _cnt

_loop:
        jsr     draw_dasm_row
        dec     _cnt
        bne     _loop
        bra     idle

        .module idle

idle:
        bra     idle

        .module data

hex_digits:
        .text   "0123456789ABCDEF"

cpu_txt:

cpu_sp_txt:
        .text   "SP"
        .byte   (' ' | msg_end)

cpu_pc_txt:
        .text   "  PC"
        .byte   (' ' | msg_end)

cpu_a_txt:
        .text   "  A"
        .byte   (' ' | msg_end)

cpu_x_txt:
        .text   "  X"
        .byte   (' ' | msg_end)

cpu_flags_txt:
        .text   "  FLAGS 11"
        .byte   ('1' | msg_end)

cpu_stop_txt:
        .text   "  STOPPED:"
        .byte   (' ' | msg_end)

stop_rst_txt:
        .text   "RESE"
        .byte   ('T' | msg_end)

stop_tst_txt:
        .text   "TES"
        .byte   ('T' | msg_end)

stop_unk_txt:
        .text   "UNKNOW"
        .byte   ('N' | msg_end)

mem_addr_sfx_txt:
        .text   ":"
        .byte   (' ' | msg_end)

cpu_crlf_txt:
        .byte   CR,(LF | msg_end)

op_adc_imm      .equ    $a9
op_add_imm      .equ    $ab
op_and_imm      .equ    $a4
op_asl_dir      .equ    $38
op_asr_dir      .equ    $37
op_bcc          .equ    $24
op_bclr0        .equ    $11
op_bcs          .equ    $25
op_beq          .equ    $27
op_bhcc         .equ    $28
op_bhcs         .equ    $29
op_bih          .equ    $2f
op_bil          .equ    $2e
op_bit_imm      .equ    $a5
op_bhi          .equ    $22
op_bhs          .equ    $24
op_blo          .equ    $25
op_bls          .equ    $23
op_bmc          .equ    $2c
op_bmi          .equ    $2b
op_bms          .equ    $2d
op_bne          .equ    $26
op_bpl          .equ    $2a
op_bra          .equ    $20
op_brclr0       .equ    $01
op_brn          .equ    $21
op_brset0       .equ    $00
op_bset0        .equ    $10
op_bsr          .equ    $ad
op_clc          .equ    $98
op_cli          .equ    $9a
op_clr_dir      .equ    $3f
op_cmp_imm      .equ    $a1
op_com_dir      .equ    $33
op_cpx_imm      .equ    $a3
op_dec_dir      .equ    $3a
op_dex          .equ    $5a
op_eor_imm      .equ    $a8
op_fcb          .equ    $01
op_inc_dir      .equ    $3c
op_inx          .equ    $5c
op_jmp_base     .equ    $ac
op_jsr_base     .equ    $ad
op_lda_imm      .equ    $a6
op_ldx_imm      .equ    $ae
op_lsl_dir      .equ    $38
op_lsr_dir      .equ    $34
op_mul          .equ    $42
op_neg_dir      .equ    $30
op_nop          .equ    $9d
op_ora_imm      .equ    $aa
op_org          .equ    $00
op_rol_dir      .equ    $39
op_ror_dir      .equ    $36
op_rsp          .equ    $9c
op_rti          .equ    $80
op_sbc_imm      .equ    $a2
op_sec          .equ    $99
op_sei          .equ    $9b
op_sta_base     .equ    $a7
op_stop         .equ    $8e
op_stx_base     .equ    $af
op_sub_imm      .equ    $a0
op_swi          .equ    $83
op_tax          .equ    $97
op_tst_dir      .equ    $3d
op_txa          .equ    $9f
op_wait         .equ    $8f

op_adc_idx      .equ    $00
op_add_idx      .equ    $01
op_and_idx      .equ    $02
op_asl_idx      .equ    $03
op_asr_idx      .equ    $04
op_bcc_idx      .equ    $05
op_bclr_idx     .equ    $06
op_bcs_idx      .equ    $07
op_beq_idx      .equ    $08
op_bhcc_idx     .equ    $09
op_bhcs_idx     .equ    $0a
op_bhi_idx      .equ    $0b
op_bih_idx      .equ    $0d
op_bil_idx      .equ    $0e
op_bit_idx      .equ    $0f
op_bls_idx      .equ    $11
op_bmc_idx      .equ    $12
op_bmi_idx      .equ    $13
op_bms_idx      .equ    $14
op_bne_idx      .equ    $15
op_bpl_idx      .equ    $16
op_bra_idx      .equ    $17
op_brclr_idx    .equ    $18
op_brn_idx      .equ    $19
op_brset_idx    .equ    $1a
op_bset_idx     .equ    $1b
op_bsr_idx      .equ    $1c
op_clc_idx      .equ    $1d
op_cli_idx      .equ    $1e
op_clr_idx      .equ    $1f
op_cmp_idx      .equ    $20
op_com_idx      .equ    $21
op_cpx_idx      .equ    $22
op_dec_idx      .equ    $23
op_eor_idx      .equ    $25
op_fcb_idx      .equ    $26
op_inc_idx      .equ    $27
op_jmp_idx      .equ    $29
op_jsr_idx      .equ    $2a
op_lda_idx      .equ    $2b
op_ldx_idx      .equ    $2c
op_lsl_idx      .equ    $2d
op_lsr_idx      .equ    $2e
op_mul_idx      .equ    $2f
op_neg_idx      .equ    $30
op_nop_idx      .equ    $31
op_ora_idx      .equ    $32
op_rol_idx      .equ    $34
op_ror_idx      .equ    $35
op_rsp_idx      .equ    $36
op_rti_idx      .equ    $37
op_rts_idx      .equ    $38
op_sbc_idx      .equ    $39
op_sec_idx      .equ    $3a
op_sei_idx      .equ    $3b
op_sta_idx      .equ    $3c
op_stop_idx     .equ    $3d
op_stx_idx      .equ    $3e
op_sub_idx      .equ    $3f
op_swi_idx      .equ    $40
op_tax_idx      .equ    $41
op_tst_idx      .equ    $42
op_txa_idx      .equ    $43
op_wait_idx     .equ    $44
op_unused_idx   .equ    $00

; op30_idx maps low nibbles to mnemonic indices.
op30_idx:
        .byte   op_neg_idx,     op_unused_idx,  op_mul_idx,     op_com_idx
        .byte   op_lsr_idx,     op_unused_idx,  op_ror_idx,     op_asr_idx
        .byte   op_lsl_idx,     op_rol_idx,     op_dec_idx,     op_unused_idx
        .byte   op_inc_idx,     op_tst_idx,     op_unused_idx,  op_clr_idx

; opa0_idx maps ALU/load/store opcode low nibbles.
opa0_idx:
        .byte   op_sub_idx,     op_cmp_idx,     op_sbc_idx,     op_cpx_idx
        .byte   op_and_idx,     op_bit_idx,     op_lda_idx,     op_sta_idx
        .byte   op_eor_idx,     op_adc_idx,     op_ora_idx,     op_add_idx
        .byte   op_jmp_idx,     op_jsr_idx,     op_ldx_idx,     op_stx_idx

; brbit_idx folds branch and bit-operation decoding.
brbit_idx:
        .byte   op_brset_idx,   op_brclr_idx,   op_bset_idx,    op_bclr_idx
        .byte   op_bsr_idx,     op_bra_idx,     op_brn_idx,     op_bhi_idx
        .byte   op_bls_idx,     op_bcc_idx,     op_bcs_idx,     op_bne_idx
        .byte   op_beq_idx,     op_bhcc_idx,    op_bhcs_idx,    op_bpl_idx
        .byte   op_bmi_idx,     op_bmc_idx,     op_bms_idx,     op_bil_idx
        .byte   op_bih_idx

; op80_idx maps inherent opcodes by low nibble.
op80_idx:
        .byte   op_rti_idx,     op_rts_idx,     op_wait_idx,    op_swi_idx
        .byte   op_unused_idx,  op_unused_idx,  op_unused_idx,  op_tax_idx
        .byte   op_clc_idx,     op_sec_idx,     op_cli_idx,     op_sei_idx
        .byte   op_rsp_idx,     op_nop_idx,     op_stop_idx,    op_txa_idx

; mnemonics compresses adjacent spelling with high-bit ends.
mnemonics:
        .byte   "ad", ('c' | msg_end)
        .byte         ('d' | msg_end)
        .byte   "n",  ('d' | msg_end)
        .byte   "s",  ('l' | msg_end)
        .byte         ('r' | msg_end)
        .byte   "bc", ('c' | msg_end)
        .byte   "l",  ('r' | msg_end)
        .byte         ('s' | msg_end)
        .byte   "e",  ('q' | msg_end)
        .byte   "hc", ('c' | msg_end)
        .byte         ('s' | msg_end)
        .byte         ('i' | msg_end)
        .byte         ('s' | msg_end)
        .byte   "i",  ('h' | msg_end)
        .byte         ('l' | msg_end)
        .byte         ('t' | msg_end)
        .byte   "l",  ('o' | msg_end)
        .byte         ('s' | msg_end)
        .byte   "m",  ('c' | msg_end)
        .byte         ('i' | msg_end)
        .byte         ('s' | msg_end)
        .byte   "n",  ('e' | msg_end)
        .byte   "p",  ('l' | msg_end)
        .byte   "r",  ('a' | msg_end)
        .byte   "cl", ('r' | msg_end)
        .byte         ('n' | msg_end)
        .byte   "se", ('t' | msg_end)
        .byte   "se", ('t' | msg_end)
        .byte         ('r' | msg_end)
        .byte   "cl", ('c' | msg_end)
        .byte         ('i' | msg_end)
        .byte         ('r' | msg_end)
        .byte   "m",  ('p' | msg_end)
        .byte   "o",  ('m' | msg_end)
        .byte   "p",  ('x' | msg_end)
        .byte   "de", ('c' | msg_end)
        .byte         ('x' | msg_end)
        .byte   "eo", ('r' | msg_end)
        .byte   "fc", ('b' | msg_end)
        .byte   "in", ('c' | msg_end)
        .byte         ('x' | msg_end)
        .byte   "jm", ('p' | msg_end)
        .byte   "s",  ('r' | msg_end)
        .byte   "ld", ('a' | msg_end)
        .byte         ('x' | msg_end)
        .byte   "s",  ('l' | msg_end)
        .byte         ('r' | msg_end)
        .byte   "mu", ('l' | msg_end)
        .byte   "ne", ('g' | msg_end)
        .byte   "o",  ('p' | msg_end)
        .byte   "or", ('a' | msg_end)
        .byte         ('g' | msg_end)
        .byte   "ro", ('l' | msg_end)
        .byte         ('r' | msg_end)
        .byte   "s",  ('p' | msg_end)
        .byte   "t",  ('i' | msg_end)
        .byte         ('s' | msg_end)
        .byte   "sb", ('c' | msg_end)
        .byte   "e",  ('c' | msg_end)
        .byte         ('i' | msg_end)
        .byte   "t",  ('a' | msg_end)
        .byte   "o",  ('p' | msg_end)
        .byte         ('x' | msg_end)
        .byte   "u",  ('b' | msg_end)
        .byte   "w",  ('i' | msg_end)
        .byte   "ta", ('x' | msg_end)
        .byte   "s",  ('t' | msg_end)
        .byte   "x",  ('a' | msg_end)
        .byte   "wai",('t' | msg_end)
        .byte   NUL

_inh            .equ    $10
_bit_dir        .equ    $20
_rel            .equ    $30
_idx            .equ    $40
_bad            .equ    $50
_mem            .equ    $60
_imm_mem        .equ    $70
_bit_rel        .equ    $80

; mnemonic_modes carries operand class and mnemonic length.
mnemonic_modes:
        .byte   $00,               $01,                 _imm_mem | $02,     _imm_mem | $02
        .byte   $01,               _imm_mem | $02,      $01,                _idx | $02
        .byte   _idx | $02,        $00,                 $01,                _rel | $02
        .byte   $02,               _bit_dir | $03,      _rel | $02,         $01
        .byte   _rel | $02,        $01,                 $02,                _rel | $03
        .byte   _rel | $03,        _rel | $02,          _rel | $02,         $01
        .byte   _rel | $02,        _rel | $02,          _imm_mem | $02,     $01
        .byte   _rel | $02,        _rel | $02,          $01,                _rel | $02
        .byte   _rel | $02,        _rel | $02,          $01,                _rel | $02
        .byte   $01,               _rel | $02,          $01,                _rel | $02
        .byte   $02,               $03,                 _bit_rel | $04,     _rel | $02
        .byte   $02,               $03,                 _bit_rel | $04,     $01
        .byte   $02,               _bit_dir | $03,      _rel | $02,         $00
        .byte   $01,               _inh | $02,          _inh | $02,         _idx | $02
        .byte   $01,               _imm_mem | $02,      $01,                _idx | $02
        .byte   $01,               _imm_mem | $02,      $00,                $01
        .byte   _idx | $02,        _inh | $02,          $00,                $01
        .byte   _imm_mem | $02,     $00,                 $01,               _bad | $02
        .byte   $00,               $01,                 _idx | $02,         _inh | $02
        .byte   $00,               $01,                 _mem | $02,         $01
        .byte   _mem | $02,        $00,                 $01,                _imm_mem | $02
        .byte   _imm_mem | $02,    $01,                 _idx | $02,         _idx | $02
        .byte   $00,               $01,                 _inh | $02,         $00
        .byte   $01,               _idx | $02,          $01,                _inh | $02
        .byte   $00,               $01,                 _imm_mem | $02,     _bad | $02
        .byte   $00,               $01,                 _idx | $02,         _idx | $02
        .byte   $01,               _inh | $02,          $01,                _inh | $02
        .byte   _inh | $02,        $00,                 $01,                _imm_mem | $02
        .byte   $01,               _inh | $02,          _inh | $02,         $01
        .byte   _mem | $02,        $02,                 _inh | $03,         _mem | $02
        .byte   $01,               _imm_mem | $02,      $01,                _inh | $02
        .byte   $00,               $01,                 _inh | $02,         $01
        .byte   _idx | $02,        $01,                 _inh | $02,         $00
        .byte   $01,               $02,                 _inh | $03,         $00

; op_tbl maps mnemonic index to representative opcode.
op_tbl:
        .byte   op_adc_imm,     op_add_imm,     op_and_imm,     op_asl_dir
        .byte   op_asr_dir,     op_bcc,         op_bclr0,       op_bcs
        .byte   op_beq,         op_bhcc,        op_bhcs,        op_bhi
        .byte   op_bhs,         op_bih,         op_bil,         op_bit_imm
        .byte   op_blo,         op_bls,         op_bmc,         op_bmi
        .byte   op_bms,         op_bne,         op_bpl,         op_bra
        .byte   op_brclr0,      op_brn,         op_brset0,      op_bset0
        .byte   op_bsr,         op_clc,         op_cli,         op_clr_dir
        .byte   op_cmp_imm,     op_com_dir,     op_cpx_imm,     op_dec_dir
        .byte   op_dex,         op_eor_imm,     op_fcb,         op_inc_dir
        .byte   op_inx,         op_jmp_base,    op_jsr_base,    op_lda_imm
        .byte   op_ldx_imm,     op_lsl_dir,     op_lsr_dir,     op_mul
        .byte   op_neg_dir,     op_nop,         op_ora_imm,     op_org
        .byte   op_rol_dir,     op_ror_dir,     op_rsp,         op_rti
        .byte   op_rts,         op_sbc_imm,     op_sec,         op_sei
        .byte   op_sta_base,    op_stop,        op_stx_base,    op_sub_imm
        .byte   op_swi,         op_tax,         op_tst_dir,     op_txa
        .byte   op_wait

boot_txt:
        .byte   ESC                     ; Boot text emits escape sequences instead of blank-filled rows
        .text   "[H"
        .byte   ESC
        .text   "[J"
        .byte   ESC
        .text   "[68G"
#include "monitor_version.inc"
        .byte   ESC
        .text   "[H"
        .byte   NUL

rom_end:

        .module int_vecs

        .org    $1ff6                   ; Vectors remain at the CPU hardware locations
        .dw     tmr_wt_disp             ; Timer from wait state
        .dw     tmr_disp                ; Timer
        .dw     ext_disp                ; External interrupt
        .dw     swi                     ; Software interrupt
        .dw     reset                   ; Reset

        .end
