#!/usr/bin/env bash
### @file create_makefile.sh
### @brief Parse all Makefiles and create one (shared/static) for all

################################################################################
# FUNCTIONS
################################################################################

### #file set.sh
### #brief Simple set container for Bash
### #warning Set name cannot contain white spaces
#
### @brief Create set
### @param $1 Set name
setNew() {
	local -r values="__SET_VALUES_${1}"

	declare -a "${values}"

	eval "${values}=()"
}
#
### @brief Delete set
### @param $1 Set name
setDelete() {
	local -r values="__SET_VALUES_${1}"

	eval "unset -v \"${values}\""
}
#
### @brief Clear set
### @param $1 Set name
setClear() {
	local -r values="__SET_VALUES_${1}"

	eval "${values}=()"
}
#
### @brief Get arrary of set values
### @param $1 Set name
### @return Array of set values is echoed
setToArray() {
	local -r values="__SET_VALUES_${1}"

	eval "echo \"\${${values}[@]}\""
}
#
### @brief Add value to set
### @param $1 Set name
### @param $2 Value
setAdd() {
	local -r values="__SET_VALUES_${1}"
	local -ir size="$(eval "echo \${#${values}[@]}")"
	local -i i
	local value

	if [ "${size}" == 0 ]; then
		eval "${values}+=(\"$2\")"
	else
		for (( i=0 ; i<size ; i++ )); do
			value="$(eval "echo \${${values}[${i}]}")"
			if [ "${value}" == "${2}" ]; then
				break
			fi
		done
		if [ "${i}" == "${size}" ]; then
			eval "${values}+=(\"$2\")"
		fi
	fi
}
#
### @brief Remove value from set
### @param $1 Set name
### @param $2 Value
setRemove() {
	local -r values="__SET_VALUES_${1}"
	local -i size
	local -i i
	local value

	size="$(eval "echo \${#${values}[@]}")"
	for (( i=0 ; i<size ; i++ )); do
		value="$(eval "echo \${${values}[${i}]}")"
		if [ "${value}" == "${2}" ]; then
			size="$((size-1))"
			if [ "${size}" != "0" ]; then
				eval "${values}[${i}]=\"\${${values}[${size}]}\""
			fi
			eval "unset -v \"${values}[${size}]\""
			break
		fi
	done
}
#
### @brief Check if value is in set
### @param $1 Set name
### @param $2 Value
### @return 0 if value is in set
### @return non-zero otherwise
setValue() {
	local -r values="__SET_VALUES_${1}"
	local -ir size="$(eval "echo \${#${values}[@]}")"
	local -i i
	local value

	for (( i=0 ; i<size ; i++ )); do
		value="$(eval "echo \${${values}[${i}]}")"
		if [ "${value}" == "${2}" ]; then
			return "0"
		fi
	done

	return "1"
}
#
### @brief Get set size
### @param $1 Set name
### @return Set size is echoed
setSize() {
	local -r values="__SET_VALUES_${1}"

	eval "echo \${#${values}[@]}"
}

### @brief Parse Makefile and add values (ALL_*) to proper set
### @param $1 Makefile to parse
read_makefile() {
	local IFS
	local LINE
	local SET
	local MODE

	IFS=
	while read -r LINE; do
		IFS=$' \t\n'
		if [[ "${LINE}" =~ ^(ALL_[A-Z_]+)[[:space:]]= ]]; then
			if setValue "SETS" "${BASH_REMATCH[1]}"; then
				SET="${BASH_REMATCH[1]}"
			else
				SET=
			fi
		elif [[ "${LINE}" =~ ^LIB_MODE[[:space:]]*=[[:space:]]*(shared|static) ]]; then
			MODE="${BASH_REMATCH[1]}"
		elif [[ "${LINE}" =~ ^[[:space:]]*([A-Za-z0-9_\./]+)[[:space:]]?\\? ]]; then
			if [ "${SET}" != "" ] && \
				[ "${MODE}" != "" ]; then
				if setValue "SETS" "${SET}"; then
					setAdd "${MODE}_${SET}" "${BASH_REMATCH[1]}"
				else
					SET=
				fi
			fi
		elif [ "${SET}" != "" ]; then
			SET=
		fi
		IFS=
	done <"${1}"
}

### @brief Create string formated for ALL_* variable
### @param $1 Set name with values
### @return Formated string is echoed
create_variable_string() {
	local -i SIZE
	local VALUE

	SIZE="$(setSize "${1}")"
	if [ "${SIZE}" != "0" ]; then
		echo "\\\\"
		for VALUE in $(setToArray "${1}"); do
			SIZE="$((SIZE-1))"
			if [ "${SIZE}" != 0 ]; then
				echo -e "\t${VALUE} \\\\\\"
			else
				echo -e "\t${VALUE}"
			fi
		done
	fi
}

################################################################################
# MAIN
################################################################################

### @brief Makefile template
### @warning Mind to escape the double quotes (") and the dollar sign ($)
### characters to avoid parameter expansion
declare -r TEMPLATE=\
"\
# MDIS for Linux project makefile
# Generated by mdiswiz 2.05.00-linux-13.0
# 2018-09-28

ifndef MEN_LIN_DIR
MEN_LIN_DIR = /opt/menlinux

endif

# You need to select the development environment so that MDIS
# modules are compiled with the correct tool chain

WIZ_CDK = Selfhosted

# All binaries (modules, programs and libraries) will be
# installed under this directory.

# TARGET_TREE

# The directory of the kernel tree used for your target's
# kernel. If you're doing selfhosted development, it's
# typically /usr/src/linux. This directory is used when
# building the kernel modules.

LIN_KERNEL_DIR = /usr/src/linux

# Defines whether to build MDIS to support RTAI. If enabled,
# MDIS modules support RTAI in addition to the standard Linux
# mode. Set it to \\\"yes\\\" if you want to access MDIS devices from
# RTAI applications

MDIS_SUPPORT_RTAI = no

# The directory where you have installed the RTAI distribution
# via \\\"make install\\\"

# RTAI_DIR

# The include directory used when building user mode libraries
# and applications. If you're doing selfhosted development,
# it's typically /usr/include. If you're doing cross
# development, select the include directory of your cross
# compiler. Leave it blank if your compiler doesn't need this
# setting.

# LIN_USR_INC_DIR

# Define whether to build/use static or shared user state
# libraries. In \\\"static\\\" mode, libraries are statically linked
# to programs. In \\\"shared\\\" mode, programs dynamically link to
# the libraries. \\\"shared\\\" mode makes programs smaller but
# requires installation of shared libraries on the target

LIB_MODE = \${LIB_MODE}

# Defines whether to build and install the release (nodbg) or
# debug (dbg) versions of the kernel modules. The debug version
# of the modules issue many debug messages using printk's for
# trouble shooting

ALL_DBGS = dbg

# The directory in which the kernel modules are to be
# installed. Usually this is the target's
# /lib/modules/\\\$(LINUX_VERSION)/misc directory.

MODS_INSTALL_DIR = /lib/modules/\\\$(LINUX_VERSION)/misc

# The directory in which the user state programs are to be
# installed. Often something like /usr/local/bin. (relative to
# the target's root tree)

BIN_INSTALL_DIR = /usr/local/bin

# The directory in which the shared (.so) user mode libraries
# are to be installed. Often something like /usr/local/lib.
# (relative to the target's root tree)

LIB_INSTALL_DIR = /usr/local/lib

# The directory in which the static user mode libraries are to
# be installed. Often something like /usr/local/lib on
# development host. For cross compilation select a path
# relative to your cross compilers lib directory.

STATIC_LIB_INSTALL_DIR = /usr/local/lib

# The directory in which the MDIS descriptors are to be
# installed. Often something like /etc/mdis. (Relative to the
# targets root tree)

DESC_INSTALL_DIR = /etc/mdis

# The directory in which the MDIS device nodes are to be
# installed. Often something like /dev. (Relative to the
# targets root tree)

DEVNODE_INSTALL_DIR = /dev

ALL_LL_DRIVERS = \${ALL_LL_DRIVERS}

ALL_BB_DRIVERS = \${ALL_BB_DRIVERS}

ALL_USR_LIBS = \${ALL_USR_LIBS}

ALL_CORE_LIBS = \${ALL_CORE_LIBS}

ALL_LL_TOOLS = \${ALL_LL_TOOLS}

ALL_COM_TOOLS = \${ALL_COM_TOOLS}

ALL_NATIVE_DRIVERS = \${ALL_NATIVE_DRIVERS}

ALL_NATIVE_LIBS = \${ALL_NATIVE_LIBS}

ALL_NATIVE_TOOLS = \${ALL_NATIVE_TOOLS}

ALL_DESC = system

include \\\$(MEN_LIN_DIR)/BUILD/MDIS/TPL/rules.mak
"

declare -ar SETS=("ALL_LL_DRIVERS" \
	"ALL_BB_DRIVERS" \
	"ALL_USR_LIBS" \
	"ALL_CORE_LIBS" \
	"ALL_LL_TOOLS" \
	"ALL_COM_TOOLS" \
	"ALL_NATIVE_DRIVERS" \
	"ALL_NATIVE_LIBS" \
	"ALL_NATIVE_TOOLS")
declare -ar MODES=("shared" \
	"static")
declare -ar OUTPUTS=("Makefile.shared" \
	"Makefile.static")
declare -a MAKEFILES
declare MAKEFILE
declare SET
declare VALUE
declare -i i

setNew "SETS"
for SET in "${SETS[@]}"; do
	setAdd "SETS" "${SET}"
	for (( i=0 ; i<${#MODES[@]} ; i++ )); do
		setNew "${MODES[${i}]}_${SET}"
	done
done

echo -n "Parsing Makefiles..."
MAKEFILES=($(ls "$(dirname "${BASH_SOURCE[0]}")"/Makefiles/Makefile.*))
for MAKEFILE in "${MAKEFILES[@]}"; do
	echo -n "."
	read_makefile "${MAKEFILE}"
done
echo "done!"

for (( i=0 ; i<${#MODES[@]} ; i++ )); do
	declare LIB_MODE
	# LIB_MODE Used in $TEMPLATE
	# shellcheck disable=SC2034
	LIB_MODE="${MODES[${i}]}"
	for SET in $(setToArray "SETS"); do
		VALUE="$(create_variable_string "${MODES[${i}]}_${SET}")"
		declare "${SET}"
		eval "${SET}=\"${VALUE}\""
	done
	echo -n "Writing ${OUTPUTS[${i}]}..."
	eval "echo \"${TEMPLATE}\" > \"${OUTPUTS[${i}]}\""
	echo "done!"
	for SET in $(setToArray "SETS"); do
		unset -v "${SET}"
	done
	unset -v "LIB_MODE"
done

for SET in "${SETS[@]}"; do
	for (( i=0 ; i<${#MODES[@]} ; i++ )); do
		setDelete "${MODES[${i}]}_${SET}"
	done
done
setDelete "SETS"
