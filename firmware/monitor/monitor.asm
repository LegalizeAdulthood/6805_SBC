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

        .ORG    $1000
reset_entry:
        RSP
        LDA     #MONITOR_STACK_TOP
        STA     SAVED_SP
        LDA     #$10
        STA     SAVED_PC_HI
        LDA     #$00
        STA     SAVED_PC_LO
        CLRA
        STA     SAVED_A
        CLRX
        STX     SAVED_X
        LDA     #RESET_CC
        STA     SAVED_CC
        LDA     #STOP_RESET
        STA     STOP_REASON
        BRA     monitor_idle

swi_entry:
        BRA     monitor_idle

timer_entry:
        BRA     monitor_idle

monitor_idle:
        BRA     monitor_idle

rom_code_end:

        .ORG    $1FF6
        .DW     timer_entry     ; Timer from wait state
        .DW     timer_entry     ; Timer
        .DW     reset_entry     ; External interrupt
        .DW     swi_entry       ; Software interrupt
        .DW     reset_entry     ; Reset

        .END
