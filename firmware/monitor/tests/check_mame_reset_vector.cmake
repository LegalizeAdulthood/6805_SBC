foreach(_required_var IN ITEMS MONITOR_BINARY MAME_EXE MAME_DATA_DIR MAME_STAGE_DIR MONITOR_OUTPUT_DIR)
    if(NOT DEFINED ${_required_var} OR "${${_required_var}}" STREQUAL "")
        message(FATAL_ERROR "${_required_var} is required")
    endif()
endforeach()

get_filename_component(_monitor_binary "${MONITOR_BINARY}" ABSOLUTE)
get_filename_component(_mame_exe "${MAME_EXE}" ABSOLUTE)
get_filename_component(_mame_data_dir "${MAME_DATA_DIR}" ABSOLUTE)
get_filename_component(_monitor_output_dir "${MONITOR_OUTPUT_DIR}" ABSOLUTE)
get_filename_component(_stage_dir "${MAME_STAGE_DIR}" ABSOLUTE BASE_DIR "${_monitor_output_dir}")

if(NOT EXISTS "${_monitor_binary}")
    message(FATAL_ERROR "Monitor binary does not exist: ${_monitor_binary}")
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

file(SIZE "${_monitor_binary}" _monitor_size)
if(NOT _monitor_size EQUAL 4096)
    message(FATAL_ERROR "Monitor ROM must be 4096 bytes, got ${_monitor_size}")
endif()

file(READ "${_monitor_binary}" _monitor_hex HEX)
math(EXPR _reset_hi_offset "(4096 - 2) * 2")
math(EXPR _reset_lo_offset "(4096 - 1) * 2")
string(SUBSTRING "${_monitor_hex}" ${_reset_hi_offset} 2 _reset_hi)
string(SUBSTRING "${_monitor_hex}" ${_reset_lo_offset} 2 _reset_lo)
set(_expected_pc "${_reset_hi}${_reset_lo}")
string(TOUPPER "${_expected_pc}" _expected_pc)

_snapshot_tree("${_mame_data_dir}" _mame_data_before)

file(REMOVE_RECURSE "${_stage_dir}")
file(MAKE_DIRECTORY
    "${_stage_dir}/roms/m6805sbc"
    "${_stage_dir}/cfg"
)

configure_file("${_monitor_binary}" "${_stage_dir}/roms/m6805sbc/rom1.bin" COPYONLY)
configure_file("${_mame_data_dir}/cfg/m6805sbc.cfg" "${_stage_dir}/cfg/m6805sbc.cfg" COPYONLY)

set(_reset_script "${_stage_dir}/reset_vector.lua")
file(WRITE "${_reset_script}"
    "local cpu = manager.machine.devices[\":maincpu\"]\r\n"
    "print(string.format(\"RESET_PC=%04X\", cpu.state[\"PC\"].value))\r\n"
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
        -autoboot_script reset_vector.lua
        -seconds_to_run 1
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

string(REGEX MATCH "RESET_PC=([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])" _reset_match "${_mame_output}")
if(NOT _reset_match)
    message(FATAL_ERROR "MAME output did not report RESET_PC\n${_mame_output}")
endif()

set(_actual_pc "${CMAKE_MATCH_1}")
string(TOUPPER "${_actual_pc}" _actual_pc)

if(NOT _actual_pc STREQUAL _expected_pc)
    message(FATAL_ERROR "Expected reset PC ${_expected_pc}, got ${_actual_pc}\n${_mame_output}")
endif()
