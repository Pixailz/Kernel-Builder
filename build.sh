#!/bin/bash
##Bash Color
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

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
##UTILS FUNCTIONS
#=#=#=#=#=#=#=#=#
function info() {
	printf "${lcyan}[ INFO ]${reset} $*${reset}\n"
}

function success() {
	if [ -z $2 ]; then
		printf "${lgreen}[ SUCCESS ]${reset} $1${reset}\n"

	else
		printf "${red}[ FAILED ]${reset} $1${reset}\n"

	fi
}

function warning() {
	printf "${lyellow}[ WARNING ]${reset} $*${reset}\n"
}

function error() {
	printf "${red}[ ERROR ]${reset}$*${reset}\n"
	exit
}

function question() {
	printf "${yellow}[ QUESTION ]${reset} "
}

##PAUSE
function pause() {
	read -p "Press [Enter] to continue.." readEnterkey
}
##DETECT OS
function check_os() {
	if [ -f /etc/SUSE-brand ]; then
		suse=true
	fi
}
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
##SETUP_ENV
#=#=#=#=#=#
function setup_env() {
	if [ ${UPDATE} ]; then
		git_update

	fi

	check_os

	#TODO# ADD CHECK IF DEPENDENCIES ALREADY INSTALLED
	#get_dependencies

	get_toolchains
}
##Update git as needed
function git_update() {
	if [ ${CURRENT_BRANCH_ID} == ${LATEST_BRANCH_ID} ]; then
		warning "Already up-to-date"

	else
		info "Not up-to-date"
		if [ ${CURRENT_BRANCH_NAME} != ${LATEST_BRANCH_NAME} ]; then
			info "The Latest commit is comming from an another branches"
			info "switching to it"
			git reset --hard "${LATEST_BRANCH_NAME}"

		else
			info "Pulling repo"
			git reset --hard HEAD && git pull

		fi
	fi
}

##DOWNLOAD FILE FROM SETTING FILE NAME
function get_toolchain() {
	source ${BUILD_DIR}/toolchains/${1}

	local ARCH_DIR="${BUILD_DIR}/toolchain_archs"
	mkdir -p ${ARCH_DIR}

	if [ ! -z ${TOOLCHAIN_SRC} ]; then
		if [ ! -d ${TOOLCHAIN_ROOT} ]; then
			success "${TOOLCHAIN_NAME} isn't setup" false
			info "Setting up ${TOOLCHAIN_NAME}"

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

			elif [ ${TOOLCHAIN_SRC_TYPE} == "git" ]; then
				if [ -d ${ARCH_DIR}/${TOOLCHAIN_NAME} ]; then
					rm -rf ${ARCH_DIR}/${TOOLCHAIN_NAME}
				fi

				git clone ${TOOLCHAIN_SRC} "${ARCH_DIR}/${TOOLCHAIN_NAME}"
				if [ $? -eq 0 ]; then
					if [ ! -d ${TOOLCHAIN_ROOT} ]; then
						mkdir -p ${TOOLCHAIN_ROOT}

					fi

					mv ${ARCH_DIR}/${TOOLCHAIN_NAME}/* ${TOOLCHAIN_ROOT}

				else
					error "Download failed"
					return 1

				fi
			fi
		elif [ -z "$(ls -A ${TOOLCHAIN_ROOT})" ]; then
			warning "${TOOLCHAIN_ROOT} is empty"
			rm -r ${TOOLCHAIN_ROOT}
			get_toolchain ${1}

		fi
	else
		error "${TOOLCHAIN_NAME} have error in his config"

	fi
}

##EXTRACT DOWNLOADED FILE IN GET_TOOLCHAIN
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

##DOWNLOAD DEFAULT TOOLCHAIN
function get_toolchains() {
	if [ -z ${CUSTOM_TOOLCHAIN} ]; then
		get_toolchain "default_clang"

	else
		get_toolchain "${CUSTOM_TOOLCHAIN_NAME}"

	fi

	get_toolchain "default_gcc64"
	get_toolchain "default_gcc32"
}
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
##COMPILE_KERNEL
#=#=#=#=#=#=#=#=#
function compile_kernel() {
	make_oclean
	make_sclean
	setup_dirs
	edit_config && make_kernel
}

##Clean "out" folders
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

##Clean source tree
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

##Create kernel compilation working directories
function setup_dirs() {
	info "Creating new out directory"
	mkdir -p "$KERNEL_OUT"
	success "Created new out directory"
	info "Creating new modules_out directory"
	mkdir -p "$MODULES_OUT"
	success "Created new modules_out directory"
}

##Edit .config in working directory
function edit_config() {
	local cc
	printf "\n"

	##CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"

	fi

	if [ -z ${EDITION} ]; then
		info "Create config"
		make -C $KDIR O="$KERNEL_OUT" $cc $CUSTOM_CONFIG_NAME

	else
		info "Creating custom config"
		make -C $KDIR O="$KERNEL_OUT" $cc $CUSTOM_CONFIG_NAME $CONFIG_TOOL
		cp -r ${KERNEL_OUT} ${CONFIG_FOLDER}

	fi
}

##Enable ccache to speed up compilation
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

##copy version file across
function copy_version() {
	if [ ! -z ${SRC_VERSION} ] && [ ! -z ${TARGET_VERSION} ] && [ -f ${SRC_VERSION} ]; then
		cp -f ${SRC_VERSION} ${TARGET_VERSION}
	fi
	return 0
}

##SHOW INFO BEFORE COMPILING
function info_before_compile() {
	printf "\n"

	warning "Info Before Compiling"

	info "Config :\t\t\t${CUSTOM_CONFIG_NAME}"

	if [ ! -z ${CUSTOM_TOOLCHAIN} ]; then
		info "Toolchain config :\t\t${CUSTOM_TOOLCHAIN_NAME}"

	else
		info "Toolchain config :\t\tdefault"

	fi

	if [ ! -z ${OUTPUT} ]; then
		info "Anykernel zip output :\t\t${OUTPUT_ZIP_FOLDER}"

	else
		info "Anykernel zip output :\t\t${HOME}"

	fi

	if [ -z ${EDITION} ]; then
		info "Edited :\t\t\tfalse"

	else
		info "Edited :\t\t\ttrue"

	fi

	if [ -z ${UPDATE} ]; then
		info "Updated :\t\t\tfalse"

	else
		info "Updated :\t\t\ttrue"

	fi

	printf "\n"

	pause
}

##Compile the kernel
function make_kernel() {
	local cc
	local confdir=${KDIR}/arch/$ARCH/configs
	printf "\n"

	##CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
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

	info_before_compile

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

	success "Kernel build completed\n"
}
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
##CREATE_ANYKERNEL
#=#=#=#
function create_anykernel_zip() {
	make_aclean
	make_anykernel_zip
}
##Function to generate a dtb image, expects output directory as argument
function make_dtb() {
	local dtb_dir=$1
	if [ "$DTB_VER" == "2" ]; then
		DTB_VER="-2"
	elif [ ! "DTB_VER" == "-2" ]; then
		unset DTB_VER
	fi
	printf "\n"
	info " Building dtb"
	make -C $KDIR $cc -j "$THREADS" $DTB_FILES    # Don't use brackets around $DTB_FILES
	info "Generating DTB Image"
	$DTBTOOL $DTB_VER -o $dtb_dir/$DTB_IMG -s 2048 -p $KERNEL_OUT/scripts/dtc/ $DTB_IN/
	rm -rf $DTB_IN/.*.tmp
	rm -rf $DTB_IN/.*.cmd
	rm -rf $DTB_IN/*.dtb
	success "DTB generated"
}

##Generate Changelog
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

##ZIPING ANYKERNEL FOLDER
function make_anykernel_zip() {
	mkdir -p ${UPLOAD_DIR}

	info "Copying kernel to anykernel zip directory"
	if [[ ! -f "$KERNEL_IMAGE" ]]; then
		error "File missing. try relaunching scripts"
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

	if [ ${EDITION} ]; then
		ANY_ARCHIVE=$(echo $ANY_ARCHIVE | sed 's/.zip/-edited.zip/')
	fi

	zip -r "$ANY_ARCHIVE" *

	if [ -z ${OUTPUT} ]; then
		info "Copying ${ANY_ARCHIVE} to ${HOME}"
		cp --force ${ANY_ARCHIVE} ${HOME}

	else
		#*# TO SYNC WITH ARG PARSER
		info "Copying ${ANY_ARCHIVE} to ${OUTPUT_ZIP_FOLDER}"
		cp --force ${ANY_ARCHIVE} ${OUTPUT_ZIP_FOLDER}

	fi
	cd $BUILD_DIR
}

# Clean anykernel directory
function make_aclean() {
	info "Cleaning up anykernel zip directory"
	rm -rf $ANYKERNEL_DIR/Image* $ANYKERNEL_DIR/dtb $CHANGELOG ${ANYKERNEL_DIR}/modules
	success "Anykernel directory cleaned"
}
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#


#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
##MAIN
#=#=#=#
function main() {
	setup_env

	compile_kernel

	create_anykernel_zip
}

function list_toolchains() {
	info "Available toolchains config"
	for toolchain in $(ls $TOOLCHAIN_CONFIG); do
		printf "\t$toolchain\n"

	done
}

function usage() {
	printf "Usage : ${0} -c <config_file_name> [[-e] [-o <path_to_output_folder>] [-u]]\n"
	printf "\t-h : show this help\n"
	printf "\t-c : config file name to compile/edit\n"
	printf "\t-e : edit the config before compiling\n"
	printf "\t-o : output of the anykernel zip (only accept absolute path)\n"
	printf "\t-u : update repo\n"
	printf "\t-t : specify toolchain\n"
	exit
}

##BUILD DIR
BUILD_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${BUILD_DIR}/config

while [ "$1" != "" ]; do
	case $1 in
		-c)
			CUSTOM_CONFIG=true
			shift
			if [ -z "${KDIR}/arch/${ARCH}/configs/${1}" ]; then
				warning "config file ${1} not found"
				usage

			else
				CUSTOM_CONFIG_NAME="${1}"

			fi
			;;

		-t)
			CUSTOM_TOOLCHAIN=true
			shift
			if [ ! -z $1 ]; then
				if [ -f ${TOOLCHAIN_CONFIG}/${1} ]; then
					CUSTOM_TOOLCHAIN_NAME="${1}"

				else
					warning "toolchain config \"${1}\" not found\n"
					list_toolchains
					exit

				fi
			else
				list_toolchains
				printf "\n"
				usage

			fi
			;;

		-o)
			OUTPUT=true
			shift
			if [[ -z "$1" ]]; then
				warning "$1 folder dosen't exist."
				usage

			else
				OUTPUT_ZIP_FOLDER="$1"

			fi
			;;

		-e)
			EDITION=true
			;;

		-u)
			UPDATE=true
			;;

		-h)
			usage
			;;

		*)
			warnings "Wrong args"
			usage
			;;

	esac
	shift
done

if [ -z ${CUSTOM_CONFIG} ]; then
	usage
fi

main
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
