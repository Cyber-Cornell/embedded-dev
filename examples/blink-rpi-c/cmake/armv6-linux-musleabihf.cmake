# Cross-compile Linux userspace for the Pi Zero / Zero W (BCM2835, ARMv6 with
# hard-float VFP), or any other Pi running a 32-bit OS, with the static musl
# GCC from the dev shell. The compiler already defaults to -march=armv6kz
# -mfpu=vfp -mfloat-abi=hard.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER armv6l-unknown-linux-musleabihf-gcc)
set(CMAKE_CXX_COMPILER armv6l-unknown-linux-musleabihf-g++)

# Static: no dynamic loader or libc version to match on the Pi.
set(CMAKE_EXE_LINKER_FLAGS_INIT -static)
