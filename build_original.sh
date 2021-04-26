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

 #
# Setup

# Create kernel compilation working directories
function setup_dirs() {
    mkdir -p "$KERNEL_OUT"
    mkdir -p "$MODULES_OUT"
}

# Install dependencies
function get_dependencies() {
    info "Installing dependencies"
    if [ "$suse" = true ]; then
        for i in $SUSE_DEPEND; do
            sudo zypper in -y $i
        done
    else
        sudo apt-get update
        for i in $DEBIAN_DEPEND; do
            sudo apt-get install -y $i
        done
    fi
}

# Verfify file against 256sha; required argument <sha file> <directory>
function verify_sha256 {
	local sha=$1
	local dir=$2
    info "Verifying integrity of downloaded file"
	cd ${dir}
    sha256sum -c ${sha} || {
        error "Rootfs corrupted. Please run this installer again or download the file manually"
	    cd -
        return 1
    }
	cd -
	return 0
}

# Download file via http(s); required arguments: <URL> <download directory>
function get_sha {
    local url=${1}
	local sha_url=${url}.sha256
    local dir=${2}
    local file="${url##*/}"
    local sha_file="${sha_url##*/}"
    info "Getting SHA"
    if [ -f ${dir}/${sha_file} ]; then
            rm -f ${dir}/${sha_file}
    fi
    axel --alternate -o ${dir}/${sha_file} "$sha_url"
	if [ $? -ne 0 ]; then
        if ask "Could not verify file integrity. Continue without verification?" "Y"; then
            return 0
		else
			return 1
		fi
	fi
	verify_sha256 "${sha_file}" "${dir}"
	if [ $? -ne 0 ]; then
        if ask "File verification failed. File may be corrupted. Continue anyway?" "Y"; then
            return 0
		else
			return 1
		fi
	fi
}


# Download file via http(s); required arguments: <URL> <download directory>
function wget_file {
    local url=${1}
    local dir=${2}
    local file="${url##*/}"
    if [ -f ${dir}/${file} ]; then
        if ask "Existing image file found. Delete and download a new one?" "N"; then
            rm -f ${dir}/${file}
        else
            warning "Using existing archive"
            return 0
        fi
    fi
    info "Downloading ${file}"
    axel --alternate -o ${dir}/${file} "$url"
	if [ $? -eq 0 ]; then
		printf "\n"
		success "Download successful"
	else
		printf "\n"
		error "Download failed"
        return 1
	fi
	get_sha "${url}" ${dir}
	if [ $? -eq 0 ]; then
		printf "\n"
		success "Download successful"
        return 0
	else
		printf "\n"
		error "Download failed"
        return 1
	fi
}


# Download toolchain; required arguments: "source URL" "Download type(wget/git)"
function get_toolchain() {
	local url=$1
	local type=$2
    local TMP_DIR="${BUILD_DIR}/toolchain_archs"
	if [ ${type} == "wget" ]; then
	    wget_file ${url} ${TMP_DIR}
		return $?
	else
	    error "Download type ${type} not availabe"
	fi
}

# Download all toolchains
function get_toolchains() {
    local ARCH_DIR="${BUILD_DIR}/toolchain_archs"
    mkdir -p ${ARCH_DIR}
    ## clang
    if [ ! -z "${CLANG_SRC}" ]; then
        printf "\n"
        info "Downloading clang toolchain"
        if [ -z "${CLANG_SRC_TYPE}" ]; then
            CLANG_SRC_TYPE="wget"
        fi
        get_toolchain ${CLANG_SRC} ${CLANG_SRC_TYPE}
        if [ $? -eq 0 ]; then
            if [ -d ${CLANG_ROOT} ]; then
                if ask "Clang directory exists. Overwrite?" "N"; then
                    rm -rf ${CLANG_ROOT}
                fi
            fi
            if [ ! -d ${CLANG_ROOT} ]; then
                local archive="${CLANG_SRC##*/}"
                mkdir -p ${CLANG_ROOT}
                tar -xJf ${ARCH_DIR}/${archive} -C ${CLANG_ROOT} --strip-components=1
            else
                warning "Skipping ${archive}"
            fi
            info "Done"
        fi
    fi
    ## gcc32
    if [ ! -z "${CROSS_COMPILE_ARM32_SRC}" ]; then
        printf "\n"
        info "Downloading 32bit gcc toolchain"
        if [ -z "${CROSS_COMPILE_ARM32_TYPE}" ]; then
                        CROSS_COMPILE_ARM32_TYPE="wget"
        fi
            get_toolchain ${CROSS_COMPILE_ARM32_SRC} ${CROSS_COMPILE_ARM32_TYPE}
            if [ $? -eq 0 ]; then
            if [ -d ${CCD32} ]; then
                if ask "GCC 32bit directory exists. Overwrite?" "N"; then
                    rm -rf ${CCD32}
                fi
            fi
            if [ ! -d ${CCD32} ]; then
                                local archive="${CROSS_COMPILE_ARM32_SRC##*/}"
                    mkdir -p ${CCD32}
                        tar -xJf ${ARCH_DIR}/${archive} -C ${CCD32} --strip-components=1
            else
                warning "Skipping ${archive}"
            fi
                info "Done"
        fi
    fi
    ## gcc64
        if [ ! -z "${CROSS_COMPILE_SRC}" ]; then
        printf "\n"
        info "Downloading 64bit gcc toolchain"
        if [ -z "${CROSS_COMPILE_SRC_TYPE}" ]; then
                        CROSS_COMPILE_SRC_TYPE="wget"
        fi
            get_toolchain ${CROSS_COMPILE_SRC} ${CROSS_COMPILE_SRC_TYPE}
            if [ $? -eq 0 ]; then
            if [ -d ${CCD64} ]; then
                if ask "GCC 64bit directory exists. Overwrite?" "N"; then
                    rm -rf ${CCD64}
                fi
            fi
            if [ ! -d ${CCD64} ]; then
                                local archive="${CROSS_COMPILE_SRC##*/}"
                    mkdir -p ${CCD64}
                        tar -xJf ${ARCH_DIR}/${archive} -C ${CCD64} --strip-components=1
            else
                warning "Skipping ${archive}"
            fi
                info "Done"
        fi
    fi
    pause
}

function setup() {
	setup_dirs
	get_dependencies
	get_toolchains
}
 #
#

function anykernel() {
   	make_aclean
   	make_anykernel_zip
}

function build() {
	make_oclean
	make_sclean
	setup_dirs
	edit_config && make_kernel
}

function main() {
    check_os
	setup
	build
	anykernel
}

main
 #
#
