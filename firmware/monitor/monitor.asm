        .MSFIRST

MONITOR_STACK_TOP      .EQU    $7F
RESET_CC               .EQU    $08

STOP_RESET             .EQU    $01

SAVED_SP               .EQU    $10
SAVED_PC_HI            .EQU    $11
SAVED_PC_LO            .EQU    $12
SAVED_A                .EQU    $13
SAVED_X                .EQU    $14
SAVED_CC               .EQU    $15
STOP_REASON            .EQU    $16

TIMER_WAIT_VECTOR_HI   .EQU    $17
TIMER_WAIT_VECTOR_LO   .EQU    $18
TIMER_VECTOR_HI        .EQU    $19
TIMER_VECTOR_LO        .EQU    $1A
EXTERNAL_VECTOR_HI     .EQU    $1B
EXTERNAL_VECTOR_LO     .EQU    $1C
INT_JUMP_OPCODE        .EQU    $1D
INT_JUMP_HI            .EQU    $1E
INT_JUMP_LO            .EQU    $1F

ACIA_STATUS            .EQU    $06
ACIA_DATA              .EQU    $07
ACIA_TDRE_BIT          .EQU    1

JMP_EXTENDED           .EQU    $CC

        .ORG    $1000
reset_entry:
        RSP
        LDA     #MONITOR_STACK_TOP
        STA     SAVED_SP
        LDA     #reset_entry/100H
        STA     SAVED_PC_HI
        LDA     #reset_entry-(reset_entry/100H*100H)
        STA     SAVED_PC_LO
        CLRA
        STA     SAVED_A
        CLRX
        STX     SAVED_X
        LDA     #RESET_CC
        STA     SAVED_CC
        LDA     #STOP_RESET
        STA     STOP_REASON
        LDA     #timer_wait_default_handler/100H
        STA     TIMER_WAIT_VECTOR_HI
        LDA     #timer_wait_default_handler-(timer_wait_default_handler/100H*100H)
        STA     TIMER_WAIT_VECTOR_LO
        LDA     #timer_default_handler/100H
        STA     TIMER_VECTOR_HI
        LDA     #timer_default_handler-(timer_default_handler/100H*100H)
        STA     TIMER_VECTOR_LO
        LDA     #external_default_handler/100H
        STA     EXTERNAL_VECTOR_HI
        LDA     #external_default_handler-(external_default_handler/100H*100H)
        STA     EXTERNAL_VECTOR_LO
        LDA     #JMP_EXTENDED
        STA     INT_JUMP_OPCODE
        BRA     monitor_idle

swi_entry:
        BRA     monitor_idle

timer_wait_dispatch:
        LDA     TIMER_WAIT_VECTOR_HI
        STA     INT_JUMP_HI
        LDA     TIMER_WAIT_VECTOR_LO
        STA     INT_JUMP_LO
        JMP     INT_JUMP_OPCODE

timer_dispatch:
        LDA     TIMER_VECTOR_HI
        STA     INT_JUMP_HI
        LDA     TIMER_VECTOR_LO
        STA     INT_JUMP_LO
        JMP     INT_JUMP_OPCODE

external_dispatch:
        LDA     EXTERNAL_VECTOR_HI
        STA     INT_JUMP_HI
        LDA     EXTERNAL_VECTOR_LO
        STA     INT_JUMP_LO
        JMP     INT_JUMP_OPCODE

timer_wait_default_handler:
        BRA     monitor_idle

timer_default_handler:
        BRA     monitor_idle

external_default_handler:
        BRA     monitor_idle

CHROUT:
        BRCLR   ACIA_TDRE_BIT,ACIA_STATUS,CHROUT
        STA     ACIA_DATA
        RTS

test_console_output:
        LDA     #$4F
        JSR     CHROUT
        LDA     #$4B
        JSR     CHROUT
        LDA     #$0D
        JSR     CHROUT
        LDA     #$0A
        JSR     CHROUT
        BRA     monitor_idle

monitor_idle:
        BRA     monitor_idle

rom_code_end:

        .ORG    $1FF6
        .DW     timer_wait_dispatch   ; Timer from wait state
        .DW     timer_dispatch        ; Timer
        .DW     external_dispatch     ; External interrupt
        .DW     swi_entry       ; Software interrupt
        .DW     reset_entry     ; Reset

        .END
