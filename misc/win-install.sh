#!/usr/bin/env bash

# ./win-install.sh [OpenOCD Version]
#
# Installs OpenOCD for Windows and a matching shim.
# This has been tested on WSL Ubuntu 18.04 and Windows 10 Build 17134.

if ! grep -q Microsoft /proc/version; then
    echo "This script is meant for Bash on Windows!" && exit 1
fi

DEPENDENCIES=(curl 7z grep wslpath echo printf cut cat chmod)

OPENOCD_URL_BASE="https://sysprogs.com/files/gnutoolchains/arm-eabi/openocd"
OPENOCD_VER="OpenOCD-20180728"
OPENOCD_URL="${OPENOCD_URL_BASE}/${OPENOCD_VER}.7z"

DOWNLOAD_PATH="/tmp/oocd" # Omitting the file ext is intentional

INSTALL_LOC="%userprofile%\\Appdata\\Roaming"

readonly BOLD='\033[0;1m' #(OR USE 31)
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[1;35m'
readonly GREEN='\033[0;32m'
readonly BROWN='\033[0;33m'
readonly RED='\033[1;31m'
readonly NC='\033[0m' # No Color

function print
{
    N=0
    n="-e"

    if [[ "$*" == *"-n" ]]; then
        N=1
        n="-ne"
    fi

    if [ "$#" -eq $((1 + N)) ]; then
        echo $n "$1"
    elif [ "$#" -eq $((2 + N)) ]; then
        printf "${2}" && echo $n "$1" && printf "${NC}"
    else
        printf "${RED}" && echo "Received: $* ($# args w/N=$N)" \
            && printf "${NC}"; return 1
    fi
}

function checkDependencies
{
    dependencies=("${DEPENDENCIES[@]}")
    dependencies+=("$*")

    exitC=0

    for d in "${dependencies[@]}"; do
        if ! hash "${d}" 2>/dev/null; then
            print "Error: ${d} is not installed." "$RED"
            exitC=1
        fi
    done

    return ${exitC}
}

function getOpenOCD
{
    # If we got an OpenOCD Version, let's try that:
    if [ -n "${1}" ]; then
        print "Using provided OpenOCD Version (${1})" "$PURPLE"

        exts=(.7z .zip)
        for ext in "${exts[@]}"; do
            print "Trying '${1}${ext}'" "$PURPLE"

            curl "${OPENOCD_URL_BASE}/${1}${ext}" -o "${DOWNLOAD_PATH}" -s && {
                print "Download successful!" "$CYAN"
                OPENOCD_VER="$nom"
                return
            }
        done

        print "Unable to grab ${1}; falling back to latest version..." "$RED"
    fi

    # Try to grab the latest version:
    readarray versions < \
        <(curl -Ls "http://gnutoolchains.com/arm-eabi/openocd/" \
            | grep "neat_table" -A 50 \
            | grep "<tr>" -A 4 \
            | grep "href" \
            | cut -d= -f2 \
            | cut -d\> -f1 \
            | cut -d\" -f2)

    # If we got versions, try to use them!
    if [ ${#versions[@]} -gt 0 ]; then
        for url in "${versions[@]}"; do
            url=$(echo ${url} | tr -d '\n')
            nom=$(basename "${url}" | rev | cut -d'.' -f2- | rev)

            print "Trying to download $nom from $url..." $PURPLE
            curl -L "${url}" -o "${DOWNLOAD_PATH}" -s -k && {
                print "Download successful!" "$CYAN"
                OPENOCD_VER="$nom"
                return
            }

            print "Download unsuccessful; trying again.." "$PURPLE"
        done
    fi

    # Failing that, fall back to last known good:
    print "Falling back on ${OPENOCD_VER} (last known good version):" "$PURPLE"
    curl -L "${OPENOCD_URL}" -o "${DOWNLOAD_PATH}" -s && {
        print "Download successful!" "$CYAN"
        return
    }

    # Couldn't download; let callee handle the error:
    print "Unable to download OpenOCD." "$RED"
    return 1
}

function installOpenOCD
{
    # Find the place:
    install_path="$(wslpath "$(cmd.exe /C echo ${INSTALL_LOC})" \
        | tr -d '\r' )/OpenOCD"

    # Unarchive to the place:
    7z x "${DOWNLOAD_PATH}" \
        -o"$install_path" \
        -y > /dev/null

    # Verify:
    install_path="${install_path}/${nom}"
    if [ -d "${install_path}" ] && \
            [ -f "${install_path}/bin/openocd.exe" ]; then
        chmod +x "${install_path}/bin/openocd.exe"
        rm -f ${DOWNLOAD_PATH}
    else
        print "openocd.exe not found in '${install_path}/bin/'!" "$RED"
        return 1
    fi

    # Some setup (involving some heavy assumptions):
    mkdir -p ~/.bin
    echo "PATH=${HOME}/.bin:\$PATH" >> ~/.bashrc

    # Install the shim:
    cat <<-FIN > ~/.bin/openocd
	#!/usr/bin/env bash

	# Generated OpenOCD Shim for WSL.
	# More information here: github.com/ut-ras/RASWare.git
	# Generated on $(date '+%B%e, %Y at %I:%M:%S %p') by version $(tail -2 < "${0}" | head -1 | cut -d: -f2 | cut -d' ' -f2).

	OPENOCD_LOC="${install_path}"
	OPENOCD_BIN="\${OPENOCD_LOC}/bin/openocd.exe"

	# This operates under the dangerous assumption that the Windows version of
	# OpenOCD has the same .cfg files in the same directory structure under the
	# same names. This is bad, but the alternative (putting WSL detection logic
	# into the Makefile + tweaking find to run on the Windows install dirs when
	# appropriate) seems _much_ worse.
	function wsl2win
	{
	    # This is naive and untested, much like me.

	    path="\$(realpath "\${1}")"

	    # WSL let's you change the prefix! Ahh!
	    prefix=\$(wslpath C:/ | xargs dirname)

	    # Check if we've very obviously got an untranslatable path:
	    if [[ ! \$path =~ \${prefix}.* ]]; then echo "Can't translate \${path}!" >&2 && exit 1; fi

	    # File names containing '/' are not legal so we do not need to worry:
	    # Note that the prefix is stripped here.
	    IFS="/" read -ra parts <<<"\${path#\$prefix}"

	    # Check that the first part is indeed a Drive Letter:
	    if [ \${#parts[0]} -gt 1 ]; then echo "Invalid Drive Letter! (\${parts[0]})" >&2; exit 1; fi

	    # No adjustments needed - god bless windows and its case insensitive heritage
	    out="\${parts[0]}:"

	    for p in "\${parts[@]:1}"; do
	        out="\${out}\\\\\${p}"
	    done

	    # One last test:
	    if [ ! "\$(wslpath "\${out}" 2>/dev/null)" = "\${path}" ]; then
	        >&2 echo "Failed to convert \${path} (\${out} was marked incorrect by wslpath)" && exit 1
	    fi

	    echo "\${out}"
	}

	function conf_file
	{
	    if [[ \${1} == *"/scripts/board/"* ]]; then
	        FILE_NAME="\$(basename "\${1}")"

	        # If it's where we expect, great:
	        if [ -f "\${OPENOCD_LOC}/share/openocd/scripts/board/\${FILE_NAME}" ]; then
	            echo "\$(wsl2win "\${OPENOCD_LOC}/share/openocd/scripts/board/\${FILE_NAME}")"
	        # If not, look for the file: (untested)
	        elif find "\${OPENOCD_LOC}" -path "\${FILE_NAME}" 2>/dev/null; then
	            export -f wsl2win
	            echo "\$(find "\${OPENOCD_LOC}" -path "\${FILE_NAME}" 2>/dev/null | xargs wsl2win)"
	        # Failing that, just error out:
	        else
	            echo "Failed to find \${1} for OpenOCD!" && exit 1
	        fi

	    else # Bail
	        echo "\$1"
	    fi
	}

	args=( "\$@" )

	while (( "\$#" )); do
	    { { [ "\$1" = "-f" ] || [ "\$1" = "--file" ]; } && args[((++i))]="\$(conf_file "\${args[((++i))]}")" && shift; } || ((i++)) && shift
	done

	# If you've made it this far, here's some fun Bash trivia to keep you busy:

	    # arr[((arr+0))]=\$((arr[((arr++))] + 5))
	    # done <
	    # < <
	    # unset i && ((i++)) && echo \$i

	"\${OPENOCD_BIN}" "\${args[@]}"
FIN

    chmod +x "${HOME}/.bin/openocd"
}

function err
{
    >&2 print "Errors! Check above and please try again." "$RED"
    >&2 print \
"If this problem persists, file an issue at bit.ly/2nziQhj or contact us." "$RED"
    exit $1
}

# Register error handling:
set -e

trap 'err $?' ERR
trap 'print Interrupted. $RED && exit 2' SIGINT SIGQUIT


# And finally, do the things:
{
    checkDependencies "rm"

    print "Grabbing OpenOCD:" "$BOLD"
    getOpenOCD "${1}"

    print "Installing:" "$BOLD"
    installOpenOCD "${0}"

    print "Success!" "$CYAN"
}

##########################
# AUTHOR:  Rahul Butani  #
# DATE:    Oct. 07, 2018 #
# VERSION: 0.1.0         #
##########################
