add_test(
    NAME evsbug12.rom_matches_dump
    COMMAND
        "${CMAKE_COMMAND}"
        "-DEVSBUG12_BINARY=${EVSBUG12_BINARY}"
        "-DEVSBUG12_ROM=${EVSBUG12_ROM}"
        "-P"
        "${CMAKE_CURRENT_SOURCE_DIR}/check_evsbug12_rom.cmake"
)
