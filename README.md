# TM4C LLVM Toolchain


[![](https://tokei.rs/b1/github/rrbutani/tm4c-llvm-toolchain)](https://github.com/rrbutani/tm4c-llvm-toolchain)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![](https://images.microbadger.com/badges/image/rrbutani/arm-llvm-toolchain.svg)](https://cloud.docker.com/u/rrbutani/repository/docker/rrbutani/arm-llvm-toolchain)

An opinionated toolchain for TI's [TM4C](http://www.ti.com/tool/EK-TM4C123GXL) (should work on the LM4F too).

The goal of this project is to provide a somewhat minimal setup for the TM4C that uses LLVM tools wherever possible and is easy to install and use. As such, this project takes a strong stance on things like build tools (we use [Ninja](https://ninja-build.org/)) and project layout; it, by design, doesn't expose many configuration options.

A lesser goal of this project is to be somewhat transparent. The pieces of this setup are documented in the hopes that it's possible to understand what's happening underneath, even (and especially) if you don't have much experience with bare metal C.

This is definitely still a work in progress and the toolchain (newlib in particular) contains some pretty unsightly workarounds. Using this in production or for anything important is probably not a great idea. That said, it _does_ seem to work on TM4Cs and LM4Fs without too much fuss.

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
By default, will search for files in the top of the folder and in src/ (for .c, .cpp, .cc, .cxx) and in the top and asm/ (for .s, .S). Include paths are set to inc/ and the top of the folder (.h files).

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

#### Known Issues:
 - Exiting from a debugger without stepping causes the debug chip to go into a state `openocd` really doesn't like (restarting seems to be the quickest way to get it out of this state).
     + For now, run `continue` before you leave the debugger.

##### Toolchain Container
- [x] newlib + newlib nano
- [x] arm-compiler-rt for intrinsics
- [x] openocd
- [x] gdb
- [x] ninja
- [x] graphviz (dot)
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
- [x] Support custom common path
- [x] Target to regenerate build.ninja
- [ ] LTO support
- [ ] LTO support for modules
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
    * Currently supported, without the C++ stdlib. I think this is a good compromise.
- [ ] Add a clang format file, maybe
- [ ] TODO: fix github actions tagging (version)
- [ ] TODO: add some real CI?


##### Ord:
 - [ ] Add headers (and public headers?) to files_to_format
 - [x] Make `tlt.sh`.
 - [x] Add `tlt.sh` init support.
    + [x] Make it drop .gitignore files if not present. (target + build.ninja + compile_commands.json)
 - [x] Add a `misc/install.sh` script that does:
    + [x] clones the repo to `${HOME}/.tlt`
    + [x] yells if it's not in `${PATH}`
    + [x] checks that you've installed things right (for now won't try to do these things for you..)
      * [x] /usr/lib/... (newlib-nano and compiler-rt)
      * [x] all the clang tools + all the things the container would give you
      * [x] check bash version!! (yell about homebrew on macOS?)
      * [ ] ninja version?
      * [ ] udev rule on Linux?
 - [x] Add a `tlt` self-update command.
 - [x] Add `tlt` update.
 - [x] Add a version/help screen to `tlt` (the default).
 - [x] Add .env file support to `gen.sh`
    + [x] subtle stuff about the load order?
    + [x] silently replace COMMON_DIR if doesn't exist
 - [x] Make the template repo:
    + [x] .gitignore
    + [ ] GitHub Actions CI! (pending publication)
      * [x] use the container
      * [x] run build
      * [x] run check
    + [x] .clang-format
    + [x] .clang-tidy
    + [x] just flash an LED
    + [x] check in an .env file; not the build.ninja
 - [ ] CI/CD:
    + [ ] Build the container w/new actions
    + [ ] Tag + upload the container to dockerhub and github
    + [ ] Check that all the versions match
    + [ ] Run shellcheck
    + [ ] Extract compiler-rt and newlib-nano and zip em up and upload to GitHub releases (on tag?).
      * [ ] Maybe just do this manually for now...
    + [ ] Running inside the container
      * [ ] Clone the template project
      * [ ] Run these commands and check that they don't fail:
        - build
        - fmt
        - tidy
        - size
        - sections
        - clean
        - scrub
        - powerwash
        - pristine
        - fix
        - update
        - compdb
        - all
        - graph
 - [ ] Add lib support to `gen.sh`
   + [ ] Use PUB_LIB_HEADERS
   + [ ] Add ar rules + use them for libraries
     * actually, `ar` doesn't work since bitcode... may need to ditch whole program LTO and make .a files here :-(
   + [ ] Add a rule to copy over the PUB_LIB_HEADERS + use it
 - [x] Put up the ninja fork
   + [x] Go use it in the container
 - [ ] UART
 - [ ] Get `gen.sh` to _use_ modules
   + [x] recursively regenerate
   + [ ] extract the info (headers, name)
   + [ ] add to header_search_dirs
   + [ ] add to link
 - [ ] Locally, turn RASLib and StellarisWare into tlt libraries and verify that that works.
   + [ ] Potentially make RASLib just depend on local StellarisWare (but this'll break CI in places and just generally be gross).
 - [ ] Make the `rasware-template` repo:
   + [ ] Local stellarisware and RASLib until the PR goes through
   + [ ] same stuff as the other template repo
   + [ ] plus VS Code:
     * [ ] ninja targets
     * [ ] debug configuration (may need a script)
     * [ ] remote environment (for linux)
     * [ ] remote environment (for WSL)
 - [ ] Manually get WSL working.
 - [ ] Fix up the openocd script.
   + [ ] Check it into the repo
 - [ ] Fix up the openocd install script.
   + [ ] Check it into the repo
 - [ ] Test the WSL remote environment VS Code thing
 - [ ] Finally, docs:
   + [ ] Make a docs folder in the repo
   + [ ] Add the mdbook structure
   + [ ] Steal the appropriate sections from the old thing
   + [ ] Update CI to push built docs to `gh-pages`
   + [ ] Fill 'em out:
   + [ ] Structure, tentatively:
     * WSL:
       - install WSL + the aliases and all that old config
       - install openocd
       - install VS Code
       - go to Linux-common
     * Linux:
       - install the udev rule
       - install VS Code
       - go to Linux-common
     * Linux-common:
       - install:
         + git, clang, clangd, clang-format, clang-tidy, llvm-tools, lld, gdb-multiarch, openocd, etc.
       - go to common
     * macOS:
       - install homebrew
       - update bash
       - xcode select or whatever
       - clang, clangd, clang-format, clang-tidy, llvm-tools, lld, gdb-multiarch, openocd, etc.
       - go to common
     * Common:
       - install ninja (the fork!)
       - install newlib-nano + compiler-rt
       - install run-clang-format
       - install tlt
           + Also add to $PATH!
       - done?
     * Linux-docker (if you're daring):
       - udev rule
       - install docker
       - install tlt with `--docker`
       - install VS Code
       - clone the repo + press the button
       - that's it
 - [ ] Later docs:
    + [ ] How to use TLT (all the commands, etc.)
    + [ ] Examples (library example, binary example, using modules example)
    + [ ] Implementation notes
    + [ ] Misc:
      * thank yous + we accept PRs, etc. on the first page
