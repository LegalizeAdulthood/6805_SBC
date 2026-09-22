        .MSFIRST

        .ORG    $1000
reset_entry:
        BRA     monitor_idle

swi_entry:
        BRA     monitor_idle

timer_entry:
        BRA     monitor_idle

monitor_idle:
        BRA     monitor_idle

rom_code_end:

        .ORG    $1FF6
        .DW     timer_entry     ; Timer from wait state
        .DW     timer_entry     ; Timer
        .DW     reset_entry     ; External interrupt
        .DW     swi_entry       ; Software interrupt
        .DW     reset_entry     ; Reset

        .END
