# Copyright (c) Microsoft Corporation. All rights reserved.
cmake_minimum_required(VERSION 3.20)
project(MidlTests NONE)
include(CTest)
foreach(MODE IN ITEMS notlb typelib invalid)
    add_test(
        NAME "midl.${MODE}"
        COMMAND
            "${CMAKE_COMMAND}" "-DMODE=${MODE}" "-DROOT=${CMAKE_CURRENT_SOURCE_DIR}"
            "-DBINARY=${CMAKE_CURRENT_BINARY_DIR}/${MODE}" "-DNINJA=${CMAKE_MAKE_PROGRAM}" -P
            "${CMAKE_CURRENT_SOURCE_DIR}/Verify.cmake"
    )
endforeach()
