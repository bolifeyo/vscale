<img src="http://albert-magyar.github.io/vscale/vscale.svg">

# vscale

Verilog version of [Z-scale](https://github.com/ucb-bar/zscale), a microarchitectural implementation of the 32-bit RISC-V ISA (RV32IM).

## Usage with Verilator

Since verilator translates verilog code into C++ and given that various C++ libraries (see [external](external/README.md) directory) are integrated into the verilator build, CMake has been used as build system.

### Building

As the result, vscale with verilator can be built like any other cmake project with the following commands:

```
$ mkdir <build-directory>
$ cd <build-directory>
$ cmake [cmake-options] <source-directory>
$ cmake --build . [--target <target-name>]
```

Alternatively, the makefile in the project root can be used when the sim directory is used as build directory:

```
$ make verilator-sim
```
After building, the `vscale` executable can be found in the build directory. To perform a quick functionality check, either the `check` target in the build directory, or the `verilator-run-asm-tests` target in the project root directory can be used.

### Executing Software

To execute your own software in hex or elf format on vscale, the following command can be used:

```
$ ./<build-directory>/vscale --loadmem <path-to-hex-or-elf-file>
```

## Usage with Synopsys VCS
In order to build and test vscale using the supplied makefile,
Synopsys VCS must be installed and on the path.

```
$ make
$ make run-asm-tests
```

