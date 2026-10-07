cmake_minimum_required(VERSION 3.13)

# PICO_SDK_PATH is exported by the `pico` dev shell.
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(blink C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(blink src/main.c)
target_link_libraries(blink pico_stdlib)

# Wireless boards (pico_w, pico2_w) drive the LED through the CYW43 chip.
if(PICO_CYW43_SUPPORTED)
  target_link_libraries(blink pico_cyw43_arch_none)
endif()

# Produce .uf2/.hex/.bin alongside the .elf.
pico_add_extra_outputs(blink)
