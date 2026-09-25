        .msfirst
#include "monitor_entries.inc"

done            .equ    $f0
cnt             .equ    $f1
pass            .equ    $a5
rows            .equ    96

        .org    $0000

        .module disasm_test

start:
        lda     #rows
        sta     cnt
_loop:
        jsr     draw_dasm_row
        dec     cnt
        bne     _loop
        lda     #pass
        sta     done
_halt:
        bra     _halt

        .end
