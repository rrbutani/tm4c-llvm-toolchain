#!/usr/bin/env bash

# Options (arguments):
NATIVE_OR_DOCKER=${1:-docker} # native or docker
TARGET=${2:-proj.out} # .out or .a
COMMON_PATH=${3:-.}
MODULE_STRING=${4:-""} # list of things that end with .a as a string

# There are really three toolchain configurations: native, docker for tools,
# and docker for everything. Native involves no containers, docker for tools
# has ninja running outside the container and everything else running in the
# container and docker for everything has ninja + everything else running in
# the container.
#
# As such, native and docker for everything are identical as far as we're
# concerned (for generating the build.ninja file).

# $1 : variable name; $2 : default value
with_default () { declare $1=${!1-$2}; }

#tests
assert () { echo $1 == $2; }
#has declaration:
foo=yak
with_default foo other
assert "$foo" yak

#has no declaration:
with_default bar nuit
assert "$bar" nuit

# Other options:
DOCKER="${DOCKER-docker}"
CONTAINER_NAME=${CONTAINER_NAME-rrbutani/llvm-toolchain}

###############################################################################

readonly BOLD='\033[0;1m' #(OR USE 31)
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[1;35m'
readonly GREEN='\033[0;32m'
readonly BROWN='\033[0;33m'
readonly RED='\033[1;31m'
readonly NC='\033[0m' # No Color

# shellcheck disable=SC2059
function print
{
    N=0
    n="-e"

    if [[ "$*" == *"-n" ]]; then
        N=1
        n="-ne"
    fi

    if [ "$#" -eq $((1 + N)) ]; then
        >&2 echo $n "$1"
    elif [ "$#" -eq $((2 + N)) ]; then
        >&2 printf "${2}" && >&2 echo $n "$1" && >&2 printf "${NC}"
    else
        >&2 printf "${RED}" && >&2 echo "Received: $* ($# args w/N=$N)" &&
        >&2 printf "${NC}"; return 1
    fi
}

# $1 : exit message; $2 : an anchor for the README; $3 : exit code
error () { print "${1}" ${RED}; print "(https://git.io/fhNW6${3+#}${3:-#usage} has more details and should be able to help)" ${BROWN}; exit ${2:-1}; }


# Check NATIVE_OR_DOCKER:
! { [ "${NATIVE_OR_DOCKER}" == "native" ] || [ "${NATIVE_OR_DOCKER}" == "docker" ]; } &&
    error "Invalid toolchain configuration ($NATIVE_OR_DOCKER); valid options are 'native' and 'docker'."

# If we're using docker, check that it's installed:
# (we run `docker images` here instead of just using hash to check that docker
# permissions are set up right too)
[ "${NATIVE_OR_DOCKER}" == "docker" ] &&
    { "${DOCKER}" images > /dev/null 2>&1 ||
        error "Please make sure docker (${DOCKER}) is installed, configured, and running." 2 "installation"; }

# Check TARGET:
TARGET_TYPE=
if [[ "${TARGET}" =~ .*\.a$ ]]; then
    TARGET_TYPE=lib
elif [[ "${TARGET}" =~ .*\.out$ ]]; then
    TARGET_TYPE=bin
else
    error "Invalid target (${TARGET})."
fi

# Check COMMON_PATH:
declare -a common_files=(common.ninja misc/{gdb-script,tm4c.ld,gen.sh} src/startup.c asm/intrinsics.s)
for f in "${common_files[@]}"; do
    [ ! -f "${COMMON_PATH}/$f" ] &&
        error "Specified common path (${COMMON_PATH}) is missing ${f}."
done

# Check MODULE_STRING:
IFS=' ' read -r -a modules <<< "${MODULE_STRING}"
for mod in "${modules[@]}"; do
    dir="$(dirname "${mod}")"
    lib="$(basename "${mod}")"

    [[ ! "${lib}" =~ .*\.a$ ]] && error "'${mod}' doesn't appear to be a valid module (\`${lib}\` must end with .a)."

    [ ! -d "${dir}" ] && error "Module '${mod}' doesn't seem to exist."
    [ ! -f "${dir}/build.ninja" ] && error "Module '${mod}' doesn't seem to have a build.ninja file. Please run \`gen.sh\` in the module."
    ! grep -q "TARGET = ${lib}" "${dir}/build.ninja" && error "Module '${mod}' doesn't appear to be configured to build '${lib}'."
done

# TODO: Check if we're on WSL


