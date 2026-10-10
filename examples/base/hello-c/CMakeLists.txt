cmake_minimum_required(VERSION 3.20)
project(hello C)
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_executable(hello src/main.c)
target_compile_options(hello PRIVATE -Wall -Wextra -Wpedantic)
