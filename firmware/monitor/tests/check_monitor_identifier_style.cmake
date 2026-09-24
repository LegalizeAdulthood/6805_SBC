if(NOT DEFINED MONITOR_SOURCE)
    message(FATAL_ERROR "MONITOR_SOURCE is required")
endif()

if(NOT EXISTS "${MONITOR_SOURCE}")
    message(FATAL_ERROR "monitor source does not exist: ${MONITOR_SOURCE}")
endif()

set(public_labels
    "reset_entry"
    "swi_entry"
    "timer_wait_dispatch"
    "timer_dispatch"
    "external_dispatch"
    "timer_wait_default_handler"
    "timer_default_handler"
    "external_default_handler"
    "init_console"
    "chrout"
    "draw_boot_screen"
    "draw_cpu_row"
    "emit_cpu_row_text"
    "emit_spaces"
    "decode_inst"
    "disassemble_line"
    "emit_hex_byte"
    "emit_hex_nibble"
    "emit_flag_h"
    "emit_flag_i"
    "emit_flag_n"
    "emit_flag_z"
    "emit_flag_c"
    "emit_stop_reason"
    "draw_memory_row"
    "draw_disassembly_row"
    "emit_memory_ascii"
    "init_memory_panel"
    "memory_key_input"
    "memory_cursor_left"
    "memory_cursor_right"
    "memory_cursor_up"
    "memory_cursor_down"
    "memory_cursor_done"
    "mem_thunk_read"
    "mem_thunk_write"
    "memory_read_cursor"
    "memory_select_cursor"
    "memory_write_cursor"
    "test_console_output"
    "test_cpu_row_output"
    "test_memory_row_output"
    "test_disassembler_output"
    "monitor_idle"
    "rom_code_end"
)

file(STRINGS "${MONITOR_SOURCE}" source_lines)

set(active_module "")
set(errors "")
set(line_no 0)

foreach(line IN LISTS source_lines)
    math(EXPR line_no "${line_no} + 1")

    if(line MATCHES "^[ \t]*\\.module[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
        set(active_module "${CMAKE_MATCH_1}")
    endif()

    set(kind "")
    set(identifier "")
    if(line MATCHES "^([A-Za-z_][A-Za-z0-9_]*):")
        set(kind "label")
        set(identifier "${CMAKE_MATCH_1}")
    elseif(NOT active_module STREQUAL "" AND line MATCHES "^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]+\\.equ[ \t]+")
        set(kind "equate")
        set(identifier "${CMAKE_MATCH_1}")
    endif()

    if(kind STREQUAL "")
        continue()
    endif()

    if(active_module STREQUAL "data_tables")
        continue()
    endif()

    list(FIND public_labels "${identifier}" public_index)
    if(NOT public_index EQUAL -1)
        continue()
    endif()

    string(LENGTH "${identifier}" identifier_length)
    if(identifier_length GREATER 8)
        list(APPEND errors
            "${kind} '${identifier}' at line ${line_no} is module-local; use <= 8 characters or make it an explicitly justified public name"
        )
    endif()

    if(kind STREQUAL "label" AND NOT identifier MATCHES "^_")
        list(APPEND errors
            "local label '${identifier}' at line ${line_no} should use module-local underscore spelling"
        )
    endif()
endforeach()

if(errors)
    list(JOIN errors "\n  - " error_text)
    message(FATAL_ERROR "monitor.asm identifier style failed:\n  - ${error_text}")
endif()
