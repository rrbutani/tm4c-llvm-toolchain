# TM4C LLVM Toolchain


[![](https://tokei.rs/b1/github/rrbutani/tm4c-llvm-toolchain)](https://github.com/rrbutani/tm4c-llvm-toolchain)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![](https://images.microbadger.com/badges/image/rrbutani/arm-llvm-toolchain.svg)](https://cloud.docker.com/u/rrbutani/repository/docker/rrbutani/arm-llvm-toolchain)

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
 - ninja
 - newlib + newlib nano (libc, libm, libnosys)
 - compiler-rt for Arm (intrinsics used by Clang)

Perhaps confusingly, this contains what's typically regarded as the toolchain. Hence, _Toolchain Container_.

This component is not particularly specific to the TM4C. The tools within the container can be used for any Arm target and the newlib build arguments can be tweaked to support other devices (there's more about this within the container's [Dockerfile](env/Dockerfile)).

##### Build and Initialization Files

The toolchain container gives us the tools we need to build projects for Arm devices in general, but it doesn't really know about our board. In order to put programs on a TM4C and run them there are a few other things we need to provide:

###### [startup.c](src/startup.c)
This essentially sets up the [NVIC table](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dai0179b/ar01s01s01.html) (table of interrupt handlers), sets up memory, and starts our programs.

This file also determines the naming convention for interrupt handlers.

###### [tm4c.ld](misc/tm4c.ld)
In order for our tools to make programs that we can flash onto our TM4C, they need to know how memory is arranged on our board. This linker script tells `ld.lld` things like how much flash and SRAM we have and where to put things like code and global variables.

###### [gdb-script](misc/gdb-script)
A debugger isn't _technically_ required to build and run programs, but it definitely is nice to have. In order to get GDB (a command line debugger) to talk to our TM4C, we have to tell it how to start OpenOCD (a program that facilitates MCU <-> computer communication), which is exactly what `gdb-script` does.

There are also a few other files that are provided but those are for convenience and aren't _required_ ([intrinsics.s](asm/intrinsics.s) for example).

As you've probably guessed, this component is _highly_ specific to the TM4C. It'll mostly work with the LM4F too, though with some key exceptions (no PWM peripherals on the LM4F).

##### Build System

Thanks to the previous two components, we have a system that can compile code and assemble binaries and talk to the TM4C. Now we just need something to go and push the right buttons and that's exactly what our build system does.

### Installation

### Usage

##### Files
Will search for files in the top of the folder and in src/ (for .s, .S, .c, .cpp, .cc, .cxx) and in inc/ (for .h).

##### Targets
Targets ending in .out build binaries (must contain a main). Targets ending in .a build libraries (we'll call these modules).

##### Two Configurations: one directory and separate common directory.

###### One Directory
```bash
├── asm
│   └── intrinsics.s
├── build.ninja
├── common.ninja
├── env
│   └── Dockerfile
├── inc
├── misc
│   ├── gdb-script
│   └── tm4c.ld
└── src
    ├── main.c
    └── startup.c
```

`COMMON_PATH` in build.ninja is set to `.`; `TARGET` is set to `main.out`.

###### Separate Common Directory
```bash
├── common
│   ├── asm
│   │   └── intrinsics.s
│   ├── build.ninja
│   ├── common.ninja
│   ├── env
│   │   └── Dockerfile
│   ├── inc
│   ├── misc
│   │   ├── gdb-script
│   │   └── tm4c.ld
│   ├── README.md
│   └── src
│       ├── main.c
│       └── startup.c
└── proj
    ├── build.ninja
    ├── inc
    └── src
        └── main.c
```

`COMMON_PATH` in proj/build.ninja is set to `../common`; `TARGET` is set to `main.out`.

Note that this won't use or even compile the `main.c` in `common/src`.

##### Modules

Additionally, you can use other modules (other projects that are set up to compile a library - `TARGET` ends in .a) by adding the path of the module plus it's name to `MODULES`.

For example, a separate common directory setup with some modules:

```bash
├── common
│   ├── asm
│   │   └── intrinsics.s
│   ├── build.ninja
│   ├── common.ninja
│   ├── env
│   │   └── Dockerfile
│   ├── inc
│   ├── LICENSE
│   ├── misc
│   │   ├── gdb-script
│   │   └── tm4c.ld
│   ├── README.md
│   └── src
│       ├── main.c
│       └── startup.c
├── modules
│   ├── contrib
│   │   ├── build.ninja
│   │   ├── inc
│   │   │   └── SPI.h
│   │   └── src
│   │       └── SPI.c
│   └── porcelain
│       ├── build.ninja
│       ├── inc
│       │   └── HAL.h
│       └── src
│           └── HAL.c
└── proj
    ├── build.ninja
    ├── inc
    └── src
        └── main.c
```

Here contrib and porcelain are both modules. They have `TARGET` in their build.ninja files set to `contrib.a` and `hal.a` respectively. Both have `COMMON` set to `../../common`.

As in the previous example, `COMMON_PATH` in proj/build.ninja is set to `../common`; `TARGET` is set to `main.out`. `MODULES` is set to `../modules/contrib/contrib.a ../modules/porcelain/hal.a` so that `proj/src/main.c` can use functions in `SPI.c` and `HAL.c`.

Note that you can use common (this repo) as a module even if it is also being used as `COMMON` for a project. The only special thing about common is the files it has (intrinsics.s, startup.c, tm4c.ld, gdb-script, common.ninja).

Also note that modules can use other modules. For example, in the above porcelain's build.ninja could have set `MODULES` to `../contrib/contrib.a` so that it could use functions in `SPI.c`.

In a module, it's generally best to name your target the same as your folder name; for example the contrib module above used contrib.a as its target.

### Examples

TODO: examples branch

### Features

### Status

##### Toolchain Container
- [x] newlib + newlib nano
- [x] arm-compiler-rt for intrinsics
- [x] openocd
- [x] gdb
- [x] ninja
- [ ] graphviz (dot)
- [x] clang-tools + clang-format + clang-tidy
- [x] Clang version + image base + newlib tag as build args
- [x] update-alternatives for llvm/clang tools

##### Build and Initialization Files
- [x] TM4C specific linker script
- [x] GDB script
- [x] FPU support
- [x] NVIC Table + weak aliases to the default handler
- [ ] Heap support (in linker script)

##### Build System
- [ ] Support custom common path
- [ ] Support libraries w/different paths (with the container option)
- [ ] Compilation Database target (for clangd)
- [ ] Clang format/tidy targets
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
- [x] Push to Docker Hub (done - with GitHub Actions!)
- [ ] C++ support?
    * Not sure about this one.
- [ ] Add a clang format file, maybe