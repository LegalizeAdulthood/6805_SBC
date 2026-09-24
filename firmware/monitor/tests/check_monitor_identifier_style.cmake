foreach(required_var IN ITEMS MONITOR_SOURCE MONITOR_SYMBOLS)
    if(NOT DEFINED ${required_var} OR "${${required_var}}" STREQUAL "")
        message(FATAL_ERROR "${required_var} is required")
    endif()
endforeach()

if(NOT EXISTS "${MONITOR_SOURCE}")
    message(FATAL_ERROR "monitor source does not exist: ${MONITOR_SOURCE}")
endif()

if(NOT EXISTS "${MONITOR_SYMBOLS}")
    message(FATAL_ERROR "monitor symbols do not exist: ${MONITOR_SYMBOLS}")
endif()

set(errors "")

file(STRINGS "${MONITOR_SYMBOLS}" symbol_lines)
set(symbol_count 0)

foreach(line IN LISTS symbol_lines)
    if(NOT line MATCHES "^([^ \t]+)[ \t]+[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]")
        continue()
    endif()

    set(symbol "${CMAKE_MATCH_1}")
    math(EXPR symbol_count "${symbol_count} + 1")
    string(REPLACE "." ";" components "${symbol}")
    list(LENGTH components component_count)

    foreach(component IN LISTS components)
        string(LENGTH "${component}" component_length)
        if(component_length GREATER 16)
            list(APPEND errors
                "symbol '${symbol}' component '${component}' is longer than 16 characters"
            )
        endif()
    endforeach()

    if(component_count GREATER 1)
        math(EXPR last_component_index "${component_count} - 1")
        foreach(component_index RANGE 1 ${last_component_index})
            list(GET components ${component_index} local_name)
            string(LENGTH "${local_name}" local_length)
            if(local_length GREATER 8)
                list(APPEND errors
                    "local symbol '${symbol}' component '${local_name}' is longer than 8 characters"
                )
            endif()
            if(NOT local_name MATCHES "^_")
                list(APPEND errors
                    "local symbol '${symbol}' component '${local_name}' should start with '_'"
                )
            endif()
        endforeach()
    endif()
endforeach()

if(symbol_count EQUAL 0)
    list(APPEND errors "monitor symbol file did not contain any symbols")
endif()

file(STRINGS "${MONITOR_SOURCE}" source_lines)
set(line_no 0)

foreach(line IN LISTS source_lines)
    math(EXPR line_no "${line_no} + 1")

    if(NOT line MATCHES "^[ \t]*\\.module[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
        continue()
    endif()

    set(module "${CMAKE_MATCH_1}")
    string(LENGTH "${module}" module_length)
    if(module_length GREATER 16)
        list(APPEND errors
            "module '${module}' at line ${line_no} is longer than 16 characters"
        )
    endif()
endforeach()

if(errors)
    list(JOIN errors "\n  - " error_text)
    message(FATAL_ERROR "monitor.asm identifier style failed:\n  - ${error_text}")
endif()
