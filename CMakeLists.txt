cmake_minimum_required(VERSION 3.20)

set(SBC_PROJECT_NAME "6805-sbc" CACHE "STRING" "Default project name for IDEs")
project("${SBC_PROJECT_NAME}" VERSION 1.0.0 LANGUAGES CXX)

include(CTest)

add_subdirectory(firmware)
