# Cross-compile for the ESP32 (Xtensa LX6) with the GCC that ESP-IDF ships in
# the `esp32` dev shell, without ESP-IDF itself. CMake resolves these to
# absolute /nix/store paths, which is what clangd's --query-driver matches.
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR xtensa)

set(CMAKE_C_COMPILER xtensa-esp32-elf-gcc)
set(CMAKE_CXX_COMPILER xtensa-esp32-elf-g++)
set(CMAKE_ASM_COMPILER xtensa-esp32-elf-gcc)
set(CMAKE_OBJCOPY xtensa-esp32-elf-objcopy)
set(CMAKE_SIZE xtensa-esp32-elf-size)

# A bare-metal test link would fail without a linker script.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
