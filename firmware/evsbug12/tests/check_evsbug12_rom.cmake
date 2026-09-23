foreach(required_var IN ITEMS EVSBUG12_BINARY EVSBUG12_ROM)
    if(NOT DEFINED ${required_var})
        message(FATAL_ERROR "${required_var} is required")
    endif()

    if(NOT EXISTS "${${required_var}}")
        message(FATAL_ERROR "${required_var} does not exist: ${${required_var}}")
    endif()
endforeach()

file(READ "${EVSBUG12_BINARY}" actual_hex HEX)
file(READ "${EVSBUG12_ROM}" expected_hex HEX)
string(TOLOWER "${actual_hex}" actual_hex)
string(TOLOWER "${expected_hex}" expected_hex)

string(LENGTH "${actual_hex}" actual_hex_length)
string(LENGTH "${expected_hex}" expected_hex_length)
math(EXPR actual_byte_length "${actual_hex_length} / 2")
math(EXPR expected_byte_length "${expected_hex_length} / 2")

if(NOT actual_hex_length EQUAL expected_hex_length)
    message(
        FATAL_ERROR
        "EVSBUG12 ROM size mismatch: assembled ${actual_byte_length} bytes, expected ${expected_byte_length} bytes"
    )
endif()

if(NOT actual_hex STREQUAL expected_hex)
    math(EXPR last_byte "${expected_byte_length} - 1")

    foreach(byte_index RANGE 0 ${last_byte})
        math(EXPR hex_index "${byte_index} * 2")
        string(SUBSTRING "${actual_hex}" ${hex_index} 2 actual_byte)
        string(SUBSTRING "${expected_hex}" ${hex_index} 2 expected_byte)

        if(NOT actual_byte STREQUAL expected_byte)
            message(
                FATAL_ERROR
                "EVSBUG12 ROM byte mismatch at offset ${byte_index}: assembled 0x${actual_byte}, expected 0x${expected_byte}"
            )
        endif()
    endforeach()

    message(FATAL_ERROR "EVSBUG12 ROM differs from repository dump")
endif()

message(STATUS "EVSBUG12 assembled ROM matches repository dump (${expected_byte_length} bytes)")
