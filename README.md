# TM4C LLVM Toolchain

[![](https://tokei.rs/b1/github/rrbutani/tm4c-llvm-toolchain)](https://github.com/rrbutani/tm4c-llvm-toolchain)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An opinionated toolchain for TI's [TM4C](http://www.ti.com/tool/EK-TM4C123GXL) (should work on the LM4F too).

The goal of this project is to provide a somewhat minimal setup for the TM4C that uses LLVM tools wherever possible and is easy to install and use. As such, this project takes a strong stance on things like build tools (we use [Ninja](https://ninja-build.org/)) and project layout; it, by design, doesn't expose many configuration options.

A lesser goal of this project is to be somewhat transparent. The pieces of this setup are documented in the hopes that it's possible to understand what's happening underneath, even (and especially) if you don't have much experience with bare metal C.

This is definitely still a work in progress and the toolchain (newlib in particular) contains some pretty unsightly workarounds. Using this in production or for anything important is probably not a great idea. That said, it _does_ seem to work on TM4C's and LM4F's without too much fuss.

If you run into problems or find something that's not quite right feel free to open an issue! PRs are welcome too, especially for documentation.

### What's inside?


### Installation and Usage

### Examples

### Status