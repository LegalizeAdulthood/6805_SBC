foreach(_required_var IN ITEMS MONITOR_BINARY MONITOR_SYMBOLS DISASSEMBLY_TEST_BINARY DISASSEMBLY_EXPECTED MAME_EXE MAME_STAGE_DIR MONITOR_OUTPUT_DIR)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required")
    endif()
endforeach()

set(ACIA_STATUS 0x0006)
set(ACIA_CONTROL 0x0006)
set(ACIA_DATA 0x0007)
set(TEST_CODE_LOAD 0x0400)
set(TEST_ROW_CURRENT 0x0046)
set(TEST_ROWS_DONE 0x0047)

get_filename_component(_monitor_binary "${MONITOR_BINARY}" ABSOLUTE)
get_filename_component(_monitor_symbols "${MONITOR_SYMBOLS}" ABSOLUTE)
get_filename_component(_disassembly_test_binary "${DISASSEMBLY_TEST_BINARY}" ABSOLUTE)
get_filename_component(_disassembly_expected "${DISASSEMBLY_EXPECTED}" ABSOLUTE)
get_filename_component(_mame_exe "${MAME_EXE}" ABSOLUTE)
get_filename_component(_monitor_output_dir "${MONITOR_OUTPUT_DIR}" ABSOLUTE)
get_filename_component(_stage_dir "${MAME_STAGE_DIR}" ABSOLUTE BASE_DIR "${_monitor_output_dir}")

foreach(_path_var IN ITEMS _monitor_binary _monitor_symbols _disassembly_test_binary _disassembly_expected _mame_exe)
    if(NOT EXISTS "${${_path_var}}")
        message(FATAL_ERROR "required input does not exist: ${${_path_var}}")
    endif()
endforeach()

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
_require_symbol("disasm_pc_hi")
_require_symbol("disasm_pc_lo")

file(STRINGS "${_disassembly_expected}" _expected_lines)
list(LENGTH _expected_lines _row_count)
set(_row_keys "")
set(_fixture_writes "")
set(_sparse_bytes "")
set(_row_addrs "")

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
    set(_mnemonic_width 4)
    if(_line_length GREATER 23)
        string(SUBSTRING "${_line}" 23 1 _maybe_mnemonic_char)
        if(NOT _maybe_mnemonic_char STREQUAL " ")
            string(SUBSTRING "${_line}" 19 5 _row_mnemonic)
            set(_mnemonic_width 5)
        endif()
    endif()
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

    if(NOT _row_mnemonic MATCHES "^[a-z][a-z0-9 ][a-z0-9 ][a-z0-9 ][a-z0-9 ]?$")
        message(FATAL_ERROR "Disassembly row has invalid mnemonic field: '${_line}'")
    endif()

    if(_line_length GREATER 27)
        math(EXPR _operand_gap_start "19 + ${_mnemonic_width}")
        math(EXPR _operand_gap_length "27 - ${_operand_gap_start}")
        string(SUBSTRING "${_line}" ${_operand_gap_start} ${_operand_gap_length} _operand_gap)
        string(REPEAT " " ${_operand_gap_length} _expected_operand_gap)
        string(SUBSTRING "${_line}" 27 -1 _row_operand)
        string(STRIP "${_row_operand}" _row_operand)
        if(NOT _operand_gap STREQUAL "${_expected_operand_gap}")
            message(FATAL_ERROR "Disassembly row operand must begin in column 28: '${_line}'")
        endif()
    else()
        set(_row_operand "")
    endif()

    string(SUBSTRING "${_row_addr}" 0 2 _row_hi)
    string(SUBSTRING "${_row_addr}" 2 2 _row_lo)
    string(APPEND _row_addrs "    { 0x${_row_hi}, 0x${_row_lo} },\r\n")

    set(_row_key_addr "${_row_addr}")
    string(REPLACE " " ";" _row_byte_list "${_row_bytes}")
    math(EXPR _byte_addr "0x${_row_addr}")
    foreach(_byte IN LISTS _row_byte_list)
        if(_byte_addr GREATER_EQUAL 0x1ff0)
            string(APPEND _sparse_bytes "    [${_byte_addr}] = 0x${_byte},\r\n")
        else()
            string(APPEND _fixture_writes "        mem:write_u8(${_byte_addr}, 0x${_byte})\r\n")
        endif()
        math(EXPR _byte_addr "${_byte_addr} + 1")
    endforeach()

    list(APPEND _row_keys "${_row_key_addr}|${_row_bytes}|${_row_mnemonic}|${_row_operand}")
endforeach()

function(_require_row _addr _bytes _mnemonic _operand _description)
    set(_key "${_addr}|${_bytes}|${_mnemonic}|${_operand}")
    list(FIND _row_keys "${_key}" _row_index)
    if(_row_index EQUAL -1)
        message(FATAL_ERROR "Missing ${_description} disassembly fixture row: ${_key}")
    endif()
endfunction()

_require_row("0200" "48" "asla" "" "inherent")
_require_row("0228" "31" "fcb " "$31" "invalid-opcode")
_require_row("0229" "24 00" "bcc " "$022B" "relative")
_require_row("024D" "AD 00" "bsr " "$024F" "relative")
_require_row("024F" "10 44" "bset" "0,$44" "bit-operation")
_require_row("026D" "1F 44" "bclr" "7,$44" "bit-operation")
_require_row("026F" "00 44 00" "brset" "0,$44,$0272" "bit-relative")
_require_row("029C" "0F 44 00" "brclr" "7,$44,$029F" "bit-relative")
_require_row("029F" "A9 5A" "adc " "#$5A" "immediate")
_require_row("02A9" "A3 5A" "cpx " "#$5A" "canonical immediate alias")
_require_row("02B9" "38 44" "asl " "$44" "direct unary")
_require_row("02BD" "38 44" "asl " "$44" "canonical direct unary alias")
_require_row("02D1" "B9 44" "adc " "$44" "direct")
_require_row("02DB" "B3 44" "cpx " "$44" "canonical direct alias")
_require_row("02F3" "C9 12 34" "adc " "$1234" "extended")
_require_row("0302" "C3 12 34" "cpx " "$1234" "canonical extended alias")
_require_row("0336" "F6" "lda " ",x" "indexed")
_require_row("036F" "E9 44" "adc " "$44,x" "direct indexed")
_require_row("039B" "D9 12 34" "adc " "$1234,x" "extended indexed")
_require_row("1FFE" "C9" "fcb " "$C9" "truncated extended")
_require_row("1FFF" "A9" "fcb " "$A9" "truncated immediate")

file(READ "${_disassembly_expected}" _expected_bytes HEX)
string(TOUPPER "${_expected_bytes}" _expected_bytes)
string(LENGTH "${_expected_bytes}" _expected_hex_length)
math(EXPR _expected_count "${_expected_hex_length} / 2")

file(READ "${_disassembly_test_binary}" _test_code_bytes HEX)
string(LENGTH "${_test_code_bytes}" _test_code_hex_length)
math(EXPR _test_code_size "${_test_code_hex_length} / 2")
string(REGEX REPLACE "([0-9A-Fa-f][0-9A-Fa-f])" "0x\\1;" _test_code_list "${_test_code_bytes}")
string(REGEX REPLACE ";$" "" _test_code_list "${_test_code_list}")

string(REPLACE ";" ", " _lua_test_code_bytes "${_test_code_list}")

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
    "local disasm_pc_hi = 0x${SYM_disasm_pc_hi}\r\n"
    "local disasm_pc_lo = 0x${SYM_disasm_pc_lo}\r\n"
    "local code_base = ${TEST_CODE_LOAD}\r\n"
    "local expected = ${_expected_count}\r\n"
    "local rows = ${_row_count}\r\n"
    "local row_addrs = {\r\n"
    "${_row_addrs}"
    "}\r\n"
    "local sparse = {\r\n"
    "${_sparse_bytes}"
    "}\r\n"
    "local test_code = { ${_lua_test_code_bytes} }\r\n"
    "local bytes = {}\r\n"
    "local row = 0\r\n"
    "local phase = \"wait_reset\"\r\n"
    "local frames = 0\r\n"
    "local cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "local mem = cpu.spaces[\"program\"]\r\n"
    "_G.disassembler_taps = {}\r\n"
    "_G.disassembler_taps.acia_data = mem:install_write_tap(${ACIA_DATA}, ${ACIA_DATA}, \"disassembler_acia_data\", function(offset, data, mask)\r\n"
    "    table.insert(bytes, data & 0xff)\r\n"
    "end)\r\n"
    "_G.disassembler_taps.acia_stat = mem:install_read_tap(${ACIA_STATUS}, ${ACIA_STATUS}, \"disassembler_acia_stat\", function(offset, data, mask)\r\n"
    "    return data | 0x02\r\n"
    "end)\r\n"
    "local function hex_bytes()\r\n"
    "    local out = {}\r\n"
    "    for _, byte in ipairs(bytes) do table.insert(out, string.format(\"%02X\", byte)) end\r\n"
    "    return table.concat(out, \"\")\r\n"
    "end\r\n"
    "local function launch_row(next_row)\r\n"
    "    local addr = row_addrs[next_row]\r\n"
    "    row = next_row\r\n"
    "    mem:write_u8(disasm_pc_hi, addr[1])\r\n"
    "    mem:write_u8(disasm_pc_lo, addr[2])\r\n"
    "    mem:write_u8(${TEST_ROW_CURRENT}, next_row)\r\n"
    "    cpu.state[\"CC\"].value = cpu.state[\"CC\"].value | 0x08\r\n"
    "    cpu.state[\"S\"].value = 0x7f\r\n"
    "    cpu.state[\"PC\"].value = code_base\r\n"
    "end\r\n"
    "emu.register_frame_done(function()\r\n"
    "    frames = frames + 1\r\n"
    "    cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "    mem = cpu.spaces[\"program\"]\r\n"
    "    if phase == \"wait_reset\" then\r\n"
    "        if cpu.state[\"PC\"].value ~= idle and frames < 60 then return end\r\n"
    "        mem:write_u8(${ACIA_CONTROL}, 0x03)\r\n"
    "        mem:write_u8(${ACIA_CONTROL}, 0x15)\r\n"
    "${_fixture_writes}"
    "        _G.disassembler_taps.sparse = mem:install_read_tap(0x1ff0, 0x1fff, \"disassembler_sparse\", function(offset, data, mask)\r\n"
    "            return sparse[offset] or sparse[0x1ff0 + offset] or data\r\n"
    "        end)\r\n"
    "        for index, byte in ipairs(test_code) do mem:write_u8(code_base + index - 1, byte) end\r\n"
    "        mem:write_u8(${TEST_ROW_CURRENT}, 0)\r\n"
    "        mem:write_u8(${TEST_ROWS_DONE}, 0)\r\n"
    "        bytes = {}\r\n"
    "        launch_row(1)\r\n"
    "        phase = \"wait_done\"\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if phase == \"wait_done\" then\r\n"
    "        local halt = code_base + #test_code - 2\r\n"
    "        if cpu.state[\"PC\"].value ~= halt and frames < 5000 then return end\r\n"
    "        if cpu.state[\"PC\"].value == halt and row < rows then\r\n"
    "            launch_row(row + 1)\r\n"
    "            return\r\n"
    "        end\r\n"
    "        print(string.format(\"DISASSEMBLY HALT=%d ROWS=%d ROW=%d DONE=%d COUNT=%d BYTES=%s\", cpu.state[\"PC\"].value, rows, mem:read_u8(${TEST_ROW_CURRENT}), mem:read_u8(${TEST_ROWS_DONE}), #bytes, hex_bytes()))\r\n"
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
        -seconds_to_run 30
    WORKING_DIRECTORY "${_stage_dir}"
    RESULT_VARIABLE _mame_result
    OUTPUT_VARIABLE _mame_stdout
    ERROR_VARIABLE _mame_stderr
)

set(_mame_output "${_mame_stdout}\n${_mame_stderr}")

if(NOT _mame_result EQUAL 0)
    message(FATAL_ERROR "MAME failed with exit code ${_mame_result}\n${_mame_output}")
endif()

string(REGEX MATCH "DISASSEMBLY HALT=([0-9]+) ROWS=([0-9]+) ROW=([0-9]+) DONE=([0-9]+) COUNT=([0-9]+) BYTES=([0-9A-Fa-f]*)" _output_match "${_mame_output}")
if(NOT _output_match)
    message(FATAL_ERROR "MAME output did not report DISASSEMBLY\n${_mame_output}")
endif()

set(_halt_value "${CMAKE_MATCH_1}")
set(_actual_rows "${CMAKE_MATCH_2}")
set(_actual_row "${CMAKE_MATCH_3}")
set(_actual_done "${CMAKE_MATCH_4}")
set(_actual_count "${CMAKE_MATCH_5}")
set(_actual_bytes "${CMAKE_MATCH_6}")
string(TOUPPER "${_actual_bytes}" _actual_bytes)

math(EXPR _halt_expected "${TEST_CODE_LOAD} + ${_test_code_size} - 2")
if(NOT _halt_value STREQUAL "${_halt_expected}")
    message(FATAL_ERROR "Disassembler test program did not reach halt ${_halt_expected}; pc=${_halt_value}\n${_mame_output}")
endif()

if(NOT _actual_rows STREQUAL "${_row_count}")
    message(FATAL_ERROR "Expected ${_row_count} disassembly rows, got ${_actual_rows}\n${_mame_output}")
endif()

if(NOT _actual_row STREQUAL "${_row_count}" OR NOT _actual_done STREQUAL "${_row_count}")
    message(FATAL_ERROR "Expected ${_row_count} completed disassembly rows; row=${_actual_row}, done=${_actual_done}\n${_mame_output}")
endif()

if(NOT _actual_count STREQUAL "${_expected_count}")
    message(FATAL_ERROR "Expected ${_expected_count} disassembly bytes, got ${_actual_count}\n${_mame_output}")
endif()

if(NOT _actual_bytes STREQUAL "${_expected_bytes}")
    message(FATAL_ERROR "Expected disassembly bytes ${_expected_bytes}, got ${_actual_bytes}\n${_mame_output}")
endif()
