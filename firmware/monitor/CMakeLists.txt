set(TASM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../tasm32")
set(TASM_EXE "${TASM_DIR}/TASM.EXE")
set(TASM_6805_TABLE "${TASM_DIR}/TASM05.TAB")
set(BUNDLED_MAME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../mame")
set(MAME_SYSTEM_NAME "m6805sbc")

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

function(_mame_supports_system _candidate _supports_var)
    set(${_supports_var} FALSE PARENT_SCOPE)

    if(NOT _candidate)
        return()
    endif()

    execute_process(
        COMMAND "${_candidate}" -listxml "${MAME_SYSTEM_NAME}"
        RESULT_VARIABLE _mame_listxml_result
        OUTPUT_VARIABLE _mame_listxml_stdout
        ERROR_VARIABLE _mame_listxml_stderr
    )

    if(_mame_listxml_result EQUAL 0 AND _mame_listxml_stdout MATCHES "<machine name=\"${MAME_SYSTEM_NAME}\"")
        set(${_supports_var} TRUE PARENT_SCOPE)
    else()
        message(STATUS "MAME executable does not support ${MAME_SYSTEM_NAME}: ${_candidate}")
    endif()
endfunction()

if(MAME_COMMAND)
    set(MAME_COMMAND_HINT "${MAME_COMMAND}")

    if(NOT IS_DIRECTORY "${MAME_COMMAND}")
        get_filename_component(MAME_COMMAND_HINT "${MAME_COMMAND}" DIRECTORY)
    endif()

    find_program(
        MAME_EXECUTABLE
        NAMES m6805sbc m6805sbc.exe mame mame.exe
        HINTS "${MAME_COMMAND_HINT}"
        DOC "Path to the MAME executable"
    )

    _mame_supports_system("${MAME_EXECUTABLE}" _mame_command_supports_system)
    if(NOT _mame_command_supports_system)
        unset(MAME_EXECUTABLE CACHE)
        unset(MAME_EXECUTABLE)
    endif()
endif()

if(NOT MAME_EXECUTABLE)
    find_program(
        MAME_EXECUTABLE
        NAMES m6805sbc m6805sbc.exe mame mame.exe
        HINTS "${BUNDLED_MAME_DIR}"
        NO_DEFAULT_PATH
        DOC "Path to the MAME executable"
    )

    _mame_supports_system("${MAME_EXECUTABLE}" _bundled_mame_supports_system)
    if(NOT _bundled_mame_supports_system)
        unset(MAME_EXECUTABLE CACHE)
        unset(MAME_EXECUTABLE)
    endif()
endif()

if(MAME_EXECUTABLE)
    message(STATUS "Using MAME executable for ${MAME_SYSTEM_NAME}: ${MAME_EXECUTABLE}")
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
set(MONITOR_EXPECTED_ROM_END "1E0B")
set(MONITOR_VERSION_INCLUDE "${MONITOR_OUTPUT_DIR}/monitor_version.inc")
set(MONITOR_BUILD_TASM_TABLE "${MONITOR_OUTPUT_DIR}/TASM05.TAB")
set(MONITOR_ENTRIES_INCLUDE "${MONITOR_OUTPUT_DIR}/monitor_entries.inc")
set(MONITOR_ENTRY_SYMBOLS draw_dasm_row idle srec_load srec_dump)

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

add_custom_command(
    OUTPUT "${MONITOR_ENTRIES_INCLUDE}"
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMONITOR_ENTRIES_OUTPUT=${MONITOR_ENTRIES_INCLUDE}"
        "-DMONITOR_ENTRY_SYMBOLS=${MONITOR_ENTRY_SYMBOLS}"
        -P
        "${CMAKE_CURRENT_SOURCE_DIR}/generate_monitor_entries.cmake"
    DEPENDS
        "${MONITOR_BINARY}"
        "${CMAKE_CURRENT_SOURCE_DIR}/generate_monitor_entries.cmake"
    COMMENT "Generating monitor ROM entry include"
    VERBATIM
)

add_custom_target(monitor-entries DEPENDS "${MONITOR_ENTRIES_INCLUDE}")

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
