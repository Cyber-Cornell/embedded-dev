cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/msp430-elf.cmake)

project(blink C)
set(CMAKE_C_STANDARD 11)

# MSP-EXP430G2ET LaunchPad. Change to your part, e.g. msp430fr2433.
set(MCU msp430g2553)

add_executable(blink.elf src/main.c)
target_compile_options(blink.elf PRIVATE -mmcu=${MCU} -Wall -Wextra -ffunction-sections -fdata-sections)
target_link_options(blink.elf PRIVATE -mmcu=${MCU} -Wl,--gc-sections)

# -mmcu links with TI's default script for the part. msp430g2553.ld is a copy
# of it to edit, e.g. to move the program behind a bootloader; uncomment to use it.
# target_link_options(blink.elf PRIVATE -T${CMAKE_CURRENT_SOURCE_DIR}/msp430g2553.ld)

add_custom_command(TARGET blink.elf POST_BUILD COMMAND ${CMAKE_SIZE} blink.elf)

# `cmake --build build --target flash`. The eZ-FET on current LaunchPads
# needs the `tilib` driver; older G2 LaunchPads (eZ430/rf2500) use `rf2500`.
set(MSPDEBUG_DRIVER tilib CACHE STRING "mspdebug driver")
add_custom_target(flash
  COMMAND mspdebug ${MSPDEBUG_DRIVER} "prog blink.elf"
  DEPENDS blink.elf
)
