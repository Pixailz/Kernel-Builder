



# Full clean
function make_fclean() {
	printf "\n"
	make_nhclean
	make_aclean
	make_oclean
	pause
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

# Check if $CONFIG exists and create it if not
function get_defconfig() {
	local defconfig
	local confdir=${KDIR}/arch/$ARCH/configs
	printf "\n"
        if [ ! -f ${confdir}/${CONFIG} ]; then
		warning "${CONFIG} not found, creating."
		select_defconfig
		return $?
	fi
        return 0
}

# Select defconfig file
function select_defconfig() {
        local IFS opt options f i
	local confdir=${KDIR}/arch/$ARCH/configs
	info "Please select the configuration you would like to use as basis"
	printf "\n"
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
	info "Using ${opt} as new ${CONFIG}"
	cp ${confdir}/${opt} ${confdir}/${CONFIG}
	return 0
}

# Edit defconfig in kernel source directory
function make_config() {
	local cc
	local tmpdir=/tmp/nethunter-kernel
	local confdir=${KDIR}/arch/$ARCH/configs
        # CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"
	fi
        get_defconfig || return 1
	printf "\n"
	info "Editing $CONFIG"
	if [ -d ${tmpdir} ]; then
		rm -rf ${tmpdir}
	fi
	mkdir -p ${tmpdir}
	make -C $KDIR O="${tmpdir}" $cc $CONFIG $CONFIG_TOOL
	if ask "Replace existing $CONFIG with this one?"; then
		cp -f ${confdir}/$CONFIG ${confdir}/$CONFIG.old
		cp -f ${tmpdir}/.config ${confdir}/$CONFIG
		info "Done. Old config backed up as $CONFIG.old"
	else
		cp -f ${tmpdir}/.config ${confdir}/$CONFIG.new
		info "Config saved as $CONFIG.new"
	fi
	pause
}

function apply_patch() {
	local ret=1
	printf "\n"
	info "Testing $1\n"
        patch -d${KDIR} -p1 --dry-run < $1
	if [ $? == 0 ]; then
		printf "\n"
		if ask "The test run was completed successfully, apply the patch?" "Y"; then
			patch -d${KDIR} -p1 < $1
			ret=$?
		else
			ret=1
		fi
	else
		printf "\n"
		if ask "Warning: The test run completed with errors, apply the patch anyway?" "N"; then
			patch -d${KDIR} -p1 < $1
			ret=$?
		else
			ret=1
		fi
	fi
	printf "\n"
        pause
        return $ret
}

# Show all patches in the current directory
function show_patches() {
	clear
	local IFS opt f i
	unset options
	printf "${lblue} ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n${reset}"
	printf "${lblue} Please choose the patch to apply\n${reset}"
	printf "${lblue} ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n${reset}"
	printf "\n"
        while IFS= read -r -d $'\0' f; do
                options[i++]="$f"
        done < <(find -L * -type f -print0 )
}

# Select a patch
function select_patch() {
	COLUMNS=12
        select opt in "${options[@]}" "Return"; do
                case $opt in
                        "Return")
			    cd -
                            return 1
                            ;;
                        *)
			    apply_patch $opt
			    return 0
                            ;;
                esac
        done
}

# Select kernel patch
function patch_kernel() {
	COLUMNS=12
        local IFS opt options f i pd
	printf "${lblue} ~~~~~~~~~~~~~~~~~~~~~~~~~~\n${reset}"
	printf "${lblue} Please choose the patch\n${reset}"
	printf "${lblue} directory closest matching\n${reset}"
	printf "${lblue} your kernel version\n${reset}"
	printf "${lblue} ~~~~~~~~~~~~~~~~~~~~~~~~~~\n${reset}"
	printf "\n"
        cd $PATCH_DIR
        while IFS= read -r -d $'\0' f; do
                options[i++]="$f"
        done < <(find * -type d -print0 )
        select opt in "${options[@]}" "Return"; do
                case $opt in
                        "Return")
			    cd -
                            return 1
                            ;;
                        *)
			    cd $opt
			    while true
	 			do
				    	clear
					show_patches
					select_patch || return 0
			        done
			    break
                            ;;
                esac
        done

	pause
	return 0
}

# Enable ccache to speed up compilation
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

# Function to generate a dtb image, expects output directory as argument
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

# Generate Changelog
function make_clog() {
	printf "\n"
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
		printf "====================" >> $CHANGELOG;
		git log --after=$After_Date --until=$Until_Date --pretty=tformat:"%h  %s  [%an]" --abbrev-commit --abbrev=7 >> $CHANGELOG
		printf "" >> $CHANGELOG;
	done
	sed -i 's/project/ */g' $CHANGELOG
	sed -i 's/[/]$//' $CHANGELOG
	info "Done"
}

# Build the NetHunter kernel zip to be extracted in the devices directory of the nethunter-installer
function make_nethunter() {
	printf "\n"
	make_oclean
	make_nhclean
	setup_dirs
	edit_config
	make_kernel
	make_nhkernel_zip
}

# Build the test kernel zip using anykernel3
function make_test() {
	printf "\n"
	make_oclean
	make_aclean
	setup_dirs
	edit_config
	make_kernel
	make_anykernel_zip
}

# Print README.md
function print_help() {
	pandoc ${BUILD_DIR}/README.md | lynx -stdin
}

# Main Menu
##############################################
# Display menu
show_menu() {
	clear
	printf "${lblue}"
	printf "\t##################################################\n"
	printf "\t##                                              ##\n"
	printf "\t##  88      a8P         db        88        88  ##\n"
	printf "\t##  88    .88'         d88b       88        88  ##\n"
	printf "\t##  88   88'          d8''8b      88        88  ##\n"
	printf "\t##  88 d88           d8'  '8b     88        88  ##\n"
	printf "\t##  8888'88.        d8YaaaaY8b    88        88  ##\n"
	printf "\t##  88P   Y8b      d8''''''''8b   88        88  ##\n"
	printf "\t##  88     '88.   d8'        '8b  88        88  ##\n"
	printf "\t##  88       Y8b d8'          '8b 888888888 88  ##\n"
	printf "\t##                                              ##\n"
	printf "\t####  ############# NetHunter ####################\n"
	printf "\t~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
	printf "\t           K E R N E L   B U I L D E R\n"
	printf "\t~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
	printf "${reset}"
	printf "\t---------------------------------------------------\n"
	printf "\t                   FULL BUILDS\n"
	printf "\t---------------------------------------------------\n"
	printf "\tN. NetHunter build = Create zip for NH-installer\n"
	printf "\tT. Test build      = Create zip to flash in TWRP\n"
	printf "\n"
	printf "\t---------------------------------------------------\n"
	printf "\t                 INDIVIDUAL STEPS\n"
	printf "\t---------------------------------------------------\n"
	printf "\t1. Edit default kernel config\n"
	printf "\t2. Configure & compile kernel from scratch\n"
	printf "\t3. Configure & recompile kernel from previous run\n"
	printf "\t4. Apply NetHunter kernel patches\n"
	printf "\t5. Create NetHunter zip\n"
	printf "\t6. Create Anykernel zip\n"
	printf "\t7. Generate Changelog\n"
	printf "\t8. Edit Anykernel config\n"
 	printf "\t0. Clean Environment\n"
	printf "\n"
	printf "\t---------------------------------------------------\n"
	printf "\t                     OTHER\n"
	printf "\t---------------------------------------------------\n"
  	printf "\tS. Set up environment & download toolchains\n"
	printf "\tH. Help\n"
  	printf "\tE. Exit\n"
	printf "\n"
}
# Read menu choices
read_choice(){
	local choice
	read -p "Enter selection [N/T/1-8/S/H/E] " choice
	case ${choice,,} in
		n)
		   clear
		   make_nethunter
		   ;;
		t)
		   clear
		   make_test
		   ;;
		1)
		   clear
		   make_config
		   ;;
		2)
		   clear
		   make_oclean
		   make_sclean
		   setup_dirs
		   edit_config && make_kernel
		   ;;
		3)
		   clear
		   if [ "$THREADS" -gt "10" ]; then
			## limit threads to simplify debugging
			THREADS = 10
		   fi
		   make_kernel
		   ;;
		4)
		   clear
		   patch_kernel
		   ;;
		5)
		   clear
		   make_nhclean
		   make_nhkernel_zip
		   ;;
		6)
		   clear
		   make_aclean
		   make_anykernel_zip
		   ;;
		7)
		   clear
		   make_clog
		   ;;
		8)
		   clear
		   $EDIT ${ANYKERNEL_DIR}/anykernel.sh
		   ;;
		0)
		   clear
		   make_fclean
		   ;;
        s)
		   clear
           setup_env
           ;;
        h)
		   clear
           print_help
           ;;
		e)
		   printf "${restore}\n\n"
	 	   exit 0
		   ;;
		*)
		   error "Please select a valid options" && sleep 2
	esac
}
