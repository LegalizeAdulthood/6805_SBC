if(NOT DEFINED MONITOR_SOURCE)
    message(FATAL_ERROR "MONITOR_SOURCE is required")
endif()

if(NOT EXISTS "${MONITOR_SOURCE}")
    message(FATAL_ERROR "monitor source does not exist: ${MONITOR_SOURCE}")
endif()

file(STRINGS "${MONITOR_SOURCE}" source_lines)
file(READ "${MONITOR_SOURCE}" source_text)

set(errors "")

set(required_tables
    "mnemonics"
    "mnemonic_modes"
    "op_tbl"
    "op30_idx"
    "opa0_idx"
    "brbit_idx"
    "op80_idx"
)

foreach(table IN LISTS required_tables)
    set(block_${table} "")
    set(seen_${table} FALSE)
endforeach()

set(section "")

foreach(line IN LISTS source_lines)
    if(line MATCHES "^([A-Za-z_][A-Za-z0-9_]*):")
        set(label "${CMAKE_MATCH_1}")
        list(FIND required_tables "${label}" table_index)
        if(NOT table_index EQUAL -1)
            set(section "${label}")
            set(seen_${label} TRUE)
        elseif(NOT section STREQUAL "")
            set(section "")
        endif()
    endif()

    if(NOT section STREQUAL "")
        set(block_${section} "${block_${section}}${line}\n")
    endif()
endforeach()

foreach(table IN LISTS required_tables)
    if(NOT seen_${table})
        list(APPEND errors "missing EVSBUG12-derived table label '${table}'")
    endif()

    if(NOT source_text MATCHES ";[^\n]*${table}")
        list(APPEND errors "missing review comment for EVSBUG12-derived table '${table}'")
    endif()
endforeach()

function(require_source_regex description regex)
    if(NOT source_text MATCHES "${regex}")
        list(APPEND errors "${description}")
        set(errors "${errors}" PARENT_SCOPE)
    endif()
endfunction()

function(require_block_regex table description regex)
    if(NOT block_${table} MATCHES "${regex}")
        list(APPEND errors "${description}")
        set(errors "${errors}" PARENT_SCOPE)
    endif()
endfunction()

foreach(symbol IN ITEMS
        "op_adc_imm" "op_add_imm" "op_and_imm" "op_asl_dir"
        "op_bcc" "op_bclr0" "op_brset0" "op_bset0"
        "op_lda_imm" "op_sta_base" "op_wait"
        "op_adc_idx" "op_brset_idx" "op_bset_idx" "op_fcb_idx"
        "op_lda_idx" "op_unused_idx")
    require_source_regex(
        "missing symbolic opcode metadata '${symbol}'"
        "(^|\n)${symbol}[ \t]+\\.equ[ \t]+"
    )
endforeach()

foreach(symbol IN ITEMS "_inh" "_bit_dir" "_rel" "_idx" "_bad" "_mem" "_imm_mem" "_bit_rel")
    require_source_regex(
        "missing symbolic operand-mode metadata '${symbol}'"
        "(^|\n)${symbol}[ \t]+\\.equ[ \t]+"
    )
endforeach()

require_block_regex(
    "mnemonics"
    "mnemonic text should use high-bit terminators instead of fixed strings"
    "msg_end"
)
require_block_regex(
    "mnemonics"
    "mnemonic text should be translated to local lower-case style"
    "\"ad\""
)
require_block_regex(
    "mnemonic_modes"
    "mnemonic mode table should name immediate/memory classes"
    "_imm_mem[ \t]*\\|"
)
require_block_regex(
    "mnemonic_modes"
    "mnemonic mode table should name bit-relative classes"
    "_bit_rel[ \t]*\\|"
)
require_block_regex(
    "op_tbl"
    "opcode table should use named opcode equates"
    "op_adc_imm"
)
require_block_regex(
    "op_tbl"
    "opcode table should include the wait opcode metadata"
    "op_wait"
)
require_block_regex(
    "op30_idx"
    "30-7f index table should use mnemonic index equates"
    "op_neg_idx"
)
require_block_regex(
    "op30_idx"
    "30-7f index table should preserve EVSBUG12 lsl mnemonic selection"
    "op_lsl_idx"
)
require_block_regex(
    "op30_idx"
    "30-7f index table should mark unused entries symbolically"
    "op_unused_idx"
)
require_block_regex(
    "opa0_idx"
    "a0-af index table should use arithmetic/load/store indices"
    "op_sub_idx.*op_stx_idx"
)
require_block_regex(
    "brbit_idx"
    "branch/bit index table should use branch and bit indices"
    "op_brset_idx.*op_bih_idx"
)
require_block_regex(
    "op80_idx"
    "80-9f index table should use inherent opcode indices"
    "op_rti_idx.*op_txa_idx"
)

if(errors)
    list(JOIN errors "\n  - " error_text)
    message(FATAL_ERROR "monitor opcode table audit failed:\n  - ${error_text}")
endif()
