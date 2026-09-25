        .msfirst

        .org    $0110

        .module step_test

; STEP should execute only the first instruction.  The following NOP and SWI
; make it clear if the timer single-step path runs too far.

start:
        lda     #$22
        nop
        swi

        .end
