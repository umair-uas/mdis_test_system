#! /bin/bash
MyDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${MyDir}"/../Common/Conf.sh
source "${MyDir}"/Mdis_Functions.sh
source "${MyDir}"/Relay_Functions.sh

# This script contains all common functions that are used by St_xxxx testcases.
#

### @brief Run command as root
### @param $@ Command to run, command arguments
function run_as_root {
    if [ "${#}" -gt "0" ]; then
        echo "${MenPcPassword}" | sudo -S --prompt=$'\r' -- "${@}"
    fi
}

############################################################################
# Create directory for St_xxxx Test Case. 
# Create test_case_system_result.txt file with informations:
#       - creation date
#       - operating system
#       - id of used commit 
#       - test case result section 
# parameters:
# $1    Test Case directory name
#
function create_directory {
        local DirectoryName="$1"
        local LogPrefix="$2 "
        if [ ! -d "${DirectoryName}" ]; then
                # create and move to Test Case directory 
                if ! mkdir "${DirectoryName}"
                then
                        echo "${LogPrefix}ERR_CREATE :$1 - cannot create directory"
                        return "${ERR_CREATE}" 
                fi
        else
                echo "${LogPrefix}Directory: ${DirectoryName} exists ..." 
                return "${ERR_DIR_EXISTS}"
        fi

        return "${ERR_OK}"
}



############################################################################
# Get test summary directory name 
#
# parameters:
#       None 
#
function get_test_summary_directory_name {
        local CurrDir="$pwd" 
        local CommitIdShortened
        local SystemName
        local TestResultsDirectoryName
        cd "${MainTestDirectoryPath}/${MainTestDirectoryName}/${MdisSourcesDirectoryName}" || exit "${ERR_NOEXIST}"
        CommitIdShortened=$(git log --pretty=format:'%h' -n 1)
        SystemName=$(hostnamectl | grep "Operating System" | awk '{ print $3 $4 }')
        TestResultsDirectoryName="Results_${SystemName}_commit_${CommitIdShortened}"
        cd "${CurrDir}" || exit "${ERR_NOEXIST}"

        echo "${TestResultsDirectoryName}"
}


############################################################################
# Get mdis sources commit sha
#
# parameters:
#       None 
#
function get_os_name_with_kernel_ver {
        cd "${MainTestDirectoryPath}/${MainTestDirectoryName}/${MdisSourcesDirectoryName}" || exit "${ERR_NOEXIST}"
        local SystemName=$(hostnamectl | grep "Operating System" | awk '{ print $3 $4 }')
        local Kernel=$(uname -r)
        local Arch=$(uname -m)
        cd "${CurrDir}" || exit "${ERR_NOEXIST}"
        SystemName="${SystemName//\//_}"
        SystemName="${SystemName//(/_}"
        SystemName="${SystemName//)/_}"
        echo "${SystemName}_${Kernel}_${Arch}"
}

############################################################################
# Run_test_case_common_actions - perform: 
#       - create directory and move into it
#       - create test case log file
#
# parameters:
# $1     Test Case Log name 
# $2     Test Case name

function run_test_case_dir_create {

        local TestCaseLogName=${1}
        local TestCaseName=${2}

        local CmdResult="${ERR_UNDEFINED}"

        # Create directory with bash script name 
        if ! create_directory "${TestCaseName}"
        then
                return "${CmdResult}"
        fi

        # Move into test case directory
        cd "${TestCaseName}" || exit "${ERR_NOEXIST}"

        # Create log file
        touch "${TestCaseLogName}"
}



############################################################################
# Obtain device list from chameleon device, If there are several same boards
# number of board have to specified (default 1 board is taken as valid) 
#
# parameters:
# $1      Ven ID
# $2      Dev ID
# $3      SubVen ID
# $4      File name for results
# $5      Board number (optional, when there is more than one-the same mezz board)
#
function obtain_device_list_chameleon_device {

        echo "obtain_device_list_chameleon_device"

        local VenID=$1
        local DevID=$2
        local SubVenID=$3
        local FileWithResults=$4
        local BoardNumberParam=$5

        local BoardNumber=1
        local BoardsCnt=0
        local BusNr=0        
        local DevNr=0   

        # Check how many boards are present 
        BoardsCnt=$(echo ${MenPcPassword} | sudo -S --prompt=$'\r' /opt/menlinux/BIN/fpga_load -s | grep "${VenID} * ${DevID} * ${SubVenID}" | wc -l)

        echo "There are: ${BoardsCnt} mezzaine ${VenID} ${DevID} ${SubVenID} board(s) in the system" 

        if (( "${BoardsCnt}" >= "2" )) ; then
                if [ "${BoardNumberParam}" -eq "0" ] || [ "${BoardNumberParam}" -ge "${BoardsCnt}" ]; then
                        BoardNumber=1
                else
                        BoardNumber=${BoardNumberParam}
                fi
        fi

        echo "Obtain modules name from mezz ${BoardNumber}"

        # Obtain BUS number
        BusNr=$(echo ${MenPcPassword} | sudo -S --prompt=$'\r' /opt/menlinux/BIN/fpga_load -s | grep "${VenID} * ${DevID} * ${SubVenID}" | awk NR==${BoardNumber}'{print $3}')
        
        # Obtain DEVICE number
        DevNr=$(echo ${MenPcPassword} | sudo -S --prompt=$'\r' /opt/menlinux/BIN/fpga_load -s | grep "${VenID} * ${DevID} * ${SubVenID}" | awk NR==${BoardNumber}'{print $4}')
        
        echo "Device BUS:${BusNr}, Dev:${DevNr}"  
        # Check how many chameleon devices are present in configuration
        echo "Current Path:"
        echo $PWD

        local ChamBoardsNr=$(grep "^mezz_cham*" ../system.dsc | wc -l)
        echo "Number of Chameleon boards: ${ChamBoardsNr}"

        local ChamBusNr=0
        local ChamDevNr=0 
        local ChamValidId=0;

        # Check if device is present in system.dsc file
        #   PCI_BUS_NUMBER = BusNr
        #   PCI_DEVICE_NUMBER = DevNr

        for i in $(seq 1 ${ChamBoardsNr}); do
                # Display chameleon bus and device number
                ChamBusNr=$(sed -n "/^mezz_cham_${i}/,/}/p" ../system.dsc | grep "PCI_BUS_NUMBER" | awk '{print $4}')
                ChamDevNr=$(sed -n "/^mezz_cham_${i}/,/}/p" ../system.dsc | grep "PCI_DEVICE_NUMBER" | awk '{print $4}')

                # Convert to decimal and check if it is valid chameleon board
                ChamBusNr=$(( 16#$(echo ${ChamBusNr} | awk -F'x' '{print $2}')))
                ChamDevNr=$(( 16#$(echo ${ChamDevNr} | awk -F'x' '{print $2}') ))

                if [ ${ChamBusNr} -eq ${BusNr} ] && [ ${ChamDevNr} -eq ${DevNr} ]; then 
                        echo "mezz_cham_${i} board is valid"
                        ChamValidId=${i}
                fi
        done

        # Check how many devices are present in system.dsc 
        local DeviceNr=$(grep "{" ../system.dsc | wc -l )
        
        # Create file with devices description on mezzaine chameleon board
        touch ${FileWithResults} 

        for i in $(seq 1 ${DeviceNr}); do
                #Check if device belongs to choosen chameleon board
                local DevToCheck=$(grep "{" ../system.dsc | awk NR==${i}'{print $1}')

                if [ "${DevToCheck}" != "mezz_cham_${ChamValidId}" ]; then
                        sed -n "/${DevToCheck}/,/}/p" ../system.dsc | grep "mezz_cham_${ChamValidId}" > /dev/null 2>&1

                        if [ $? -eq 0 ]; then
                                echo "Device: ${DevToCheck} belongs to mezz_cham_${ChamValidId}"
                                echo "${DevToCheck}" >> ${FileWithResults} 
                        fi
                fi 
     done
}


############################################################################
# Function checks if GPIO is working correctly
#
# parameters:
# $1    Test case log file name
# $2    Test case name
# $3    GPIO number
# $4    Command Code
#
function gpio_test {
        
        local TestCaseLogName=${1}
        local TestCaseName=${2}
        local GpioNr=${3}
        local CommandCode=${4}
        local LogPrefix="[Gpio_Test]"
        echo "${LogPrefix} function gpio_test"

        # Make sure that input is disabled 
        change_input ${TestCaseLogName} ${TestCaseName} $((${CommandCode}+100)) ${InputSwitchTimeout} ${LogPrefix}
        # Test GPIO, banana plugs are not connected to power source
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' z17_simp ${GPIO2} >> z17_simp_${GPIO2}_banana_plug_disconnected.txt 2>&1
        CmdResult=$?
        if [ ${CmdResult} -ne ${ERR_OK} ]; then
                echo "${LogPrefix} ERR_RUN :could not run z17_simp ${GPIO2}" | tee -a ${TestCaseLogName} 2>&1     
                return ${CmdResult}
        fi
        
        # Enable input
        change_input ${TestCaseLogName} ${TestCaseName} ${CommandCode} ${InputSwitchTimeout} ${LogPrefix}
        CmdResult=$?
        if [ ${CmdResult} -ne ${ERR_OK} ]; then
                echo "${LogPrefix} Error: ${CmdResult} in function change_input" | tee -a ${TestCaseLogName} 2>&1
                return ${CmdResult}
        fi

        # Test GPIO, banana plugs are connected to power source
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' z17_simp ${GPIO2} >> z17_simp_${GPIO2}_banana_plug_connected.txt 2>&1
        CmdResult=$?
        if [ ${CmdResult} -ne ${ERR_OK} ]; then
                echo "${LogPrefix} ERR_RUN :could not run z17_simp ${GPIO1}" | tee -a ${TestCaseLogName} 2>&1
                return ${CmdResult}  
        fi
        
        # Disable input
        change_input ${TestCaseLogName} ${TestCaseName} $((${CommandCode}+100)) ${InputSwitchTimeout} ${LogPrefix}

        # Compare bit settings for read(s), shall be different
        local Index=4 #to 35
        local CheckValueDisconnected=$(cat z17_simp_${GPIO2}_banana_plug_disconnected.txt | awk NR==${Index}'{print $18}') 
        local CheckValueConnected=$(cat z17_simp_${GPIO2}_banana_plug_connected.txt | awk NR==${Index}'{print $18}')
        for i in $(seq ${Index} 35)
        do
                if [ "${CheckValueDisconnected}" == "${CheckValueConnected}" ]; then
                        echo "${LogPrefix} ERR GPIO - read values are the same"
                        return ${ERR_VALUE}
                fi
                CheckValueDisconnected=$(cat z17_simp_${GPIO2}_banana_plug_disconnected.txt | awk NR==${Index}'{print $18}') 
                CheckValueConnected=$(cat z17_simp_${GPIO2}_banana_plug_connected.txt | awk NR==${Index}'{print $18}')
        done
        
        return ${ERR_OK}
}


############################################################################
# Function that performs all needed steps to check if uart modules are working on
# specific mezzaine board.
# Functions perfroms steps: 
# - modprobing the driver
# - obtains tty number list from board
# - performs loopback test on interfaces that have been found on board
# 
# parameters:
# $1    - Test Case log file name
# $2    - VenID
# $3    - DevID
# $4    - SubVenID
# $5    - BoardInSystem
#
function uart_loopback_test {
        echo "function uart_loopback_test"

        local TestCaseLogName=${1}
        local VenID=${2}
        local DevID=${3}
        local SubVenID=${4}
        local BoardInSystem=${5}
        local CmdResult=${ERR_UNDEFINED}
        local LogPrefix="[Uart_test]"

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_mdis_kernel
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_lx_z25 baud_base=1843200 mode=se,se

        ## DEBIAN workaround -- on DEBIAN chameleon table disapears when module men_lx_z25 is loaded
        ## rmmod men_lx_z25 for a while. (it must be loaded to set proper uart mmmio address)
        local IsDebian="$(hostnamectl | grep "Operating System" | grep "Debian" | wc -l)"
        echo "IsDebian: ${IsDebian}" | tee -a ${TestCaseLogName} 2>&1
        if [ "${IsDebian}" == "1" ]; then
            echo ${MenPcPassword} | sudo -S --prompt=$'\r' rmmod men_lx_z25
        fi
        ###

        if [ $? -ne 0 ]; then
                echo "${LogPrefix} ERR_MODPROBE :could not modprobe men_lx_z25 baud_base=1843200 mode=se,se"\
                  | tee -a ${TestCaseLogName} 2>&1
                return ${ERR_MODPROBE}
        fi

        obtain_tty_number_list_from_board  ${TestCaseLogName} ${VenID} ${DevID} ${SubVenID} ${BoardInSystem}
        CmdResult=$?
        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                 echo "${LogPrefix} obtain_tty_number_list_from_board failed, err: ${CmdResult} "\
                   | tee -a ${TestCaseLogName} 2>&1
                 return ${CmdResult}
        fi

        ## DEBIAN workaround
        if [ "${IsDebian}" == "1" ]; then
            echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_lx_z25 baud_base=1843200 mode=se,se
        fi
        ###

        uart_test_lx_z25 "${TestCaseLogName}" ${LogPrefix}
        CmdResult=$?
        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                 echo "${LogPrefix} uart_test_lx_z25 failed, err: ${CmdResult} "\
                   | tee -a ${TestCaseLogName} 2>&1
                 return ${CmdResult}
        fi
        return ${CmdResult}
}

############################################################################
# Test RS232 with men_lx_z25 IpCore 

#
# parameters:
# $1      name of file with log 
# $2      array of ttyS that should be tested
#        
#
function uart_test_lx_z25 {

        local LogFileName=${1}
        local LogPrefix=${2}
        shift

        FILE="UART_board_tty_numbers.txt"
        if [ -f ${FILE} ]; then
                echo "${LogPrefix} file UART_board_tty_numbers exists"\
                  | tee -a ${LogFileName} 2>&1
                TtyDeviceCnt=$(cat ${FILE} | wc -l)

                for i in $(seq 1 ${TtyDeviceCnt}); do
                        Arr[${i}]=$(cat ${FILE} | awk NR==${i}'{print $1}')
                        echo "${LogPrefix} read from file: ${Arr[${i}]}"
                done
        else
                echo "${LogPrefix} file UART_board_tty_numbers does not exists"\
                  | tee -a ${LogFileName} 2>&1
                return ${ERR_NOEXIST}
        fi

        local tty0="ttyS$(cat ${FILE} | awk NR==1'{print $1}')"
        local tty1="ttyS$(cat ${FILE} | awk NR==2'{print $1}')"

        uart_test_tty ${tty1} ${tty0}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: ${tty1} with ${tty0}" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi
        
        sleep 1
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' rmmod men_lx_z25 
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not rmmod m" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_lx_z25 baud_base=1843200 mode=se,se
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not  modprobe men_lx_z25 baud_base=1843200 mode=se,se" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi
        sleep 1

        uart_test_tty ${tty0} ${tty1}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: ${tty0} with ${tty1}" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi

        return ${ERR_OK}

        # Be aware of Linux kernel bug 
        # https://bugs.launchpad.net/ubuntu/+source/linux-signed-hwe/+bug/1815021
        #
        #for item in "${Arr[@]}"; do 
        #        # Conditions must be met: i2c-i801 is loaded, mcb_pci is disabled
        #        echo ${MenPcPassword} | sudo -S --prompt=$'\r' chmod o+rw /dev/ttyS${item}
        #        if [ $? -ne 0 ]; then
        #                echo "${LogPrefix} Could not chmod o+rw on ttyS${item}"\
        #                  | tee -a ${LogFileName} 2>&1
        #        fi
        #        sleep 2
        #        # Below command prevent infitite loopback on serial port 
        #        echo ${MenPcPassword} | sudo -S --prompt=$'\r' stty -F /dev/ttyS${item} -echo -onlcr
        #        if [ $? -ne 0 ]; then
        #                echo "${LogPrefix} Could not stty -F on ttyS${item}"\
        #                  | tee -a ${LogFileName} 2>&1
        #        fi
        #        sleep 2
        #        # Listen on port in background
        #        echo ${MenPcPassword} | sudo -S --prompt=$'\r' cat /dev/ttyS${item}\
        #          > echo_on_serial_S${item}.txt &
        #        
        #        if [ $? -ne 0 ]; then
        #                echo "${LogPrefix} Could not cat on ttyS${item} in background"\
        #                  | tee -a ${LogFileName} 2>&1
        #        fi
        #        sleep 2 
        #        # Save background process PID 
        #        CatEchoTestPID=$!
        #        # Send data into port
        #        echo ${MenPcPassword} | sudo -S --prompt=$'\r' echo ${EchoTestMessage} > /dev/ttyS${item}
        #        if [ $? -ne 0 ]; then
        #                echo "${LogPrefix} Could not echo on ttyS${item}"\
        #                  | tee -a ${LogFileName} 2>&1
        #        fi
        #        # Kill process
        #        sleep 2 
        #        echo ${MenPcPassword} | sudo -S --prompt=$'\r' kill -9 ${CatEchoTestPID}
        #        if [ $? -ne 0 ]; then
        #                echo "${LogPrefix} Could not kill cat backgroung process ${CatEchoTestPID} on ttyS${item}"\
        #                  | tee -a ${LogFileName} 2>&1
        #        fi
        #        # Compare and check if echo test message was received.
        #        sleep 1 
        #        grep -a "${EchoTestMessage}" echo_on_serial_S${item}.txt
        #        if [ $? -eq 0 ]; then
        #                echo "${LogPrefix} Echo succeed on ttyS${item}"\
        #                  | tee -a ${LogFileName} 2>&1
        #        else
        #                echo "${LogPrefix} Echo failed on ttyS${item}"\
        #                  | tee -a ${LogFileName} 2>&1
        #                return ${ERR_VALUE}
        #        fi
        #
        #        #rm echo_on_serial_S${item}.txt
        #done
}

############################################################################
# Test RS232 at given tty_xx device
# Example:
#       uart_test_tty xxxx yyyy
#
# where x is: ttyS0 ... ttySx / ttyD0 ... ttyDx
# where y is: ttyS0 ... ttySx / ttyD0 ... ttyDx  
# It two uarts are connected with each other, then pass two different parameters
# It uart is connected with loopback, then pass two same parameters
# Example:
#       uart_test_tty xxxx yyyy
#       uart_test_tty ttyD0 ttyD1
#       uart_test_tty ttyD0 ttyD0
# parameters:
# $1      tty 0 name
# $2      tty 1 name
#
function uart_test_tty {
        local tty0=${1}
        local tty1=${2}

        
        #Conditions must be met: i2c-i801 is loaded, mcb_pci is 
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' chmod o+rw /dev/${tty0}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix} Could not chmod o+rw on ${tty0}"\
                  | tee -a ${LogFileName} 2>&1
        fi
        sleep 1
        # Below command prevent infitite loopback on serial port
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' stty -F /dev/${tty0} -onlcr
        if [ $? -ne 0 ]; then
                echo "${LogPrefix} Could not stty -F on ttyS${item}"\
                  | tee -a ${LogFileName} 2>&1
        fi
        sleep 1
        # Listen on port in background
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' cat /dev/${tty1}\
          > echo_on_serial_${tty1}.txt &
        
        if [ $? -ne 0 ]; then
                echo "${LogPrefix} Could not cat on ${tty1} in background"\
                  | tee -a ${LogFileName} 2>&1
        fi
        sleep 1 
        # Save background process PID 
        CatEchoTestPID=$!

        # Send data into port
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' echo ${EchoTestMessage} > /dev/${tty0}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix} Could not echo on ${tty0}"\
                  | tee -a ${LogFileName} 2>&1
        fi
        # Kill process
        sleep 1
        # Set up previous settings
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' chmod o-rw /dev/${tty0}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix} Could not chmod o+rw on ${tty0}"\
                  | tee -a ${LogFileName} 2>&1
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' kill ${CatEchoTestPID}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix} Could not kill cat backgroung process ${CatEchoTestPID} on ${tty1}"\
                  | tee -a ${LogFileName} 2>&1
        fi
        # Compare and check if echo test message was received.
        sleep 1
        grep -a "${EchoTestMessage}" echo_on_serial_${tty1}.txt
        if [ $? -eq 0 ]; then
                echo "${LogPrefix} Echo succeed on ${tty1}"\
                  | tee -a ${LogFileName} 2>&1
                return ${ERR_OK}
        else
                echo "${LogPrefix} Echo failed on ${tty1}"\
                  | tee -a ${LogFileName} 2>&1
        fi
        
        return ${ERR_VALUE}
}


############################################################################
# Test CAN with men_ll_z15 IpCore 
#
# parameters:
# $1      name of file with log 
# $2      mezzaine chameleon device description file
#        
#
function can_test_ll_z15 {

        local LogFileName=$1
        local MezzChamDevDescriptionFile=$2
        local LogPrefix="[Can_test]"

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_ll_z15
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE :could not modprobe men_ll_z15" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi      

        local CanNumber=$(grep "^can" ${MezzChamDevDescriptionFile} | wc -l)
        if [ "${CanNumber}" -ne "2" ]; then
                echo "${LogPrefix}  There are ${CanNumber} CAN interfaces"  | tee -a ${LogFileName}
        else
                local CAN1=$(grep "^can" ${MezzChamDevDescriptionFile} | awk NR==1'{print $1}')
                local CAN2=$(grep "^can" ${MezzChamDevDescriptionFile} | awk NR==2'{print $1}')
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' mscan_pingpong ${CAN1} ${CAN2} >> mscan_pingpong_${CAN1}_${CAN2}.txt 2>&1
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  mscan_pingpong on ${CAN1} ${CAN2} error" | tee -a ${LogFileName}
                return ${ERR_VALUE}
        else
                local CanResult=$(grep "TEST RESULT:" mscan_pingpong_${CAN1}_${CAN2}.txt | awk NR==1'{print $3}')
                if [ "${CanResult}" -ne "${ERR_OK}" ]; then
                         return ${ERR_RUN}
                fi
                return ${ERR_OK}
        fi
}

############################################################################
# Test CAN with men_ll_z15 IpCore (loopback)
#
# parameters:
# $1      name of file with log 
# $2      mezzaine chameleon device description file
#        
#
function can_test_ll_z15_loopback {

        local LogFileName=$1
        local MezzChamDevDescriptionFile=$2
        local LogPrefix="[Can_test]"

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_ll_z15
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE :could not modprobe men_ll_z15" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi

        local CanNumber=$(grep "^can" ${MezzChamDevDescriptionFile} | wc -l)
        if [ "${CanNumber}" -ne "1" ]; then
                echo "${LogPrefix}  There are ${CanNumber} CAN interfaces"  | tee -a ${LogFileName}
        else
                local CAN1=$(grep "^can" ${MezzChamDevDescriptionFile} | awk NR==1'{print $1}')
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' mscan_loopb ${CAN1} >> mscan_loopb_${CAN1}.txt 2>&1
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  mscan_loopb on ${CAN1} error" | tee -a ${LogFileName}
                return ${ERR_VALUE}
        else
                local CanResult=$(grep "TEST RESULT:" mscan_loopb_${CAN1}.txt | awk NR==1'{print $3}')
                if [ "${CanResult}" -ne "${ERR_OK}" ]; then
                         return ${ERR_RUN}
                fi
                return ${ERR_OK}
        fi
}

############################################################################
# Test CAN with men_ll_z15 IpCore (loopback) version 2
#
# parameters:
# $1      name of file with log 
# $2      CAN device name
#        
#
function can_test_ll_z15_loopback2 {

        local LogFileName=$1
        local CANDevice=$2
        local LogPrefix="[Can_test]"

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_ll_z15
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE :could not modprobe men_ll_z15" | tee -a ${LogFileName} 
                return ${ERR_VALUE}
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' mscan_loopb ${CANDevice} >> mscan_loopb_${CANDevice}.txt 2>&1
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  mscan_loopb on ${CANDevice} error" | tee -a ${LogFileName}
                return ${ERR_VALUE}
        else
                local CanResult=$(grep "TEST RESULT:" mscan_loopb_${CANDevice}.txt | awk NR==1'{print $3}')
                if [ "${CanResult}" -ne "${ERR_OK}" ]; then
                         return ${ERR_RUN}
                fi
                return ${ERR_OK}
        fi
}

############################################################################
# This function resolves 'connection' beetween UART IpCore and ttyS number
# in linux system. Addresses for UART and ttyS are compared. 
#
# parameters:
# $1      Log file name
# $2      VenID
# $3      DevID
# $4      SubVenID
# $5      Board Number (1 as default)
#
function obtain_tty_number_list_from_board {

        echo "obtain_tty_number_list_from_board"

        local TestCaseLogName=$1
        local VenID=$2   
        local DevID=$3
        local SubVenID=$4
        
        # Obtain proper addresses for UART devices, save Chameleon table into file
        local BoardCnt=0
        local BoardMaxSlot=8

        for i in $(seq 0 ${BoardMaxSlot}); do
                echo ${MenPcPassword} | sudo -S --prompt=$'\r' /opt/menlinux/BIN/fpga_load ${VenID} ${DevID} ${SubVenID} $i -t > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        BoardCnt=$((${BoardCnt}+1))
                else
                        break
                fi
        done

        echo "Found ${BoardCnt}:  ${VenID} ${DevID} ${SubVenID} board(s)" | tee -a ${TestCaseLogName} 2>&1

        # Save chamelon table for board(s)
        for i in $(seq 1 ${BoardCnt}); do
                echo ${MenPcPassword} | sudo -S --prompt=$'\r' /opt/menlinux/BIN/fpga_load ${VenID} ${DevID} ${SubVenID} $((${i}-1)) -t >> Board_${VenID}_${DevID}_${SubVenID}_${i}_chameleon_table.txt
                if [ $? -eq 0 ]; then
                        echo "Chameleon for Board_${VenID}_${DevID}_${SubVenID}_${i} board saved (1)" | tee -a ${TestCaseLogName} 2>&1
                else
                        break
                fi
        done

        # Save uart devices into file
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' cat /proc/tty/driver/serial >> UART_devices_dump.txt

        # Check How many UARTS are on board(s)
        UartCnt=0
        for i in $(seq 1 ${BoardCnt}); do
                UartBrdCnt=$(grep "UART" Board_${VenID}_${DevID}_${SubVenID}_${i}_chameleon_table.txt | wc -l)
                for j in $(seq 1 ${UartBrdCnt}); do
                        UartAddr=$(grep "UART" Board_${VenID}_${DevID}_${SubVenID}_${i}_chameleon_table.txt | awk NR==${j}'{print $11}')
                        if [ $? -eq 0 ]; then
                                echo "UART ${j} addr for Board_${VenID}_${DevID}_${SubVenID}_${i} board saved" | tee -a ${TestCaseLogName} 2>&1
                                UartBrdNr[${UartCnt}]=$i      
                                UartNr[${UartCnt}]=`grep -i ${UartAddr} "UART_devices_dump.txt" | awk '{print $1}' | egrep -o '^[^:]+'`
                                UartCnt=$((UartCnt+1))
                        else
                                echo "No more UARTs in board" | tee -a ${TestCaseLogName} 2>&1
                        fi 
                done 
        done
        
        echo "There are ${UartCnt} UART(s) on ${VenID} ${DevID} ${SubVenID} board(s)" | tee -a ${TestCaseLogName} 2>&1
        if [ ${UartCnt} -eq 0 ]; then
            return ${ERR_NOT_DEFINED}
        fi
        # List all UARTs that are on board(s)
        touch "UART_board_tty_numbers.txt"
        
        # Loop through all UART interfaces per board
        local UartNrInBoard=0
        for item in ${UartBrdNr[@]}; do
                echo Board: ${item}
                echo "For board ${item} UART ttyS${UartNr[${UartNrInBoard}]} should be tested"\
                 | tee -a ${TestCaseLogName} 2>&1
                echo "${UartNr[${UartNrInBoard}]}" >> UART_board_tty_numbers.txt
                UartNrInBoard=$((${UartNrInBoard} + 1))
        done
}

############################################################################
# run m77 test 
# 
# parameters:
# $1    Test case log file name
# $2    Test case name
# $3    M77 board number
# $4    Carrier board number
function m_module_m77_test {
        local TestCaseLogName=${1}
        local TestCaseName=${2}
        local M77Nr=${3}
        local M77CarrierName="d203_a24_${4}" # obtain from system.dsc (only G204)
        local LogPrefix="[m77_test]"

        # modprobe men_ sth sth 
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_mdis_kernel
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not modprobe men_mdis_kernel" | tee -a ${LogFileName}
                return ${ERR_VALUE}
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' mdis_createdev -b ${M77CarrierName}
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not mdis_createdev -b ${M77CarrierName}" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_lx_m77 devName=m77_${M77Nr} brdName=${M77CarrierName} slotNo=0 mode=7,7,7,7
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not modprobe men_lx_m77 devName=m77_${M77Nr} brdName=${M77CarrierName} slotNo=0 mode=7,7,7,7" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi
        local tty0="ttyD0"
        local tty1="ttyD1"
        local tty2="ttyD2"
        local tty3="ttyD3"

        if ! uart_test_tty "${tty0}" "${tty1}"
        then
                echo "${LogPrefix}  ERR_VALUE: ${tty0} with ${tty1}" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi

        if ! uart_test_tty "${tty3}" "${tty2}"
        then
                echo "${LogPrefix}  ERR_VALUE: ${tty3} with ${tty2}" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi

        sleep 2 
        echo ${MenPcPassword} | sudo -S --prompt=$'\r' rmmod men_lx_m77 
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not rmmod m" | tee -a ${LogFileName} 
                return "${ERR_VALUE}"
        fi

        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe men_lx_m77 devName=m77_${M77Nr} brdName=${M77CarrierName} slotNo=0 mode=7,7,7,7
        if [ $? -ne 0 ]; then
                echo "${LogPrefix}  ERR_VALUE: could not modprobe men_lx_m77 devName=m77_${M77Nr} brdName=${M77CarrierName} slotNo=0 mode=7,7,7,7" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi

        if ! uart_test_tty "${tty1}" "${tty0}"
        then
                echo "${LogPrefix}  ERR_VALUE: ${tty1} with ${tty0}" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi

        if ! uart_test_tty "${tty2}" "${tty3}"
        then
                echo "${LogPrefix}  ERR_VALUE: ${tty2} with ${tty3}" | tee -a ${LogFileName}
                return "${ERR_VALUE}"
        fi

        return "${ERR_OK}"
}

############################################################################
# This function runs m module test
#   Possible machine states
#   1 - ModprobeDriver
#   2 - CheckInput
#   3 - EnableInput
#   4 - RunExampleInputEnable
#   5 - RunExampleInputDisable
#   6 - CompareResults
#   7 - DisableInput
#
#   IMPORTANT: 
#   If device cannot be opened there should always be line:
#   *** ERROR (LINUX) #2:  No such file or directory ***
#
# Function supports below m-modules
#       m66
#       m31
#       m35 
#       m36 - not yet !!
#       m82

# parameters:
# $1    
#
function m_module_x_test {
        local TestCaseLogName=${1}
        local TestCaseName=${2}
        local CommandCode=${3}
        local MModuleName=${4}
        local MModuleBoardNr=${5}
        local SubtestName=${6}
        local LogPrefix="${7}"

        local CmdResult=${ERR_UNDEFINED}
        local ErrorLogCnt=1
        local TestError=${ERR_UNDEFINED}
        local MachineState="ModprobeDriver"
        local MachineRun=true 

        local ModprobeDriver=""
        local ModuleSimp=""
        local ModuleSimpOutput="simp"
        local ModuleResultCmpFunc=""
        local ModuleInstanceName=""

        case "${MModuleName}" in
          m11)
                ModprobeDriver="men_ll_m11"
                ModuleSimp="m11_port_veri"
                ModuleResultCmpFunc="compare_m11_port_veri_values"
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr}"
                ;;
          m31)
                ModprobeDriver="men_ll_m31"
                ModuleSimp="m31_simp"
                ModuleResultCmpFunc="compare_m31_simp_values"
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr}"
                ;;
          m35)
                ModprobeDriver="men_ll_m34"
                if [ "${SubtestName}" == "blkread" ]; then
                      ModuleSimp="m34_blkread -r=14 -b=1 -i=3 -d=1"
                      ModuleSimpOutput="blkread"
                      ModuleResultCmpFunc="compare_m35_blkread_values"
                else
                      ModuleSimp="m34_simp"
                      ModuleResultCmpFunc="compare_m35_simp_values"
                fi
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr} 14" 
                ;;
          m36n)
                ModprobeDriver="men_ll_m36"
                ModuleSimp="m36_simp"
                ModuleResultCmpFunc="compare_m36_simp_values"
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr}"
                ;;
          m43)
                ModprobeDriver="men_ll_m43"
                ModuleSimp="m43_ex1"
                ModuleResultCmpFunc="compare_m43_simp_values"
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr}"
                ;;
          m66)
                ModprobeDriver="men_ll_m66"
                ModuleSimp="m66_simp"
                ModuleResultCmpFunc="compare_m66_simp_values"
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr}"
                ;;
          m82)
                #Software compatible with m31
                ModprobeDriver="men_ll_m31"
                ModuleSimp="m31_simp"
                ModuleResultCmpFunc="compare_m82_simp_values"
                ModuleInstanceName="${MModuleName}_${MModuleBoardNr}"
                ;;
          *)
          echo "MModule is not set"
          MModuleName="NotDefined"
          MachineRun=false
          TestError=${ERR_NOT_DEFINED}
          ;;
        esac

        echo "${LogPrefix} M-Module to test: ${MModuleName}" | tee -a "${TestCaseLogName}" 2>&1
        echo "${LogPrefix} M-Module modprobeDriver: ${ModprobeDriver}" | tee -a "${TestCaseLogName}" 2>&1
        echo "${LogPrefix} M-Module simp: ${ModuleSimp}" | tee -a "${TestCaseLogName}" 2>&1
        echo "${LogPrefix} M-Module cmp function: ${ModuleResultCmpFunc}" | tee -a "${TestCaseLogName}" 2>&1

        while ${MachineRun}; do
                case "${MachineState}" in
                  ModprobeDriver)
                        # Modprobe driver
                        echo "${LogPrefix} ModprobeDriver" | tee -a "${TestCaseLogName}" 2>&1
                        echo ${MenPcPassword} | sudo -S --prompt=$'\r' modprobe "${ModprobeDriver}"
                        CmdResult=$?
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${ERR_MODPROBE} :could not modprobe ${ModprobeDriver}" | tee -a "${TestCaseLogName}" 2>&1
                                MachineRun=false
                        else
                                MachineState="CheckInput"
                        fi
                        ;;
                  CheckInput)
                        # Check if input is disabled - if not disable input 
                        echo "${LogPrefix} CheckInput" | tee -a "${TestCaseLogName}" 2>&1
                        change_input "${TestCaseLogName}" "${TestCaseName}" $((CommandCode+100)) "${InputSwitchTimeout}" "${LogPrefix}"
                        CmdResult=$?
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${CmdResult} in function change_input" | tee -a "${TestCaseLogName}" 2>&1
                                MachineRun=false
                        else
                                MachineState="RunExampleInputDisable"
                        fi
                        ;;
                  RunExampleInputDisable)
                        # Run example first time (banana plugs disconnected)
                        # If device cannot be opened there is a log in result  :
                        # *** ERROR (LINUX) #2:  No such file or directory ***
                        echo "${LogPrefix} RunExampleInputDisable" | tee -a "${TestCaseLogName}" 2>&1
                        echo "${MenPcPassword}" | sudo -S --prompt=$'\r' "${ModuleSimp}" "${ModuleInstanceName}" > ${MModuleName}_${MModuleBoardNr}_${ModuleSimpOutput}_output_disconnected.txt 2>&1
                        ErrorLogCnt=$(grep "ERROR" ${MModuleName}_${MModuleBoardNr}_${ModuleSimpOutput}_output_disconnected.txt | grep "No such file or directory" | wc -l) 
                        CmdResult="${ErrorLogCnt}"
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${ERR_SIMP_ERROR} :could not run ${ModuleSimp} ${ModuleInstanceName} " | tee -a "${TestCaseLogName}" 2>&1
                                MachineRun=false
                        else
                                if [ "${MModuleName}" == "m35" ] && [ "${SubtestName}" == "blkread" ]; then
                                        MachineState="CompareResults"
                                else
                                        MachineState="EnableInput"
                                fi
                        fi
                        ;;
                  EnableInput)
                        echo "${LogPrefix} EnableInput" | tee -a "${TestCaseLogName}" 2>&1
                        change_input "${TestCaseLogName}" "${TestCaseName}" "${CommandCode}" "${InputSwitchTimeout}" "${LogPrefix}"
                        CmdResult=$?
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${CmdResult} in function change_input" | tee -a "${TestCaseLogName}" 2>&1
                                MachineState=false
                        else
                                MachineState="RunExampleInputEnable"
                        fi
                        ;;
                  RunExampleInputEnable)
                        # Run example second time (banana plugs connected)
                        # If device cannot be opened there is a log in result  :
                        # *** ERROR (LINUX) #2:  No such file or directory ***
                        echo "${LogPrefix} RunExampleInputEnable" | tee -a "${TestCaseLogName}" 2>&1
                        echo "${MenPcPassword}" | sudo -S --prompt=$'\r' "${ModuleSimp}" "${ModuleInstanceName}" > ${MModuleName}_${MModuleBoardNr}_${ModuleSimpOutput}_output_connected.txt 2>&1
                        ErrorLogCnt=$(grep "ERROR" ${MModuleName}_${MModuleBoardNr}_${ModuleSimpOutput}_output_connected.txt | grep "No such file or directory" | wc -l) 
                        CmdResult="${ErrorLogCnt}"
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${ERR_SIMP_ERROR} :could not run ${ModuleSimp} ${ModuleInstanceName} " | tee -a ${TestCaseLogName} 2>&1
                                MachineState="DisableInput"
                        else
                                MachineState="CompareResults"
                        fi
                        ;;
                  CompareResults)
                        echo "${LogPrefix} CompareResults" | tee -a "${TestCaseLogName}" 2>&1
                        "${ModuleResultCmpFunc}" "${TestCaseLogName}" "${LogPrefix}" "${MModuleBoardNr}"
                        CmdResult=$?
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${CmdResult} in ${ModuleResultCmpFunc} ${TestCaseLogName} ${TestCaseName} ${MModuleBoardNr}" | tee -a ${TestCaseLogName} 2>&1
                                MachineState="DisableInput"
                                TestError=${CmdResult}
                        else
                                MachineState="DisableInput"
                                TestError=${ERR_OK}
                        fi
                        ;;
                  DisableInput)
                        echo "${LogPrefix} DisableInput" | tee -a "${TestCaseLogName}" 2>&1
                        change_input "${TestCaseLogName}" "${TestCaseName}" $((CommandCode+100)) "${InputSwitchTimeout}" "${LogPrefix}"
                        CmdResult=$?
                        if [ "${CmdResult}" -ne "${ERR_OK}" ]; then
                                echo "${LogPrefix} Error: ${CmdResult} in function change_input" | tee -a "${TestCaseLogName}" 2>&1
                        fi
                        MachineRun=false
                        ;;
                *)
                  echo "${LogPrefix} State is not set, start with ModprobeDriver"
                  MachineState="ModprobeDriver"
                  ;;
                esac
        done

        if [ "${TestError}" -eq "${ERR_UNDEFINED}" ]; then
                return "${CmdResult}"
        else
                return "${TestError}"
        fi
}
