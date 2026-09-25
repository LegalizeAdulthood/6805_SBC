        .msfirst
#include "monitor_entries.inc"

        .org    $0200

        .module srec_test

mode    .equ    $ff
done    .equ    $fe

; The MAME harness selects load or dump, then checks memory and serial bytes.

start:
        lda     mode
        cmp     #$01
        beq     _dump
        jsr     srec_load
        bra     _done

_dump:
        jsr     srec_dump

_done:
        inc     done

_halt:
        bra     _halt

        .end
