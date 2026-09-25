        .msfirst
#include "monitor_entries.inc"

        .org    $0120

        .module int_tst

marker  .equ    $00ff

; External interrupt dispatch should indirect through the RAM vector.  This
; handler uses a different marker byte so the test can distinguish paths.

start:
        lda     #$5a
        sta     marker
        jmp     idle

        .end
