cmake_minimum_required(VERSION 3.21)

project(vega-network-helper VERSION 0.1.0 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core DBus Network)

add_executable(vega-network-helper
    src/main.cpp
)

target_link_libraries(vega-network-helper PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Network
)

target_compile_options(vega-network-helper PRIVATE
    -Wall
    -Wextra
    -Wpedantic
)

add_test(NAME vega-network-helper-self-test
    COMMAND vega-network-helper --self-test
)

install(TARGETS vega-network-helper
    RUNTIME DESTINATION lib/vega
)
