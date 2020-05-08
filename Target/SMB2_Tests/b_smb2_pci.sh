#! /bin/bash
MyDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${MyDir}/../../Common/Conf.sh"
source "${MyDir}/../St_Functions.sh"

############################################################################
# b_smb2_pci_description
#
# parameters:
# $1    Module number
# $2    Module log path 
function b_smb2_pci_description {
    local ModuleNo=${1}
    local ModuleLogPath=${2}
    local TestSummaryDirectory="${3}"
    local LongDescription="${4}"
    echo "---------------------SMB2 pci card Test Case-----------------------"
    echo "PREREQUISITES:"
    echo "    It is assumed that at this point all necessary drivers have been build and"
    echo "    are available in the system"
    echo "DESCRIPTION:"
    echo "    1.Get HW name to configure proper device address"
    echo "    2.Disable PCIe slot"
    echo "    3.Check if PCIe slot has been disabled"
    echo "    4.Enable PCIe slot"
    echo "PURPOSE:"
    echo "    Check if PCIe slot disabling is working"
    echo "REQUIREMENT_ID:"
    echo "RESULTS"
    echo "    SUCCESS if test is passed without error(s) warning(s)"
    echo "    FAIL otherwise"
    echo ""
}

############################################################################
# run board smb2 pci card test
#
# parameters:
# $1    Log file
# $2    Log prefix
# $3    M-Module number
function b_smb2_pci_test {
    local TestCaseId="${1}"
    local TestSummaryDirectory="${2}"
    local OsNameKernel="${3}"
    local LogFile=${4}
    local LogPrefix=${5}
    local BoardInSystem=${6}
    local DeviceAddress
    local HwName

    MachineState="Step1"
    MachineRun=true

    DevName="smb2_1"    # smb device name (e.g. smb2_1)

    while ${MachineRun}; do
        case ${MachineState} in
            Step1)
                debug_print "${LogPrefix} Run step @1" "${LogFile}"
                HwName="$(run_as_root smb2_boardident "${DevName}" | grep "HW-Name[[:space:]]\+=")"
                if [[ "${HwName}" =~ [[:space:]]*HW-Name[[:space:]]+=[[:space:]]+([A-Za-z0-9]+).* ]]; then
                    HwName="${BASH_REMATCH[1]}"
                    case "${HwName}" in
                       "S25") DeviceAddress="0x40";;
                       "S24") DeviceAddress="0x42";;
                       *) DeviceAddress="0x42";;
                    esac
                    TestCaseStep1=${ERR_OK}
                    MachineState="Step2"
                else
                    debug_print "${LogPrefix}  ERR_VALUE: HW-Name not found with smb2_boardident" "${LogFile}"
                    TestCaseStep1=${ERR_VALUE}
                    MachineState="Break"
                fi
                ;;
            Step2)
                debug_print "${LogPrefix} Run step @2" "${LogFile}"
                if ! run_as_root smb2_ctrl smb2_1 -a=${DeviceAddress} wb -d=0x00 > "smb2_crtl_disable.log"; then
                    debug_print "${LogPrefix}  ERR_VALUE: Could not disable PCIe with smb2_ctrl" "${LogFile}"
                    TestCaseStep2=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep2=${ERR_OK}
                    MachineState="Step3"
                fi
                ;;
            Step3)
                debug_print "${LogPrefix} Run step @3" "${LogFile}"
                if lsubs -d 0403:6001 > lsusb_disabled.log; then
                    debug_print "${LogPrefix}  PCIe has not been disabled" "${LogFile}"
                    TestCaseStep3=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep3=${ERR_OK}
                    MachineState="Step4"
                fi
                ;;
            Step4)
                debug_print "${LogPrefix} Run step @4" "${LogFile}"
                if ! run_as_root smb2_ctrl smb2_1 -a=${DeviceAddress} wb -d=0xff > "smb2_crtl_enable.log"; then
                    debug_print "${LogPrefix}  Could not enable PCIe with smb2_ctrl" "${LogFile}"
                    TestCaseStep4=${ERR_VALUE}
                    MachineState="Break"
                else
                    TestCaseStep4=${ERR_OK}
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
       [ "${TestCaseStep3}" = "${ERR_OK}" ] && [ "${TestCaseStep4}" = "${ERR_OK}" ]; then
        return "${ERR_OK}"
    else
        return "${ERR_VALUE}"
    fi
}