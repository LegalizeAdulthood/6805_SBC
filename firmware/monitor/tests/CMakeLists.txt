get_filename_component(MONITOR_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

set(MONITOR_DISASM_TEST_SOURCE "${MONITOR_OUTPUT_DIR}/disasm_user_test.asm")
set(MONITOR_DISASM_TEST_BINARY "${MONITOR_OUTPUT_DIR}/disasm_user_test.bin")
set(MONITOR_DISASM_TEST_LISTING "${MONITOR_OUTPUT_DIR}/disasm_user_test.lst")
set(MONITOR_DISASM_TEST_EXPORTS "${MONITOR_OUTPUT_DIR}/disasm_user_test.exp")
set(MONITOR_DISASM_TEST_SYMBOLS "${MONITOR_OUTPUT_DIR}/disasm_user_test.sym")

add_custom_command(
    OUTPUT "${MONITOR_DISASM_TEST_SOURCE}"
    COMMAND
        "${CMAKE_COMMAND}"
        "-DDISASSEMBLY_EXPECTED=${CMAKE_CURRENT_SOURCE_DIR}/expected_disassembly.txt"
        "-DDISASSEMBLY_TEST_SOURCE=${MONITOR_DISASM_TEST_SOURCE}"
        -P
        "${CMAKE_CURRENT_SOURCE_DIR}/generate_disasm_user_test.cmake"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/expected_disassembly.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/generate_disasm_user_test.cmake"
    COMMENT "Generating RAM disassembler test program"
    VERBATIM
)

add_custom_command(
    OUTPUT "${MONITOR_DISASM_TEST_BINARY}"
    BYPRODUCTS
        "${MONITOR_DISASM_TEST_LISTING}"
        "${MONITOR_DISASM_TEST_EXPORTS}"
        "${MONITOR_DISASM_TEST_SYMBOLS}"
    COMMAND "${TASM_EXE}" -05 -b -s "${MONITOR_DISASM_TEST_SOURCE}" "${MONITOR_DISASM_TEST_BINARY}" "${MONITOR_DISASM_TEST_LISTING}" "${MONITOR_DISASM_TEST_EXPORTS}" "${MONITOR_DISASM_TEST_SYMBOLS}"
    DEPENDS
        "${MONITOR_DISASM_TEST_SOURCE}"
        "${MONITOR_ENTRIES_INCLUDE}"
        "${MONITOR_BUILD_TASM_TABLE}"
        "${TASM_EXE}"
    WORKING_DIRECTORY "${MONITOR_OUTPUT_DIR}"
    COMMENT "Assembling RAM disassembler test program"
    VERBATIM
)

add_custom_target(monitor-disasm-test ALL DEPENDS "${MONITOR_DISASM_TEST_BINARY}")
add_dependencies(monitor-disasm-test monitor-entries)

add_test(
    NAME monitor.rom_layout
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMONITOR_SOURCE_DIR=${MONITOR_SOURCE_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_rom.cmake"
)

add_test(
    NAME monitor.size_baseline
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DEXPECTED_ROM_END=${MONITOR_EXPECTED_ROM_END}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_size_baseline.cmake"
)

add_test(
    NAME monitor.source_structure
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_source_structure.cmake"
)

add_test(
    NAME monitor.identifier_style
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_identifier_style.cmake"
)

add_test(
    NAME monitor.assembly_style
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_assembly_style.cmake"
)

add_test(
    NAME monitor.ram_lifetime_map
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_ram_map.cmake"
)

add_test(
    NAME monitor.zero_page_allocations
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_zero_page.cmake"
)

add_test(
    NAME monitor.table_encoding
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_table_encoding.cmake"
)

add_test(
    NAME monitor.opcode_tables
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_opcode_tables.cmake"
)

add_test(
    NAME monitor.disassembler_core
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_SOURCE=${MONITOR_SOURCE}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_disassembler_core.cmake"
)

add_test(
    NAME monitor.disassembler_coverage
    COMMAND
        "${CMAKE_COMMAND}"
        "-DTASM_TABLE=${TASM_6805_TABLE}"
        "-DDISASSEMBLY_EXPECTED=${CMAKE_CURRENT_SOURCE_DIR}/expected_disassembly.txt"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_monitor_disassembler_coverage.cmake"
)

if(MAME_EXECUTABLE)
add_test(
    NAME monitor.mame.reset_vector
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-reset-vector"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_reset_vector.cmake"
)

add_test(
    NAME monitor.mame.reset_state
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-reset-state"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_reset_state.cmake"
)

add_test(
    NAME monitor.mame.boot_screen
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMONITOR_VERSION_TEXT=${MONITOR_VERSION_TEXT}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-boot-screen"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_boot_screen.cmake"
)

add_test(
    NAME monitor.mame.serial_file_boot_screen
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMONITOR_VERSION_TEXT=${MONITOR_VERSION_TEXT}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-serial-file-boot-screen"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_serial_file_boot_screen.cmake"
)

add_test(
    NAME monitor.mame.cpu_row
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DCPU_ROW_EXPECTED=${CMAKE_CURRENT_SOURCE_DIR}/expected_cpu_row.txt"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-cpu-row"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_cpu_row.cmake"
)

add_test(
    NAME monitor.mame.memory_row
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMEMORY_ROW_EXPECTED=${CMAKE_CURRENT_SOURCE_DIR}/expected_memory_row.txt"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-memory-row"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_memory_row.cmake"
)

add_test(
    NAME monitor.mame.disassembler
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DDISASSEMBLY_TEST_BINARY=${MONITOR_DISASM_TEST_BINARY}"
        "-DDISASSEMBLY_EXPECTED=${CMAKE_CURRENT_SOURCE_DIR}/expected_disassembly.txt"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-disassembler"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_disassembler.cmake"
)

add_test(
    NAME monitor.mame.memory_cursor_edit
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-memory-cursor-edit"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_memory_cursor_edit.cmake"
)

add_test(
    NAME monitor.mame.assembler_cmd
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-assembler-cmd"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_assembler_cmd.cmake"
)

add_test(
    NAME monitor.mame.interrupt_vectors
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-interrupt-vectors"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_interrupt_vectors.cmake"
)

add_test(
    NAME monitor.mame.swi_entry
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-swi-entry"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_swi_entry.cmake"
)

add_test(
    NAME monitor.mame.timer_step
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-timer-step"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_timer_step.cmake"
)

add_test(
    NAME monitor.mame.console_output
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMONITOR_SYMBOLS=${MONITOR_SYMBOLS}"
        "-DMAME_EXE=${MAME_EXECUTABLE}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-console-output"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_console_output.cmake"
)
else()
    message(STATUS "No MAME executable with m6805sbc support was found; skipping monitor MAME tests")
endif()
