        .msfirst
#include "monitor_entries.inc"

        .org    $0000

        .module disasm_test

row_cur .equ    $60
rows_done .equ  $61

start:
        jsr     draw_dasm_row
        inc     rows_done
_halt:
        bra     _halt

        .end
