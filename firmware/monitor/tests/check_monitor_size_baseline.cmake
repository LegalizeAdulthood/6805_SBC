foreach(required_var IN ITEMS MONITOR_SYMBOLS EXPECTED_ROM_END)
    if(NOT DEFINED ${required_var} OR "${${required_var}}" STREQUAL "")
        message(FATAL_ERROR "${required_var} is required")
    endif()
endforeach()

if(NOT EXISTS "${MONITOR_SYMBOLS}")
    message(FATAL_ERROR "monitor symbols do not exist: ${MONITOR_SYMBOLS}")
endif()

string(TOUPPER "${EXPECTED_ROM_END}" expected_rom_end)
string(REGEX REPLACE "^0X" "" expected_rom_end "${expected_rom_end}")

if(NOT expected_rom_end MATCHES "^[0-9A-F][0-9A-F][0-9A-F][0-9A-F]$")
    message(FATAL_ERROR "EXPECTED_ROM_END must be a four digit hex value, got '${EXPECTED_ROM_END}'")
endif()

file(STRINGS "${MONITOR_SYMBOLS}" symbol_lines)
foreach(line IN LISTS symbol_lines)
    if(line MATCHES "^rom_end[ \t]+([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])")
        string(TOUPPER "${CMAKE_MATCH_1}" actual_rom_end)
    endif()
endforeach()

if(NOT DEFINED actual_rom_end)
    message(FATAL_ERROR "missing rom_end symbol")
endif()

if(NOT actual_rom_end STREQUAL expected_rom_end)
    math(EXPR actual_used "0x${actual_rom_end} - 0x1000")
    math(EXPR expected_used "0x${expected_rom_end} - 0x1000")
    message(FATAL_ERROR
        "monitor rom_end is ${actual_rom_end} (${actual_used} bytes from $1000), "
        "expected ${expected_rom_end} (${expected_used} bytes). Update the size "
        "baseline only for intentional ROM growth or shrinkage."
    )
endif()
