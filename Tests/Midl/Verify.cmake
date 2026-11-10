# Copyright (c) Microsoft Corporation. All rights reserved.
function(run)
    execute_process(
        COMMAND ${ARGV}
        RESULT_VARIABLE RESULT
        OUTPUT_VARIABLE OUTPUT
        ERROR_VARIABLE ERROR
    )
    if(NOT
       RESULT
       EQUAL
       0
    )
        message(FATAL_ERROR "Command failed (${RESULT}): ${ARGV}\n${OUTPUT}\n${ERROR}")
    endif()
    set(LAST_OUTPUT
        "${OUTPUT}\n${ERROR}"
        PARENT_SCOPE
    )
endfunction()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${ROOT}/Fixture" -B "${BINARY}" -G Ninja "-DCMAKE_MAKE_PROGRAM=${NINJA}"
            "-DMODE=${MODE}" -DALT_HEADER=OFF
    RESULT_VARIABLE RESULT
    OUTPUT_VARIABLE OUTPUT
    ERROR_VARIABLE ERROR
)
if(MODE STREQUAL "invalid")
    if(RESULT EQUAL 0
       OR NOT
          "${OUTPUT}${ERROR}"
          MATCHES
          "cannot combine TLB and NOTLB"
    )
        message(FATAL_ERROR "Expected conflicting typelib options to be rejected:\n${OUTPUT}\n${ERROR}")
    endif()
    return()
endif()
if(NOT
   RESULT
   EQUAL
   0
)
    message(FATAL_ERROR "Configure failed:\n${OUTPUT}\n${ERROR}")
endif()
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
set(HEADER "${BINARY}/generated files/Custom.h")
set(OUTPUTS
    "${HEADER}"
    "${BINARY}/generated files/Custom_i.c"
    "${BINARY}/generated files/Custom_p.c"
    "${BINARY}/generated files/Custom_dlldata.c"
)
if(MODE STREQUAL "typelib")
    list(APPEND OUTPUTS "${BINARY}/generated files/Custom.tlb")
elseif(EXISTS "${BINARY}/generated files/Example.tlb")
    message(FATAL_ERROR "NOTLB unexpectedly generated a type library")
endif()
foreach(OUTPUT IN LISTS OUTPUTS)
    if(NOT EXISTS "${OUTPUT}")
        message(FATAL_ERROR "Missing declared output: ${OUTPUT}")
    endif()
endforeach()
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
if(NOT
   LAST_OUTPUT
   MATCHES
   "no work to do"
)
    message(FATAL_ERROR "Expected a no-op:\n${LAST_OUTPUT}")
endif()
file(REMOVE "${HEADER}")
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
if(NOT EXISTS "${HEADER}")
    message(FATAL_ERROR "Deleted header was not regenerated")
endif()
run("${CMAKE_COMMAND}"
    -E
    sleep
    1
)
run("${CMAKE_COMMAND}"
    -E
    touch
    "${BINARY}/input files/Types.idl"
)
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
if(NOT
   LAST_OUTPUT
   MATCHES
   "Processing"
)
    message(FATAL_ERROR "Imported input did not trigger regeneration:\n${LAST_OUTPUT}")
endif()
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
if(NOT
   LAST_OUTPUT
   MATCHES
   "no work to do"
)
    message(FATAL_ERROR "Expected a final no-op:\n${LAST_OUTPUT}")
endif()
run("${CMAKE_COMMAND}"
    -E
    sleep
    1
)
run("${CMAKE_COMMAND}"
    -E
    touch
    "${BINARY}/Midl.cmd"
)
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
if(NOT
   LAST_OUTPUT
   MATCHES
   "Processing"
)
    message(FATAL_ERROR "Compiler target file did not trigger regeneration:\n${LAST_OUTPUT}")
endif()
file(WRITE "${BINARY}/generated files/unowned.txt" "preserve this file\n")
file(READ "${BINARY}/generated files/.windows-outputs" MANIFEST)
run("${CMAKE_COMMAND}"
    -S
    "${ROOT}/Fixture"
    -B
    "${BINARY}"
    -DALT_HEADER=ON
)
file(APPEND "${BINARY}/input files/Example.idl" "\nthis is invalid IDL;\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${BINARY}" --target example_generate
    RESULT_VARIABLE RESULT
    OUTPUT_VARIABLE OUTPUT
    ERROR_VARIABLE ERROR
)
if(RESULT EQUAL 0)
    message(FATAL_ERROR "Invalid IDL unexpectedly succeeded")
endif()
file(READ "${BINARY}/generated files/.windows-outputs" AFTER_FAILURE)
if(NOT
   AFTER_FAILURE
   STREQUAL
   MANIFEST
   OR NOT EXISTS "${HEADER}"
)
    message(FATAL_ERROR "Failed compilation changed output ownership or pruned the old header")
endif()
file(WRITE "${BINARY}/missing.outputs" "${BINARY}/generated files/Custom_i.c\n${BINARY}/generated files/Missing.h\n")
execute_process(
    COMMAND "${CMAKE_COMMAND}" "-DROOT=${BINARY}/generated files" "-DINVENTORY=${BINARY}/missing.outputs" -P
            "${ROOT}/../../WindowsCMake/MidlOutputs.cmake"
    RESULT_VARIABLE RESULT
    OUTPUT_VARIABLE OUTPUT
    ERROR_VARIABLE ERROR
)
if(RESULT EQUAL 0
   OR NOT
      "${OUTPUT}${ERROR}"
      MATCHES
      "did not produce its declared output"
)
    message(FATAL_ERROR "Expected missing declared output to be rejected:\n${OUTPUT}\n${ERROR}")
endif()
file(READ "${BINARY}/generated files/.windows-outputs" AFTER_FAILURE)
if(NOT
   AFTER_FAILURE
   STREQUAL
   MANIFEST
   OR NOT EXISTS "${HEADER}"
)
    message(FATAL_ERROR "Missing output changed ownership or pruned the old header")
endif()
run("${CMAKE_COMMAND}"
    -S
    "${ROOT}/Fixture"
    -B
    "${BINARY}"
    -DALT_HEADER=ON
)
run("${CMAKE_COMMAND}"
    --build
    "${BINARY}"
    --target
    example_generate
)
if(EXISTS "${HEADER}"
   OR NOT EXISTS "${BINARY}/generated files/Renamed.h"
   OR NOT EXISTS "${BINARY}/generated files/unowned.txt"
)
    message(FATAL_ERROR "Output rename did not prune only the obsolete owned header")
endif()
