        .msfirst

        .org    $0110

        .module swi_test

; Exercise the monitor SWI entry path with recognizable user CPU state.
; The flag instructions leave carry and interrupt mask set so the test can
; verify that SWI saved the condition code register from the user program.

start:
        ldx     #$34
        lda     #$00
        clc
        cli
        sec
        sei
        swi

        .end
