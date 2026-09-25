if(NOT DEFINED MONITOR_SOURCE)
    message(FATAL_ERROR "MONITOR_SOURCE is required")
endif()

if(NOT EXISTS "${MONITOR_SOURCE}")
    message(FATAL_ERROR "monitor source does not exist: ${MONITOR_SOURCE}")
endif()

file(STRINGS "${MONITOR_SOURCE}" source_lines)

set(active_module "")
set(errors "")
set(line_no 0)
set(global_equates "")
set(module_equates "")

foreach(line IN LISTS source_lines)
    math(EXPR line_no "${line_no} + 1")

    if(line MATCHES "^[ \t]*\\.module[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
        set(active_module "${CMAKE_MATCH_1}")
    endif()

    if(line MATCHES "^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]+\\.equ[ \t]+([^; \t][^;]*)(;.*)?$")
        set(name "${CMAKE_MATCH_1}")
        string(STRIP "${CMAKE_MATCH_2}" expr)
        set(comment "${CMAKE_MATCH_3}")
        if(active_module STREQUAL "")
            list(APPEND global_equates "${name}")
            set("global_expr_${name}" "${expr}")
        else()
            list(APPEND module_equates "${active_module}:${name}")
            set("module_expr_${active_module}_${name}" "${expr}")
            set("module_comment_${active_module}_${name}" "${comment}")
            set("module_line_${active_module}_${name}" "${line_no}")
        endif()
    endif()
endforeach()

macro(require_global name)
    list(FIND global_equates "${name}" index)
    if(index EQUAL -1)
        list(APPEND errors "missing global RAM-map equate '${name}'")
    endif()
endmacro()

macro(forbid_global name)
    list(FIND global_equates "${name}" index)
    if(NOT index EQUAL -1)
        list(APPEND errors "short-lived RAM '${name}' is still a global equate")
    endif()
endmacro()

macro(require_module_scratch module name)
    list(FIND module_equates "${module}:${name}" index)
    if(index EQUAL -1)
        list(APPEND errors "missing module-local scratch alias '${name}' in module '${module}'")
    else()
        if(NOT "${module_expr_${module}_${name}}" MATCHES "^scratch( *\\+ *\\$[0-9A-Fa-f]+)?$")
            list(APPEND errors
                "scratch alias '${module}:${name}' must be expressed relative to scratch, got '${module_expr_${module}_${name}}'"
            )
        endif()
        if("${module_comment_${module}_${name}}" STREQUAL "")
            list(APPEND errors
                "scratch alias '${module}:${name}' at line ${module_line_${module}_${name}} needs an ownership/lifetime comment"
            )
        endif()
    endif()
endmacro()

require_global("scratch")
if(DEFINED global_expr_dline_buf AND NOT "${global_expr_dline_buf}" STREQUAL "scratch + $03")
    list(APPEND errors "dline_buf must reclaim the original scratch bytes before the line buffer")
endif()
if(DEFINED global_expr_dline_tmp AND NOT "${global_expr_dline_tmp}" STREQUAL "dline_buf + $14")
    list(APPEND errors "dline_tmp must be inside the contiguous scratch window")
endif()
require_global("dline_buf")
require_global("dline_tmp")

foreach(name
        hex_value
        memory_row_hi
        memory_row_lo
        memory_row_index
        disasm_opcode
        disasm_test_count)
    forbid_global("${name}")
endforeach()

foreach(name
        saved_sp
        saved_pc_hi
        saved_pc_lo
        saved_a
        saved_x
        saved_cc
        stop_rsn
        tmr_wt_vec_hi
        tmr_wt_vec_lo
        tmr_vec_hi
        tmr_vec_lo
        ext_vec_hi
        ext_vec_lo
        int_jmp_op
        int_jmp_hi
        int_jmp_lo
        mem_thunk_op
        mem_thunk_hi
        mem_thunk_lo
        mem_thunk_rts
        mem_page_hi
        mem_page_lo
        mem_cur_hi
        mem_cur_lo
        mem_focus
        mem_hex_phs
        disasm_pc_hi
        disasm_pc_lo
        asm_len)
    require_global("${name}")
endforeach()

require_module_scratch("scr_out" "_save")
require_module_scratch("dasm_out" "_op")
require_module_scratch("dasm_out" "_len")
require_module_scratch("dasm_out" "_mnem")
require_module_scratch("dasm_out" "_pos")
require_module_scratch("hex_out" "_byte")
require_module_scratch("draw_mem_row" "_idx")
require_module_scratch("mem_edit" "_ch")
require_module_scratch("mem_edit" "_nib")
require_module_scratch("mem_edit" "_tmp")
require_module_scratch("mem_cur" "_byte")
require_module_scratch("asm_cmd" "_len")

if(errors)
    list(JOIN errors "\n  - " error_text)
    message(FATAL_ERROR "monitor.asm RAM lifetime map failed:\n  - ${error_text}")
endif()
