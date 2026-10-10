cmake_minimum_required(VERSION 3.20)
project(hello CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(hello src/main.cpp)
target_compile_options(hello PRIVATE -Wall -Wextra -Wpedantic)
