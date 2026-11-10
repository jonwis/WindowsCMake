#----------------------------------------------------------------------------------------------------------------------
# MIT License
#
# Copyright (c) 2025 Mark Schofield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#----------------------------------------------------------------------------------------------------------------------
include_guard()

if(CMAKE_VERSION VERSION_LESS 3.20)
    message(FATAL_ERROR "WindowsCMake requires at least CMake 3.20, but CMake ${CMAKE_VERSION} is in use.")
endif()

set(MIDL_1_0_PLATFORM_RESPONSE_FILE "${CMAKE_BINARY_DIR}/midl.1.0.platform.rsp")

#[[
add_midl(<target> COMPILER <executable-or-target> IDL <file>
    OUTPUT_DIRECTORY <directory> OUTPUTS <files...>
    [HEADER <name>] [IID <name>] [PROXY <name>] [DLLDATA <name>]
    [TLB <name> | NOTLB] [OPTIONS <arguments...>]
    [INCLUDE_DIRECTORIES <directories...>] [DEPENDS <files-or-targets...>]
    [WORKING_DIRECTORY <directory>])

Creates an interface target owning one IDL invocation. Unlike enable_midl,
compiler options and generated filenames are explicit, and generated C sources
are not automatically compiled into consumers.
]]
function(add_midl TARGET)
    cmake_parse_arguments(
        PARSE_ARGV
        1
        MIDL
        "NOTLB"
        "COMPILER;IDL;OUTPUT_DIRECTORY;HEADER;IID;PROXY;DLLDATA;TLB;WORKING_DIRECTORY"
        "OUTPUTS;OPTIONS;INCLUDE_DIRECTORIES;DEPENDS"
    )
    if(MIDL_UNPARSED_ARGUMENTS OR MIDL_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "Invalid add_midl arguments: ${MIDL_UNPARSED_ARGUMENTS};${MIDL_KEYWORDS_MISSING_VALUES}")
    endif()
    foreach(
        REQUIRED IN
        ITEMS COMPILER
              IDL
              OUTPUT_DIRECTORY
              OUTPUTS
    )
        if(NOT MIDL_${REQUIRED})
            message(FATAL_ERROR "add_midl requires ${REQUIRED}")
        endif()
    endforeach()
    if(MIDL_NOTLB AND MIDL_TLB)
        message(FATAL_ERROR "add_midl cannot combine TLB and NOTLB")
    endif()
    if(NOT MIDL_WORKING_DIRECTORY)
        set(MIDL_WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    get_filename_component(
        MIDL_WORKING_DIRECTORY
        "${MIDL_WORKING_DIRECTORY}"
        ABSOLUTE
        BASE_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    get_filename_component(
        MIDL_IDL
        "${MIDL_IDL}"
        ABSOLUTE
        BASE_DIR
        "${MIDL_WORKING_DIRECTORY}"
    )
    get_filename_component(
        MIDL_OUTPUT_DIRECTORY
        "${MIDL_OUTPUT_DIRECTORY}"
        ABSOLUTE
        BASE_DIR
        "${CMAKE_CURRENT_BINARY_DIR}"
    )
    foreach(OUTPUT IN LISTS MIDL_OUTPUTS)
        if(NOT IS_ABSOLUTE "${OUTPUT}")
            message(FATAL_ERROR "add_midl OUTPUTS must be absolute: ${OUTPUT}")
        endif()
        file(
            RELATIVE_PATH
            RELATIVE
            "${MIDL_OUTPUT_DIRECTORY}"
            "${OUTPUT}"
        )
        if(IS_ABSOLUTE "${RELATIVE}" OR RELATIVE MATCHES "^\\.\\.(/|$)")
            message(FATAL_ERROR "add_midl OUTPUTS must be inside OUTPUT_DIRECTORY: ${OUTPUT}")
        endif()
    endforeach()
    set(MIDL_ARGUMENTS ${MIDL_OPTIONS})
    foreach(DIRECTORY IN LISTS MIDL_INCLUDE_DIRECTORIES)
        list(
            APPEND
            MIDL_ARGUMENTS
            /I
            "${DIRECTORY}"
        )
    endforeach()
    list(
        APPEND
        MIDL_ARGUMENTS
        /out
        "${MIDL_OUTPUT_DIRECTORY}"
    )
    foreach(
        FIELD IN
        ITEMS HEADER
              IID
              PROXY
              DLLDATA
              TLB
    )
        if(MIDL_${FIELD})
            string(TOLOWER "${FIELD}" SWITCH)
            if(FIELD STREQUAL "HEADER")
                set(SWITCH h)
            endif()
            list(
                APPEND
                MIDL_ARGUMENTS
                "/${SWITCH}"
                "${MIDL_${FIELD}}"
            )
        endif()
    endforeach()
    if(MIDL_NOTLB)
        list(APPEND MIDL_ARGUMENTS /notlb)
    endif()
    set(COMPILER_DEPENDENCIES "${MIDL_COMPILER}")
    if(TARGET "${MIDL_COMPILER}")
        list(APPEND COMPILER_DEPENDENCIES "$<TARGET_FILE:${MIDL_COMPILER}>")
    endif()
    list(APPEND MIDL_ARGUMENTS "${MIDL_IDL}")
    set(RESPONSE "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${TARGET}-$<CONFIG>.midl.rsp")
    set(CONTENT "")
    foreach(ARGUMENT IN LISTS MIDL_ARGUMENTS)
        if(ARGUMENT MATCHES "[\"\r\n]")
            message(FATAL_ERROR "MIDL response arguments cannot contain quotes or newlines: ${ARGUMENT}")
        endif()
        string(APPEND CONTENT "\"${ARGUMENT}\"\n")
    endforeach()
    file(
        GENERATE
        OUTPUT
        "${RESPONSE}"
        CONTENT
        "${CONTENT}"
    )
    set(INVENTORY "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${TARGET}-$<CONFIG>.midl.outputs")
    list(
        JOIN
        MIDL_OUTPUTS
        "\n"
        CONTENT
    )
    file(
        GENERATE
        OUTPUT
        "${INVENTORY}"
        CONTENT
        "${CONTENT}\n"
    )
    set(PRUNE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/MidlOutputs.cmake")
    add_custom_command(
        OUTPUT ${MIDL_OUTPUTS}
        BYPRODUCTS "${MIDL_OUTPUT_DIRECTORY}/.windows-outputs"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${MIDL_OUTPUT_DIRECTORY}"
        COMMAND "${MIDL_COMPILER}" "@${RESPONSE}"
        COMMAND "${CMAKE_COMMAND}" "-DROOT=${MIDL_OUTPUT_DIRECTORY}" "-DINVENTORY=${INVENTORY}" -P "${PRUNE}"
        DEPENDS ${COMPILER_DEPENDENCIES}
                "${MIDL_IDL}"
                ${MIDL_DEPENDS}
                "${RESPONSE}"
                "${INVENTORY}"
                "${PRUNE}"
        WORKING_DIRECTORY "${MIDL_WORKING_DIRECTORY}"
        COMMENT "Processing ${MIDL_IDL}"
        VERBATIM
    )
    add_custom_target(
        "${TARGET}_generate"
        DEPENDS ${MIDL_OUTPUTS}
        COMMENT "Generating MIDL outputs for ${TARGET}"
    )
    add_library("${TARGET}" INTERFACE)
    add_dependencies("${TARGET}" "${TARGET}_generate")
    target_include_directories("${TARGET}" BEFORE INTERFACE "${MIDL_OUTPUT_DIRECTORY}")
    set_target_properties("${TARGET}" PROPERTIES MIDL_OUTPUTS "${MIDL_OUTPUTS}")
endfunction()

#----------------------------------------------------------------------------------------------------------------------
#
#----------------------------------------------------------------------------------------------------------------------
function(enable_midl)
    if(NOT ((CMAKE_C_COMPILER_ID STREQUAL "MSVC") OR (CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")))
        message(STATUS "CMAKE_C_COMPILER_ID = ${CMAKE_C_COMPILER_ID}")
        message(STATUS "CMAKE_C_COMPILER_FRONTEND_VARIANT = ${CMAKE_C_COMPILER_FRONTEND_VARIANT}")
        message(FATAL_ERROR "'enable_midl' is only supported with MSVC or an MSVC frontend.")
    endif()

    cmake_language(EVAL CODE "cmake_language(DEFER CALL _process_target_midl_1_0 [[${ARGV0}]])")
endfunction()

#----------------------------------------------------------------------------------------------------------------------
#
#----------------------------------------------------------------------------------------------------------------------
function(_generateMidlOutput TARGET IDL_FILES MIDL_GENERATED_FILES)
    get_target_property(TARGET_SOURCE_DIR ${TARGET} SOURCE_DIR)

    # COMPILER_DIR and COMPILER_NAME
    get_filename_component(COMPILER_DIR ${CMAKE_C_COMPILER} DIRECTORY)
    get_filename_component(COMPILER_NAME ${CMAKE_C_COMPILER} NAME)

    set(MIDL_COMMAND "")
    list(APPEND MIDL_COMMAND "\"${MIDL_COMPILER}\"")
    list(APPEND MIDL_COMMAND /nologo)

    if(CMAKE_C_COMPILER_ARCHITECTURE_ID STREQUAL "x64")
        list(APPEND MIDL_COMMAND /env x64)
    elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID STREQUAL "ARM64")
        list(APPEND MIDL_COMMAND /env arm64)
    elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID STREQUAL "X86")
        list(APPEND MIDL_COMMAND /env win32)
    else()
        message(FATAL_ERROR "Unsupported CMAKE_C_COMPILER_ARCHITECTURE_ID '${CMAKE_C_COMPILER_ARCHITECTURE_ID}' for MIDL.")
    endif()

    list(APPEND MIDL_COMMAND /W3 /WX)
    list(APPEND MIDL_COMMAND /char signed)
    list(APPEND MIDL_COMMAND /error all)
    list(APPEND MIDL_COMMAND /newtlb)
    list(APPEND MIDL_COMMAND /robust)
    list(APPEND MIDL_COMMAND /target NT60)
    list(APPEND MIDL_COMMAND /dlldata "DllData.c")
    list(APPEND MIDL_COMMAND /out "\"${CMAKE_CURRENT_BINARY_DIR}/Generated Files\"")

    list(APPEND MIDL_COMMAND /cpp_cmd ${COMPILER_NAME})

    if(CMAKE_C_COMPILER_ID STREQUAL "Clang")
        # Midl's use of the preprocessor parses files that logs clang warnings, so
        # explicitly disabling them.
        list(APPEND MIDL_COMMAND /cpp_opt "\"-Wno-undef -Wno-language-extension-token -Wno-unused-macros -Wno-nonportable-system-include-path -Wno-reserved-macro-identifier -Wno-nonportable-include-path /E\"")
    endif()

    # Build the MIDL_INCLUDE_DIRECTORIES. They are:
    #   1) The 'INCLUDE_DIRECTORIES' from the TARGET
    #   2) The 'CMAKE_C_STANDARD_INCLUDE_DIRECTORIES'
    get_target_property(MIDL_INCLUDE_DIRECTORIES ${TARGET} INCLUDE_DIRECTORIES)
    list(APPEND MIDL_INCLUDE_DIRECTORIES ${CMAKE_C_STANDARD_INCLUDE_DIRECTORIES})
    list(TRANSFORM MIDL_INCLUDE_DIRECTORIES PREPEND "/I \"")
    list(TRANSFORM MIDL_INCLUDE_DIRECTORIES APPEND "\"")

    list(APPEND MIDL_COMMAND ${MIDL_INCLUDE_DIRECTORIES})

    set(GENERATED_FILES)
    list(APPEND GENERATED_FILES "${CMAKE_CURRENT_BINARY_DIR}/Generated Files/DllData.c")

    foreach(IDL_FILE IN LISTS IDL_FILES)
        get_filename_component(IDL_FILE_BASE ${IDL_FILE} NAME_WLE)

        set(MIDL_FILE_SPECIFIC_COMMAND ${MIDL_COMMAND})
        list(APPEND MIDL_FILE_SPECIFIC_COMMAND /h "${IDL_FILE_BASE}_i.h")
        list(APPEND MIDL_FILE_SPECIFIC_COMMAND /iid "${IDL_FILE_BASE}_i.c")
        list(APPEND MIDL_FILE_SPECIFIC_COMMAND /proxy "${IDL_FILE_BASE}_p.c")
        list(APPEND MIDL_FILE_SPECIFIC_COMMAND /tlb "${IDL_FILE_BASE}.tlb")
        list(APPEND MIDL_FILE_SPECIFIC_COMMAND ${IDL_FILE})

        set(MIDL_OUTPUT_FILES)
        list(APPEND MIDL_OUTPUT_FILES "${CMAKE_CURRENT_BINARY_DIR}/Generated Files/${IDL_FILE_BASE}_i.h")
        list(APPEND MIDL_OUTPUT_FILES "${CMAKE_CURRENT_BINARY_DIR}/Generated Files/${IDL_FILE_BASE}_i.c")
        list(APPEND MIDL_OUTPUT_FILES "${CMAKE_CURRENT_BINARY_DIR}/Generated Files/${IDL_FILE_BASE}_p.c")
        list(APPEND MIDL_OUTPUT_FILES "${CMAKE_CURRENT_BINARY_DIR}/Generated Files/${IDL_FILE_BASE}.tlb")

        set(MIDL_COMMAND_SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/midl.1.0.${IDL_FILE_BASE}.cmd)
        list(JOIN MIDL_FILE_SPECIFIC_COMMAND " " MIDL_COMMAND_LINE)

        file(GENERATE OUTPUT ${MIDL_COMMAND_SCRIPT} CONTENT "\
@echo off
setlocal enabledelayedexpansion
set PATH=%PATH%;${COMPILER_DIR}
${MIDL_COMMAND_LINE} > ${MIDL_COMMAND_SCRIPT}.log 2>&1
IF ERRORLEVEL 1 (
    SET LOGFILE=${MIDL_COMMAND_SCRIPT}.log
    SET LOGFILE=!LOGFILE:/=\\!
    type !LOGFILE!
    exit /b 1
)
")

        add_custom_command(
            OUTPUT ${MIDL_OUTPUT_FILES} "${CMAKE_CURRENT_BINARY_DIR}/Generated Files/DllData.c"
            COMMAND ${MIDL_COMMAND_SCRIPT}
            MAIN_DEPENDENCY ${IDL_FILE}
            DEPENDS ${MIDL_COMMAND_SCRIPT}
            BYPRODUCTS ${MIDL_COMMAND_SCRIPT}.log
            COMMENT "Processing ${IDL_FILE}"
            WORKING_DIRECTORY ${TARGET_SOURCE_DIR}
        )

        list(APPEND GENERATED_FILES ${MIDL_OUTPUT_FILES})
    endforeach()

    set(${MIDL_GENERATED_FILES} ${GENERATED_FILES} PARENT_SCOPE)
endfunction()

#----------------------------------------------------------------------------------------------------------------------
#
#----------------------------------------------------------------------------------------------------------------------
function(_process_target_midl_1_0 TARGET)
    get_target_property(TARGET_SOURCE_DIR ${TARGET} SOURCE_DIR)

    get_target_property(IDL_FILES ${TARGET} SOURCES)
    list(FILTER IDL_FILES INCLUDE REGEX "\.idl$")

    # Run MIDL on every '.idl' file specified to the target.
    _generateMidlOutput(${TARGET} ${IDL_FILES} MIDL_GENERATED_FILES)

    target_include_directories(${TARGET}
        PRIVATE
            "${TARGET_SOURCE_DIR}"
        PUBLIC
            "${CMAKE_CURRENT_BINARY_DIR}/Generated Files"
    )

    target_sources(${TARGET}
        PRIVATE
            ${MIDL_GENERATED_FILES}
    )
endfunction()
