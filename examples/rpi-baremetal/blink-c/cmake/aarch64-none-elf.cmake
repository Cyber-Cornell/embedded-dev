# Cross-compile bare-metal aarch64 (Pi 3, 4, 5, Zero 2 W) with the
# aarch64-none-elf GCC from the dev shell. CMake resolves it to an absolute
# /nix/store path, which is what clangd's --query-driver matches against in
# compile_commands.json.
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-none-elf-gcc)
set(CMAKE_CXX_COMPILER aarch64-none-elf-g++)
set(CMAKE_ASM_COMPILER aarch64-none-elf-gcc)

# A bare-metal test link would fail without a linker script.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
