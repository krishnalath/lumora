cmake_minimum_required(VERSION 3.18.1)
project("vector_engine")

# Define the native library
add_library(
        vector_engine
        SHARED
        vector_engine.cpp
)

# Set C++ standard
set_target_properties(vector_engine PROPERTIES CXX_STANDARD 17)

# Find Android logging library
find_library(
        log-lib
        log
)

# Link dependencies
target_link_libraries(
        vector_engine
        ${log-lib}
)
