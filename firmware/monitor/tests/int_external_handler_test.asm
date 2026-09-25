        .msfirst
#include "monitor_entries.inc"

        .org    $0000

        .module int_tst

marker  .equ    $002f

; External interrupt dispatch should indirect through the RAM vector.  This
; handler uses a different marker byte so the test can distinguish paths.

start:
        lda     #$5a
        sta     marker
        jmp     idle

        .end
