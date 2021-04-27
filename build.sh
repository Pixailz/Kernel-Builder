#!/bin/bash
# Bash Color
green='\e[32m'
red='\e[31m'
yellow='\e[33m'
blue='\e[34m'
lgreen='\e[92m'
lyellow='\e[93m'
lblue='\e[94m'
lmagenta='\e[95m'
lcyan='\e[96m'
blink_red='\033[05;31m'
restore='\033[0m'
reset='\e[0m'

# #
# Utils Func

# Pause
function pause() {
	local message="$@"
	[ -z $message ] && message="Press [Enter] to continue.."
	read -p "$message" readEnterkey
}

function ask() {
    	# http://djm.me/ask
    	while true; do

        	if [ "${2:-}" = "Y" ]; then
        		prompt="Y/n"
        		default=Y
        	elif [ "${2:-}" = "N" ]; then
        		prompt="y/N"
            		default=N
        	else
            		prompt="y/n"
            		default=
        	fi

        	# Ask the question
        	question
        	read -p "$1 [$prompt] " REPLY

        	# Default?
        	if [ -z "$REPLY" ]; then
        		REPLY=$default
        	fi

        	# Check if the reply is valid
        	case "$REPLY" in
        		Y*|y*) return 0 ;;
        		N*|n*) return 1 ;;
        	esac
    	done
}

function info() {
        printf "${lcyan}[   INFO   ]${reset} $*${reset}\n"
}

function success() {
        printf "${lgreen}[ SUCCESS  ]${reset} $*${reset}\n"
}

function warning() {
        printf "${lyellow}[ WARNING  ]${reset} $*${reset}\n"
}

function error() {
        printf "${red}[  ERROR   ]${reset} $*${reset}\n"
        exit
}

function check() {
    if [ $2 == true ]; then
        printf "${lgreen}[  CHECK   ]${reset} $1${reset}\n"

    else
        printf "${red}[  CHECK   ]${reset} $1${reset}\n"
    fi
}

function question() {
        printf "${yellow}[ QUESTION ]${reset} "
}

# Detect OS
function check_os() {
	if [ -f /etc/SUSE-brand ]; then
		suse=true
	fi
}
 #
#

function extract() {
    file_path=${1}
    file_name=${file_path##*/}
    file_extension=${file_name: -6}
    out_dir=${2}

    if [ ${file_extension} == tar.xz ]; then
        info "Extracting ${file_name} in ${out_dir}"
        tar -xJf ${file_path} -C ${out_dir} --strip-components=1
        success "${file_name} Successfully extracted\n"

    elif [ ${file_extension} == tar.gz ]; then
        info "Extracting ${file_name} in ${out_dir}"
        tar -xzf ${file_path} -C ${out_dir} --strip-components=1
        success "${file_name} Successfully extracted\n"

    fi
}

function get_toolchain() {
    source ${BUILD_DIR}/toolchains/${1}

    local ARCH_DIR="${BUILD_DIR}/toolchain_archs"
    mkdir -p ${ARCH_DIR}

    if [ ! -z ${TOOLCHAIN_SRC} ]; then
        if [ ! -d ${TOOLCHAIN_ROOT} ]; then
            check "Setting up ${TOOLCHAIN_NAME}" false

            local file_name="${TOOLCHAIN_SRC##*/}"

            if [ -f "${ARCH_DIR}/${file_name}" ]; then
                warning "Removing file from previous run"
                rm -f ${ARCH_DIR}/${file_name}
            fi

            if [ ${TOOLCHAIN_SRC_TYPE} == "wget" ]; then
                info "Downloading ${TOOLCHAIN_NAME}"

                wget ${TOOLCHAIN_SRC} --quiet --show-progress -O ${ARCH_DIR}/${file_name}

                if [ $? -eq 0 ]; then
                    success "Successfully downloaded ${file_name}"

                    if [ ! -d ${TOOLCHAIN_ROOT} ]; then
                        mkdir -p ${TOOLCHAIN_ROOT}
                    fi

                    extract "${ARCH_DIR}/${file_name}" "$TOOLCHAIN_ROOT"

                else
                    error "Download failed"

                fi
            fi
        fi
    else
        error "${TOOLCHAIN_NAME} have error in his config"
    fi
}

function get_default_toolchains() {
    get_toolchain "default_clang"
    get_toolchain "default_gcc32"
    get_toolchain "default_gcc64"
}

function setup_env() {
    # Build directory
    BUILD_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    source ${BUILD_DIR}/new_config

    check_os

    # ADD CHECK IF DEPENDENCIES ALREADY INSTALLED
    #get_dependencies

    get_default_toolchains
}

function main() {
    setup_env
}

main
 #
#
