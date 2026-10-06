# Cross-compile Linux userspace for a 64-bit Raspberry Pi OS (Pi 3, 4, 5,
# Zero 2 W) with the static musl GCC from the dev shell. CMake resolves the
# compiler to an absolute /nix/store path, which is what clangd's
# --query-driver matches against in compile_commands.json.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-unknown-linux-musl-gcc)
set(CMAKE_CXX_COMPILER aarch64-unknown-linux-musl-g++)

# Static: no dynamic loader or libc version to match on the Pi.
set(CMAKE_EXE_LINKER_FLAGS_INIT -static)
