get_filename_component(MONITOR_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

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
    NAME monitor.mame.reset_vector
    COMMAND
        "${CMAKE_COMMAND}"
        "-DMONITOR_BINARY=${MONITOR_BINARY}"
        "-DMAME_EXE=${M6805SBC_EXE}"
        "-DMAME_DATA_DIR=${M6805SBC_DATA_DIR}"
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
        "-DMAME_EXE=${M6805SBC_EXE}"
        "-DMAME_DATA_DIR=${M6805SBC_DATA_DIR}"
        "-DMAME_STAGE_DIR=${MONITOR_OUTPUT_DIR}/mame-reset-state"
        "-DMONITOR_OUTPUT_DIR=${MONITOR_OUTPUT_DIR}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_mame_reset_state.cmake"
)
