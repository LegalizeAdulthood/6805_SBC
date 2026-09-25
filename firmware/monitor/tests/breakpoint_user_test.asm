        .msfirst

        .org    $0000

        .module bp_test

; Provide two real instructions at fixed offsets for the breakpoint test.
; The Lua harness patches both instruction starts with SWI, resumes from the
; first breakpoint, and verifies that the second breakpoint remains armed.

start:
        ldx     #$34
bp1:
        lda     #$56
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
bp2:
        ldx     #$78
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        swi

        .end
