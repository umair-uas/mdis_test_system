#! /bin/bash
MyDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${MyDir}/../../Common/Conf.sh"
source "${MyDir}/../St_Functions.sh"

############################################################################
# b_smb2_led_description
#
# parameters:
# $1    Module number
# $2    Module log path 
function b_smb2_led_description {
    local ModuleNo=${1}
    local ModuleLogPath=${2}
    local TestSummaryDirectory="${3}"
    local LongDescription="${4}"
    echo "---------------------SMB2 led Test Case-----------------------"
    echo "PREREQUISITES:"
    echo "    It is assumed that at this point all necessary drivers have been build and"
    echo "    are available in the system"
    echo "DESCRIPTION:"
    echo "    1.Load drivers: modprobe men_mdis_kernel"
    echo "    2.Get HW name to configure proper device address"
    echo "    3.Turn LEDs on"
    echo "    4.Check if LEDs are on"
    echo "    5.Turn LEDs off"
    echo "    6.Check if LEDs are off"
    echo "PURPOSE:"
    echo "    Check if user LEDs can be enabled"
    echo "UPPER_REQUIREMENT_ID:"
    print_env_requirements "${TestSummaryDirectory}"
    echo "    MEN_13MD0590_SWR_1950"
    #echo "REQUIREMENT_ID:"
    #echo "    MEN_13MD05-90_SA_1600"
    echo "RESULTS"
    echo "    SUCCESS if test is passed without error(s) warning(s)"
    echo "    FAIL otherwise"
    echo ""
}

############################################################################
# run board smb2 led test, turn on/off leds
#
# parameters:
# $1    Log file
# $2    Log prefix
# $3    M-Module number
function b_smb2_led_test {
    local TestCaseId="${1}"
    local TestSummaryDirectory="${2}"
    local OsNameKernel="${3}"
    local LogFile=${4}
    local LogPrefix=${5}
    local BoardInSystem=${6}
    local DeviceAddress
    local HwName
    local LEDsOn
    local LEDsOff

    MachineState="Step1"
    MachineRun=true

    DevName="smb2_1"    # smb device name (e.g. smb2_1)

    while ${MachineRun}; do
        case ${MachineState} in
            Step1)
                debug_print "${LogPrefix} Run step @1" "${LogFile}"
                if ! run_as_root modprobe men_mdis_kernel
                then
                    debug_print "${LogPrefix}  ERR_MODPROBE: could not modprobe men_mdis_kernel" "${LogFile}" 
                    TestCaseStep1=${ERR_MODPROBE}
                    MachineState="Break"
                else
                    TestCaseStep1=${ERR_OK}
                    MachineState="Step2"
                fi
                ;;
            Step2)
                debug_print "${LogPrefix} Run step @2" "${LogFile}"
                HwName="$(run_as_root smb2_boardident "${DevName}" | grep "HW-Name[[:space:]]\+=")"
                if [[ "${HwName}" =~ [[:space:]]*HW-Name[[:space:]]+=[[:space:]]+([A-Za-z0-9]+).* ]]; then
                    HwName="${BASH_REMATCH[1]}"
                    case "${HwName}" in
                       "SC25")
                           DeviceAddress="0x40"
                           LEDsOn="f0"
                           LEDsOff="ff"
                           ;;
                       "SC24")
                           DeviceAddress="0x40"
                           LEDsOn="00"
                           LEDsOff="ff"
                           ;;
                       *)
                           DeviceAddress="0x40"
                           LEDsOn="00"
                           LEDsOff="ff"
                           ;;
                    esac
                    debug_print "${LogPrefix} Using device address: ${DeviceAddress}" "${LogFile}"
                    TestCaseStep2=${ERR_OK}
                    MachineState="Step3"
                else
                    debug_print "${LogPrefix}  ERR_VALUE: HW-Name not found with smb2_boardident" "${LogFile}"
                    TestCaseStep2=${ERR_VALUE}
                    MachineState="Break"
                fi
                ;;
            Step3)
                debug_print "${LogPrefix} Run step @3" "${LogFile}"
                if ! run_as_root smb2_ctrl smb2_1 -a=${DeviceAddress} wb -d=0x${LEDsOn} > "smb2_crtl_enable.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: Could not enable LEDs" "${LogFile}"
                    TestCaseStep3=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep3=${ERR_OK}
                    MachineState="Step4"
                fi
                ;;
            Step4)
                debug_print "${LogPrefix} Run step @4" "${LogFile}"
                sleep 3
                if ! run_as_root smb2_ctrl smb2_1 -a=${DeviceAddress} rb > "smb2_crtl_isenabled.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: Could not get LEDs status" "${LogFile}"
                    TestCaseStep4=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep4=${ERR_OK}
                    MachineState="Step5"
                fi
                ;;
            Step5)
                debug_print "${LogPrefix} Run step @5" "${LogFile}"
                if ! grep "^${LEDsOn}\$" "smb2_crtl_isenabled.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: LEDs have not been enabled" "${LogFile}"
                    TestCaseStep5=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep5=${ERR_OK}
                    MachineState="Step6"
                fi
                ;;
            Step6)
                debug_print "${LogPrefix} Run step @6" "${LogFile}"
                if ! run_as_root smb2_ctrl smb2_1 -a=${DeviceAddress} wb -d=0x${LEDsOff} > "smb2_crtl_disable.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: Could not disable LEDs" "${LogFile}"
                    TestCaseStep6=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep6=${ERR_OK}
                    MachineState="Step7"
                fi
                ;;
            Step7)
                debug_print "${LogPrefix} Run step @7" "${LogFile}"
                sleep 3
                if ! run_as_root smb2_ctrl smb2_1 -a=${DeviceAddress} rb > "smb2_crtl_isdisabled.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: Could not get LEDs status" "${LogFile}"
                    TestCaseStep7=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep7=${ERR_OK}
                    MachineState="Step8"
                fi
                ;;
            Step8)
                debug_print "${LogPrefix} Run step @8" "${LogFile}"
                if ! grep "^${LEDsOff}\$" "smb2_crtl_isdisabled.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: LEDs have not been disabled" "${LogFile}"
                    TestCaseStep8=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep8=${ERR_OK}
                    MachineState="Break"
                fi
                ;;
            Break) # Clean after Test Case
                debug_print "${LogPrefix} Break State" "${LogFile}"
                MachineRun=false
                ;;
            *)
                debug_print "${LogPrefix} State is not set, start with Step1" "${LogFile}"
                MachineState="Step1"
                ;;
        esac
    done

    if [ "${TestCaseStep1}" = "${ERR_OK}" ] && [ "${TestCaseStep2}" = "${ERR_OK}" ] &&\
       [ "${TestCaseStep3}" = "${ERR_OK}" ] && [ "${TestCaseStep4}" = "${ERR_OK}" ] &&\
       [ "${TestCaseStep5}" = "${ERR_OK}" ] && [ "${TestCaseStep6}" = "${ERR_OK}" ] &&\
       [ "${TestCaseStep7}" = "${ERR_OK}" ] && [ "${TestCaseStep8}" = "${ERR_OK}" ]; then
        return "${ERR_OK}"
    else
        return "${ERR_VALUE}"
    fi
}
