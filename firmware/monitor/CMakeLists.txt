set(TASM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../tasm32")
set(TASM_EXE "${TASM_DIR}/TASM.EXE")
set(TASM_6805_TABLE "${TASM_DIR}/TASM05.TAB")

get_filename_component(DEFAULT_M6805SBC_EXE "${CMAKE_SOURCE_DIR}/../mame/m6805sbc.exe" ABSOLUTE)
get_filename_component(DEFAULT_MAME_DATA_DIR "${CMAKE_SOURCE_DIR}/../mame" ABSOLUTE)
set(M6805SBC_EXE "${DEFAULT_M6805SBC_EXE}" CACHE FILEPATH "Path to the m6805sbc MAME executable")
set(M6805SBC_DATA_DIR "${DEFAULT_MAME_DATA_DIR}" CACHE PATH "Path to the source MAME data directory")

set(MONITOR_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/monitor.asm")
set(MONITOR_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(MONITOR_BINARY "${MONITOR_OUTPUT_DIR}/monitor.bin")
set(MONITOR_BINARY_LISTING "${MONITOR_OUTPUT_DIR}/monitor.lst")
set(MONITOR_EXPORTS "${MONITOR_OUTPUT_DIR}/monitor.exp")
set(MONITOR_SYMBOLS "${MONITOR_OUTPUT_DIR}/monitor.sym")
set(MONITOR_SREC "${MONITOR_OUTPUT_DIR}/monitor.s19")
set(MONITOR_SREC_LISTING "${MONITOR_OUTPUT_DIR}/monitor-s19.lst")

add_custom_command(
    OUTPUT "${MONITOR_BINARY}"
    BYPRODUCTS
        "${MONITOR_BINARY_LISTING}"
        "${MONITOR_EXPORTS}"
        "${MONITOR_SYMBOLS}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${MONITOR_OUTPUT_DIR}"
    COMMAND "${TASM_EXE}" -05 -b -fFF -s "${MONITOR_SOURCE}" "${MONITOR_BINARY}" "${MONITOR_BINARY_LISTING}" "${MONITOR_EXPORTS}" "${MONITOR_SYMBOLS}"
    DEPENDS
        "${MONITOR_SOURCE}"
        "${TASM_EXE}"
        "${TASM_6805_TABLE}"
    WORKING_DIRECTORY "${TASM_DIR}"
    COMMENT "Assembling monitor.asm to binary ROM image"
    VERBATIM
)

add_custom_command(
    OUTPUT "${MONITOR_SREC}"
    BYPRODUCTS "${MONITOR_SREC_LISTING}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${MONITOR_OUTPUT_DIR}"
    COMMAND "${TASM_EXE}" -05 -g2 "${MONITOR_SOURCE}" "${MONITOR_SREC}" "${MONITOR_SREC_LISTING}"
    DEPENDS
        "${MONITOR_SOURCE}"
        "${TASM_EXE}"
        "${TASM_6805_TABLE}"
    WORKING_DIRECTORY "${TASM_DIR}"
    COMMENT "Assembling monitor.asm to Motorola S-record"
    VERBATIM
)

add_custom_target(monitor ALL DEPENDS "${MONITOR_BINARY}")
add_custom_target(monitor-s19 ALL DEPENDS "${MONITOR_SREC}")

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
