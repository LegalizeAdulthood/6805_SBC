        .msfirst

        .org    $0110

        .module go_test

; GO should restore saved user state and run until the user program returns
; through SWI.  The final A and X values make that resumed execution visible.

start:
        ldx     #$34
        lda     #$56
        swi

        .end
