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

# NEW: simulation build (preset `sim`): runs in QEMU's raspi-pico machine.
option(BLINK_SIM "Build for the QEMU raspi-pico simulation" OFF)
if(BLINK_SIM)
  target_compile_definitions(blink PRIVATE BLINK_SIM=1)
  # QEMU's stand-in boot ROM lacks the ROM float/double routines the SDK
  # looks up at startup, so use the compiler's own implementations.
  pico_set_float_implementation(blink compiler)
  pico_set_double_implementation(blink compiler)
  # Log over the UART; QEMU shows it on the terminal.
  pico_enable_stdio_uart(blink 1)
  pico_enable_stdio_usb(blink 0)
  # `cmake --build build-sim --target sim` runs it and checks the output.
  add_custom_target(sim
    COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/sim/run.sh $<TARGET_FILE:blink>
    DEPENDS blink
    USES_TERMINAL)
endif()

# Produce .uf2/.hex/.bin alongside the .elf.
pico_add_extra_outputs(blink)