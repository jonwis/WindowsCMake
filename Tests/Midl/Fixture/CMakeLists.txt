# Copyright (c) Microsoft Corporation. All rights reserved.
cmake_minimum_required(VERSION 3.20)
project(MidlFixture NONE)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../../WindowsCMake/Midl.cmake")
find_program(MIDL_EXECUTABLE midl REQUIRED)
add_executable(SDK::midl IMPORTED)
file(TO_NATIVE_PATH "${MIDL_EXECUTABLE}" NATIVE_MIDL)
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Midl.cmd.in" "${CMAKE_CURRENT_BINARY_DIR}/Midl.cmd" @ONLY)
set_target_properties(SDK::midl PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/Midl.cmd")
set(INPUT "${CMAKE_CURRENT_BINARY_DIR}/input files")
set(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/generated files")
file(MAKE_DIRECTORY "${INPUT}")
if(NOT EXISTS "${INPUT}/Types.idl")
    file(WRITE "${INPUT}/Types.idl" "#define RESULT_TYPE long\n")
endif()
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Example.idl" "${INPUT}/Example.idl" COPYONLY)
if(ALT_HEADER)
    set(HEADER Renamed.h)
else()
    set(HEADER Custom.h)
endif()
set(OUTPUTS
    "${OUTPUT}/${HEADER}"
    "${OUTPUT}/Custom_i.c"
    "${OUTPUT}/Custom_p.c"
    "${OUTPUT}/Custom_dlldata.c"
)
if(MODE STREQUAL "typelib")
    list(APPEND OUTPUTS "${OUTPUT}/Custom.tlb")
    set(TYPELIB TLB Custom.tlb)
elseif(MODE STREQUAL "invalid")
    set(TYPELIB TLB Custom.tlb NOTLB)
else()
    set(TYPELIB NOTLB)
endif()
add_midl(
    example
    COMPILER
    SDK::midl
    IDL
    Example.idl
    OUTPUT_DIRECTORY
    "${OUTPUT}"
    OUTPUTS
    ${OUTPUTS}
    HEADER
    "${HEADER}"
    IID
    Custom_i.c
    PROXY
    Custom_p.c
    DLLDATA
    Custom_dlldata.c
    ${TYPELIB}
    OPTIONS
    /nologo
    /W1
    /char
    signed
    /env
    x64
    /target
    NT100
    /sal
    /D
    REQUIRED_OPTION
    INCLUDE_DIRECTORIES
    "${INPUT}"
    DEPENDS
    "${INPUT}/Types.idl"
    "${MIDL_EXECUTABLE}"
    WORKING_DIRECTORY
    "${INPUT}"
)
