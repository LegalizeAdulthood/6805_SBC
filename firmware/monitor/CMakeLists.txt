set(TASM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../tasm32")
set(TASM_EXE "${TASM_DIR}/TASM.EXE")
set(TASM_6805_TABLE "${TASM_DIR}/TASM05.TAB")

set(MAME_COMMAND "" CACHE PATH "Directory hint used to find the MAME executable")

if(NOT MAME_COMMAND AND DEFINED M6805SBC_EXE)
    get_filename_component(MAME_COMMAND "${M6805SBC_EXE}" DIRECTORY)
    set(MAME_COMMAND "${MAME_COMMAND}" CACHE PATH "Directory hint used to find the MAME executable" FORCE)
endif()

if(DEFINED ENV{MAME_COMMAND} AND NOT "$ENV{MAME_COMMAND}" STREQUAL "")
    file(TO_CMAKE_PATH "$ENV{MAME_COMMAND}" MAME_COMMAND)
    set(MAME_COMMAND "${MAME_COMMAND}" CACHE PATH "Directory hint used to find the MAME executable" FORCE)
endif()

unset(MAME_EXECUTABLE CACHE)
unset(MAME_EXECUTABLE)

if(MAME_COMMAND)
    set(MAME_COMMAND_HINT "${MAME_COMMAND}")

    if(NOT IS_DIRECTORY "${MAME_COMMAND}")
        get_filename_component(MAME_COMMAND_HINT "${MAME_COMMAND}" DIRECTORY)
    endif()

    find_program(
        MAME_EXECUTABLE
        NAMES mame mame.exe m6805sbc.exe
        HINTS "${MAME_COMMAND_HINT}"
        DOC "Path to the MAME executable"
    )
endif()

set(MONITOR_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/monitor.asm")
set(MONITOR_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(MONITOR_BINARY "${MONITOR_OUTPUT_DIR}/monitor.bin")
set(MONITOR_BINARY_LISTING "${MONITOR_OUTPUT_DIR}/monitor.lst")
set(MONITOR_EXPORTS "${MONITOR_OUTPUT_DIR}/monitor.exp")
set(MONITOR_SYMBOLS "${MONITOR_OUTPUT_DIR}/monitor.sym")
set(MONITOR_SREC "${MONITOR_OUTPUT_DIR}/monitor.s19")
set(MONITOR_SREC_LISTING "${MONITOR_OUTPUT_DIR}/monitor-s19.lst")
set(MONITOR_VERSION_TEXT "MONITOR ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}")
set(MONITOR_VERSION_INCLUDE "${MONITOR_OUTPUT_DIR}/monitor_version.inc")
set(MONITOR_BUILD_TASM_TABLE "${MONITOR_OUTPUT_DIR}/TASM05.TAB")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/monitor_version.inc.in"
    "${MONITOR_VERSION_INCLUDE}"
    @ONLY
    NEWLINE_STYLE CRLF
)

add_custom_command(
    OUTPUT "${MONITOR_BUILD_TASM_TABLE}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${MONITOR_OUTPUT_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${TASM_6805_TABLE}" "${MONITOR_BUILD_TASM_TABLE}"
    DEPENDS "${TASM_6805_TABLE}"
    COMMENT "Copying TASM 6805 table for monitor build"
    VERBATIM
)

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
        "${MONITOR_VERSION_INCLUDE}"
        "${MONITOR_BUILD_TASM_TABLE}"
        "${TASM_EXE}"
    WORKING_DIRECTORY "${MONITOR_OUTPUT_DIR}"
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
        "${MONITOR_VERSION_INCLUDE}"
        "${MONITOR_BUILD_TASM_TABLE}"
        "${TASM_EXE}"
    WORKING_DIRECTORY "${MONITOR_OUTPUT_DIR}"
    COMMENT "Assembling monitor.asm to Motorola S-record"
    VERBATIM
)

add_custom_target(monitor ALL DEPENDS "${MONITOR_BINARY}")
add_custom_target(monitor-s19 ALL DEPENDS "${MONITOR_SREC}")

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
