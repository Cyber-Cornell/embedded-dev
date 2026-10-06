cmake_minimum_required(VERSION 3.21)

# The toolchain file comes from the preset: `default` for a 64-bit OS,
# `armv6` for the Pi Zero / Zero W or any 32-bit OS.
project(blink CXX)
set(CMAKE_CXX_STANDARD 20)

add_executable(blink src/main.cpp)
target_compile_options(blink PRIVATE -Wall -Wextra)

# `cmake --build build --target run`: copies blink to $RPI_HOST over SSH and
# runs it there (default host raspberrypi.local).
add_custom_target(run
  COMMAND rpi-run $<TARGET_FILE:blink>
  DEPENDS blink
  USES_TERMINAL
)
