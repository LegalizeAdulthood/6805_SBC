; EVSBUG12 source provenance:
;
; - Disassembled the binary dump with unidasm to produce evsbug12.lst.
; - Extracted the initial evsbug12.asm source from the listing file.
; - Assembled with TASM until the output matched the binary byte for byte.
; - Revised the source to identify routines, tables, and related symbols.
;
        .msfirst

NUL             .equ    $00             ; null character
BS              .equ    $08             ; backspace
LF              .equ    $0a             ; line feed
CR              .equ    $0d             ; carriage return
DC3             .equ    $13             ; control-S
CAN             .equ    $18             ; cancel
SP              .equ    $20             ; space
msg_end         .equ    $80             ; string high-bit terminator

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
acia_isr_rdrf_bit .equ  0               ; receive data full
acia_isr_tdre_bit .equ  6               ; transmit data empty
acia_csr_rx_brk_bit .equ 2              ; receive break seen
acia_cfr_fmt    .equ    $80             ; write format register
acia_cfr_ctl_mask .equ  $7f             ; write control register
acia_fr_8bit    .equ    $60             ; 8 data bits
acia_fr_8n      .equ    acia_cfr_fmt | acia_fr_8bit
acia_cr_tbr     .equ    $40             ; select transmit break reg
acia_baud_9600  .equ    $0c             ; 9600 baud select
acia_cr_9600    .equ    acia_cr_tbr | acia_baud_9600
cop_update      .equ    $fff0           ; COP watchdog update register
map_switch      .equ    $50
map_direct_rti_bit .equ 0               ; direct RTI resume path
map_user_bit    .equ    1               ; transient user access
map_mon_bit     .equ    2               ; monitor map selected
map_brk_armed_bit .equ 3                ; normal breaks armed
map_step_armed_bit .equ 4               ; step breaks armed
map_step_brk_bit .equ 5                 ; step break path
map_resume_swi_bit .equ 7               ; monitor resume SWI
scratch         .equ    $51
cmd_thunk       .equ    $9c
int_vecs        .equ    $1ff0
stk_cc          .equ    $01             ; stacked condition codes
stk_a           .equ    $02             ; stacked A register
stk_x           .equ    $03             ; stacked X register
stk_pc          .equ    $04             ; stacked PC high byte
stk_len         .equ    $05             ; saved register byte count
stk_swi_src     .equ    $06             ; SWI copy source offset
stk_swi_end     .equ    $08             ; SWI copy limit offset

cmd_err         .equ    scratch + $01   ; command error flag
cmd_args        .equ    scratch + $02   ; command argument count
disasm_op_len   .equ    scratch + $02   ; disasm operand byte count
line_buf        .equ    scratch + $03   ; command line buffer
cmd_arg_hi      .equ    scratch + $20   ; command arg table high
cmd_arg_lo      .equ    scratch + $21   ; command arg table low
addr_hi         .equ    scratch + $22   ; active address high
addr_lo         .equ    scratch + $23   ; active address low
word_hi         .equ    scratch + $24   ; secondary word high
word_lo         .equ    scratch + $25   ; secondary word low
parse_hi        .equ    scratch + $2c   ; parsed word high
parse_lo        .equ    scratch + $2d   ; parsed word low
line_pos        .equ    scratch + $2e   ; line buffer index
mod_idx         .equ    scratch + $2f   ; modify register field index
mod_len         .equ    scratch + $31   ; modify value byte count
brk_idx         .equ    scratch + $31   ; breakpoint slot index
cmd_char        .equ    scratch + $32   ; command input character
brk_addr_hi     .equ    scratch + $34   ; breakpoint table: high first
brk_addr_lo     .equ    scratch + $35   ; breakpoint table: low next
inst_target_hi  .equ    scratch + $3e   ; decoded target high
inst_target_lo  .equ    scratch + $3f   ; decoded target low
inst_next       .equ    scratch + $40   ; decoded next address
brk_ops         .equ    scratch + $42   ; saved breakpoint opcodes
brk_user_last   .equ    $08             ; last user brk slot
brk_step_slot   .equ    $0a             ; step brk slot
brk_temp_slot   .equ    $0c             ; temp brk slot
brk_table_last  .equ    $0d             ; last brk table byte
trace_cnt       .equ    scratch + $49   ; trace instruction count
proceed_cnt     .equ    scratch + $4a   ; proceed breakpoint count
step_flag       .equ    scratch + $51   ; step-over pending flag
mon_flags       .equ    scratch + $52   ; monitor control flags
one_nibl_bit    .equ    0               ; parse one hex nibl
nowait_tx_bit   .equ    1               ; skip tx-ready wait
user_sp         .equ    scratch + $53   ; captured user SP
saved_addr_hi   .equ    scratch + $54   ; saved address high
saved_addr_lo   .equ    scratch + $55   ; saved address low
checksum        .equ    scratch + $56   ; checksum accumulator
op_len          .equ    scratch + $57   ; operand byte count
decode_flags    .equ    scratch + $58   ; decode attribute flags
df_reg_a_bit    .equ    0               ; emit A register suffix
df_reg_bit      .equ    1               ; emit register suffix
df_imm_bit      .equ    2               ; emit immediate marker
df_idx_bit      .equ    3               ; emit indexed suffix
hex_digit       .equ    scratch + $59   ; parsed hex digit
asm_once        .equ    scratch + $5a   ; assembler one-shot flag
serial_ctl      .equ    scratch + $5b   ; serial control bits
poll_flag       .equ    scratch + $5c   ; pause poll pending
tmp_a           .equ    scratch + $5d   ; temporary A save
unknown         .equ    scratch + $5e   ; unknown scratch byte
io_stat         .equ    scratch + $60   ; I/O status scratch

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
op_bset1        .equ    $12
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
op_jmp_ext      .equ    $cc
op_jsr_base     .equ    $ad
op_lda_ext      .equ    $c6
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
op_rts          .equ    $81
op_sbc_imm      .equ    $a2
op_sec          .equ    $99
op_sei          .equ    $9b
op_sta_base     .equ    $a7
op_sta_ext      .equ    $c7
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
op_bhs_idx      .equ    $0c
op_bih_idx      .equ    $0d
op_bil_idx      .equ    $0e
op_bit_idx      .equ    $0f
op_blo_idx      .equ    $10
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
op_dex_idx      .equ    $24
op_eor_idx      .equ    $25
op_fcb_idx      .equ    $26
op_inc_idx      .equ    $27
op_inx_idx      .equ    $28
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
op_org_idx      .equ    $33
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

        .org    $0000
        .byte   $00
        .org    $0800

        .module console_io
_save_x         .equ    scratch + $59   ; saved X register

service_cop:
        sta     tmp_a
        lda     #$00
        sta     cop_update
        lda     tmp_a
        rts

read_console_char_echo:
        stx     _save_x

_read_poll:
        jsr     service_cop
        ldx     acia_csra
        stx     io_stat
        brset   acia_csr_rx_brk_bit, io_stat, _serial_event
        ldx     acia_isra
        stx     io_stat
        brclr   acia_isr_rdrf_bit, io_stat, _read_poll
        lda     acia_rdra
        and     #$7f
        bra     _write_char

write_console_char:
        stx     _save_x
        ldx     acia_isra
        stx     io_stat
        brclr   acia_isr_rdrf_bit, io_stat, _write_char
        ldx     #$ff
        stx     poll_flag

_write_char:
        sta     acia_tdra
        brset   nowait_tx_bit, mon_flags, _return

_tx_poll:
        jsr     service_cop
        ldx     acia_isra
        stx     io_stat
        brclr   acia_isr_tdre_bit, io_stat, _tx_poll
        ldx     acia_csra
        stx     io_stat
        brset   acia_csr_rx_brk_bit, io_stat, _serial_event

_return:
        ldx     _save_x
        rts

_serial_event:
        lda     acia_rdra
        jsr     init_serial_or_timer
        clr     mon_flags
        jmp     cmd_loop

        .module write_hex_byte
_save_a         .equ    scratch + $33   ; saved byte for output

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
        add     #'0'
        cmp     #'9'
        bls     _emit
        add     #('A' - ('9' + 1))

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
        lda     #'='
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
_reg_idx        .equ    scratch + $33   ; register field index

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
        lda     #'S'
        jsr     write_console_char
        lda     #'='
        jsr     write_console_char
        lda     addr_lo
        add     #stk_len
        jsr     write_hex_byte
        rts

; register display field table

register_fields:
        .byte   "SPAXC", NUL

write_crlf:
        lda     #CR
        jsr     write_console_char
        lda     #LF
        jsr     write_console_char
        rts

; condition-code display table
        .fill   $0008,$00

condition_bits:
        .byte   "111HINZC"

        .module select_reg_addr
_cnt            .equ    scratch + $31   ; offset/flag count
_tmp            .equ    scratch + $33   ; X save/flags byte

select_reg_addr:
        stx     _tmp
        tax
        lda     user_sp
        clr     _cnt
        clr     addr_hi
        cpx     #'P'
        bne     _check_x
        inc     _cnt
        add     #stk_pc

_check_x:
        cpx     #'X'
        bne     _check_a
        add     #stk_x

_check_a:
        cpx     #'A'
        bne     _check_cc
        add     #stk_a

_check_cc:
        cpx     #'C'
        bne     _store_addr
        add     #stk_cc

_store_addr:
        sta     addr_lo
        txa
        ldx     _tmp
        rts

display_cc:
        ldx     #msg_sp4
        jsr     write_string
        lda     user_sp
        add     #stk_cc
        sta     addr_lo
        clr     addr_hi
        jsr     read_memory_byte
        sta     _tmp
        ldx     #$ff
        lda     #$08
        sta     _cnt

_flag_loop:
        incx
        lda     #'.'
        asl     _tmp
        bcc     _write_flag
        lda     condition_bits,x

_write_flag:
        jsr     write_console_char
        dec     _cnt
        bne     _flag_loop
        rts

        .module write_memory_byte
_byte           .equ    scratch + $33   ; memory write byte
_map_op         .equ    cmd_thunk       ; map-switch opcode
_map_addr       .equ    cmd_thunk + $01 ; map-switch operand
_mem_op         .equ    cmd_thunk + $02 ; memory access opcode
_mem_addr_hi    .equ    cmd_thunk + $03 ; target address high
_mem_addr_lo    .equ    cmd_thunk + $04 ; target address low
_return_op      .equ    cmd_thunk + $05 ; return opcode

write_memory_byte:
        sta     _byte
        jsr     service_cop
        lda     #op_sta_ext
        bra     _access_user

read_memory_byte:
        lda     #op_lda_ext
        jsr     service_cop

_access_user:
        bclr    map_mon_bit, map_switch
        sta     _mem_op
        lda     #op_bset1
        sta     _map_op
        lda     #map_switch
        sta     _map_addr
        lda     addr_hi
        sta     _mem_addr_hi
        lda     addr_lo
        sta     _mem_addr_lo
        lda     #op_rts
        sta     _return_op
        lda     _byte
        jsr     cmd_thunk
        bclr    map_user_bit, map_switch
        bset    map_mon_bit, map_switch
        rts

        .module address_math
_delta          .equ    scratch + $33   ; address delta byte

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
        ldx     #stk_pc

load_stack_addr:
        bsr     read_stack_word
        bsr     restore_addr
        rts

write_stack_pc:
        ldx     #stk_pc
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
        cpx     #brk_table_last
        bls     clear_addr_slots
        rts

        .module brk_helpers
_end            .equ    scratch + $32   ; breakpoint range limit

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
        lda     #brk_user_last

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
        lda     #brk_user_last

arm_break_range:
        sta     _end
        stx     brk_idx

_arm_slot:
        bsr     load_breakpoint_address
        beq     _next_arm
        bset    map_brk_armed_bit, map_switch
        jsr     read_memory_byte
        lsrx
        sta     brk_ops,x
        lda     #op_swi
        jsr     write_memory_byte

_next_arm:
        ldx     brk_idx
        cpx     _end
        bls     _arm_slot
        jmp     resume_user

restore_breaks:
        ldx     #brk_user_last
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
_op             .equ    scratch + $33   ; opcode byte
_addr_adj       .equ    scratch + $32   ; target address adjust

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
        bset    df_idx_bit, decode_flags
        cmp     #$60
        beq     _operand_byte
        bra     _len1_addr

_set_flag0:
        bset    df_reg_a_bit, decode_flags

_set_flag1:
        bset    df_reg_bit, decode_flags
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
        bset    df_imm_bit, decode_flags

_operand_byte:
        bra     _op_from_code

_decode_b0_up:
        cmp     #$b0
        beq     _op_from_code
        cmp     #$c0
        beq     _read_ext_addr
        bset    df_idx_bit, decode_flags
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
_save_x         .equ    scratch + $33   ; saved X register

_restart:
        jsr     write_crlf

read_command_line:
        lda     #$3e
        jsr     write_console_char
        clrx

_read_char:
        jsr     read_console_char_echo
        cmp     #CAN
        beq     _restart
        cmp     #BS
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
        cmp     #CR
        bne     _read_char

_finish_line:
        lda     #CR
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
_flags          .equ    mon_flags       ; parser control flags
_save_x         .equ    scratch + $33   ; saved X register

parse_hex_word:
        clr     parse_hi
        clr     parse_lo
        jsr     read_command_char
        cmp     #'$'
        bne     parse_hex_digit

_next_digit:
        jsr     read_command_char

parse_hex_digit:
        jsr     uppercase_command_char
        clr     hex_digit
        dec     hex_digit
        sub     #'0'
        bmi     _finish
        cmp     #$09
        bls     _valid_digit
        sub     #('A' - ('9' + 1))
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
_cmd_idx        .equ    scratch         ; command handler index
_handler_op     .equ    cmd_thunk       ; handler jump opcode
_handler_hi     .equ    cmd_thunk + $01 ; handler address high
_handler_lo     .equ    cmd_thunk + $02 ; handler address low
_load_cmd_idx   .equ    $04             ; LOAD command index
_max_arg_off    .equ    $0a             ; max arg table offset

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
        cmp     #CR
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
        cmp     #CR
        beq     _dispatch
        cmp     #SP
        bne     _no_match
        lda     _cmd_idx
        cmp     #_load_cmd_idx
        beq     _dispatch

_parse_arg:
        jsr     parse_hex_word
        ldx     cmd_args
        aslx
        cpx     #_max_arg_off
        bhi     _bad_cmd
        lda     parse_hi
        sta     cmd_arg_hi,x
        lda     parse_lo
        sta     cmd_arg_lo,x
        lda     cmd_char
        cmp     #SP
        beq     _parse_arg
        cmp     #CR
        bne     _bad_cmd

_dispatch:
        lda     _cmd_idx
        asla
        tax
        lda     #op_jmp_ext
        sta     _handler_op
        lda     cmd_handlers,x
        sta     _handler_hi
        lda     cmd_handlers+1,x
        sta     _handler_lo
        jmp     cmd_thunk

; command handler table

        .module cmd_handlers
cmd_handlers:
        .dw     asm_cmd,block_fill_cmd,breakpoint_cmd,go_cmd
        .dw     load_cmd,mem_display_cmd,mem_modify_cmd,nobr_cmd
        .dw     proceed_cmd,reg_display_cmd,reg_modify_cmd,trace_cmd
        .dw     help_cmd

        .module disassemble_line
_mnem           .equ    scratch         ; mnemonic index
_reg_ch         .equ    scratch + $12   ; A/X suffix slot
_mode           .equ    scratch + $2f   ; mode/index temp
_mnem_x         .equ    scratch + $31   ; mnemonic scan index
_tmp            .equ    scratch + $33   ; shared temp byte
_line_last      .equ    $1d             ; output line limit
_bytes_col      .equ    $02             ; opcode byte column
_operand_col    .equ    $12             ; operand column
_target_col     .equ    $17             ; target addr column
_mnem_col       .equ    $0c             ; mnemonic column base

disassemble_line:
        ldx     #saved_addr_hi
        jsr     store_address_pair
        jsr     write_crlf
        jsr     write_hex_word_at_73
        lda     #SP
        ldx     #_line_last

_clear_line:
        sta     line_buf,x
        decx
        bpl     _clear_line
        jsr     decode_inst
        jsr     load_line_addr
        lda     op_len
        sta     _tmp
        sta     disasm_op_len
        ldx     #_bytes_col
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
        ldx     #op_fcb_idx
        bra     _to_mnem

_class_op:
        jsr     read_memory_byte
        and     #$0f
        tax
        jsr     read_memory_byte
        cmp     #$0f
        bhi     _chk_10
        sta     _tmp
        ldx     #_target_col
        stx     line_pos
        jsr     app_comma_dol
        jsr     app_hex_word
        clrx

_set_bit:
        stx     _mode
        ldx     #_operand_col
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
        cmp     #op_wait
        bne     _idx_80
        ldx     #$02

_idx_80:
        ldx     opcode_80_9f_index,x
        bra     _store_mnem

_chk_a0:
        cmp     #op_bsr
        bne     _idx_a0
        lda     #$04

_set_mode:
        sta     _mode
        ldx     #_operand_col
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
        add     #_mnem_col
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
        brset   df_reg_a_bit, decode_flags, _reg_a
        brclr   df_reg_bit, decode_flags, _op_pos
        lda     #'X'
        bra     _store_reg

_reg_a:
        lda     #'A'

_store_reg:
        sta     _reg_ch

_op_pos:
        ldx     #_operand_col
        stx     line_pos
        brclr   df_imm_bit, decode_flags, _operand
        lda     #'#'
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
        brclr   df_idx_bit, decode_flags, _write_line
        lda     #','
        bsr     app_char
        lda     #'X'
        bsr     app_char

_write_line:
        clrx

_write_loop:
        lda     line_buf,x
        jsr     write_console_char
        incx
        cpx     #_line_last
        bls     _write_loop
        ldx     #$0a
        jsr     clear_addr_slots
        clr     cmd_err

        .module load_line_addr
_hex_byte       .equ    scratch + $32   ; byte for hex output

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
        add     #'0'
        cmp     #'9'
        bls     app_char
        add     #('A' - ('9' + 1))

app_char:
        sta     line_buf,x
        incx
        stx     line_pos
        rts

app_comma_dol:
        lda     #','
        bsr     app_char

app_dol:
        lda     #'$'
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
        .byte   op_neg_idx,     op_unused_idx,  op_mul_idx,     op_com_idx
        .byte   op_lsr_idx,     op_unused_idx,  op_ror_idx,     op_asr_idx
        .byte   op_lsl_idx,     op_rol_idx,     op_dec_idx,     op_unused_idx
        .byte   op_inc_idx,     op_tst_idx,     op_unused_idx,  op_clr_idx

opcode_a0_af_index:
        .byte   op_sub_idx,     op_cmp_idx,     op_sbc_idx,     op_cpx_idx
        .byte   op_and_idx,     op_bit_idx,     op_lda_idx,     op_sta_idx
        .byte   op_eor_idx,     op_adc_idx,     op_ora_idx,     op_add_idx
        .byte   op_jmp_idx,     op_jsr_idx,     op_ldx_idx,     op_stx_idx

branch_bit_index:
        .byte   op_brset_idx,   op_brclr_idx,   op_bset_idx,    op_bclr_idx
        .byte   op_bsr_idx,     op_bra_idx,     op_brn_idx,     op_bhi_idx
        .byte   op_bls_idx,     op_bcc_idx,     op_bcs_idx,     op_bne_idx
        .byte   op_beq_idx,     op_bhcc_idx,    op_bhcs_idx,    op_bpl_idx
        .byte   op_bmi_idx,     op_bmc_idx,     op_bms_idx,     op_bil_idx
        .byte   op_bih_idx

opcode_80_9f_index:
        .byte   op_rti_idx,     op_rts_idx,     op_wait_idx,    op_swi_idx
        .byte   op_unused_idx,  op_unused_idx,  op_unused_idx,  op_tax_idx
        .byte   op_clc_idx,     op_sec_idx,     op_cli_idx,     op_sei_idx
        .byte   op_rsp_idx,     op_nop_idx,     op_stop_idx,    op_txa_idx

        .module asm_cmd
_op             .equ    scratch         ; assembled opcode byte
_mpos           .equ    scratch + $2f   ; mnemonic match position
_mode           .equ    scratch + $31   ; mode/operand temp

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
        cmp     #CR
        bne     _parse_mnem

_next_line:
        lda     disasm_op_len
        inca
        jsr     add_a_to_address
        bra     _show_line

_parse_mnem:
        cmp     #'.'
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
        cmp     #'A'
        beq     _reg_a
        cmp     #'X'
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
        cmp     #'.'
        beq     _finish_no_arg
        cmp     #CR
        bne     _need_space

_finish_no_arg:
        lda     _mode
        deca
        bne     _bad_entry
        dec     line_pos
        bra     _mode_jump

_need_space:
        cmp     #SP
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
        cmp     #','

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
        cmp     #','
        bne     _bad_to_entry
        rts

_parse_index:
        jsr     read_command_char
        cmp     #','
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
        cmp     #'#'
        beq     _parse_zp

_check_comma:
        cmp     #','
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
        cmp     #','
        bne     _check_end
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #'X'
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
        cmp     #CR
        beq     _write_bytes
        cmp     #'.'
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
        .byte   "AD", ('C' | msg_end)
        .byte         ('D' | msg_end)
        .byte   "N",  ('D' | msg_end)
        .byte   "S",  ('L' | msg_end)
        .byte         ('R' | msg_end)
        .byte   "BC", ('C' | msg_end)
        .byte   "L",  ('R' | msg_end)
        .byte         ('S' | msg_end)
        .byte   "E",  ('Q' | msg_end)
        .byte   "HC", ('C' | msg_end)
        .byte         ('S' | msg_end)
        .byte         ('I' | msg_end)
        .byte         ('S' | msg_end)
        .byte   "I",  ('H' | msg_end)
        .byte         ('L' | msg_end)
        .byte         ('T' | msg_end)
        .byte   "L",  ('O' | msg_end)
        .byte         ('S' | msg_end)
        .byte   "M",  ('C' | msg_end)
        .byte         ('I' | msg_end)
        .byte         ('S' | msg_end)
        .byte   "N",  ('E' | msg_end)
        .byte   "P",  ('L' | msg_end)
        .byte   "R",  ('A' | msg_end)
        .byte   "CL", ('R' | msg_end)
        .byte         ('N' | msg_end)
        .byte   "SE", ('T' | msg_end)
        .byte   "SE", ('T' | msg_end)
        .byte         ('R' | msg_end)
        .byte   "CL", ('C' | msg_end)
        .byte         ('I' | msg_end)
        .byte         ('R' | msg_end)
        .byte   "M",  ('P' | msg_end)
        .byte   "O",  ('M' | msg_end)
        .byte   "P",  ('X' | msg_end)
        .byte   "DE", ('C' | msg_end)
        .byte         ('X' | msg_end)
        .byte   "EO", ('R' | msg_end)
        .byte   "FC", ('B' | msg_end)
        .byte   "IN", ('C' | msg_end)
        .byte         ('X' | msg_end)
        .byte   "JM", ('P' | msg_end)
        .byte   "S",  ('R' | msg_end)
        .byte   "LD", ('A' | msg_end)
        .byte         ('X' | msg_end)
        .byte   "S",  ('L' | msg_end)
        .byte         ('R' | msg_end)
        .byte   "MU", ('L' | msg_end)
        .byte   "NE", ('G' | msg_end)
        .byte   "O",  ('P' | msg_end)
        .byte   "OR", ('A' | msg_end)
        .byte         ('G' | msg_end)
        .byte   "RO", ('L' | msg_end)
        .byte         ('R' | msg_end)
        .byte   "S",  ('P' | msg_end)
        .byte   "T",  ('I' | msg_end)
        .byte         ('S' | msg_end)
        .byte   "SB", ('C' | msg_end)
        .byte   "E",  ('C' | msg_end)
        .byte         ('I' | msg_end)
        .byte   "T",  ('A' | msg_end)
        .byte   "O",  ('P' | msg_end)
        .byte         ('X' | msg_end)
        .byte   "U",  ('B' | msg_end)
        .byte   "W",  ('I' | msg_end)
        .byte   "TA", ('X' | msg_end)
        .byte   "S",  ('T' | msg_end)
        .byte   "X",  ('A' | msg_end)
        .byte   "WAI",('T' | msg_end)
        .byte   NUL

; mnemonic addressing-mode table

        .module mnemonic_modes
_inh            .equ    $10             ; inherent/no operand
_bit_dir        .equ    $20             ; bit + direct addr
_rel            .equ    $30             ; relative target
_idx            .equ    $40             ; indexed/A/X suffix
_bad            .equ    $50             ; invalid/reserved mode
_mem            .equ    $60             ; memory operand
_imm_mem        .equ    $70             ; immediate/memory operand
_bit_rel        .equ    $80             ; bit + branch target

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

; opcode table

        .module opcode_table
opcode_table:
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
        lda     #'s'
        jsr     write_console_char
        lda     #'='
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
        cpx     #brk_user_last
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
        ldx     #stk_pc
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
        bset    map_step_armed_bit, map_switch
        jsr     load_stack_pc
        jsr     decode_inst
        tst     cmd_err
        bne     _bad_run
        ldx     #brk_step_slot
        lda     #brk_temp_slot
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
_col            .equ    scratch + $2f   ; display column count

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
        cmp     #SP
        bcs     _dot_char
        cmp     #$7f
        bcs     _save_char

_dot_char:
        lda     #'.'

_save_char:
        ldx     line_pos
        jsr     app_char
        jsr     read_memory_byte
        jsr     write_hex_byte
        lda     #SP
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
        jsr     service_cop
        tst     poll_flag
        beq     _return
        clr     poll_flag
        lda     acia_rdra
        and     #$7f
        cmp     #DC3
        bne     _check_cancel

_wait_resume:
        jsr     service_cop
        ldx     acia_isra
        stx     io_stat
        brclr   acia_isr_rdrf_bit, io_stat, _wait_resume
        lda     acia_rdra
        and     #$7f

_check_cancel:
        cmp     #CAN
        beq     cmd_exit

_return:
        rts

        .module reg_display_cmd
reg_display_cmd:
        jsr     write_crlf
        ldx     #msg_regs

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
        cmp     #'='
        beq     _eq_addr
        cmp     #'^'
        beq     _prev_addr
        cmp     #CR
        beq     _next_addr
        cmp     #'.'
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
        .byte   "^=.", CR, NUL

        .module mem_modify_cmd
_fill_byte      .equ    scratch + $27   ; fill byte argument

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
        cmp     #'.'
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
        cmp     #'.'
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
_s9_flag        .equ    scratch + $57   ; S9/end record flag
_rec_cnt        .equ    scratch + $2f   ; S-record byte count
_rec_sum        .equ    scratch + $2f   ; checksum compare save

_bad_cmd:
        inc     cmd_err
        jmp     cmd_loop

load_cmd:
        jsr     write_crlf
        lda     cmd_char
        cmp     #CR
        beq     _bad_cmd
        cmp     #SP
        bne     _bad_cmd
        jsr     read_command_char
        jsr     uppercase_command_char
        cmp     #'T'
        bne     _bad_cmd
        bset    one_nibl_bit, mon_flags
        bra     _init_srec

_init_srec:
        clr     _s9_flag

_wait_srec:
        jsr     read_console_char_echo
        cmp     #'S'
        bne     _wait_srec
        jsr     read_console_char_echo
        cmp     #'9'
        beq     _s9_record
        cmp     #'1'
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
        bclr    map_resume_swi_bit, map_switch
        cmp     #$ff
        bne     _check_sp
        bset    map_direct_rti_bit, map_switch
        rti

_check_sp:
        bit     #$01
        bne     _push_pc
        add     #$03
        bset    map_resume_swi_bit, map_switch
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
        sta     unknown
        clr     map_switch
        bset    map_mon_bit, map_switch
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
        lda     #acia_baud_9600
        sta     serial_ctl
        jsr     init_serial_or_timer
        clrx
        jsr     write_crlf

enter_monitor:
        bclr    nowait_tx_bit, mon_flags
        clr     proceed_cnt
        clr     cmd_err
        clr     trace_cnt
        clr     step_flag
        clr     map_switch
        bset    map_mon_bit, map_switch
        jmp     show_msg_regs

init_serial_or_timer:
        lda     acia_csra
        ora     #acia_cfr_fmt
        sta     acia_cra
        lda     #acia_fr_8n
        sta     acia_fra
        lda     acia_csra
        and     #acia_cfr_ctl_mask
        sta     acia_cra
        lda     #acia_cr_tbr
        tax
        ora     serial_ctl
        sta     acia_cra
        rts

        .module swi_handler
_stk_idx        .equ    scratch + $31   ; stack copy index

swi_handler:
        bclr    map_direct_rti_bit, map_switch
        brset   map_resume_swi_bit, map_switch, resume_from_swi
        lda     acia_isrb
        deca
        sta     user_sp
        rsp
        jsr     load_stack_pc
        jsr     decrement_address
        jsr     save_addr
        lda     #brk_temp_slot
        jsr     find_address_slot
        beq     _breaks_ready
        jsr     read_memory_byte
        cmp     #op_swi
        beq     _adjust_swi_stack
        bset    map_step_brk_bit, map_switch

_breaks_ready:
        brclr   map_step_armed_bit, map_switch, _restore_trace
        ldx     #brk_temp_slot
        lda     #brk_step_slot
        jsr     restore_break_range
        ldx     #brk_step_slot
        jsr     clear_addr_slots
        bclr    map_brk_armed_bit, map_switch

_restore_trace:
        brclr   map_brk_armed_bit, map_switch, _restore_user_pc
        jsr     restore_breaks

_restore_user_pc:
        jsr     write_stack_pc
        jsr     restore_addr
        brset   map_step_brk_bit, map_switch, _step_break
        clr     map_switch
        bset    map_mon_bit, map_switch
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
        ldx     #msg_brkpt
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
        ldx     #msg_empty
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
        ldx     #msg_abort
        bra     _reset_msg

_adjust_swi_stack:
        lda     user_sp
        sub     #stk_len
        sta     user_sp
        ldx     #stk_swi_src

_copy_stack_byte:
        stx     _stk_idx
        jsr     read_stack_byte
        sta     word_hi
        txa
        sub     #stk_len
        tax
        jsr     write_stack_byte
        ldx     _stk_idx
        incx
        cpx     #stk_swi_end
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
        .byte   "AS",  ('M' | msg_end)
        .byte   "B",   ('F' | msg_end)
        .byte   "B",   ('R' | msg_end)
        .byte          ('G' | msg_end)
        .byte   "LOA", ('D' | msg_end)
        .byte   "M",   ('D' | msg_end)
        .byte   "M",   ('M' | msg_end)
        .byte   "NOB", ('R' | msg_end)
        .byte          ('P' | msg_end)
        .byte   "R",   ('D' | msg_end)
        .byte   "R",   ('M' | msg_end)
        .byte          ('T' | msg_end)
        .byte   "HEL", ('P' | msg_end)
        .byte   NUL

; banner text

message_text:
msg_banner      .equ    ($ - message_text)
        .byte   "EVSbug-HC05 REV 1.2", NUL
msg_empty       .equ    ($ - message_text) - 1
msg_brkpt       .equ    ($ - message_text)
        .byte   "Brkpt", NUL
msg_abort       .equ    ($ - message_text)
        .byte   "Abort", NUL
msg_regs        .equ    ($ - message_text)
        .byte   "Regs ", NUL
msg_bad_entry   .equ    ($ - message_text)
        .byte   "ILLEGAL/INSUFFICIENT ENTRY", NUL
msg_sp4         .equ    ($ - message_text)
        .byte   SP
msg_sp3         .equ    ($ - message_text)
        .byte   SP, SP, SP, NUL

; help text

help_intro:
        .byte   "BREAK = Abort command, ", CR, LF
        .byte   "CTRL-S = Freeze screen, CTRL-X = Cancel command line", CR, LF
        .byte   "ASM <START ADDR>- Assembler/disassembler", CR, LF
        .byte   "BF <START ADDR> <END ADDR> <DATA>- Block fill memory", NUL

help_breakpoint:
        .byte   "BR [<ADDR1 - ADDR5>]- Set 1 to 5 breakpoints", NUL

help_go_load_md:
        .byte   "G [<START ADDR>]- Execute user program", CR, LF
        .byte   "LOAD T - Download from port to memory", CR, LF
        .byte   "MD <START ADDR> [<END ADDR>]- Display memory", NUL

help_modify_nobr_proceed:
        .byte   "MM <ADDRESS>- Modify memory", CR, LF
        .byte   "NOBR [<ADDR1 - ADDR5>]- Remove breakpoints", CR, LF
        .byte   "P [<COUNT>]- Proceed 1-FF times through a breakpoint", CR, LF
        .byte   "RD- Register display", NUL

help_register_trace:
        .byte   "RM- Register modify", CR, LF
        .byte   "T [<COUNT>]- Trace 1-FF instructions", NUL

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
