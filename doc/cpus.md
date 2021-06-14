# CPUs

Some CPUs are included in JTFRAME. Some of them can be found in other repositories in Github but the versions in JTFRAME include clock enable inputs and other improvements.

CPUs should have their respective license file in the folder, or directly embedded in the files. Note that they don't use GPL3 but more permissive licenses.

Many CPUs have convenient wrappers that add cycle recovery functionality, or
that allow the selection between different modules for the same CPU.

CPU selection is done via verilog [macros](macros.md).