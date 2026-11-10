# Copyright (c) Microsoft Corporation. All rights reserved.
cmake_minimum_required(VERSION 3.20)
if(NOT IS_ABSOLUTE "${ROOT}" OR NOT EXISTS "${INVENTORY}")
    message(FATAL_ERROR "MIDL output reconciliation requires an absolute ROOT and an existing INVENTORY")
endif()
file(STRINGS "${INVENTORY}" OUTPUTS)
set(MANIFEST "${ROOT}/.windows-outputs")
set(PREVIOUS)
if(EXISTS "${MANIFEST}")
    file(STRINGS "${MANIFEST}" PREVIOUS)
endif()
foreach(OUTPUT IN LISTS OUTPUTS PREVIOUS)
    if(NOT IS_ABSOLUTE "${OUTPUT}")
        message(FATAL_ERROR "MIDL output manifest contains a relative path: ${OUTPUT}")
    endif()
    file(
        RELATIVE_PATH
        RELATIVE
        "${ROOT}"
        "${OUTPUT}"
    )
    if(IS_ABSOLUTE "${RELATIVE}"
       OR RELATIVE MATCHES "^\\.\\.(/|$)"
       OR RELATIVE STREQUAL ""
    )
        message(FATAL_ERROR "MIDL output is outside its owned directory: ${OUTPUT}")
    endif()
endforeach()
foreach(OUTPUT IN LISTS OUTPUTS)
    if(NOT EXISTS "${OUTPUT}" OR IS_DIRECTORY "${OUTPUT}")
        message(FATAL_ERROR "MIDL did not produce its declared output: ${OUTPUT}")
    endif()
endforeach()
foreach(OUTPUT IN LISTS PREVIOUS)
    if(NOT
       OUTPUT
       IN_LIST
       OUTPUTS
    )
        if(IS_DIRECTORY "${OUTPUT}")
            message(FATAL_ERROR "Refusing to remove a directory from MIDL output manifest: ${OUTPUT}")
        endif()
        file(REMOVE "${OUTPUT}")
    endif()
endforeach()
configure_file("${INVENTORY}" "${MANIFEST}" COPYONLY)
