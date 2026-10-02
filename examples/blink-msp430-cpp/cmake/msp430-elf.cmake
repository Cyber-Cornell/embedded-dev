# Cross-compile for TI MSP430 with TI's msp430-elf GCC from the `ti` dev shell.
# Device headers (msp430.h) and linker scripts ship inside that toolchain, so
# -mmcu=<device> is all a project needs.
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR msp430)

set(CMAKE_C_COMPILER msp430-elf-gcc)
set(CMAKE_CXX_COMPILER msp430-elf-g++)
set(CMAKE_ASM_COMPILER msp430-elf-gcc)
set(CMAKE_OBJCOPY msp430-elf-objcopy)
set(CMAKE_SIZE msp430-elf-size)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
