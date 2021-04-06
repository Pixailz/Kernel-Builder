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

# NetHunter Stage 1 Kernel Build Script
#
# This script if heavily based on work by holyangle
# https://gitlab.com/HolyAngel/op7
##############################################

##############################################
# Utils Func
## Pause
function pause() {
	local message="$@"
	[ -z $message ] && message="Press [Enter] to continue.."
	read -p "$message" readEnterkey
}

## ASK
function ask() {
	# https://gist.github.com/davejamesmiller/1965569
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
		printf "${lmagenta}[  ERROR   ]${reset} $*${reset}\n"
}

function question() {
		printf "${yellow}[ QUESTION ]${reset} "
}

##############################################
# Compile Kernel
## Clean "out" folders
function make_oclean() {
	info "Cleaning up kernel-out & modules-out directories"
	## Let's make sure we dont't delete the kernel source if we compile in the source tree
	if [ "$KDIR" == "$KERNEL_OUT" ]; then
		# Clean the source tree as well if we use it to build the kernel, i.e. we have no OUT directory
		make -C $KDIR clean && make -C $KDIR mrproper
		rm -f $KDIR/source
	else
		rm -rf "$KERNEL_OUT"
	fi
	rm -rf "$MODULES_OUT"
	success "Out directories removed!"
}

## Clean source tree
function make_sclean() {
	local confdir=${KDIR}/arch/$ARCH/configs
	info "Cleaning source directory"
	if [ -f ${confdir}/$BUILD_CONFIG.old ]; then
			rm -f ${confdir}/$BUILD_CONFIG.old
	fi
	if [ -f ${confdir}/$BUILD_CONFIG.new ]; then
			rm -f ${confdir}/$BUILD_CONFIG.new
	fi
	success "Source directory cleaned"
}

## Create kernel compilation working directories
function setup_dirs() {
	info "Creating new out directory"
	mkdir -p "$KERNEL_OUT"
	success "Created new out directory"
	info "Creating new modules_out directory"
	mkdir -p "$MODULES_OUT"
	success "Created new modules_out directory"
}

## Select defconfig file
function select_defconfig() {
	local IFS opt options f i
	local confdir=${KDIR}/arch/$ARCH/configs
	info "Please select the configuration you would like to use as basis"
	cd $confdir
	while IFS= read -r -d $'\0' f; do
		options[i++]="$f"
	done < <(find * -type f -print0 )

	select opt in "${options[@]}" "Cancel"; do
		case $opt in
		"Cancel")
			cd -
			return 1
			;;
		*)
			cd -
			break
			;;
		esac
	done
	info "Using ${opt} as new ${BUILD_CONFIG}"
	cp ${confdir}/${opt} ${confdir}/${BUILD_CONFIG}
	return 0
}

## Check if $BUILD_CONFIG exists and create it if not
function get_defconfig() {
	local defconfig
	local confdir=${KDIR}/arch/$ARCH/configs
	if [ ! -f ${confdir}/${BUILD_CONFIG} ]; then
		warning "${BUILD_CONFIG} not found, creating."
		select_defconfig
		return $?
	fi
	return 0
}

## Edit .config in working directory
function edit_config() {
	local cc
	# CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"
	fi
	get_defconfig || return 1
	if [[ "$EDITION" ]]; then
		info "Creating custom config"
		make -C $KDIR O="$KERNEL_OUT" $cc $BUILD_CONFIG $CONFIG_TOOL
		cp -r ${KERNEL_OUT} ${CONFIG_FOLDER}
	else
		info "Create config"
		make -C $KDIR O="$KERNEL_OUT" $cc $BUILD_CONFIG
	fi

	cfg_done=true
}

## Enable ccache to speed up compilation
function enable_ccache() {
	if [ "$CCACHE" = true ]; then
		if [ "$CC" == "clang" ]; then
			CC="ccache clang"
			else
			if [ ! -z "${CC}" ] && [[ ${CC} != ccache* ]]; then
				CC="ccache $CC"
			fi
			if [ ! -z "${CROSS_COMPILE}" ] && [[ ${CROSS_COMPILE} != ccache* ]]; then
				export CROSS_COMPILE="ccache ${CROSS_COMPILE}"
			fi
			if [ ! -z "${CROSS_COMPILE_ARM32}" ] && [[ ${CROSS_COMPILE_ARM32} != ccache* ]]; then
				export CROSS_COMPILE_ARM32="ccache ${CROSS_COMPILE_ARM32}"
			fi
		fi
		info "~~~~~~~~~~~~~~~~~~"
		info " ccache enabled"
		info "~~~~~~~~~~~~~~~~~~"
	fi
	return 0
}

## copy version file across
function copy_version() {
	if [ ! -z ${SRC_VERSION} ] && [ ! -z ${TARGET_VERSION} ] && [ -f ${SRC_VERSION} ]; then
		cp -f ${SRC_VERSION} ${TARGET_VERSION}
	fi
	return 0
}

## Compile the kernel
function make_kernel() {
	local cc
	local confdir=${KDIR}/arch/$ARCH/configs
	# CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"
	fi
	enable_ccache
	info "~~~~~~~~~~~~~~~~~~"
	info " Building kernel"
	info "~~~~~~~~~~~~~~~~~~"
	copy_version
	grep "CONFIG_MODULES=y" ${KERNEL_OUT}/.config >/dev/null && MODULES=true
	## Some kernel sources do not compile into a separate $OUT directory so we set $OUT = $ KDIR
	## This works with clean and config targets but not for a build, we'll catch this here
	if [ "$KDIR" == "$KERNEL_OUT" ]; then
		if [ "$CC" == "ccache clang" ]; then
			time make -C $KDIR CC="ccache clang"  -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
					time make -C $KDIR CC="ccache clang" -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		else
			time make -C $KDIR $cc -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
					time make -C $KDIR $cc -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		fi
	else
		if [ "$CC" == "ccache clang" ]; then
			time make -C $KDIR O="$KERNEL_OUT" CC="ccache clang" -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
				time make -C $KDIR O="$KERNEL_OUT" CC="ccache clang" -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		else
			time make -C $KDIR O="$KERNEL_OUT" $cc -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
				time make -C $KDIR O="$KERNEL_OUT" $cc -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		fi
	fi
	rm -f ${MODULES_OUT}/lib/modules/*/source
	rm -f ${MODULES_OUT}/lib/modules/*/build
	success "Kernel build completed"
}

function compile_kernel() {
	make_oclean
	make_sclean
	setup_dirs
	edit_config && make_kernel
}
##############################################

##############################################
# Create Anykernel Zip
## Clean anykernel directory
function make_aclean() {
	info "Cleaning up anykernel zip directory"
	rm -rf $ANYKERNEL_DIR/Image* $ANYKERNEL_DIR/dtb $CHANGELOG ${ANYKERNEL_DIR}/modules ${ANYKERNEL_DIR}/*.zip
	success "Anykernel directory cleaned"
}

## Generate Changelog
function make_clog() {
	info "Generating Changelog"
	rm -rf $CHANGELOG
	touch $CHANGELOG
	for i in $(seq 180);
	do
		local After_Date=`date --date="$i days ago" +%F`
		local kcl=$(expr $i - 1)
		local Until_Date=`date --date="$kcl days ago" +%F`
		printf "====================" >> $CHANGELOG;
		printf "     $Until_Date    " >> $CHANGELOG;
		printf "====================\n" >> $CHANGELOG;
		git log --after=$After_Date --until=$Until_Date --pretty=tformat:"%h  %s  [%an]" --abbrev-commit --abbrev=7 >> $CHANGELOG
		printf "" >> $CHANGELOG;
	done
	sed -i 's/project/ */g' $CHANGELOG
	sed -i 's/[/]$//' $CHANGELOG
	info "Done"
	cd $ANYKERNEL_DIR
}

## Generate the anykernel zip
function make_anykernel_zip() {
	mkdir -p ${UPLOAD_DIR}
	info "Copying kernel to anykernel zip directory"
	if [[ ! -f "$KERNEL_IMAGE" ]]; then
		warning "File missing. try relaunching scripts"
	else
		cp "$KERNEL_IMAGE" "$ANYKERNEL_DIR"
	fi
	if [ "$DO_DTBO" = true ]; then
		info "Copying dtbo to zip directory"
		cp "$DTBO_IMAGE" "$ANYKERNEL_DIR"
	fi
	if [ "$DO_DTB" = true ]; then
		info "Generating dtb in zip directory"
		make_dtb ${ANYKERNEL_DIR}
	fi
	if [ -d ${MODULES_OUT}/lib ]; then
		info "Copying modules to zip directory"
		mkdir -p ${ANYKERNEL_DIR}/${MODULE_DIRTREE}
		cp -r ${MODULES_IN} ${ANYKERNEL_DIR}/${MODULE_DIRTREE}
	fi
	success "Done"
	make_clog
	info "Creating anykernel zip file"
	cd "$ANYKERNEL_DIR"
	sed -i "/Version/c\   Version=\"$CURRENT_BRANCH_SHORT7\"" banner
	zip -r "$ANY_ARCHIVE" *
	if [[ "$OUTPUTED" ]]; then
		info "Copying ${ANY_ARCHIVE} to ${OUTPUT_ZIP_FOLDER}"
		cp ${ANY_ARCHIVE} ${OUTPUT_ZIP_FOLDER}
	else
		info "Copying ${ANY_ARCHIVE} to ${HOME}"
		cp ${ANY_ARCHIVE} ${HOME}
	fi
	cd $BUILD_DIR
}

function create_anykernel_zip() {
	make_aclean
	make_anykernel_zip
}
##############################################

##############################################
# Update git as needed
function git_update() {
	if [[ "${CURRENT_BRANCH_ID}" == "${LATEST_BRANCH_ID}" ]]; then
		info "Already up-to-date"
	else
		warning "Not up-to-date"
		if [[ "${CURRENT_BRANCH_NAME}" != "${LATEST_BRANCH_NAME}" ]]; then
			info "The Latest commit is comming from an another branches"
			info "switching to it"
			git checkout "${LATEST_BRANCH_NAME}" -f
			git pull
		else
			info "Pulling repo"
			git reset --hard HEAD && git pull
		fi
	fi
}
##############################################

##############################################
# Check_Toolchains

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
		return 0
	fi
	verify_sha256 "${sha_file}" "${dir}"
	if [ $? -ne 0 ]; then
		return 0
	fi
}

# Download file via http(s); required arguments: <URL> <download directory>
function wget_file {
	local url=${1}
	local dir=${2}
	local file="${url##*/}"
	if [ -f ${dir}/${file} ]; then
		rm -f ${dir}/${file}
	fi
	info "Downloading ${file}"
	axel --alternate -o ${dir}/${file} "$url"
	if [ $? -eq 0 ]; then
		success "Download successful"
	else
		error "Download failed"
		return 1
	fi
	get_sha "${url}" ${dir}
	if [ $? -eq 0 ]; then
		success "Download successful"
		return 0
	else
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
		info "Downloading clang toolchain"
		if [ -z "${CLANG_SRC_TYPE}" ]; then
			CLANG_SRC_TYPE="wget"
		fi
		get_toolchain ${CLANG_SRC} ${CLANG_SRC_TYPE}
		if [ $? -eq 0 ]; then
			if [ -d ${CLANG_ROOT} ]; then
				rm -rf ${CLANG_ROOT}
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
		info "Downloading 32bit gcc toolchain"
		if [ -z "${CROSS_COMPILE_ARM32_TYPE}" ]; then
			CROSS_COMPILE_ARM32_TYPE="wget"
		fi
		get_toolchain ${CROSS_COMPILE_ARM32_SRC} ${CROSS_COMPILE_ARM32_TYPE}
		if [ $? -eq 0 ]; then
			if [ -d ${CCD32} ]; then
				rm -rf ${CCD32}
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
		info "Downloading 64bit gcc toolchain"
		if [ -z "${CROSS_COMPILE_SRC_TYPE}" ]; then
			CROSS_COMPILE_SRC_TYPE="wget"
		fi
		get_toolchain ${CROSS_COMPILE_SRC} ${CROSS_COMPILE_SRC_TYPE}
		if [ $? -eq 0 ]; then
			if [ -d ${CCD64} ]; then
				rm -rf ${CCD64}
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
}

function setup_toolchain() {
	if [[ ! -d "${TD}" ]]; then
		get_toolchains
	fi
}
#
##############################################

##############################################
# Main
function usage() {
	printf "Usage : ${0} -c <config_file_name> [-e]\n"
	printf "\t-h : show this help\n"
	printf "\t-c : config file name to compile/edit\n"
	printf "\t-e : edit the config before compiling\n"
	printf "\t-o : output of the anykernel zip (only accept absolute path)\n"
	printf "\t-u : update repo\n"
	exit
}

BUILD_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${BUILD_DIR}/config
UPDATE=false
while [[ "$1" != "" ]]; do
	case $1 in
		-c)
			CONFIG=true
			shift
			if [[ -z "${KDIR}/arch/${ARCH}/configs/${1}" ]]; then
				error "config file ${1} not found"
				usage
			else
				export BUILD_CONFIG="${1}"
			fi
			;;
		-e)
			EDITION=true
			;;
		-o)
			OUTPUTED=true
			shift
			if [[ -z "$1" ]]; then
				error "$1 folder dosen't exist."
				usage
			else
				export OUTPUT_ZIP_FOLDER="$1"
			fi
			;;
		-u)
			UPDATE=true
			;;
		-h)
			usage
			;;
		*)
			error "Wrong args"
			usage
			;;
	esac
	shift
done

if [[ ! "$CONFIG" ]]; then
	usage
fi

if [[ "$EDITION" ]]; then
	export ANY_ARCHIVE=$(echo $ANY_ARCHIVE | sed 's/.zip/-edited.zip/')
fi

if [[ "$UPDATE" ]]; then
	git_update
fi

setup_toolchain

compile_kernel

create_anykernel_zip
#
##############################################
