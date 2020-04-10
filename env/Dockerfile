# A working LLVM toolchain for ARM embedded devices.
#
# This is currently tailored for Cortex M4F devices (specifically TI's TM4C) but
# it should be usable for any ARM platform supported by clang and compiler-rt
# with some minor tweaks.
#
# If this is something you're trying to do, here are some hints:
#  - change CC_FOR_TARGET for newlib to match the CPU, FPU, and target you're
#    building for
#  - change the LIBRARY_PATH to point to the right library from compiler-rt
#
# Also note that newlib is only built for the hard float ABI; linking soft float
# compiled programs against it will result in errors (hopefully at link time).
# Eventually this container might do the right thing and provide a multilib
# newlib setup but for now we're just going to stick with `float-abi=hard`.
#
# I feel compelled to note that this is *almost entirely untested*. This seems
# to work on TM4Cs but it's entirely possible there are parts of the standard
# library or intrinsics in compiler-rt that just won't work. This container
# provides a modified version of newlib (see below for the tweaks that are made
# so that newlib can compile with clang) which could cause all kinds of issues -
# though I was fairly cautious in making changes to newlib, I'm not a newlib
# developer so please be careful.
#
# If you run into issues or have suggestions I'd love to hear them! This file
# and some other handy build system things (more specifically for the TM4C) live
# in [this repo](github.com/rrbutani/tm4c-llvm-toolchain.git).
#
# Good luck!
#
# With thanks to:
#  - ReservedField's [arm-compiler-rt repo](git.io/fhbX4)
#  - Maintainers of the newlib-arm-none-eabi packages in the Ubuntu PPAs and in
#    the AUR (the newlib configure flags are essentially borrowed from them)
#  - charlie-ht from [this thread](https://git.io/fhNfB) for providing a patch
#    for ninja's compdb tool that makes it actually emit rules
#
# Modified: Apr 10th, 2020


ARG BASE=ubuntu:18.04
ARG VERSION=0.3.1
ARG LLVM_VER=10
ARG INSTALL_DIR=/usr
ARG NEWLIB_TAG=newlib-3.1.0
ARG NINJA_TAG=a7e3eef91cf63d62deb28eecaaa227fc61d9044d
ARG RUN_CLANG_FMT_SHA=d849ff8507f62713d1433bad5db015f7c68b2891
ARG RUST_VER=1.42.0

# Compiler-RT and friends
FROM $BASE as libs

RUN : \
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get upgrade -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        curl gnupg \
        git make \
        python \
        # binutils-arm-none-eabi \
    -qq 2>/dev/null

ARG LLVM_VER
RUN : \
 && curl https://apt.llvm.org/llvm-snapshot.gpg.key \
    | apt-key add - \
 && . /etc/lsb-release \
 && echo \
        "deb http://apt.llvm.org/${DISTRIB_CODENAME:-bionic}/ llvm-toolchain-${DISTRIB_CODENAME:-bionic}-${LLVM_VER} main" \
    >> /etc/apt/sources.list.d/llvm.list \
 && echo \
        "deb-src http://apt.llvm.org/${DISTRIB_CODENAME:-bionic}/ llvm-toolchain-${DISTRIB_CODENAME:-bionic}-${LLVM_VER} main" \
    >> /etc/apt/sources.list.d/llvm.list

RUN : \
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        clang-${LLVM_VER} \
    -qq 2>/dev/null

WORKDIR /opt

# --enable-newlib-reent-small :: newlib-nano
#
# newlib's build system doesn't reliably pass CFLAGS_FOR_TARGET down to modules
# which is why we're sticking the flags in CC_FOR_TARGET
# -DHAVE_XCOFF suppresses .stabs in libc-symbols.h (libc/sys/linux)
# the first patch swaps .GLOBAL (which gas accepts) for .global
# the second suppresses .stabs in warning.h (libgloss/libnosys)
# the third removes `__attribute__((naked))` so a function can be invoked
#   - this is a weird gcc v. clang thing; more here: bit.ly/2BLCD78
# the fourth changes the `ldrb.w` instruction in strlen-thumb2-Os.S to `ldrb`
#   - (libc/machine/arm)
#   - `ldrb.w` seems to only exist for specific cortex m3 revisions (r1p1)
#   - clang flat out refuses to assemble the `ldrb.w  r2, [r3], #1` in the file
#     not because the instruction isn't known but because of the post-increment
#     (gives "error: too many operands for instruction")
#   - it, however, happily compiles `ldrb    r2, [r3], #1`
#   - since this instruction is only used in the Os impl of strlen, we didn't
#     have this problem earlier
#
# AS_FOR_TARGET and COMPILER_AS_FOR_TARGET don't seem to actually be needed:
#        AS_FOR_TARGET="arm-none-eabi-as" \
#        COMPILER_AS_FOR_TARGET="arm-none-eabi-as" \
# This is why binutils-arm-none-eabi is commented out above (just LLVM tools!)
ARG NEWLIB_TAG
ARG INSTALL_DIR
RUN : \
 && git clone git://sourceware.org/git/newlib-cygwin.git \
 && cd newlib-cygwin \
    && git checkout ${NEWLIB_TAG} \
    && sed -i 's/\.GLOBAL/.global/g' libgloss/arm/linux-syscalls0.S \
    && sed -i '29,31d' libgloss/libnosys/warning.h \
        && sed -i '/\!ELF/a #  define link_warning(symbol, msg)' libgloss/libnosys/warning.h \
    && sed -i '32d' libgloss/arm/linux-crt0.c \
    && sed -i 's/ldrb.w/ldrb/g' newlib/libc/machine/arm/strlen-thumb2-Os.S \
 && cd .. \
 && mkdir newlib-build \
 && cd newlib-build \
    && CC="clang-${LLVM_VER}" \
       CC_FOR_TARGET="clang-${LLVM_VER} \
        --target=thumbv7em-unknown-none-eabi \
        -mthumb \
        -mcpu=cortex-m4 \
        -mfpu=fpv4-sp-d16 \
        -mfloat-abi=hard \
        -g \
        -ffreestanding \
        -ffunction-sections \
        -fdata-sections \
        -DHAVE_XCOFF" \
       AR_FOR_TARGET="llvm-ar-${LLVM_VER}" \
       RANLIB_FOR_TARGET="llvm-ranlib-${LLVM_VER}" \
       CFLAGS_FOR_TARGET="--target=thumbv7em-unknown-none-eabi -g -ffreestanding -ffunction-sections -fdata-sections" \
        ../newlib-cygwin/configure \
            --target=arm-none-eabi \
            --prefix="${INSTALL_DIR}/newlib" \
            --disable-newlib-supplied-syscalls \
            --disable-nls \
            --enable-newlib-io-long-long \
            --enable-newlib-register-fini \
            --with-cpu=armv7e-m \
    && make all -j $((2 * $(nproc))) \
    && make install \
 && cd .. \
 && mkdir nano-build \
 && cd nano-build \
    && CC="clang-${LLVM_VER}" \
       CC_FOR_TARGET="clang-${LLVM_VER} \
        --target=thumbv7em-unknown-none-eabi \
        -mthumb \
        -mcpu=cortex-m4 \
        -mfpu=fpv4-sp-d16 \
        -mfloat-abi=hard \
        -g \
        -Os \
        -ffreestanding \
        -ffunction-sections \
        -fdata-sections \
        -DHAVE_XCOFF" \
       AR_FOR_TARGET="llvm-ar-${LLVM_VER}" \
       RANLIB_FOR_TARGET="llvm-ranlib-${LLVM_VER}" \
       CFLAGS_FOR_TARGET="--target=thumbv7em-unknown-none-eabi -g -Os -ffreestanding -ffunction-sections -fdata-sections" \
        ../newlib-cygwin/configure \
            --target=arm-none-eabi \
            --prefix="${INSTALL_DIR}/newlib-nano" \
            --disable-newlib-supplied-syscalls \
            --disable-nls \
            --enable-newlib-reent-small \
            --disable-newlib-fvwrite-in-streamio \
            --disable-newlib-fseek-optimization \
            --disable-newlib-wide-orient \
            --enable-newlib-nano-malloc \
            --disable-newlib-unbuf-stream-opt \
            --enable-lite-exit \
            --enable-newlib-global-atexit \
            --enable-newlib-nano-formatted-io \
            --with-cpu=armv7e-m \
    && make all -j $((2 * $(nproc))) \
    && make install \
 && cd ..

RUN : \
 && git clone https://github.com/ReservedField/arm-compiler-rt \
        --recursive \
 && cd arm-compiler-rt \
 && CC=clang-${LLVM_VER} make -j $(nproc) AR=llvm-ar-${LLVM_VER} \
 && cd ..

ARG NINJA_TAG
RUN : \
 && git clone https://github.com/rrbutani/ninja.git \
 && cd ninja \
 && git checkout ${NINJA_TAG} \
 && CXX=clang++-${LLVM_VER} ./configure.py --bootstrap


FROM $BASE

ARG BASE
ARG VERSION
ARG LLVM_VER
ARG INSTALL_DIR
ARG NEWLIB_TAG
ARG RUN_CLANG_FMT_SHA
ARG RUST_VER

LABEL version=${VERSION}
LABEL props.base-image=${BASE}
LABEL props.llvm-version=${LLVM_VER}
LABEL props.newlib-install-dir=${INSTALL_DIR}
LABEL props.newlib-version=${NEWLIB_TAG}
LABEL props.ninja-version=${NINJA_TAG}
LABEL props.rust-version=${RUST_VER}

ENV VERSION=${VERSION}
ENV NEWLIB_DIR="${INSTALL_DIR}/newlib"
ENV NEWLIB_NANO_DIR="${INSTALL_DIR}/newlib-nano"

COPY --from=libs /opt/arm-compiler-rt/lib /usr/arm-compiler-rt/lib
COPY --from=libs "${NEWLIB_DIR}" "${NEWLIB_DIR}"
COPY --from=libs "${NEWLIB_NANO_DIR}" "${NEWLIB_NANO_DIR}"
COPY --from=libs /opt/ninja/ninja /usr/bin/ninja
COPY --from=libs /opt/ninja/misc/bash-completion /usr/share/bash-completion/completions/ninja

RUN : \
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get upgrade -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        curl gnupg \
        gdb-multiarch openocd \
        graphviz \
        lm4flash \
        git \
        jq \
    -qq 2>/dev/null \
 && apt-get clean -y \
        -qq 2>/dev/null \
 && apt-get autoremove -y \
        -qq 2>/dev/null \
 && rm -rf \
        /var/tmp/* \
        /var/lib/apt/lists/*

RUN : \
 && curl https://apt.llvm.org/llvm-snapshot.gpg.key \
    | apt-key add - \
 && . /etc/lsb-release \
 && echo \
        "deb http://apt.llvm.org/${DISTRIB_CODENAME:-bionic}/ llvm-toolchain-${DISTRIB_CODENAME:-bionic}-${LLVM_VER} main" \
    >> /etc/apt/sources.list.d/llvm.list \
 && echo \
        "deb-src http://apt.llvm.org/${DISTRIB_CODENAME:-bionic}/ llvm-toolchain-${DISTRIB_CODENAME:-bionic}-${LLVM_VER} main" \
    >> /etc/apt/sources.list.d/llvm.list

RUN : \
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        clang-${LLVM_VER} \
        clang-tools-${LLVM_VER} clang-tidy-${LLVM_VER} clang-format-${LLVM_VER} \
        clangd-${LLVM_VER} \
        lld-${LLVM_VER} \
        libc++-${LLVM_VER}-dev libc++abi-${LLVM_VER}-dev \
        python3-lldb-${LLVM_VER} \
        lldb-${LLVM_VER} \
        # clang-${LLVM_VER}-doc \
     -qq 2>/dev/null \
# && : "The lldb-9 package has some weird conflicts; this is a workaround:" \
#    && mkdir /tmp/lldb \
#    && cd /tmp/lldb \
#    && apt-get download lldb-${LLVM_VER} -y \
#       -qq 2>/dev/null \
#    && ar x lldb*.deb \
#        && : "This'll handle control.tar.{xz,gz} inputs, but it'll always make an .xz." \
#        && tar xf control.tar.* \
#        && sed -i '/^\(Breaks\|Replaces\):/d' control \
#        && tar c postinst md5sums control | xz -c > control.tar.xz \
#        && ar rcs lldb-modified.deb debian-binary control.tar.xz data.tar.* \
#    && : dpkg --ignore-depends=llvm-9-tools \
#            --install lldb*.deb \
#    && dpkg --install lldb-modified.deb \
#    && cd - \
#    && rm -rf /tmp/lldb \
 && apt-get clean -y \
        -qq 2>/dev/null \
 && apt-get autoremove -y \
        -qq 2>/dev/null \
 && rm -rf \
        /var/tmp/* \
        /var/lib/apt/lists/*

ENV C_INCLUDE_PATH="$C_INCLUDE_PATH:${NEWLIB_NANO_DIR}/arm-none-eabi/include"
ENV LIBRARY_PATH="$LIBRARY_PATH:/usr/arm-compiler-rt/lib/armv7e-m/:${NEWLIB_NANO_DIR}/arm-none-eabi/lib"
ENV COMPILER_RT_DIR=/usr/arm-compiler-rt/lib

RUN : \
 && curl -sL git.io/.gdbinit > ${HOME}/.gdbinit \
 && curl -sL https://raw.githubusercontent.com/rrbutani/run-clang-format/${RUN_CLANG_FMT_SHA}/run-clang-format.py \
    > /usr/bin/run-clang-format \
 && chmod +x /usr/bin/run-clang-format \
 && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- \
        --verbose -y \
        --default-toolchain ${RUST_VER} \
        --profile minimal \
        --target thumbv7em-unknown-none-eabi thumbv7em-unknown-none-eabi

RUN : \
 && alt () { update-alternatives --install /usr/bin/${1} ${1} $(which ${1}-${LLVM_VER}) 1; } \
 && alt clang \
 && alt clang++ \
 && alt clangd \
 && alt clang-tidy \
 && alt run-clang-tidy \
 && alt clang-apply-replacements \
 && alt clang-format \
 && alt ld.lld \
 && alt llvm-ar \
 && alt llvm-as \
 && alt llvm-objcopy \
 && alt llvm-objdump \
 && alt llvm-ranlib \
 && alt llvm-nm \
 && alt llvm-size \
 && alt llvm-strings \
 && alt lldb

WORKDIR /opt/
