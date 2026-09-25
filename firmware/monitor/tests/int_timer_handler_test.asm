        .msfirst
#include "monitor_entries.inc"

        .org    $0110

        .module int_tst

marker  .equ    $00ff

; Timer dispatch should indirect through the RAM vector.  This handler records
; a marker byte, then returns to the monitor idle loop instead of using RTI.

start:
        lda     #$a5
        sta     marker
        jmp     idle

        .end
