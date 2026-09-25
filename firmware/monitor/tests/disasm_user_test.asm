        .msfirst
#include "monitor_entries.inc"

        .org    $0110

        .module disasm_test

row_cur .equ    $ff
rows_done .equ  $fe

start:
        jsr     draw_dasm_row
        inc     rows_done
_halt:
        bra     _halt

        .end
