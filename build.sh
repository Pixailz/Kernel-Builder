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

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
##UTILS FUNCTIONS
#=#=#=#=#=#=#=#=#
## PAUSE
function pause() {
	local message="$@"
	[ -z $message ] && message="Press [Enter] to continue.."
	read -p "$message" readEnterkey
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

# DETECT OS
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
    ##BUILD DIR
    BUILD_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    source ${BUILD_DIR}/config

    check_os

    #TODO# ADD CHECK IF DEPENDENCIES ALREADY INSTALLED
    #get_dependencies

    get_toolchains
}

##DOWNLOAD FILE FROM SETTING FILE NAME
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

#*# TO SYNC WITH ARG PARSER
function get_defconfig() {
	return 0
}

##Edit .config in working directory
function edit_config() {
	local cc
	printf "\n"

    ##CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"

	fi

    get_defconfig || return 1

	if [ -z ${EDITION} ]; then
		info "Create config"
		make -C $KDIR O="$KERNEL_OUT" $cc $CONFIG

	else
		info "Creating custom config"
	    make -C $KDIR O="$KERNEL_OUT" $cc $CONFIG $CONFIG_TOOL

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

## copy version file across
function copy_version() {
	if [ ! -z ${SRC_VERSION} ] && [ ! -z ${TARGET_VERSION} ] && [ -f ${SRC_VERSION} ]; then
		cp -f ${SRC_VERSION} ${TARGET_VERSION}
	fi
	return 0
}

# Compile the kernel
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
	zip -r "$ANY_ARCHIVE" *

	if [ -z ${OUTPUTED} ]; then
		info "Copying ${ANY_ARCHIVE} to ${HOME}"
		cp ${ANY_ARCHIVE} ${HOME}

	else
		#*# TO SYNC WITH ARG PARSER
		info "Copying ${ANY_ARCHIVE} to ${OUTPUT_ZIP_FOLDER}"
		cp ${ANY_ARCHIVE} ${OUTPUT_ZIP_FOLDER}

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
	printf "\n"

    setup_env

	#compile_kernel

    create_anykernel_zip
}

main
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
