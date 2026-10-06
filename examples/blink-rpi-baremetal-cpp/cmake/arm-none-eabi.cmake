# Cross-compile bare-metal ARMv6 (Pi Zero / Zero W, BCM2835) with the
# arm-none-eabi GCC from the dev shell. CMake resolves it to an absolute
# /nix/store path, which is what clangd's --query-driver matches against in
# compile_commands.json.
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)

# A bare-metal test link would fail without a linker script.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
