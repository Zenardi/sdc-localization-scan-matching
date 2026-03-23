cmake_minimum_required (VERSION 3.10)

if(POLICY CMP0144)
  cmake_policy(SET CMP0144 NEW)
endif()

project(Localization)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# -g allows for gdb debugging
# turn on -03 for best performance
add_compile_options(-O3)

set(CXX_FLAGS "-pthread -fPIC")
set(CMAKE_CXX_FLAGS "${CXX_FLAGS}")

set(sources ndt-main.cpp helper.cpp)

find_package(PCL 1.2 REQUIRED)

include_directories(${PCL_INCLUDE_DIRS})
link_directories(${PCL_LIBRARY_DIRS})
add_definitions(${PCL_DEFINITIONS})

if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

endif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

add_executable(ndt ${sources} )

target_link_libraries(ndt ${PCL_LIBRARIES})
