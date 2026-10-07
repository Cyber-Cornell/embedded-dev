cmake_minimum_required(VERSION 3.13)

# PICO_SDK_PATH is exported by the `pico` dev shell.
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(blink C CXX ASM)
set(CMAKE_C_STANDARD 11)

pico_sdk_init()

# Register-level blink: the SDK only supplies the boot path (boot2, crt0, clock
# setup) and the linker script; src/main.c touches no SDK API.
add_executable(blink src/main.c)
target_link_libraries(blink pico_runtime)

# The SDK links with its own default script for the chip. rp2040.ld (Pico) and
# rp2350.ld (Pico 2) are flattened copies of those to edit, e.g. to move the
# program behind a bootloader; uncomment to use the one for PICO_BOARD's chip.
string(REGEX MATCH "^rp2[0-9]+" PICO_CHIP ${PICO_PLATFORM}) # rp2350-arm-s -> rp2350
# pico_set_linker_script(blink ${CMAKE_CURRENT_SOURCE_DIR}/${PICO_CHIP}.ld)

# Produce .uf2/.hex/.bin alongside the .elf.
pico_add_extra_outputs(blink)
