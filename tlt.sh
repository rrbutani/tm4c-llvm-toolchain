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
    cmd "   help" "ℹ️ Displays this help message!"
    cmd "upgrade" "💿 Tries to update your tlt installation."

    exit "${1}"
}

case ${SUBCOMMAND} in
    "help" | "info" ) help 0
        ;;
    *)  print "Sorry, we don't understand \`${*}\`! Here's the help message:    " "${RED}"
        help 1
        ;;
esac
