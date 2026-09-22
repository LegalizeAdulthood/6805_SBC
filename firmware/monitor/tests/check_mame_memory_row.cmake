foreach(_required_var IN ITEMS MONITOR_BINARY MONITOR_SYMBOLS MEMORY_ROW_EXPECTED MAME_EXE MAME_DATA_DIR MAME_STAGE_DIR MONITOR_OUTPUT_DIR)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required")
    endif()
endforeach()

set(ACIA_CONTROL 0x0006)
set(ACIA_DATA 0x0007)

get_filename_component(_monitor_binary "${MONITOR_BINARY}" ABSOLUTE)
get_filename_component(_monitor_symbols "${MONITOR_SYMBOLS}" ABSOLUTE)
get_filename_component(_memory_row_expected "${MEMORY_ROW_EXPECTED}" ABSOLUTE)
get_filename_component(_mame_exe "${MAME_EXE}" ABSOLUTE)
get_filename_component(_mame_data_dir "${MAME_DATA_DIR}" ABSOLUTE)
get_filename_component(_monitor_output_dir "${MONITOR_OUTPUT_DIR}" ABSOLUTE)
get_filename_component(_stage_dir "${MAME_STAGE_DIR}" ABSOLUTE BASE_DIR "${_monitor_output_dir}")

if(NOT EXISTS "${_monitor_binary}")
    message(FATAL_ERROR "Monitor binary does not exist: ${_monitor_binary}")
endif()

if(NOT EXISTS "${_monitor_symbols}")
    message(FATAL_ERROR "Monitor symbols do not exist: ${_monitor_symbols}")
endif()

if(NOT EXISTS "${_memory_row_expected}")
    message(FATAL_ERROR "Expected memory row fixture does not exist: ${_memory_row_expected}")
endif()

if(NOT EXISTS "${_mame_exe}")
    message(FATAL_ERROR "MAME executable does not exist: ${_mame_exe}")
endif()

if(NOT EXISTS "${_mame_data_dir}/cfg/m6805sbc.cfg")
    message(FATAL_ERROR "MAME configuration does not exist: ${_mame_data_dir}/cfg/m6805sbc.cfg")
endif()

file(TO_CMAKE_PATH "${_monitor_output_dir}" _monitor_output_cmp)
file(TO_CMAKE_PATH "${_stage_dir}" _stage_cmp)

if("${_stage_cmp}" STREQUAL "${_monitor_output_cmp}")
    message(FATAL_ERROR "MAME stage directory must not be the monitor output directory")
endif()

string(APPEND _monitor_output_cmp "/")
string(APPEND _stage_cmp "/")
string(FIND "${_stage_cmp}" "${_monitor_output_cmp}" _stage_prefix)
if(NOT _stage_prefix EQUAL 0)
    message(FATAL_ERROR "MAME stage directory must be under the monitor output directory: ${_stage_dir}")
endif()

function(_snapshot_tree _root _out_var)
    set(_snapshot)

    if(EXISTS "${_root}")
        file(GLOB_RECURSE _paths LIST_DIRECTORIES true RELATIVE "${_root}" "${_root}/*")
        list(SORT _paths)

        foreach(_rel_path IN LISTS _paths)
            set(_full_path "${_root}/${_rel_path}")

            if(IS_DIRECTORY "${_full_path}")
                list(APPEND _snapshot "D:${_rel_path}")
            else()
                file(SHA256 "${_full_path}" _hash)
                list(APPEND _snapshot "F:${_rel_path}:${_hash}")
            endif()
        endforeach()
    endif()

    set(${_out_var} "${_snapshot}" PARENT_SCOPE)
endfunction()

function(_require_symbol _name)
    if(NOT DEFINED "SYM_${_name}")
        message(FATAL_ERROR "Missing symbol '${_name}' in ${_monitor_symbols}")
    endif()
endfunction()

file(STRINGS "${_monitor_symbols}" _symbol_lines)
foreach(_line IN LISTS _symbol_lines)
    if(_line MATCHES "^([A-Za-z_][A-Za-z0-9_]*)[ \t]+([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])")
        string(TOUPPER "${CMAKE_MATCH_2}" _symbol_value)
        set("SYM_${CMAKE_MATCH_1}" "${_symbol_value}")
    endif()
endforeach()

_require_symbol("monitor_idle")
_require_symbol("test_memory_row_output")

file(READ "${_memory_row_expected}" _expected_bytes HEX)
string(TOUPPER "${_expected_bytes}" _expected_bytes)
string(LENGTH "${_expected_bytes}" _expected_hex_length)
math(EXPR _expected_count "${_expected_hex_length} / 2")

_snapshot_tree("${_mame_data_dir}" _mame_data_before)

file(REMOVE_RECURSE "${_stage_dir}")
file(MAKE_DIRECTORY
    "${_stage_dir}/roms/m6805sbc"
    "${_stage_dir}/cfg"
)

configure_file("${_monitor_binary}" "${_stage_dir}/roms/m6805sbc/rom1.bin" COPYONLY)
configure_file("${_mame_data_dir}/cfg/m6805sbc.cfg" "${_stage_dir}/cfg/m6805sbc.cfg" COPYONLY)

set(_memory_row_script "${_stage_dir}/memory_row.lua")
file(WRITE "${_memory_row_script}"
    "local idle = 0x${SYM_monitor_idle}\r\n"
    "local entry = 0x${SYM_test_memory_row_output}\r\n"
    "local expected = ${_expected_count}\r\n"
    "local bytes = {}\r\n"
    "local phase = \"wait_reset\"\r\n"
    "local frames = 0\r\n"
    "local cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "local mem = cpu.spaces[\"program\"]\r\n"
    "mem:install_write_tap(${ACIA_DATA}, ${ACIA_DATA}, \"memory_row_acia_data\", function(offset, data, mask)\r\n"
    "    table.insert(bytes, data & 0xff)\r\n"
    "end)\r\n"
    "local function hex_bytes()\r\n"
    "    local out = {}\r\n"
    "    for _,byte in ipairs(bytes) do table.insert(out, string.format(\"%02X\", byte)) end\r\n"
    "    return table.concat(out, \"\")\r\n"
    "end\r\n"
    "emu.register_frame_done(function()\r\n"
    "    frames = frames + 1\r\n"
    "    cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "    mem = cpu.spaces[\"program\"]\r\n"
    "    if phase == \"wait_reset\" then\r\n"
    "        if cpu.state[\"PC\"].value ~= idle and frames < 60 then return end\r\n"
    "        mem:write_u8(${ACIA_CONTROL}, 0x03)\r\n"
    "        mem:write_u8(${ACIA_CONTROL}, 0x15)\r\n"
    "        for i = 0, 15 do mem:write_u8(0x0080 + i, 0x20 + i) end\r\n"
    "        bytes = {}\r\n"
    "        cpu.state[\"PC\"].value = entry\r\n"
    "        phase = \"wait_output\"\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if phase == \"wait_output\" then\r\n"
    "        if #bytes < expected and frames < 240 then return end\r\n"
    "        print(string.format(\"MEMORY_ROW COUNT=%d BYTES=%s\", #bytes, hex_bytes()))\r\n"
    "        manager.machine:exit()\r\n"
    "        return\r\n"
    "    end\r\n"
    "end, \"memory_row\")\r\n"
)

execute_process(
    COMMAND
        "${_mame_exe}"
        m6805sbc
        -rompath roms
        -cfg_directory cfg
        -homepath .
        -video none
        -sound none
        -skip_gameinfo
        -nothrottle
        -autoboot_delay 0
        -autoboot_script memory_row.lua
        -seconds_to_run 3
    WORKING_DIRECTORY "${_stage_dir}"
    RESULT_VARIABLE _mame_result
    OUTPUT_VARIABLE _mame_stdout
    ERROR_VARIABLE _mame_stderr
)

_snapshot_tree("${_mame_data_dir}" _mame_data_after)
if(NOT _mame_data_before STREQUAL _mame_data_after)
    message(FATAL_ERROR "MAME source data directory changed during test: ${_mame_data_dir}")
endif()

set(_mame_output "${_mame_stdout}\n${_mame_stderr}")

if(NOT _mame_result EQUAL 0)
    message(FATAL_ERROR "MAME failed with exit code ${_mame_result}\n${_mame_output}")
endif()

string(REGEX MATCH "MEMORY_ROW COUNT=([0-9]+) BYTES=([0-9A-Fa-f]*)" _output_match "${_mame_output}")
if(NOT _output_match)
    message(FATAL_ERROR "MAME output did not report MEMORY_ROW\n${_mame_output}")
endif()

set(_actual_count "${CMAKE_MATCH_1}")
set(_actual_bytes "${CMAKE_MATCH_2}")
string(TOUPPER "${_actual_bytes}" _actual_bytes)

if(NOT _actual_count STREQUAL "${_expected_count}")
    message(FATAL_ERROR "Expected ${_expected_count} memory-row bytes, got ${_actual_count}\n${_mame_output}")
endif()

if(NOT _actual_bytes STREQUAL "${_expected_bytes}")
    message(FATAL_ERROR "Expected memory-row bytes ${_expected_bytes}, got ${_actual_bytes}\n${_mame_output}")
endif()
