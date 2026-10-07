cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/arm-none-eabi.cmake)

project(blink C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)

# LP-MSPM0L2228. For another MSPM0 part, change DEVICE, the startup file
# (one per family) and the linker script (one per part), e.g. MSPM0G3507 with
# startup_mspm0g350x_gcc.c and mspm0g3507.lds.
set(DEVICE MSPM0L2228)
set(SDK $ENV{MSPM0_SDK_PATH}/source) # exported by the `mspm0` dev shell
set(MCU_FLAGS -mcpu=cortex-m0plus -mthumb -mfloat-abi=soft)

# TI's startup file (vector table, and a reset handler that also runs C++
# constructors) and the DriverLib sources the program calls; most DriverLib
# functions are inline in the headers.
add_executable(blink.elf
  src/main.cpp
  ${SDK}/ti/devices/msp/m0p/startup_system_files/gcc/startup_mspm0l222x_gcc.c
  ${SDK}/ti/driverlib/dl_common.c
)
target_compile_definitions(blink.elf PRIVATE __${DEVICE}__)
target_include_directories(blink.elf SYSTEM PRIVATE ${SDK} ${SDK}/third_party/CMSIS/Core/Include)
target_compile_options(blink.elf PRIVATE ${MCU_FLAGS} -Wall -Wextra -ffunction-sections -fdata-sections
  $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions -fno-rtti -fno-threadsafe-statics>)
target_link_options(blink.elf PRIVATE
  ${MCU_FLAGS}
  -T${SDK}/ti/devices/msp/m0p/linker_files/gcc/mspm0l2228.lds
  -nostartfiles --specs=nano.specs --specs=nosys.specs
  -Wl,--gc-sections -Wl,-Map=blink.map -Wl,--print-memory-usage
)

add_custom_command(TARGET blink.elf POST_BUILD
  COMMAND ${CMAKE_OBJCOPY} -O binary blink.elf blink.bin
  COMMAND ${CMAKE_SIZE} blink.elf
)

# `cmake --build build --target flash` (the LaunchPad's XDS110 probe).
# MSPM0 has SWD only; probe-rs would otherwise try JTAG first through the XDS110.
add_custom_target(flash
  COMMAND probe-rs download --chip ${DEVICE} --protocol swd --verify blink.elf
  COMMAND probe-rs reset --chip ${DEVICE} --protocol swd
  DEPENDS blink.elf
)
