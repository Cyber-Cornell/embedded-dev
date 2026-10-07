cmake_minimum_required(VERSION 3.21)

# The toolchain file comes from the preset: `default` builds kernel8.img for
# the Pi 3, 4, 5 and Zero 2 W, `armv6` builds kernel.img for the Pi Zero / Zero W.
project(blink C ASM)
set(CMAKE_C_STANDARD 11)

if(CMAKE_SYSTEM_PROCESSOR STREQUAL aarch64)
  # Plain ARMv8.0 runs on every 64-bit Pi. With the MMU off all memory is
  # Device memory, so no unaligned accesses; and stay off the FP/SIMD
  # registers, which the firmware may leave trapped.
  set(CPU_FLAGS -march=armv8-a -mgeneral-regs-only -mstrict-align)
  set(BITS 64)
else()
  # BCM2835: ARM1176JZF-S with VFPv2 (enabled in start32.S).
  set(CPU_FLAGS -mcpu=arm1176jzf-s -marm -mfpu=vfp -mfloat-abi=hard)
  set(BITS 32)
endif()
set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/link${BITS}.ld)

add_executable(blink.elf src/main.c src/start${BITS}.S)
target_compile_options(blink.elf PRIVATE ${CPU_FLAGS} -Wall -Wextra -ffreestanding -ffunction-sections -fdata-sections)
target_link_options(blink.elf PRIVATE ${CPU_FLAGS} -T${LINKER_SCRIPT} -nostartfiles -Wl,--gc-sections -Wl,--no-warn-rwx-segments)
set_target_properties(blink.elf PROPERTIES LINK_DEPENDS ${LINKER_SCRIPT})

# `cmake --build build --target flash`: writes the kernel image, GPU firmware
# and config.txt to $RPI_BOOT_DIR (your mounted SD card), else build/boot.
add_custom_target(flash
  COMMAND rpi-boot $<TARGET_FILE:blink.elf>
  DEPENDS blink.elf
  USES_TERMINAL
)
