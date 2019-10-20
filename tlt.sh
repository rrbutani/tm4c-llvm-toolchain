#!/usr/bin/env bash

VERSION=0.3.0

# Arguments
SUBCOMMAND=${1:-info}

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

# Global Vars #

: "${TLT_FILE:=".tlt"}"
TLT_INSTALL_DIR="$(dirname "$(realpath "${0}")")"

# Functions #

# shellcheck disable=SC2059
function print {
    n="-e"

    if [[ "$1" == "-n" ]]; then
        n="-ne"
        shift
    fi

    if [ "$#" -eq 1 ]; then
        >&2 echo $n "$1"
    elif [ "$#" -eq 2 ]; then
        >&2 printf "${2}" && >&2 echo $n "$1" && >&2 printf "${NC}"
    else
        >&2 printf "${RED}" && >&2 echo "Received: $* ($# args)" &&
        >&2 printf "${NC}"; return 1
    fi
}

function help {
    print "Usage: ${0} [subcommand]"
    print "Version: ${VERSION}\n"
    print "A tool to help create and manage tlt projects."
    print "More information here: https://git.io/fhNW6.\n"
    print "Subcommands:" "${GREEN}"

    cmd () { print -n "  ${1}" "${CYAN}"; print -n " -- "; print "${2}" "${BROWN}"; }

    cmd "   init" "🔨 Creates a new project."
    cmd " update" "🔄 Regenerates the build file for the current project."
    cmd "upgrade" "💿 Tries to update your tlt installation."
    cmd "   help" "ℹ️ Displays this help message!"
    cmd "version" "🔢 Shows the version number for the tlt installation."

    exit "${1}"
}

function upgrade {
    local local_sha upstream_sha
    g () { git -C "${TLT_INSTALL_DIR}" "${@}"; }

    g fetch
    local_sha="$(g rev-parse HEAD)"
    upstream_sha="$(g rev-parse HEAD)"

    if [ "${local_sha}" != "${upstream_sha}" ]; then
        print "Update available!" "${BOLD}"
        print "Current version is ${VERSION}.\n"

        print "Attempting to update..." "${BROWN}"
        g pull

        print -n "New version is $("${0}" version)." "${BOLD}"
        print "Success!"
    else
        print -n "Already up to date!" "${CYAN}"
        print " (version: ${VERSION})"
    fi
}

function update {
    if [ ! -f "${TLT_FILE}" ]; then
        print "It doesn't look like this is a tlt project!" "${RED}"
        print "(we couldn't find a \`${TLT_FILE}\` file)\n"
        print "If you're trying to make a new project, try running \`${0} init\`."

        exit 2
    fi

    "${TLT_INSTALL_DIR}/gen.sh"
}

function new {
    local target_dir proj_name type mode modules
    target_dir="$(realpath "${2-.}")"

    print "Making a new tlt project in \`${target_dir}\`.\n" "${CYAN}"
    mkdir -p "${target_dir}"

    read -r -p "First, let's give this project a name: " proj_name

    print "\nNow pick a project type: binary or library?"
    select type in "binary" "library"; do
        case $type in
            "binary") proj_name="${proj_name}.out"
                    break;;
            "library") proj_name="${proj_name}.a"
                    break;;
        esac
    done

    print "\nNext, a project mode (if you're not sure, choose native):"
    select mode in "native" "docker" "hybrid"; do
        case $mode in
            "native" | "docker" | "hybrid") break;;
        esac
    done

    print "\nLast step! If you'd like to use any modules in your project, "
    print "list them here. Otherwise just press enter."
    read -r -p "Modules: " modules

    print "\nGenerating...\n" "${GREEN}"
    (cd "${target_dir}"; \
        "${TLT_INSTALL_DIR}/misc/gen.sh" \
            "${mode}" "${proj_name}" "${modules}" "${TLT_INSTALL_DIR}")

    if [ ! -f "${target_dir}/.gitignore" ]; then
        cat <<-EOF > "${target_dir}/.gitignore"
		# tlt project files #
		build.ninja
		target/
		EOF
    fi

    if [ ! -f ".git" ]; then
        git init -C "${target_dir}"
    fi

    print "\nYou're all set up! 🎉" "${CYAN}"
}

case ${SUBCOMMAND} in
    "new" | "init") new "${@}"
        ;;
    "update" | "build" | "up" ) update
        ;;
    "upgrade" | "self-update") upgrade
        ;;
    "help" | "info" ) help 0
        ;;
    "version")
        print "${VERSION}"
        ;;
    *)  print "Sorry, we don't understand \`${*}\`! Here's the help message:    " "${RED}"
        help 1
        ;;
esac
