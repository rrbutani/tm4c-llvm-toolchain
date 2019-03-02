#!/usr/bin/env bash

VERSION=0.2.1

# Options (arguments):
MODE=${1:-docker} # native or docker or hybrid
TARGET=${2:-proj.out} # .out or .a
MODULE_STRING=${3:-""} # list of things that end with .a as a string
COMMON_PATH=${4:-$(dirname "$0")/..} # default: assumes this script is in common

# All or nothing:
set -e

# There are really three toolchain configurations: native, docker for tools (aka
# hybrid) and docker for everything (aka docker). Native involves no containers,
# docker for tools has ninja running outside the container and everything else
# running in the container and docker for everything has ninja + everything else
# running in the container.
#
# As such, native and docker for everything are mostly identical as far as
# generating build.ninja files is concerned. We will, however, want to do a
# couple of things like emit helpful aliases for ninja and clangd (aliases that
# run in the container).
#
# The hybrid approach increasingly seems to be a bad approach. Apart from making
# everything appreciably slower, it causes issues with paths; some commands -
# especially ninja commands - end up needing to run within the container for
# paths to be correct and some outside of the container.
#
# Additionally, picking mount paths is a headache - with the just docker
# approach we could fix on a top level path that everything must be in or
# generate the alias when this script is run since at that point we know how
# high up we need to go. Since this varies per project perhaps we should spit
# out an env file..
#
# Another fun thing is that whenever ninja runs from the container and then
# locally, it dumps it's dep file (perhaps because I'm running a different
# version of ninja outside the container). This isn't a huge deal but it's
# definitely annoying.
#
# I think the hybrid approach is going to be 'best-effort': known not to work
# for some of the bells and whistles (compdb, graph, dep file dumping) but still
# available. We should flash a warning when hybrid is chosen in this script.

# About WSL support: We're not going to be able to (realistically) support using
# OpenOCD from within a container on Windows (we'd need to either modify the
# docker-machine VM to have access to the TM4C or we'd need to give the
# container a way to run windows executables - the way we get OpenOCD to work in
# WSL is by making a shim that calls the Windows OpenOCD executable; exposing
# this to the docker-machine VM would require breaking out of a container and
# then a VM and then _into_ WSL. If we can do the first two things we're already
# home since we can just run windows executables then. The easiest way to get
# this to work would be to have an OpenOCD server up and running on the Windows
# side and then to point the container to that server. However, thanks to the VM
# - which we can't avoid since most users won't have Windows 10 Pro/Enterprise -
# this isn't trivial either. So, I think it's best we just accept that WSL +
# containers + device support is a bad idea.).
#
# We can do WSL ('native') + OpenOCD (with the shim). We can have this script
# set up the shim and yell if WSL folks try to run this script with the docker
# option (we'll allow it but warn that it's unsupported and won't let users
# flash their devices).
#
# This is basically _why_ the hybrid option exists; running ninja outside the
# container lets us choose to, for example, run the OpenOCD shim while running
# all the other tools inside th container. However, as established above, the
# hybrid option has issues.
#
# We have a few options:
#  - Push for the native option on WSL. This will require creating docs or
#    scripts for installing the toolchain on WSL, something I desperately don't
#    want to create and absolutely don't want to maintain.
#  - Deal with the ugliness of the hybrid approach and push that for WSL users.
#    Doable but will add some gross logic to this script.
#  - Use the full docker approach for WSL users but also provide them with the
#    OpenOCD shim + an alias and a warning that `ninja flash` and friends won't
#    actually work. Debugging would require additional configuration.
#  - Keep the hybrid target as is (deprecated, pretty much) and relegate WSL to
#    second class support.
#
# I think I'm going to go with the 2nd approach. Unless clangd proves to be very
# fickle, it should be okay. But if anything goes wrong, I'll go with the third
# approach.
#
# I'm not going to compromise the experience on Linux/macOS for WSL support and
# it's worth noting that things like compdb aren't going to work right on WSL
# anyhow - at least not without a path translation patch or having users run
# their editors in WSL.
#
# It's also worth noting the 3rd option will actually perform _better_ since it
# won't spin up new containers per command. It'll also be easier... I guess
# we're going to do both! The 3rd option can be docker only (a small lie) and
# hybrid and native can be their usual selves.
#
# The downside is this script get more complicated, this project gets harder to
# document, and users will have to read through more stuff to understand what's
# going on.


D=()
dump_defaults () { for v in "${D[@]}"; do echo -ne "$\n    ${v}='${!v}' "; done; }

# $1 : variable name; $2 : default value
# (note: this sticks things in the global scope! use with caution)
with_default ()
    { D+=(${1}); v="${!1}"; [ -z "$v" ] && v="${2}"; declare -g $1="${v}"; }

# Other options:
with_default DOCKER "docker"
with_default CONTAINER_NAME "rrbutani/llvm-toolchain:0.2.1"
# Be very careful when using these; we don't really check for duplicates.
# a: assembly w/o preprocessor
# A: assembly w/preprocessor
# c: C source file
# C: C++ source file
# / is a stand in for * (glob)
# | is the separator between globs
with_default GLOBS "/.s:a|/.S:A|/.c:c|/.cpp:C|/.cc:C|/.cxx:C|"
with_default FOLDERS "'.' 'src/' 'asm/'"
with_default BUILD_FILE "build.ninja"

###############################################################################

# Global variables #
target_type=
target_name=
mode=
declare -A modules # [name] -> path
project_dir=
common_dir=
root_dir=
declare -A globs # [glob] -> language handler function
declare -a folders
declare -A objects # [obj name] -> relative path

# Some constants #

readonly BOLD='\033[0;1m' #(OR USE 31)
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[1;35m'
readonly GREEN='\033[0;32m'
readonly BROWN='\033[0;33m'
readonly RED='\033[1;31m'
readonly NC='\033[0m' # No Color

# Functions #

# shellcheck disable=SC2059
function print {
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
function error {
    print "${1}" "${RED}";
    print "(https://git.io/fhNW6${3+#}${3:-#usage} has more details and should be able to help)" "${BROWN}";
    exit "${2:-1}";
}

# $@ : strings
function longest_common_prefix {
    local prefix=""
    local idx=0
    local char=''
    declare -a arr=($@)

    [ "${#arr[@]}" -eq 0 ] && return 1 # We won't deal with empty arrays

    while true; do
        # Believe it or not, this is safe; if we're out of chars, the thing in
        # the for loop will catch it
        char=${arr[0]:$idx:1}

        for n in "${arr[@]}"; do
            {
                 # Bail if we're finished with a string:
                [ "${idx}" -ge "${#n}" ] ||
                # Or if a character doesn't match:
                # (Note: we need the above case too because bash will throw
                # errors for `[ h !=  ]`)
                [ ${n:$idx:1} != $char ];
            } && break 2
        done

        prefix=${prefix}${char}
        ((idx++))
    done

    echo -n "$prefix"
}

function help_text {
    for arg in "${@}"; do
        [ "$arg" == "--help" ] && {
            print "Usage: $0 [toolchain mode] [target] [modules] [common dir]" $BOLD
            error "" 1 "usage"
        }
    done

    return 0
}

function process_args {
    # Check MODE:
    ! { [ "${MODE,,}" == "native" ] ||
        [ "${MODE,,}" == "docker" ] ||
        [ "${MODE,,}" == "hybrid" ];
    } && error "Invalid toolchain mode ($MODE); valid options are 'native', 'docker', and 'hybrid'."

    mode=${MODE,,}

    # If we're using docker or hybrid, check that it's installed:
    # (we run `docker images` here instead of just using hash to check that
    # docker permissions are set up right too)
    { [ "${mode}" == "docker" ] || [ "${mode}" == "hybrid" ]; } &&
      { "${DOCKER}" images > /dev/null 2>&1 ||
        error "Please make sure docker (${DOCKER}) is installed, configured, and running." 2 "installation"; }

    # Check TARGET:
    if [[ "${TARGET}" =~ .*\.a$ ]]; then
        target_type=lib
        target_name="$(basename "${TARGET}" .a)"
    elif [[ "${TARGET}" =~ .*\.out$ ]]; then
        target_type=bin
        target_name="$(basename "${TARGET}" .out)"
    else
        error "Invalid target (${TARGET})."
    fi

    # Check COMMON_PATH:
    declare -a common_files=(common.ninja misc/{gdb-script,tm4c.ld,gen.sh} src/startup.c asm/intrinsics.s)
    for f in "${common_files[@]}"; do
        [ ! -f "${COMMON_PATH}/$f" ] &&
            error "Specified common path (${COMMON_PATH}) is missing ${f}."
    done

    common_dir="$(realpath "${COMMON_PATH}")/"

    # Check MODULE_STRING:
    local module_paths
    IFS=' ' read -r -a module_paths <<< "${MODULE_STRING}"
    for mod in "${module_paths[@]}"; do
        dir="$(dirname "${mod}")"
        lib="$(basename "${mod}")"

        [[ ! "${lib}" =~ .*\.a$ ]] &&
            error "'${mod}' doesn't appear to be a valid module (\`${lib}\` must end with .a)."

        lib="$(basename "${lib}" .a)"

        [ ! -d "${dir}" ] &&
            error "Module '${mod}' doesn't seem to exist."
        [ ! -f "${dir}/build.ninja" ] &&
            error "Module '${mod}' doesn't seem to have a build.ninja file. Please run \`gen.sh\` in the module."

        { { grep -q "target_type = lib$" "${dir}/build.ninja" ||
            { hint="  hint: target_type in '${dir}/build.ninja' should be lib" && false; } } &&
          { grep -q "name = ${lib}$" "${dir}/build.ninja" ||
            { hint="  hint: name in '${dir}/build.ninja' should be ${lib}" && false; } }
        } || error "Module '${mod}' doesn't appear to be configured to build '${lib}'.""\n${hint}"


        [ ${modules["${lib}"]+x} ] &&
            error "Module '${mod}' appears to conflict with the module at '${modules["${lib}"]}'." 2

        modules["${lib}"]="$(realpath "${dir}")/"
    done
}

# Find the new root path and then rewrite all our paths to be relative to it.
function adjust_paths {
    # Some things to note here:
    #  - We've been careful about putting / at the end of paths so that the
    #    common prefix of the paths will include / (if there is one at the end
    #    of the common prefix). This is so that when we call dirname on the path
    #    (to handle cases like `longest_common_prefix /tmp/foo /tmp/friends` =>
    #    /tmp/f), we can recognize that the last bit of the path is actually a
    #    directory and not just common characters in folder names that we need
    #    to strip (f in the above example).
    #  - When given a path like /tmp/foo/, dirname will return /tmp. In other
    #    words, it'll find the containing directory _even_ if it's given a
    #    directory to being with. This is fine - it just means that in order to
    #    handle the case where longest_common_prefix gives us back a directory
    #    (i.e. /tmp/shared/), we need to get dirname to stand down. We do this
    #    by adding an underscore to longest_common_prefix's output (as shown
    #    below). For directories (i.e. /tmp/shared/) this is now stripped away
    #    instead of the last directory; for common characters the underscore is
    #    stripped away with the common characters (i.e. `dirname /tmp/f_` =>
    #    /tmp).
    root_dir=$(dirname \
      "$(longest_common_prefix "$(realpath .)/" "${common_dir}" "${modules[@]}")_"
    )

    project_dir="$(realpath --relative-to="${root_dir}" ".")"
    common_dir="$(realpath --relative-to="." "$common_dir")"

    for mod in "${!modules[@]}"; do
        modules["${mod}"]="$(realpath --relative-to="." "${modules["${mod}"]}")"
    done
}

# function find_source_files {
#     local 
#     globs+=('*.c')
# }

function prelude {
    cat <<-EOF > "${BUILD_FILE}"
		# Build file for $target_name ($target_type)

		# Careful! This file was autogenerated (on $(date +"%B %d, %Y %I:%M %p") by version $VERSION of \`gen.sh\`).
		# If you need to make changes, consider running \`gen.sh\` again (see below for
		# the arguments it was called with) with different arguments/env vars or running
		# \`ninja regenerate\`. See https://git.io/fhNW6#usage for help.

		common_dir = ${common_dir}

		include \$common_dir/common.ninja

		# Arguments passed to gen.sh; used when regenerating this file.
		gen_vars = $(dump_defaults)
		gen_args = $
		    '${MODE}' $
		    '${TARGET}' $
		    '${MODULE_STRING}' $
		    '${COMMON_PATH}'

		target_type = ${target_type}
		name = ${target_name}

		build build.ninja: regenerate
		build regenerate: regenerate

	EOF
}

help_text "${@}"
process_args
adjust_paths
prelude

print "target name: \t ${target_name} (${target_type})"
print "type: \t\t ${mode}"
print "common dir: \t ${common_dir}"
print "modules: \t ${!modules[*]}"
for p in "${!modules[@]}"; do
    echo "${p} -> ${modules[$p]}"
done


# I know, I know, but shhh
🐋() { echo 🐋; }

print "$(longest_common_prefix "$(realpath .)/" "${common_dir}" "${!modules[@]}")"
print "new root dir = $root_dir" $PURPLE



print 🐋 $CYAN

# TODO: Check if we're on WSL
