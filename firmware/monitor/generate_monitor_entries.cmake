foreach(_required_var IN ITEMS MONITOR_SYMBOLS MONITOR_ENTRIES_OUTPUT MONITOR_ENTRY_SYMBOLS)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required")
    endif()
endforeach()

if(NOT EXISTS "${MONITOR_SYMBOLS}")
    message(FATAL_ERROR "monitor symbol file does not exist: ${MONITOR_SYMBOLS}")
endif()

file(STRINGS "${MONITOR_SYMBOLS}" _symbol_lines)
foreach(_line IN LISTS _symbol_lines)
    if(_line MATCHES "^([^ \t]+)[ \t]+([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])")
        string(TOLOWER "${CMAKE_MATCH_1}" _symbol_name)
        string(TOUPPER "${CMAKE_MATCH_2}" _symbol_value)
        set("SYM_${_symbol_name}" "${_symbol_value}")
    endif()
endforeach()

set(_output "; Generated from monitor.sym. Do not edit.\n")

foreach(_symbol IN LISTS MONITOR_ENTRY_SYMBOLS)
    string(TOLOWER "${_symbol}" _symbol_lc)

    if(_symbol_lc MATCHES "\\.")
        message(FATAL_ERROR "monitor entry '${_symbol}' must be a global symbol")
    endif()

    if(NOT DEFINED "SYM_${_symbol_lc}")
        message(FATAL_ERROR "monitor entry '${_symbol}' was not found in ${MONITOR_SYMBOLS}")
    endif()

    set(_value "${SYM_${_symbol_lc}}")
    math(EXPR _address "0x${_value}")
    if(_address LESS 0x1000 OR _address GREATER 0x1fff)
        message(FATAL_ERROR "monitor entry '${_symbol}' is outside ROM: ${_value}")
    endif()

    string(APPEND _output "${_symbol_lc}       .equ    $${_value}\n")
endforeach()

file(WRITE "${MONITOR_ENTRIES_OUTPUT}" "${_output}")
