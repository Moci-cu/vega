cmake_minimum_required(VERSION 3.21)

project(vega-launcher-backend VERSION 0.1.0 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Qml)

add_library(vega-launcher-core STATIC
    src/nativeappsearchmodel.cpp
    src/nativeappsearchmodel.h
)
set_target_properties(vega-launcher-core PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(vega-launcher-core PUBLIC src)
target_link_libraries(vega-launcher-core PUBLIC Qt6::Core)
target_compile_options(vega-launcher-core PRIVATE -Wall -Wextra -Wpedantic)

add_library(vega_launcherplugin MODULE src/plugin.cpp)
target_link_libraries(vega_launcherplugin PRIVATE vega-launcher-core Qt6::Qml)
target_compile_options(vega_launcherplugin PRIVATE -Wall -Wextra -Wpedantic)

add_executable(vega-launcher-backend-self-test tests/selftest.cpp)
target_link_libraries(vega-launcher-backend-self-test PRIVATE vega-launcher-core Qt6::Core)

add_test(NAME vega-launcher-backend-self-test COMMAND vega-launcher-backend-self-test)

set(VEGA_QML_INSTALL_DIR "Vega/Launcher" CACHE STRING "QML module directory relative to the install prefix")
install(TARGETS vega_launcherplugin LIBRARY DESTINATION "${VEGA_QML_INSTALL_DIR}")
install(FILES qml/qmldir DESTINATION "${VEGA_QML_INSTALL_DIR}")
