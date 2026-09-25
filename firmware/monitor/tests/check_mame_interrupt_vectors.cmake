foreach(_required_var IN ITEMS MONITOR_BINARY MONITOR_SYMBOLS INT_TIMER_HANDLER_TEST_BINARY INT_EXTERNAL_HANDLER_TEST_BINARY MAME_EXE MAME_STAGE_DIR MONITOR_OUTPUT_DIR)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required")
    endif()
endforeach()

set(ROM_START 0x1000)
set(VECTOR_TIMER_WAIT 0x1FF6)
set(VECTOR_TIMER 0x1FF8)
set(VECTOR_EXTERNAL 0x1FFA)
set(TEST_MARKER 0xFF)
set(TIMER_TEST_HANDLER 0x0110)
set(EXTERNAL_TEST_HANDLER 0x0120)

get_filename_component(_monitor_binary "${MONITOR_BINARY}" ABSOLUTE)
get_filename_component(_monitor_symbols "${MONITOR_SYMBOLS}" ABSOLUTE)
get_filename_component(_int_timer_handler_test_binary "${INT_TIMER_HANDLER_TEST_BINARY}" ABSOLUTE)
get_filename_component(_int_external_handler_test_binary "${INT_EXTERNAL_HANDLER_TEST_BINARY}" ABSOLUTE)
get_filename_component(_mame_exe "${MAME_EXE}" ABSOLUTE)
get_filename_component(_monitor_output_dir "${MONITOR_OUTPUT_DIR}" ABSOLUTE)
get_filename_component(_stage_dir "${MAME_STAGE_DIR}" ABSOLUTE BASE_DIR "${_monitor_output_dir}")

if(NOT EXISTS "${_monitor_binary}")
    message(FATAL_ERROR "Monitor binary does not exist: ${_monitor_binary}")
endif()

if(NOT EXISTS "${_monitor_symbols}")
    message(FATAL_ERROR "Monitor symbols do not exist: ${_monitor_symbols}")
endif()

foreach(_path_var IN ITEMS _int_timer_handler_test_binary _int_external_handler_test_binary _mame_exe)
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

function(_read_byte _out_var _address)
    math(EXPR _offset "${_address} - ${ROM_START}")
    if(_offset LESS 0)
        message(FATAL_ERROR "Address ${_address} is below ROM start")
    endif()

    math(EXPR _start "${_offset} * 2")
    string(SUBSTRING "${_rom_hex}" ${_start} 2 _value)
    string(TOUPPER "${_value}" _value)
    set(${_out_var} "${_value}" PARENT_SCOPE)
endfunction()

function(_read_word _out_var _address)
    _read_byte(_high "${_address}")
    math(EXPR _next_address "${_address} + 1")
    _read_byte(_low "${_next_address}")
    set(${_out_var} "${_high}${_low}" PARENT_SCOPE)
endfunction()

function(_require_vector _name _address _label)
    _read_word(_actual "${_address}")
    if(NOT _actual STREQUAL "${SYM_${_label}}")
        message(FATAL_ERROR "${_name} vector is ${_actual}, expected ${SYM_${_label}} for ${_label}")
    endif()
endfunction()

function(_require_not_vector _name _address _label)
    _read_word(_actual "${_address}")
    if(_actual STREQUAL "${SYM_${_label}}")
        message(FATAL_ERROR "${_name} vector unexpectedly points directly to ${_label}")
    endif()
endfunction()

function(_binary_as_lua _out_var _path)
    file(READ "${_path}" _bytes_hex HEX)
    string(REGEX REPLACE "([0-9A-Fa-f][0-9A-Fa-f])" "0x\\1;" _byte_list "${_bytes_hex}")
    string(REGEX REPLACE ";$" "" _byte_list "${_byte_list}")
    string(REPLACE ";" ", " _lua_bytes "${_byte_list}")
    set(${_out_var} "${_lua_bytes}" PARENT_SCOPE)
endfunction()

_binary_as_lua(_timer_handler_program "${_int_timer_handler_test_binary}")
_binary_as_lua(_external_handler_program "${_int_external_handler_test_binary}")

file(READ "${_monitor_binary}" _rom_hex HEX)
string(TOUPPER "${_rom_hex}" _rom_hex)

file(STRINGS "${_monitor_symbols}" _symbol_lines)
foreach(_line IN LISTS _symbol_lines)
    if(_line MATCHES "^([A-Za-z_][A-Za-z0-9_]*)[ \t]+([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])")
        string(TOUPPER "${CMAKE_MATCH_2}" _symbol_value)
        set("SYM_${CMAKE_MATCH_1}" "${_symbol_value}")
    endif()
endforeach()

foreach(_symbol IN ITEMS
        idle
        tmr_wt_disp
        tmr_disp
        ext_disp
        tmr_wt_def_hdlr
        tmr_def_hdlr
        ext_def_hdlr
        tmr_wt_vec_hi
        tmr_wt_vec_lo
        tmr_vec_hi
        tmr_vec_lo
        ext_vec_hi
        ext_vec_lo
        int_jmp_op)
    _require_symbol("${_symbol}")
endforeach()

_require_vector("timer-from-wait" "${VECTOR_TIMER_WAIT}" "tmr_wt_disp")
_require_vector("timer" "${VECTOR_TIMER}" "tmr_disp")
_require_vector("external" "${VECTOR_EXTERNAL}" "ext_disp")
_require_not_vector("timer-from-wait" "${VECTOR_TIMER_WAIT}" "tmr_wt_def_hdlr")
_require_not_vector("timer" "${VECTOR_TIMER}" "tmr_def_hdlr")
_require_not_vector("external" "${VECTOR_EXTERNAL}" "ext_def_hdlr")

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

set(_interrupt_script "${_stage_dir}/int_vecs.lua")
file(WRITE "${_interrupt_script}"
    "local idle = 0x${SYM_idle}\r\n"
    "local timer_wait_default = 0x${SYM_tmr_wt_def_hdlr}\r\n"
    "local timer_default = 0x${SYM_tmr_def_hdlr}\r\n"
    "local external_default = 0x${SYM_ext_def_hdlr}\r\n"
    "local tmr_disp = 0x${SYM_tmr_disp}\r\n"
    "local ext_disp = 0x${SYM_ext_disp}\r\n"
    "local timer_wait_hi = 0x${SYM_tmr_wt_vec_hi}\r\n"
    "local timer_wait_lo = 0x${SYM_tmr_wt_vec_lo}\r\n"
    "local timer_hi = 0x${SYM_tmr_vec_hi}\r\n"
    "local timer_lo = 0x${SYM_tmr_vec_lo}\r\n"
    "local external_hi = 0x${SYM_ext_vec_hi}\r\n"
    "local external_lo = 0x${SYM_ext_vec_lo}\r\n"
    "local jump_opcode = 0x${SYM_int_jmp_op}\r\n"
    "local marker = ${TEST_MARKER}\r\n"
    "local timer_handler = ${TIMER_TEST_HANDLER}\r\n"
    "local external_handler = ${EXTERNAL_TEST_HANDLER}\r\n"
    "local timer_handler_program = { ${_timer_handler_program} }\r\n"
    "local external_handler_program = { ${_external_handler_program} }\r\n"
    "local phase = \"wait_reset\"\r\n"
    "local frames = 0\r\n"
    "local phase_frames = 0\r\n"
    "local result = {}\r\n"
    "local function hi(value) return math.floor(value / 256) end\r\n"
    "local function lo(value) return value % 256 end\r\n"
    "local function read_word(mem, high_addr, low_addr) return mem:read_u8(high_addr) * 256 + mem:read_u8(low_addr) end\r\n"
    "local function write_word(mem, high_addr, low_addr, value) mem:write_u8(high_addr, hi(value)); mem:write_u8(low_addr, lo(value)) end\r\n"
    "local function load_program(mem, address, bytes)\r\n"
    "    for index, byte in ipairs(bytes) do mem:write_u8(address + index - 1, byte) end\r\n"
    "end\r\n"
    "emu.register_frame_done(function()\r\n"
    "    frames = frames + 1\r\n"
    "    phase_frames = phase_frames + 1\r\n"
    "    local cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "    local mem = cpu.spaces[\"program\"]\r\n"
    "    if phase == \"wait_reset\" then\r\n"
    "        if cpu.state[\"PC\"].value ~= idle and phase_frames < 1200 then return end\r\n"
    "        result.tw_default = read_word(mem, timer_wait_hi, timer_wait_lo)\r\n"
    "        result.t_default = read_word(mem, timer_hi, timer_lo)\r\n"
    "        result.e_default = read_word(mem, external_hi, external_lo)\r\n"
    "        result.jump = mem:read_u8(jump_opcode)\r\n"
    "        load_program(mem, timer_handler, timer_handler_program)\r\n"
    "        load_program(mem, external_handler, external_handler_program)\r\n"
    "        mem:write_u8(marker, 0x00)\r\n"
    "        write_word(mem, timer_hi, timer_lo, timer_handler)\r\n"
    "        cpu.state[\"PC\"].value = tmr_disp\r\n"
    "        phase_frames = 0\r\n"
    "        phase = \"wait_timer\"\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if phase == \"wait_timer\" then\r\n"
    "        if cpu.state[\"PC\"].value ~= idle and phase_frames < 120 then return end\r\n"
    "        result.timer_marker = mem:read_u8(marker)\r\n"
    "        mem:write_u8(marker, 0x00)\r\n"
    "        write_word(mem, external_hi, external_lo, external_handler)\r\n"
    "        cpu.state[\"PC\"].value = ext_disp\r\n"
    "        phase_frames = 0\r\n"
    "        phase = \"wait_external\"\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if phase == \"wait_external\" then\r\n"
    "        if cpu.state[\"PC\"].value ~= idle and phase_frames < 120 then return end\r\n"
    "        result.external_marker = mem:read_u8(marker)\r\n"
    "        manager.machine:soft_reset()\r\n"
    "        phase_frames = 0\r\n"
    "        phase = \"wait_restore\"\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if phase == \"wait_restore\" then\r\n"
    "        if cpu.state[\"PC\"].value ~= idle and phase_frames < 1200 then return end\r\n"
    "        result.t_restored = read_word(mem, timer_hi, timer_lo)\r\n"
    "        result.e_restored = read_word(mem, external_hi, external_lo)\r\n"
    "        result.tw_restored = read_word(mem, timer_wait_hi, timer_wait_lo)\r\n"
    "        print(string.format(\"INTERRUPT_VECTORS TW=%04X T=%04X E=%04X JUMP=%02X TIMER_MARK=%02X EXT_MARK=%02X TW_RESTORED=%04X T_RESTORED=%04X E_RESTORED=%04X\", result.tw_default, result.t_default, result.e_default, result.jump, result.timer_marker, result.external_marker, result.tw_restored, result.t_restored, result.e_restored))\r\n"
    "        manager.machine:exit()\r\n"
    "        return\r\n"
    "    end\r\n"
    "    if frames >= 3000 then print(\"INTERRUPT_VECTORS TIMEOUT\"); manager.machine:exit() end\r\n"
    "end, \"int_vecs\")\r\n"
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
        -autoboot_script int_vecs.lua
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

string(REGEX MATCH "INTERRUPT_VECTORS " _state_match "${_mame_output}")
if(NOT _state_match)
    message(FATAL_ERROR "MAME output did not report INTERRUPT_VECTORS\n${_mame_output}")
endif()

function(_capture_hex _out_var _pattern _description)
    string(REGEX MATCH "${_pattern}" _field_match "${_mame_output}")
    if(NOT _field_match)
        message(FATAL_ERROR "MAME output did not report ${_description}\n${_mame_output}")
    endif()

    string(TOUPPER "${CMAKE_MATCH_1}" _captured)
    set(${_out_var} "${_captured}" PARENT_SCOPE)
endfunction()

_capture_hex(_actual_tw " TW=([0-9A-Fa-f]+)" "timer-from-wait RAM vector")
_capture_hex(_actual_timer " T=([0-9A-Fa-f]+)" "timer RAM vector")
_capture_hex(_actual_external " E=([0-9A-Fa-f]+)" "external RAM vector")
_capture_hex(_actual_jump " JUMP=([0-9A-Fa-f]+)" "RAM jump opcode")
_capture_hex(_timer_marker " TIMER_MARK=([0-9A-Fa-f]+)" "timer marker")
_capture_hex(_external_marker " EXT_MARK=([0-9A-Fa-f]+)" "external marker")
_capture_hex(_actual_tw_restored " TW_RESTORED=([0-9A-Fa-f]+)" "restored timer-from-wait RAM vector")
_capture_hex(_actual_timer_restored " T_RESTORED=([0-9A-Fa-f]+)" "restored timer RAM vector")
_capture_hex(_actual_external_restored " E_RESTORED=([0-9A-Fa-f]+)" "restored external RAM vector")

if(NOT _actual_tw STREQUAL "${SYM_tmr_wt_def_hdlr}")
    message(FATAL_ERROR "Expected timer-from-wait RAM vector ${SYM_tmr_wt_def_hdlr}, got ${_actual_tw}\n${_mame_output}")
endif()

if(NOT _actual_timer STREQUAL "${SYM_tmr_def_hdlr}")
    message(FATAL_ERROR "Expected timer RAM vector ${SYM_tmr_def_hdlr}, got ${_actual_timer}\n${_mame_output}")
endif()

if(NOT _actual_external STREQUAL "${SYM_ext_def_hdlr}")
    message(FATAL_ERROR "Expected external RAM vector ${SYM_ext_def_hdlr}, got ${_actual_external}\n${_mame_output}")
endif()

if(NOT _actual_jump STREQUAL "CC")
    message(FATAL_ERROR "Expected RAM jump opcode CC, got ${_actual_jump}\n${_mame_output}")
endif()

if(NOT _timer_marker STREQUAL "A5")
    message(FATAL_ERROR "Expected timer dispatch marker A5, got ${_timer_marker}\n${_mame_output}")
endif()

if(NOT _external_marker STREQUAL "5A")
    message(FATAL_ERROR "Expected external dispatch marker 5A, got ${_external_marker}\n${_mame_output}")
endif()

if(NOT _actual_tw_restored STREQUAL "${SYM_tmr_wt_def_hdlr}")
    message(FATAL_ERROR "Expected restored timer-from-wait RAM vector ${SYM_tmr_wt_def_hdlr}, got ${_actual_tw_restored}\n${_mame_output}")
endif()

if(NOT _actual_timer_restored STREQUAL "${SYM_tmr_def_hdlr}")
    message(FATAL_ERROR "Expected restored timer RAM vector ${SYM_tmr_def_hdlr}, got ${_actual_timer_restored}\n${_mame_output}")
endif()

if(NOT _actual_external_restored STREQUAL "${SYM_ext_def_hdlr}")
    message(FATAL_ERROR "Expected restored external RAM vector ${SYM_ext_def_hdlr}, got ${_actual_external_restored}\n${_mame_output}")
endif()
