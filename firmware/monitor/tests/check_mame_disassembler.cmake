foreach(_required_var IN ITEMS MONITOR_BINARY MONITOR_SYMBOLS DISASSEMBLY_EXPECTED MAME_EXE MAME_STAGE_DIR MONITOR_OUTPUT_DIR)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required")
    endif()
endforeach()

set(ACIA_STATUS 0x0006)
set(ACIA_CONTROL 0x0006)
set(ACIA_DATA 0x0007)

get_filename_component(_monitor_binary "${MONITOR_BINARY}" ABSOLUTE)
get_filename_component(_monitor_symbols "${MONITOR_SYMBOLS}" ABSOLUTE)
get_filename_component(_disassembly_expected "${DISASSEMBLY_EXPECTED}" ABSOLUTE)
get_filename_component(_mame_exe "${MAME_EXE}" ABSOLUTE)
get_filename_component(_monitor_output_dir "${MONITOR_OUTPUT_DIR}" ABSOLUTE)
get_filename_component(_stage_dir "${MAME_STAGE_DIR}" ABSOLUTE BASE_DIR "${_monitor_output_dir}")

if(NOT EXISTS "${_monitor_binary}")
    message(FATAL_ERROR "Monitor binary does not exist: ${_monitor_binary}")
endif()

if(NOT EXISTS "${_monitor_symbols}")
    message(FATAL_ERROR "Monitor symbols do not exist: ${_monitor_symbols}")
endif()

if(NOT EXISTS "${_disassembly_expected}")
    message(FATAL_ERROR "Expected disassembly fixture does not exist: ${_disassembly_expected}")
endif()

if(NOT EXISTS "${_mame_exe}")
    message(FATAL_ERROR "MAME executable does not exist: ${_mame_exe}")
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

_require_symbol("idle")
_require_symbol("test_dasm_out")

file(READ "${_disassembly_expected}" _expected_bytes HEX)
string(TOUPPER "${_expected_bytes}" _expected_bytes)
string(LENGTH "${_expected_bytes}" _expected_hex_length)
math(EXPR _expected_count "${_expected_hex_length} / 2")

file(STRINGS "${_disassembly_expected}" _expected_lines)
set(_row_keys "")

foreach(_line IN LISTS _expected_lines)
    string(LENGTH "${_line}" _line_length)
    if(_line_length LESS 23)
        message(FATAL_ERROR "Expected disassembly row is too short: '${_line}'")
    endif()

    string(SUBSTRING "${_line}" 0 1 _row_mark)
    string(SUBSTRING "${_line}" 1 4 _row_addr)
    string(SUBSTRING "${_line}" 5 2 _row_addr_suffix)
    string(SUBSTRING "${_line}" 7 12 _row_bytes_field)
    string(SUBSTRING "${_line}" 19 4 _row_mnemonic)
    string(STRIP "${_row_bytes_field}" _row_bytes)

    if(NOT _row_mark STREQUAL " ")
        message(FATAL_ERROR "Disassembly row must reserve column 1 for current-PC marker: '${_line}'")
    endif()

    if(NOT _row_addr MATCHES "^[0-9A-F][0-9A-F][0-9A-F][0-9A-F]$")
        message(FATAL_ERROR "Disassembly row has invalid address field: '${_line}'")
    endif()

    if(NOT _row_addr_suffix STREQUAL ": ")
        message(FATAL_ERROR "Disassembly row address field must end with ': ': '${_line}'")
    endif()

    if(NOT _row_bytes MATCHES "^([0-9A-F][0-9A-F]|[0-9A-F][0-9A-F] [0-9A-F][0-9A-F]|[0-9A-F][0-9A-F] [0-9A-F][0-9A-F] [0-9A-F][0-9A-F])$")
        message(FATAL_ERROR "Disassembly row has invalid machine-byte field: '${_line}'")
    endif()

    if(NOT _row_mnemonic MATCHES "^[a-z][a-z0-9 ][a-z0-9 ][a-z0-9 ]$")
        message(FATAL_ERROR "Disassembly row has invalid mnemonic field: '${_line}'")
    endif()

    if(_line_length GREATER 27)
        string(SUBSTRING "${_line}" 23 4 _operand_gap)
        string(SUBSTRING "${_line}" 27 -1 _row_operand)
        string(STRIP "${_row_operand}" _row_operand)
        if(NOT _operand_gap STREQUAL "    ")
            message(FATAL_ERROR "Disassembly row operand must begin in column 28: '${_line}'")
        endif()
    else()
        set(_row_operand "")
    endif()

    list(APPEND _row_keys "${_row_addr}|${_row_bytes}|${_row_mnemonic}|${_row_operand}")
endforeach()

function(_require_row _addr _bytes _mnemonic _operand _description)
    set(_key "${_addr}|${_bytes}|${_mnemonic}|${_operand}")
    list(FIND _row_keys "${_key}" _row_index)
    if(_row_index EQUAL -1)
        message(FATAL_ERROR "Missing ${_description} disassembly fixture row: ${_key}")
    endif()
endfunction()

_require_row("0080" "48" "asla" "" "inherent")
_require_row("00A8" "02" "fcb " "$02" "invalid-opcode")
_require_row("00A9" "20 00" "bra " "$00AB" "relative")
_require_row("00AB" "A6 5A" "lda " "#$5A" "immediate")
_require_row("00AD" "3F 44" "clr " "$44" "direct")
_require_row("00AF" "C6 12 34" "lda " "$1234" "extended")
_require_row("00B2" "F6" "lda " ",x" "indexed")
_require_row("00B3" "10 44" "bset" "0,$44" "bit-operation")

file(REMOVE_RECURSE "${_stage_dir}")
file(MAKE_DIRECTORY
    "${_stage_dir}/roms/m6805sbc"
    "${_stage_dir}/cfg"
)

configure_file("${_monitor_binary}" "${_stage_dir}/roms/m6805sbc/rom1.bin" COPYONLY)
file(WRITE "${_stage_dir}/cfg/m6805sbc.cfg"
    "<?xml version=\"1.0\"?>\r\n"
    "<!-- This file is generated by the monitor MAME test. -->\r\n"
    "<mameconfig version=\"10\">\r\n"
    "    <system name=\"m6805sbc\">\r\n"
    "        <input>\r\n"
    "            <port tag=\":BAUD\" type=\"DIPSWITCH\" mask=\"3\" defvalue=\"0\" value=\"0\" />\r\n"
    "        </input>\r\n"
    "    </system>\r\n"
    "</mameconfig>\r\n"
)

set(_disassembler_script "${_stage_dir}/disassembler.lua")
file(WRITE "${_disassembler_script}"
    "local idle = 0x${SYM_idle}\r\n"
    "local entry = 0x${SYM_test_dasm_out}\r\n"
    "local expected = ${_expected_count}\r\n"
    "local bytes = {}\r\n"
    "local phase = \"wait_reset\"\r\n"
    "local frames = 0\r\n"
    "local cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "local mem = cpu.spaces[\"program\"]\r\n"
    "mem:install_write_tap(${ACIA_DATA}, ${ACIA_DATA}, \"disassembler_acia_data\", function(offset, data, mask)\r\n"
    "    table.insert(bytes, data & 0xff)\r\n"
    "end)\r\n"
    "mem:install_read_tap(${ACIA_STATUS}, ${ACIA_STATUS}, \"disassembler_acia_stat\", function(offset, data, mask)\r\n"
    "    return data | 0x02\r\n"
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
    "        local fixture = { 0x48, 0x58, 0x47, 0x57, 0x98, 0x9a, 0x4f, 0x5f,\r\n"
    "            0x43, 0x53, 0x4a, 0x5a, 0x5a, 0x4c, 0x5c, 0x5c,\r\n"
    "            0x48, 0x58, 0x44, 0x54, 0x42, 0x40, 0x50, 0x9d,\r\n"
    "            0x49, 0x59, 0x46, 0x56, 0x9c, 0x80, 0x81, 0x99,\r\n"
    "            0x9b, 0x8e, 0x83, 0x97, 0x4d, 0x5d, 0x9f, 0x8f,\r\n"
    "            0x02, 0x20, 0x00, 0xa6, 0x5a, 0x3f, 0x44, 0xc6,\r\n"
    "            0x12, 0x34, 0xf6, 0x10, 0x44 }\r\n"
    "        for index, byte in ipairs(fixture) do mem:write_u8(0x007f + index, byte) end\r\n"
    "        bytes = {}\r\n"
    "        cpu.state[\"PC\"].value = entry\r\n"
    "        phase = \"wait_output\"\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if phase == \"wait_output\" then\r\n"
    "        if #bytes < expected and frames < 120 then return end\r\n"
    "        print(string.format(\"DISASSEMBLY COUNT=%d BYTES=%s\", #bytes, hex_bytes()))\r\n"
    "        manager.machine:exit()\r\n"
    "        return\r\n"
    "    end\r\n"
    "end, \"disassembler\")\r\n"
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
        -autoboot_script disassembler.lua
        -seconds_to_run 3
    WORKING_DIRECTORY "${_stage_dir}"
    RESULT_VARIABLE _mame_result
    OUTPUT_VARIABLE _mame_stdout
    ERROR_VARIABLE _mame_stderr
)

set(_mame_output "${_mame_stdout}\n${_mame_stderr}")

if(NOT _mame_result EQUAL 0)
    message(FATAL_ERROR "MAME failed with exit code ${_mame_result}\n${_mame_output}")
endif()

string(REGEX MATCH "DISASSEMBLY COUNT=([0-9]+) BYTES=([0-9A-Fa-f]*)" _output_match "${_mame_output}")
if(NOT _output_match)
    message(FATAL_ERROR "MAME output did not report DISASSEMBLY\n${_mame_output}")
endif()

set(_actual_count "${CMAKE_MATCH_1}")
set(_actual_bytes "${CMAKE_MATCH_2}")
string(TOUPPER "${_actual_bytes}" _actual_bytes)

if(NOT _actual_count STREQUAL "${_expected_count}")
    message(FATAL_ERROR "Expected ${_expected_count} disassembly bytes, got ${_actual_count}\n${_mame_output}")
endif()

if(NOT _actual_bytes STREQUAL "${_expected_bytes}")
    message(FATAL_ERROR "Expected disassembly bytes ${_expected_bytes}, got ${_actual_bytes}\n${_mame_output}")
endif()
