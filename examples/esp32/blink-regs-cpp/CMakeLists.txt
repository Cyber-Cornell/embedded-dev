cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/xtensa-esp32-elf.cmake)

project(blink C CXX ASM)
set(CMAKE_CXX_STANDARD 20)

# Register-level blink without ESP-IDF. The ROM loads the program from flash
# offset 0x1000 instead of ESP-IDF's second-stage bootloader, so it must be
# linked to RAM by esp32.ld; there is no default script to fall back on.
add_executable(blink.elf src/main.cpp src/startup.cpp)
target_compile_options(blink.elf PRIVATE -Wall -Wextra -ffreestanding -ffunction-sections -fdata-sections
  $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions -fno-rtti -fno-threadsafe-statics>)
target_link_options(blink.elf PRIVATE
  -T${CMAKE_CURRENT_SOURCE_DIR}/esp32.ld
  -nostartfiles
  -Wl,--gc-sections -Wl,-Map=blink.map -Wl,--print-memory-usage
)
set_target_properties(blink.elf PROPERTIES LINK_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/esp32.ld)

# Convert the ELF to the ROM's image format (one segment per RAM region).
add_custom_command(TARGET blink.elf POST_BUILD
  COMMAND esptool.py --chip esp32 elf2image --flash_mode dio --flash_freq 40m
          --flash_size 4MB -o blink.bin blink.elf
  COMMAND ${CMAKE_SIZE} blink.elf
)

# `cmake --build build --target flash`: writes the image over the second-stage
# bootloader at 0x1000 (any ESP-IDF app on the board stops booting until you
# flash an ESP-IDF project again). esptool finds the serial port itself; set
# ESPPORT, e.g. /dev/ttyUSB0, to pick one.
add_custom_target(flash
  COMMAND esptool.py --chip esp32 $<$<BOOL:$ENV{ESPPORT}>:--port=$ENV{ESPPORT}> write_flash 0x1000 blink.bin
  DEPENDS blink.elf
  USES_TERMINAL
)
