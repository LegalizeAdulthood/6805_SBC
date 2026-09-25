        .msfirst

        .org    $0000

        .module trace_test

; TRACE should execute three instructions and stop before the SWI.  Each
; instruction changes A so the saved accumulator reveals how far execution ran.

start:
        lda     #$11
        lda     #$12
        lda     #$13
        swi

        .end
