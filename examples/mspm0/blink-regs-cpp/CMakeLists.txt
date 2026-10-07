cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/arm-none-eabi.cmake)

project(blink C CXX)
set(CMAKE_CXX_STANDARD 20)

# LP-MSPM0L2228. Register-level: no MSPM0 SDK, so src/startup.cpp and
# mspm0l2228.ld supply the vector table, reset handler and memory layout. With
# nothing to fall back on, the linker script is always used.
set(DEVICE MSPM0L2228)
set(MCU_FLAGS -mcpu=cortex-m0plus -mthumb -mfloat-abi=soft)

add_executable(blink.elf src/main.cpp src/startup.cpp)
target_compile_options(blink.elf PRIVATE ${MCU_FLAGS} -Wall -Wextra -ffunction-sections -fdata-sections
  $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions -fno-rtti -fno-threadsafe-statics>)
target_link_options(blink.elf PRIVATE
  ${MCU_FLAGS}
  -T${CMAKE_CURRENT_SOURCE_DIR}/mspm0l2228.ld
  -nostartfiles --specs=nano.specs --specs=nosys.specs
  -Wl,--gc-sections -Wl,-Map=blink.map -Wl,--print-memory-usage
)

add_custom_command(TARGET blink.elf POST_BUILD
  COMMAND ${CMAKE_OBJCOPY} -O binary blink.elf blink.bin
  COMMAND ${CMAKE_SIZE} blink.elf
)

# `cmake --build build --target flash` (the LaunchPad's XDS110 probe).
add_custom_target(flash
  COMMAND probe-rs download --chip ${DEVICE} --verify blink.elf
  COMMAND probe-rs reset --chip ${DEVICE}
  DEPENDS blink.elf
)
