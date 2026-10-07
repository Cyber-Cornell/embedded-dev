cmake_minimum_required(VERSION 3.16)

# IDF_PATH is exported by the `esp32` dev shell.
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(blink)
