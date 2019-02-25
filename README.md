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

This is essentially a bundle of the tools we need to build and run projects plus some of the libraries we need. Specifically, it contains:
 - clang
 - ld.lld + llvm-objcopy + llvm-ar + friends (essentially the LLVM alternatives to binutils)
 - lldb 
 - clangd + clang-format + clang-tidy
 - gdb
 - openocd
 - newlib + newlib nano (libc, libm, libnosys)
 - compiler-rt for Arm (intrinsics used by Clang)

Perhaps confusingly, this contains what's typically regarded as the toolchain. Hence, _Toolchain Container_.

This component is not particularly specific to the TM4C. The tools within the container can be used for any Arm target and the newlib build arguments can be tweaked to support other devices (there's more about this within the container's [Dockerfile](env/Dockerfile)).

##### Build and Initialization Files

The toolchain container gives us the tools we need to build projects for Arm devices in general, but it doesn't really know about our board. In order to put programs on a TM4C and run them there are a couple of other things we need to provide:

###### [startup.c]()
This essentially sets up the [NVIC table](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dai0179b/ar01s01s01.html) (table of interrupt handlers), sets up memory, and starts our programs.

This file also determines the naming convention for interrupt handlers.

###### [tm4c.ld]()
In order for our tools to make programs that we can flash onto our TM4C, they need to know how memory is arranged on our board. This linker script tells `ld.lld` things like how much flash and SRAM we have and where to put things like code and global variables.

There are also a few other files that are provided but those are for convenience and aren't _required_ ([intrinsics.S]() for example).

As you've probably guessed, this component is _highly_ specific to the TM4C. It'll mostly work with the LM4F too, though with some key exceptions (no PWM peripherals on the LM4F).

##### Build System

Thanks to the previous two components, we have a system that can compile code and assemble binaries and talk to the TM4C. Now we just need something to go and push the right buttons and that's exactly what our build system does.



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
- [ ] Install script (native alternative to using the docker container)
- [ ] Push to Docker Hub