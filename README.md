# CMake Tooling for Windows Builds

'WindowsCMake' contains CMake-scripts for Windows-specific build tasks, like unpacking NuGet files or generating Cpp/WinRT projections.

## Explicit COM IDL generation

`include(Midl)` provides `add_midl` for Ninja and other custom-command generators.
It creates an interface target owning the declared outputs; consumers choose which
generated C files to compile. Existing `enable_midl(target)` behavior is unchanged.

```cmake
add_midl(interfaces
    COMPILER WindowsSDK::midl
    IDL Interfaces.idl
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated"
    OUTPUTS "${CMAKE_CURRENT_BINARY_DIR}/generated/Interfaces.h"
            "${CMAKE_CURRENT_BINARY_DIR}/generated/Interfaces_i.c"
            "${CMAKE_CURRENT_BINARY_DIR}/generated/Interfaces_p.c"
            "${CMAKE_CURRENT_BINARY_DIR}/generated/dlldata.c"
    HEADER Interfaces.h
    NOTLB
    OPTIONS /nologo /W1 /char signed /env x64 /target NT100
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/Imported.idl")
```

`COMPILER` accepts an executable target or path. `OPTIONS` supplies the exact MIDL
flags without implicit warning or platform overrides. `HEADER`, `IID`, `PROXY`,
`DLLDATA` and `TLB` select filenames; `NOTLB` disables type-library generation.
List every generated file as an absolute path in `OUTPUTS`, and imported IDL or
configuration inputs in `DEPENDS`. `INCLUDE_DIRECTORIES` adds ordered `/I` options.
Relative IDL paths resolve from `WORKING_DIRECTORY`, which defaults to the current
source directory. Relative output directories resolve from the current binary directory.
Each invocation owns its output directory. Successful regeneration removes obsolete
manifest-owned files and preserves files it did not generate. Consumers link the interface
target; use `<target>_generate` to build only its generated files.

The focused tests require Ninja and an initialized Windows SDK command environment:

```powershell
cmake -S Tests/Midl -B out/midl -G Ninja
ctest --test-dir out/midl --output-on-failure
```

## Linting

WindowsCMake uses [`cmakelang`][cmakelang] for linting the CMake files in the codebase. The
[.cmake-format.yaml](./.cmake-format.yaml) file describes the formatting style for the codebase. To run the linting
tools:

1. Install [`cmakelang`][cmakelang] following [the installation instuctions](https://cmake-format.readthedocs.io/en/latest/installation.html).
Note: Since WindowsCMake uses a `.yaml` file for configuration, make sure to install the `cmakelang[YAML]` package.

2. Run [`./analyze.ps1`](./analyze.ps1)

The [WindowsCMake CI](.\.github\workflows\ci.yaml) GitHub Workflow enforces the linting rules during PR and CI.

## Testing

WindowsCMake uses [Pester][pester] for testing the CMake files in the codebase. The tests are written for
[PowerShell Core][powershellcore] and checked into [the `Tests` folder](./Tests). To run the tests:

1. Launch a [PowerShell Core][powershellcore] prompt.

    ```text
    pwsh
    ```

2. Make sure that you have [Pester][pester] installed. This only needs to be done once.

    ```powershell
    Install-Module Pester
    ```

3. Import the Pester module into the PowerShell Core session:

    ```powershell
    Import-Module Pester
    ```

4. Discover and run all tests:

    ```powershell
    Invoke-Pester
    ```

The [WindowsCMake CI](.\.github\workflows\ci.yaml) GitHub Workflow requires all tests to pass during PR and CI.

[cmakelang]: https://cmake-format.readthedocs.io/ "cmakelang"
[pester]: https://pester.dev/ "Pester"
[powershellcore]: https://learn.microsoft.com/en-us/powershell/ "PowerShell Core"
