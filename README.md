# TM4C LLVM Toolchain


[![](https://tokei.rs/b1/github/rrbutani/tm4c-llvm-toolchain)](https://github.com/rrbutani/tm4c-llvm-toolchain)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An opinionated toolchain for TI's [TM4C](http://www.ti.com/tool/EK-TM4C123GXL) (should work on the LM4F too).

The goal of this project is to provide a somewhat minimal setup for the TM4C that uses LLVM tools wherever possible and is easy to install and use. As such, this project takes a strong stance on things like build tools (we use [Ninja](https://ninja-build.org/)) and project layout; it, by design, doesn't expose many configuration options.

A lesser goal of this project is to be somewhat transparent. The pieces of this setup are documented in the hopes that it's possible to understand what's happening underneath, even (and especially) if you don't have much experience with bare metal C.

This is definitely still a work in progress and the toolchain (newlib in particular) contains some pretty unsightly workarounds. Using this in production or for anything important is probably not a great idea. That said, it _does_ seem to work on TM4C's and LM4F's without too much fuss.

If you run into problems or find something that's not quite right feel free to open an issue! PRs are welcome too, especially for documentation.

### Use Cases

This is good for small projects that don't have too many dependencies. It's essentially an alternative to the GNU ARM Embedded Toolchain + Make, plus some niceties like clangd 'support'.

Note that this _doesn't_ come with [Tivaware](http://www.ti.com/tool/sw-tm4c) or DriverLib or really anything more than the C standard library. It is possible to add these (and other libraries) to a project using this toolchain without much trouble, however if you're very dependent on TivaWare or if you're looking for something a little less barebones, you'll probably be better served by something like [Energia](http://energia.nu/) or [CCS](http://www.ti.com/tool/ccstudio).

### What's inside?

There are really three components in this repo: a docker container that holds the tools needed and some libraries, the build and initialization files needed for the TM4C, and finally the build system.

##### Toolchain Container

##### Build and Initialization Files

##### Build System

### Installation and Usage

### Examples

### Features

### Status

##### Toolchain Container
- [x] newlib + newlib nano
- [x] arm-compiler-rt for intrinsics
- [x] openocd
- [x] gdb
- [ ] ninja
- [x] clang-tools + clang-format + clang-tidy
- [x] Clang version + image base + newlib tag as build args
- [x] update-alternatives for llvm/clang tools

##### Build and Initialization Files
- [ ] TM4C specific linker script
- [ ] FPU support
- [ ] NVIC Table + weak aliases to the default handler
- [ ] Heap support (in linker script)

##### Build System
- [ ] Compilation Database target (for clangd)
- [ ] Debug target
- [ ] Flash targets (flash, run, reset)
- [ ] UART target (screen)
- [ ] Native or containerized tooling option
- [ ] WSL support (flash + UART; no debug)

##### Misc
 - [ ] Soft Floating Point Support
    * [ ] Soft float/hard float versions of newlib and compiler-rt
    * [ ] Logic in the build system to pick between soft and hard float ABIs (for libraries and compiler flags)
    * [ ] Preprocessor logic to selectively enable the FPU (in startup.c)
    * I'm not convinced this is worth doing.
- [ ] No host dependencies
    * [ ] Add ninja to the container
    * [ ] Get the build system to recognize when it's already running in the container