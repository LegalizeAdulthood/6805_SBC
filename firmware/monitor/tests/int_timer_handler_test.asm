        .msfirst
#include "monitor_entries.inc"

        .org    $0000

        .module int_tst

marker  .equ    $002f

; Timer dispatch should indirect through the RAM vector.  This handler records
; a marker byte, then returns to the monitor idle loop instead of using RTI.

start:
        lda     #$a5
        sta     marker
        jmp     idle

        .end
