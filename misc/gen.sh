#!/usr/bin/env bash

VERSION=0.4.2

# Options (arguments):
MODE="${1:-docker}" # native or docker or hybrid
TARGET="${2:-proj.out}" # .out or .a
MODULE_STRING="${3:-""}" # list of things that end with .a as a string
COMMON_PATH="${4:-$(dirname "$0")/..}" # default: assumes this script is in common
TLT_FILE="${5:-".tlt"}" # looks for this file for variables and arguments

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

# More fun path stuff: It turns out subninja doesn't do any kind of path
# remapping and has no "working directory" concept. If I were to subninja a
# build file from some other directory, it wouldn't run in that directory.
# Instead it would run in the parent ninja file's directory. Since we decided
# to use relative paths for everything, this means that the subninja-ed file's
# targets wouldn't work. More here: github.com/ninja-build/ninja/issues/977
#
# We have a few options:
#  - One is to use absolute paths for _everything_ so that subninja'd files
#    work. I don't really like this option because it makes generated ninja
#    files specific to the system they're generated on:
#     * I still haven't decided whether it's best to not commit build.ninja
#       files to repos at all, but right now it's conceivable that users using
#       the same configuration - i.e. docker or native for everyone - could just
#       commit their build files. If we use absolute paths this isn't at all
#       possible. Eventually, we'll probably move to some kind of structured way
#       to record the args passed to gen and to actually invoke gen - perhaps
#       another ninja file - and then we can check that in to repos instead of
#       build.ninja files.
#   Another thing worth noting is that right now, because of the relative path
#   stuff, a generated build.ninja file can be used within a container (docker)
#   and also natively (native and hybrid). This is nice and also means we can
#   have user specific stuff (like mode) reside in some other ninja file that
#   doesn't get checked into version control (config.ninja, perhaps).
#   Using absolute paths also increases the scenarios for which you'd need to
#   rerun gen (moving the directory for example).
# - Another option is to do things the make way and just invoke ninja again on
#   the module's ninja file (`ninja -C <dir of module> -f <build.ninja file>).
#   Downsides to this are that it's a little gross and it isn't really the ninja
#   _way_. For example, the build graph won't show targets in other modules and
#   compdb won't add entries for files in other modules. It's really just a
#   shame since there's a feature (subninja) that does almost exactly what we
#   want. On the other hand, I'm not actually sure subninja and graph/compdb
#   would have worked how I described above so maybe it's a moot point.
# - A third option is to make all paths 'absolute' with respect to some root
#   directory and then to call ninja with -C. This has similar downsides as the
#   first option but manages to retain docker/native compatibility. The big new
#   downside here is that ninja needs to be aliased on the host side for native.
#   Additionally the points about build.ninja files becoming very machine
#   specific still stand.
#
# I'm going to go with the second option. compdb and graph support would be nice
# but I think this is an acceptable tradeoff, though it does mean that modules
# probably aren't the right thing for project structure (i.e. it's probably not
# the best idea to break out part off a project that isn't a 'library' into a
# module for the sake of organization - this was kind of already true though for
# linking/LTO reasons; not sure if/how LTO and bitcode work with archives).

D=()
nnj_dump_vars () { for v in "${D[@]}"; do echo -ne " $\n  ${v}='${!v}'"; done; }
tlt_dump_vars () { for v in "${D[@]}"; do declare -p "${v}"; done; }

# $1 : variable name; $2 : default value
# (note: this sticks things in the global scope! use with caution)
with_default ()
    { D+=(${1}); v="${!1}"; [ -z "$v" ] && v="${2}"; declare -g $1="${v}"; }

# Other options:
with_default DOCKER "docker"
with_default DOCKER_CONTAINER "rrbutani/arm-llvm-toolchain:${VERSION}"
# Be very careful when using these; we don't really check for duplicates.
# a: assembly w/o preprocessor
# A: assembly w/preprocessor
# c: C source file
# C: C++ source file
# % is a stand in for * (glob)
# | is the separator between globs
with_default GLOBS "%.s:a|%.S:A|%.c:c|%.cpp:C|%.cc:C|%.cxx:C|"
with_default FOLDERS "'.' 'src' 'asm'"
with_default INCLUDE_DIRS "'.' 'inc'"
with_default PUB_INCLUDE_DIRS "'inc'"
with_default COMPILER_RT_DIR "/usr/arm-compiler-rt/lib/armv7e-m/fpu"
with_default NEWLIB_DIR "/usr/newlib-nano/arm-none-eabi/lib"
with_default BUILD_FILE "build.ninja"
with_default RELEASE_C_OPT "fast"
with_default RELEASE_LTO_OPT "3"
with_default DEBUG_C_OPT "0"
with_default DEBUG_LTO_OPT "1"
with_default RUST_CRATES ""

###############################################################################

# Load in the tlt file (${TLT_FILE}) if we've got one:
# shellcheck disable=SC1090
if [ -f "${TLT_FILE}" ]; then
	echo -e '\033[0;32m'"Found config file (\`${TLT_FILE}\`), loading..\n"'\033[0m'
	. "${TLT_FILE}"
fi

# We load in the config file here so that values set in it take precedence over
# the defaults _and_ over the environment variables.
#
# Altogether, for variables, the order goes:
#  1) tlt file
#  2) environment variables
#  3) defaults
#
# Because the tlt files are generated, they'll ordinarily have values for all
# the variables (and will thus fully shadow the defaults and env vars).

# Arguments (we currently have 4: mode, target, modules, and common_path) work
# the same way (tlt, then the ones passed in, then defaults), but with one
# exception: tlt files don't record common_path.
#
# This is because they're meant to be checked into source control (and thus not
# record host machine specific details like exactly where `tlt` is cloned on
# a particular machine).

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
declare -A globs_exts # [glob] -> file extension for produced files
declare -a folders
declare -A object_paths # [obj name] -> relative path
declare -A object_functions # [obj name] -> handler function
declare -a include_dirs
declare -A rust_crates # [crate name] -> relative path to Cargo.toml

# Some constants #

readonly BOLD='\033[0;1m' #(OR USE 31)
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[1;35m'
readonly GREEN='\033[0;32m'
readonly BROWN='\033[0;33m'
readonly RED='\033[1;31m'
readonly NC='\033[0m' # No Color

# Functions #

# &1 : things to process; $1 : function to run on each element
function map() { while read -r n; do ${1} "${n}"; done; }

# $1 : name of the array being piped out
function array { for i in "${@}"; do echo "${i}"; done; }

# $1 : name of directory to check
function filter_exists { if [ -d "${1}" ]; then echo "$1"; fi }

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


# $1 : exit message; $2 : an anchor for the README; $3 : exit code
function error {
    print "${1}" "${RED}";
    print "(https://git.io/fhNW6${3+#}${3:-#usage} has more details and should be able to help)" "${BROWN}";
    exit "${2:-1}";
}

# $1 : name of associative array
function print_kvs {
    local _kvs k v longest
    _kvs=$(declare -p  "${1}" 2>/dev/null) || return
    eval "${_kvs/"${1}"/_kvs}"

    longest=0

    for k in "${!_kvs[@]}"; do
        if [ ${#k} -gt $longest ]; then longest=${#k}; fi
    done

    for k in "${!_kvs[@]}"; do
        v="${_kvs["${k}"]}"
        printf "  ${2}%-$((longest))s${NC} -> ${3}%s${NC}\n" "${k}" "${v}"
    done
}

# $@ : strings
function longest_common_prefix {
    local prefix=""
    local idx=0
    local char=''
    declare -a arr=("${@}")

    [ "${#arr[@]}" -eq 0 ] && return 1 # We won't deal with empty arrays

    while true; do
        # Believe it or not, this is safe; if we're out of chars, the thing in
        # the for loop will catch it
        char=${arr[0]:$idx:1}

        for n in "${arr[@]}"; do
            {   # Bail if we're finished with a string:
                [ "${idx}" -ge "${#n}" ] ||
                # Or if a character doesn't match:
                # (Note: we need the above case too because bash will throw
                # errors for `[ h !=  ]`)
                [ "${n:$idx:1}" != "$char" ];
            } && break 2
        done

        prefix=${prefix}${char}
        ((idx++))
    done

    echo -n "$prefix"
}

# $1 : some string
function ninja_escaped_string {
	local out=""

	for i in $(seq 0 $((${#1}-1))); do
		char=${1:$i:1}
		[ "${char}" == ' ' ] && out="${out}$"
		out="${out}${char}"
	done

	echo -n "$out"
}

function help_text {
    for arg in "${@}"; do
        [ "$arg" == "--help" ] && {
            print "Usage: $0 [toolchain mode] [target] [modules] [common dir]" "$BOLD"
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

    # If we're using docker (and we're not already running in docker) or hybrid,
    # check that it's installed (we run `docker images` here instead of just
    # using hash to check that docker permissions are set up right too):
    if { [ "${mode}" == "docker" ] && [ ! -f "/.dockerenv" ]; } || [ "${mode}" == "hybrid" ]; then
      { "${DOCKER}" images > /dev/null 2>&1 ||
        error "Please make sure docker (${DOCKER}) is installed, configured, and running." 2 "installation"; }
    fi

    # Check TARGET:
    if [[ "${TARGET}" =~ .*\.a$ ]]; then
        target_type=lib
        target_name="$(basename "${TARGET}" .a)"
    elif [[ "${TARGET}" =~ .*\.out$ ]]; then
        target_type=bin
        target_name="$(basename "${TARGET}" .out)"
    else
        error "Invalid target (${TARGET}); valid options end with '.a' (lib) or '.out' (bin)"
    fi

    # Check COMMON_PATH:
    declare -a common_files=(common.ninja misc/{gdb-script,lldb-script,detect-board,tm4c.ld,gen.sh} src/startup.c asm/intrinsics.s)
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
        [ ! -f "${dir}/${TLT_FILE}" ] &&
            error "Module '${mod}' doesn't seem to have a \`${TLT_FILE}\` file. Please run \`gen.sh\` in the module."

        print "Regenerating build files for ${lib} (in \`${dir}\`)." "${BROWN}"
        (cd "${dir}" && "$(realpath "${0}")") || {
		  error "Failed to regenerate build files for ${lib}!" "${RED}" 8
		}

        { { grep -q "target_type = lib$" "${dir}/build.ninja" ||
            { hint="  hint: target_type in '${dir}/build.ninja' should be lib" && false; } } &&
          { grep -q "name = ${lib}$" "${dir}/build.ninja" ||
            { hint="  hint: name in '${dir}/build.ninja' should be ${lib}" && false; } }
        } || error "Module '${mod}' doesn't appear to be configured to build '${lib}'.""\n${hint}"


        [ "${modules["${lib}"]+x}" ] &&
            error "Module '${mod}' appears to conflict with the module at '${modules["${lib}"]}'." 2

        modules["${lib}"]="$(realpath "${dir}")/"
    done

    # Process Include Dirs:
    # shellcheck disable=SC2153
    declare -a -g "include_dirs=(${INCLUDE_DIRS})"
    for inc_dir in "${include_dirs[@]}"; do
    	# Warn but don't error out:
        if [ ! -d "${inc_dir}" ]; then
    		print "Warning: include directory \`${inc_dir}\` doesn't exist." "${BROWN}"
        fi
	done

	# Check optimization levels:
	# $1 : thing being checked; $2 : given opt level; $3 : valid opt levels
	function check_opt {
		local valid_opts=""

		for o in "${@:3}"; do
			if [ "${2}" == "${o}" ]; then return 0; fi;

			valid_opts="${valid_opts}'${o}', "
		done

		error "Invalid ${1} optimization level, valid values are ${valid_opts}and ''." 2
	}

    check_opt "Release Mode compiler" "${RELEASE_C_OPT}" 0 1 2 3 fast s z
    check_opt "Release Mode linker LTO" "${RELEASE_LTO_OPT}" 0 1 2 3

    check_opt "Debug Mode compiler" "${DEBUG_C_OPT}" 0 1 2 3 fast s z
    check_opt "Debug Mode linker LTO" "${DEBUG_LTO_OPT}" 0 1 2 3
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

    # Include dirs:
    for ((i = 0; i < "${#include_dirs[@]}"; i++)); do
    	include_dirs[$i]="$(realpath --relative-to="." "${include_dirs[$i]}")/"
    done
}

p () { echo -n "${@}"; }
a_rule () { p "as"; }
A_rule () { p "asp"; }
c_rule () { p "cc"; }
C_rule () { p "cxx"; }
R_rule () { p "cargo"; }

# $1: obj name, $2: build type (release, debug)
a_rule_vars () { :; }
A_rule_vars () { :; }
c_rule_vars () { :; }
C_rule_vars () { :; }
R_rule_vars () {
    echo ""
    echo "    package=$(basename "${1}" ".$(R_ext)")"
    if [[ "${2}" == "release" ]]; then
        echo "    cargo_extra_flags=--release"
        echo "    profile=release"
    else
        echo "    profile=debug"
    fi
}

a_ext () { p "o"; }
A_ext () { p "o"; }
c_ext () { p "bc"; }
C_ext () { p "bc"; }
R_ext () { p "a"; }

function process_rust_crates {
    # Basically the same format as the globs:
    # "name-of-crate:<path>|another-crate:<another/awful\:path>"
    #
    # The restriction is going to be that you can't have pipes (|) in your
    # Cargo.toml file path, which I think is reasonable enough.
    IFS="|" read -ra crates <<< "$RUST_CRATES"

    for c in "${crates[@]}"; do
        crate="$(cut -d: -f1 <<< "${c}")"
        path="$(cut -d: -f2- <<< "${c}")"

        # (TODO: are we okay to call cargo here? is this guaranteed to run in
        # container?)
        # Check that this really is a valid cargo crate with the name we were
        # given:
        cargo pkgid \
                --manifest-path "${path}" \
                "${crate}" \
                --quiet ||
            error "The specified crate ('${crate}' at '${path}') doesn't appear to exist."

        if [ ${rust_crates["${crate}"]+x} ]; then
            error "Multiple crates named '$crate' are specified!"
        fi

        # TODO: print out a list of the rust crates at the end

        rust_crates["$crate"]="${path}"

        object_paths["${crate}.$(R_ext)"]="$(realpath --relative-to=. "${path}")"
        object_functions["${crate}.a"]=R_rule
    done
}

function find_source_files {
    declare -a -g "folders=(${FOLDERS})"
    IFS="|" read -ra globs_specs <<< "$GLOBS"

    for g in "${globs_specs[@]}"; do
        glob=$(cut -d: -f1 <<< "${g}")
        rule_func="$(cut -d: -f2 <<< "${g}")_rule"
        ext_func="$(cut -d: -f2 <<< "${g}")_ext"

       type "${rule_func}" > /dev/null 2>&1 ||
            error "Rule function ${rule_func} not found. Perhaps adjust your globs?"

       type "${ext_func}" > /dev/null 2>&1 ||
            error "Extension function ${ext_func} not found. Perhaps adjust your globs?"

       globs["$(tr -s '%' '*' <<< "${glob}")"]="${rule_func}"
       globs_exts["$(tr -s '%' '*' <<< "${glob}")"]="${ext_func}"
    done

    # Default files (from common dir):
    # shellcheck disable=SC2016
    object_paths["startup.$(c_ext)"]='${common_dir}/src/startup.c'
    object_functions["startup.$(c_ext)"]=c_rule

    # shellcheck disable=SC2016
    object_paths["intrinsics.$(a_ext)"]='${common_dir}/asm/intrinsics.s'
    object_functions["intrinsics.$(a_ext)"]=a_rule

    process_rust_crates

    IFS=$'\n'
    for f in "${folders[@]}"; do
       for g in "${!globs[@]}"; do
            for match in $(compgen -G "${f}/${g}"); do
                obj_name="$(basename "${match}")"
                obj_name="${obj_name%\.*}"
                obj_ext="$(${globs_exts["${g}"]})"

                while [ ${object_paths["${obj_name}.${obj_ext}"]+x} ]; do
                    # While there's a conflict, keep adding to obj_name:
                    obj_name="${obj_name}-dup"
                done

                object_paths["${obj_name}.${obj_ext}"]="$(realpath --relative-to=. "${match}")"
                object_functions["${obj_name}.${obj_ext}"]="${globs["$g"]}"
            done
       done
    done

    declare -A object_paths_for_printing
    local k v

    for obj in "${!object_paths[@]}"; do
        # echo "'$obj' (${object_functions["${obj}"]}) -> '${object_paths["${obj}"]}'"
        k="$(echo -ne "${BROWN}""[${object_functions["${obj}"]}]") $(echo -ne "${GREEN}'${object_paths["${obj}"]}'")"
        object_paths_for_printing["${k}"]="'${obj}'"
    done

    print_kvs object_paths_for_printing "${NC}" "${CYAN}"

    unset IFS
}

# $1 : Environment variable to print
docker_var () { "${DOCKER}" run -t "${DOCKER_CONTAINER}" bash -c "echo \${$1}" | tr -d '\r\n'; }

function prelude {
    local mode_symbol=❓

    case $mode in
        "native") mode_symbol="🖥️ ";;
        "docker" | "hybrid") mode_symbol="🐋 ";;
    esac

    case $mode in
    	"docker" | "hybrid")
            if [ ! -f "/.dockerenv" ]; then # If we're in a docker container, don't:
        		COMPILER_RT_DIR="$(docker_var COMPILER_RT_DIR)/armv7e-m"
        		NEWLIB_DIR="$(docker_var NEWLIB_NANO_DIR)/arm-none-eabi/lib"
            fi
	esac

    cat <<-EOF > "${BUILD_FILE}"
		# Build file for $target_name ($target_type)

		# Careful! This file was autogenerated (on $(date +"%B %d, %Y %I:%M %p") by version
		# $VERSION of \`gen.sh\`). If you need to make changes, consider running \`gen.sh\`
		# again (see below for the arguments it was called with) with different
		# arguments and env vars or running \`ninja regenerate\`. See git.io/fhNW6#usage
		# for help.

		# Additionally, along with this file, a file name \`${TLT_FILE}\` was generated.
		# This file should have the same variables and arguments as below.
		# Another way to modify this project is to make changes to \`${TLT_FILE}\` and
		# then run \`ninja regenerate\` or \`gen.sh\`.

		common_dir = ${common_dir}

		include \$common_dir/common.ninja

		# Arguments passed to gen.sh; used when regenerating this file.
		gen_vars =$(nnj_dump_vars)
		gen_args = $
		  '${MODE}' $
		  '${TARGET}' $
		  '${MODULE_STRING}' $
		  '${COMMON_PATH}'

		target_type = ${target_type}
		name = ${target_name}
		mode = ${mode_symbol}$

		compiler_rt_dir = ${COMPILER_RT_DIR}
		newlib_dir = ${NEWLIB_DIR}

		# Our placeholder file to fool compdb:
		void = \$builddir/\$unused_file

		header_search_dirs =$(
		for dir in "${include_dirs[@]}"; do
			echo -ne " $\n  -I$dir"
		done)
	EOF

    cat <<-EOF > "${TLT_FILE}"
	# Configuration file for $target_name ($target_type).

	# Arguments:
	$(declare -p MODE)
	$(declare -p TARGET)
	$(declare -p MODULE_STRING)

	# Variables:
	$(tlt_dump_vars)
	EOF
}

function docker_mount_flags {
    # $root_dir is mapped to /opt/, in spirit. Literally mounting $root_dir to
    # /opt/ potentially opens sensitive data to the container. The container
    # isn't going to do anything nefarious, but still - this is avoidable so
    # let's avoid it.
    #
    # For each path that we have to mount, we have to strip away $root_dir (
    # rewriting relative to $root_dir does this) and prepend /opt/ (our root
    # dir). Put an absolute path on the left side and we should be good to go.
    local paths=(${common_dir} "." "${!modules[@]}")

    for p in "${paths[@]}"; do
        echo -ne "$\n  -v '$(realpath "$p")':'/opt/$(realpath --relative-to="${root_dir}" "$p")' "
    done

    # Finally, so that all our lovely relative paths still work we need to go
    # change the working directory for the container to actually be the project
    # directory:
    echo -ne "$\n  -w '/opt/$(realpath --relative-to="${root_dir}" ".")'"
}

function docker_vars {
    if [ "${mode}" == "hybrid" ]; then
        cat <<-EOF >> "${BUILD_FILE}"

		docker_prefix = ${DOCKER} run
		docker_mounts = $(docker_mount_flags)
		docker_flags  = -t
		docker_cntnr  = ${DOCKER_CONTAINER}
		EOF
    fi
}

# $1 : build type (i.e. debug, release, etc.)
# These must exist in common.ninja (opt levels)
function body {
    local build_type="${1}"

    local c_opt_level_var="${1^^}_C_OPT"
    local lto_opt_level_var="${1^^}_LTO_OPT"

    local docker_prefix
    local pipe_docker_flags
    local interactive_docker_flags

    # shellcheck disable=SC2016
    if [ "${mode}" == "hybrid" ]; then
        docker_prefix=$'\n    docker_prefix = $docker_prefix --privileged'
        # Gotta use only -i for targets that use pipes
        pipe_docker_flags=$'\n    docker_flags = -i'
        # But both for targets that are interactive:
        interactive_docker_flags=$'\n    docker_flags = -i -t'
    fi

    cat <<-EOF >> "${BUILD_FILE}"

	# Build Type: ${build_type}

	c_opt_${build_type} = ${!c_opt_level_var-0}
	lto_opt_${build_type} = ${!lto_opt_level_var-0}

	$(for obj in "${!object_paths[@]}"; do
		echo "build $(ninja_escaped_string "\$builddir/${build_type}/objs/${obj}"): $(${object_functions["${obj}"]}) $(ninja_escaped_string "${object_paths["${obj}"]}")"
		echo -n "    c_opt_level = \$c_opt_${build_type}"
        echo "$(${object_functions["${obj}"]}_vars "${obj}" "${build_type}")"
        # echo ""
	done)

	build \$builddir/${build_type}/\$name.out: link$(
		for obj in "${!object_paths[@]}"; do
			echo -ne " $\n  $(ninja_escaped_string "\$builddir/${build_type}/objs/${obj}")"
		done
		echo -ne "\n    lto_opt_level = \$lto_opt_${build_type}"
	)

	build \$builddir/${build_type}/\$name.axf: objcopy \$builddir/${build_type}/\$name.out

	build size-${build_type}: size \$builddir/${build_type}/\$name.out${pipe_docker_flags}
	build sections-${build_type}: sections \$builddir/${build_type}/\$name.out
	build build-${build_type}: phony \$builddir/${build_type}/\$name.axf

	build flash-${build_type}: flash \$builddir/${build_type}/\$name.axf${docker_prefix}
	build run-${build_type}: start \$builddir/${build_type}/\$name.axf | flash-${build_type}${docker_prefix}

	build gdb-${build_type}: gdb \$builddir/${build_type}/\$name.out | flash-${build_type}${docker_prefix}${interactive_docker_flags}
	build lldb-${build_type}: lldb \$builddir/${build_type}/\$name.out | flash-${build_type}${docker_prefix}${interactive_docker_flags}
	EOF
}

# $1 : default build type (i.e. debug, release, etc.)
function conclusion {
    local files_to_format

    files_to_format=$(
        for f in "${object_paths[@]}"; do
            { [[ $f =~ .*\.s$ ]] ||
              [[ $f =~ .*\.S$ ]] ||
              [[ $f =~ ^\$\{common_dir\}.* ]]; } ||
                echo -ne " $\n  $(ninja_escaped_string "${f}")"
                # echo -ne " $\n  '${f}'"
        done
    )

    local browse_docker_flags
    local regen_docker_flags

    # shellcheck disable=SC2016
    if [ "${mode}" == "hybrid" ]; then
        browse_docker_flags='    docker_flags = $docker_flags -i -p 8000:8000'
        regen_docker_flags=$(
        	echo "    docker_prefix ="
            echo "    docker_mounts ="
        	echo "    docker_flags ="
        	echo "    docker_cntnr ="
        )
    fi

    local existing_folders
    readarray existing_folders < <(array "${folders[@]}" | map filter_exists)

    local build_type="${1}"

    cat <<-EOF >> "${BUILD_FILE}"

		# And finally:

		build sections: phony sections-${build_type}
		build size: phony size-${build_type}
		build build: phony build-${build_type}
		build flash: phony flash-${build_type}
		build run: phony run-${build_type}
		build gdb: phony gdb-${build_type}
		build lldb: phony lldb-${build_type}

		# Delete everything in the build directory
		build clean: rm \$builddir

		# Remove all build artifacts
		build scrub: scrub

		# Remove gitignore'd files
		build powerwash: powerwash

		# Remove everything not tracked by git
		build pristine: pristine

		build graph.png: graph
		  ninja_graph_target = all

		build graph: phony graph.png

		# TODO: warning about running this in docker for hybrid confs
		build browse: browse
		    ninja_browse_flags = -p 8000 -a 0.0.0.0
		${browse_docker_flags}

		# TODO: Docker or not? Possibly only an issue for 'docker' configs..
		build compile_commands.json: compdb | build.ninja
		build compdb: phony compile_commands.json

		build format: format \$void${files_to_format[@]}
		build fmt: phony format

		build format-check: format_check \$void${files_to_format[@]}
		build fmt-check: phony format-check

		build tidy: tidy \$void${files_to_format[@]} $
		  | compile_commands.json

		build tidy-check: tidy_check \$void${files_to_format[@]} $
		  | compile_commands.json

		build fix: phony tidy fmt
		build check: phony tidy-check format-check

		# A regenerate build statement that runs unconditionally.
		build regenerate: regenerate
		${regen_docker_flags}

		# Some aliases for it:
		build update: phony regenerate
		build gen: phony regenerate
		build regen: phony regenerate

		# And a build statement that rebuilds build.ninja when required.
		build ${BUILD_FILE}: regenerate | \$common_dir/common.ninja$(
			for f in "${existing_folders[@]}"; do
				echo -ne " $\n  $(ninja_escaped_string "${f}")"
			done
		)
		${regen_docker_flags}

		build all: phony build-release build-debug

		default build
	EOF
}

# I know, I know, but shhh
# 🐋() { echo 🐋; }

function fini {
    : # TODO:
    # If docker, give aliases.

    print "target name: \t ${target_name} (${target_type})"
	print "type: \t\t ${mode}"
	print "common dir: \t ${common_dir}"
	print "modules: \t ${!modules[*]}"
	print_kvs modules "${BROWN}" "${CYAN}" || :

	print "$(longest_common_prefix "$(realpath .)/" "${common_dir}" "${!modules[@]}")"
	print "new root dir = $root_dir" "${PURPLE}"

	# print "🐋 ($project_dir)" "${CYAN}"
}

help_text "${@}"
process_args
adjust_paths
find_source_files
prelude
docker_vars
body "debug"
body "release"
conclusion "debug" # TODO: make this configurable
fini

# TODO: Check if we're on WSL
