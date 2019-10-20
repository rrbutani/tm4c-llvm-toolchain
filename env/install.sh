#!/usr/bin/env bash

# This script doesn't need to be versioned with the rest of the repo.
#
# Run like `curl -L https://raw.githubusercontent.com/rrbutani/tm4c-llvm-toolchain/master/env/install.sh | bash`
# or: `curl -L https://raw.githubusercontent.com/rrbutani/tm4c-llvm-toolchain/master/env/install.sh | bash -s --docker`

# All or nothing:
set -e

# Some constants #
readonly BOLD='\033[0;1m' #(OR USE 31)
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[1;35m'
readonly GREEN='\033[0;32m'
readonly BROWN='\033[0;33m'
readonly RED='\033[1;31m'
readonly NC='\033[0m' # No Color

readonly TLT_INSTALL_DIR="${HOME}/.tlt-install"
readonly TLT_REPO_URL="https://github.com/rrbutani/tm4c-llvm-toolchain.git"

# Global Vars #
DOCKER_INSTALL=false

# Functions #

# shellcheck disable=SC2059
function print {
    n="-e"

    if [[ "$1" == "-n" ]]; then
        n="-ne"
        shift
    fi

    if [ "$#" -eq 1 ]; then
        echo $n "$1"
    elif [ "$#" -eq 2 ]; then
        printf "${2}" && >&2 echo $n "$1" && >&2 printf "${NC}"
    else
        >&2 printf "${RED}" && >&2 echo "Received: $* ($# args)" &&
        >&2 printf "${NC}"; return 1
    fi
}

# $1: binary name, $2: suggestion
function check_local_dep {
    hash "${1}" 2>/dev/null ||
        { print 'Missing `'"${1}"'`; please install it and try again.' "$RED" &&
          print "(try ${2})" "$BLUE" &&
          exit 1
        }
}

# Check for dependencies:
check_local_deps() {
    for dep in "${!DEPS[@]}"; do
        check_local_dep "${dep}" "${DEPS["${dep}"]}"
    done
}

# Dependency listings #

# shellcheck disable=SC2016
declare -A REGULAR_DEPS=( \
    [jq]="going to https://stedolan.github.io/jq/download/" \
    [git]='`apt install git` or `brew install git`?' \
    [realpath]='`apt install coreutils` or `brew install coreutils`?' \
    [dirname]='`apt install coreutils` or `brew install coreutils`?' \
    [basename]='`apt install coreutils` or `brew install coreutils`?' \
    [realpath]='`apt install coreutils` or `brew install coreutils`?' \
    [head]='`apt install coreutils` or `brew install coreutils`?' \
    [cut]='`apt install coreutils` or `brew install coreutils`?' \
    [numfmt]='`apt install coreutils` or `brew install coreutils`?' \
    [grep]='`apt install grep` or `brew install grep`?' \
    [openocd]='`apt install openocd` or `brew install openocd`?' \
    [dot]='`apt install graphviz` or `brew install graphviz`?' \
    [gdb-multiarch]='`apt install gdb-multiarch` or `brew install gdb-multiarch`?' \
    [clang]='`apt install clang` or `brew install clang`?' \
    [clangd]='`apt install clangd` or `brew install clangd`?' \
    [clang-tidy]='`apt install clang-tidy` or `brew install clang`?' \
    [run-clang-tidy]='`apt install clang-tidy` or `brew install clang`?' \
    [clang-format]='`apt install clang-format` or `brew install clang-format`?' \
    [ld.lld]='`apt install clang` or `brew install clang`?' \
    [llvm-ar]='`apt install clang` or `brew install clang`?' \
    [llvm-as]='`apt install clang` or `brew install clang`?' \
    [llvm-objcopy]='`apt install clang` or `brew install clang`?' \
    [llvm-objdump]='`apt install clang` or `brew install clang`?' \
    [llvm-ranlib]='`apt install clang` or `brew install clang`?' \
    [llvm-nm]='`apt install clang` or `brew install clang`?' \
    [llvm-size]='`apt install clang` or `brew install clang`?' \
    [llvm-strings]='`apt install clang` or `brew install clang`?' \
    [lldb]='`apt install lldb` or `brew install lldb`?' \
    [run-clang-format]='checking the install instructions' \
    [ninja]="checking the install instructions" \
    [bash]='`apt install bash` or `brew install bash`?' \
)

# shellcheck disable=SC2016
declare -A DOCKER_DEPS=( \
    [jq]="going to https://stedolan.github.io/jq/download/" \
    [git]='`apt install git` or `brew install git`?' \
    [realpath]='`apt install coreutils` or `brew install coreutils`?' \
    [dirname]='`apt install coreutils` or `brew install coreutils`?' \
    [basename]='`apt install coreutils` or `brew install coreutils`?' \
    [realpath]='`apt install coreutils` or `brew install coreutils`?' \
    [head]='`apt install coreutils` or `brew install coreutils`?' \
    [cut]='`apt install coreutils` or `brew install coreutils`?' \
    [docker]="going to https://docs.docker.com/install/linux/docker-ce/ubuntu/ (if you're on Linux -- check the install instructions for WSL)" \
)

function dependencies {
    if [ "$(bash --version | head -1 | cut -d ' ' -f 4 | cut -d '.' -f 1)" -lt 4 ]; then
        print "Please install a newer version of bash (v4+)!" "${RED}"
        print "If you're on macOS, try \`brew install bash\`." "${BOLD}"
        exit 3
    fi

    if [ ${DOCKER_INSTALL} == "true" ]; then
        for dep in "${!DOCKER_DEPS[@]}"; do
            check_local_dep "${dep}" "${DOCKER_DEPS["${dep}"]}"
        done

        # Check the docker group:
        if ! groups $(whoami) | grep -q "docker"; then
            print "Please add yourself to the docker group (try \`sudo usermod -aG docker ${USER}\`)." "${RED}"
        fi
    else
        for dep in "${!REGULAR_DEPS[@]}"; do
            check_local_dep "${dep}" "${REGULAR_DEPS["${dep}"]}"
        done

        # TODO: check the udev rule on linux
    fi
}

function install_tlt {
    if [ ! -d "${TLT_INSTALL_DIR}" ]; then
        print "tlt doesn't seem to be installed; trying to install..." "${PURPLE}"

        git clone "${TLT_REPO_URL}" "${TLT_INSTALL_DIR}"
        print "tlt successfully installed in \`${TLT_INSTALL_DIR}\`" "${CYAN}"
    fi

    if ! hash tlt 2>/dev/null; then
        print "tlt doesn't appear to be in the \$PATH; attempting to add it..." "${PURPLE}"

        print "This will prompt you for your password to run the following command:" "${BOLD}"
        print "\`sudo ln -s ${TLT_INSTALL_DIR}/tlt.sh /usr/local/bin/tlt\`" "${BROWN}"
        sudo ln -s "$(realpath "${TLT_INSTALL_DIR}/tlt.sh")" /usr/local/bin/tlt

        if ! hash tlt; then
            print "/usr/local/bin/ doesn't appear to be in your \$PATH; please add it manually." "${RED}"
            exit 4
        else
            print "Successfully added tlt to your \$PATH." "${CYAN}"
        fi
    fi
}

function check_libs {
    if [ ! -d "/usr/arm-compiler-rt/lib" ]; then
        print "\`arm-compiler-rt\` doesn't seem to be installed; please check the install instructions." "${RED}"
        exit 5
    fi

    if [ ! -d "/usr/newlib-nano/arm-none-eabi" ]; then
        print "\`newlib-nano\` doesn't seem to be installed; please check the install instructions." "${RED}"
        exit 6
    fi
}

# And, go!

if [[ "${1}" == "--docker" ]]; then
    DOCKER_INSTALL="true"
fi

dependencies
install_tlt
check_libs

print "You're good to go! Run \`tlt\` to get started." "${CYAN}"
