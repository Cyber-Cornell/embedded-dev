cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/arm-none-eabi.cmake)

project(blink C CXX ASM)
set(CMAKE_CXX_STANDARD 20)

# STM32F401RE (Nucleo-F401RE). Adjust MCU_FLAGS and the linker script for
# other parts, e.g. -mcpu=cortex-m0plus for STM32G0 or -mcpu=cortex-m7 for F7/H7.
set(MCU_FLAGS -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard)

add_executable(blink.elf src/main.cpp src/startup.cpp)
target_compile_options(blink.elf PRIVATE ${MCU_FLAGS} -Wall -Wextra -ffunction-sections -fdata-sections
  $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions -fno-rtti -fno-threadsafe-statics>)
target_link_options(blink.elf PRIVATE
  ${MCU_FLAGS}
  -T${CMAKE_CURRENT_SOURCE_DIR}/stm32f401re.ld
  -nostartfiles --specs=nano.specs --specs=nosys.specs
  -Wl,--gc-sections -Wl,-Map=blink.map -Wl,--print-memory-usage
)

add_custom_command(TARGET blink.elf POST_BUILD
  COMMAND ${CMAKE_OBJCOPY} -O binary blink.elf blink.bin
  COMMAND ${CMAKE_SIZE} blink.elf
)

# `cmake --build build --target flash` (ST-Link on the Nucleo board).
add_custom_target(flash
  COMMAND openocd -f interface/stlink.cfg -f target/stm32f4x.cfg
          -c "program blink.elf verify reset exit"
  DEPENDS blink.elf
)
