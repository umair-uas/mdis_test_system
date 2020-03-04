#! /bin/bash

MyDir="$(dirname "$0")"
source "${MyDir}/../../Common/Conf.sh"
source "${MyDir}/Mdis_Test_Functions.sh"
LogPrefix="[Mdis_Test]"

# This script checks if hardware is present
# Mdis Test run result identification
Today=$(date +%Y_%m_%d_%H_%M_%S)

BuildMdis="1"

# read parameters
while test $# -gt 0 ; do
    case "$1" in
        --run-instantly)
                shift
                RunInstantly="1"
                ;;
        --no-build)
                shift
                BuildMdis="0"
                ;;
        *)
                echo "No valid parameters"
                break
                ;;
        esac
done

echo "Test Setup: ${TestSetup}"
case ${TestSetup} in
        1)
          GrubOses=( "${GrubOsesF23P[@]}" )
          ;;
        2)
          GrubOses=( "${GrubOsesF26L[@]}" )
          ;;
        3)
          GrubOses=( "${GrubOsesG23[@]}" )
          ;;
        4)
          GrubOses=( "${GrubOsesG25A[@]}" )
          ;;
        5)
          GrubOses=( "${GrubOsesBL51E[@]}" )
          ;;
        6)
          GrubOses=( "${GrubOsesG25A[@]}" )
          ;;
        *)
                echo "TEST SETUP IS NOT SET"
                exit 99
                ;;
esac
        echo "GrubOses: ${GrubOses}"

MdisTestBackgroundPID=0

trap cleanOnExit SIGINT SIGTERM
function cleanOnExit() {
        echo "** cleanOnExit"
        echo "MdisTestBackgroundPID: ${MdisTestBackgroundPID}"
        if [ ${MdisTestBackgroundPID} -ne 0 ]; then
            # Kill process
            echo "${LogPrefix} kill process ${MdisTestBackgroundPID}"

            if ! kill ${MdisTestBackgroundPID}
            then
                    echo "${LogPrefix} Could not kill cat backgroung process ${MdisTestBackgroundPID}"
            else
                    echo "${LogPrefix} process ${MdisTestBackgroundPID} killed"
            fi
            sleep 1
            jobs
            grub_set_os "0"
        fi
        exit
}

function cleanMdisTestBackgroundJob {
        echo "** cleanOnExit"
        if [ ${MdisTestBackgroundPID} -ne 0 ]; then
            # Kill process
            echo "${LogPrefix} kill process ${MdisTestBackgroundPID}"

            if ! kill  ${MdisTestBackgroundPID}
            then
                    echo "${LogPrefix} Could not kill cat backgroung process ${MdisTestBackgroundPID}"
            else
                    echo "${LogPrefix} process ${MdisTestBackgroundPID} killed"
            fi
            sleep 1
            jobs
        fi
}

function runTests {
            # run
            St_Test_Setup_Configuration="St_Test_Configuration_x.sh"
            echo "run:"
            echo "${St_Test_Setup_Configuration} ${TestSetup}"

            # Make all scripts executable
            run_cmd_on_remote_pc "echo ${MenPcPassword} | sudo -S --prompt=$'\r' chmod +x ${GitTestCommonDirPath}/*"
            run_cmd_on_remote_pc "echo ${MenPcPassword} | sudo -S --prompt=$'\r' chmod +x ${GitTestTargetDirPath}/*"
            run_cmd_on_remote_pc "echo ${MenPcPassword} | sudo -S --prompt=$'\r' chmod +x ${GitTestHostDirPath}/*"

            ./Mdis_Test_Background.sh &

            # Save background process PID
            MdisTestBackgroundPID=$!
            echo "${LogPrefix} MdisTestBackgroundPID is ${MdisTestBackgroundPID}"

            # Run Test script - now scripts from remote device should be run
            make_visible_in_log "TEST CASE - ${St_Test_Setup_Configuration} ${TestSetup}"
            if ! run_cmd_on_remote_pc "echo ${MenPcPassword} | sudo -S --prompt=$'\r' ${GitTestTargetDirPath}/${St_Test_Setup_Configuration} ${TestSetup} ${BuildMdis} ${Today}"
            then
                    echo "${LogPrefix} Error while running St_Test_Configuration script"
            fi

            cleanMdisTestBackgroundJob
            # Initialize tested device 
            # run_cmd_on_remote_pc "mkdir $TestCaseDirectoryName"
            # Below command must be run from local device, 
            # Test scripts have not been downloaded into remote yet.
}

#function run_single_test {
#
#}

# MAIN start here
if [ "${RunInstantly}" == "1" ]; then
            ssh-keygen -R "${MenPcIpAddr}"
            # Check if devices are available
            if ! ping -c 2 "${MenPcIpAddr}"
            then
                    echo "${MenPcIpAddr} is not responding"
            fi

            cat "${MyDir}/../../Common/Conf.sh" > tmp.sh
            echo "RunInstantly=\"1\"" >> tmp.sh
            cat "${MyDir}"/Pc_Configure.sh >> tmp.sh

            if ! run_script_on_remote_pc "${MyDir}"/tmp.sh
            then
                    echo "${LogPrefix} Pc_Configure script failed"
                    exit 
            fi
            rm tmp.sh

            runTests
else
    grub_set_os "0"
    for ExpectedOs in "${GrubOses[@]}"; do
            ssh-keygen -R "${MenPcIpAddr}"
            # Check if devices are available
            if ! ping -c 2 "${MenPcIpAddr}"
            then
                    echo "${MenPcIpAddr} is not responding"
                    break
            fi
            CurrentOs="$(grub_get_os)"
            if [ "${CurrentOs}" == "" ]; then
                    echo "Failed to get OS"
                    break
            fi
            if [ "${CurrentOs}" == "${ExpectedOs}" ]; then
                    if [ "${ExpectedOs}" == "${GrubOses[0]}" ]; then
                            continue
                    fi
                    echo "Unexpected OS \"${CurrentOs}\" while \"${ExpectedOs}\" was expected"
                    break
            fi
            grub_set_os "${ExpectedOs}"
            SetOs="$(grub_get_os)"
            if [ "${SetOs}" != "${ExpectedOs}" ]; then
                    echo "Failed to set OS"
                    break
            fi
            if ! reboot_and_wait
            then
                    echo "${MenPcIpAddr} is not responding"
                    break
            fi
            ssh-keygen -R "${MenPcIpAddr}"

            cat "${MyDir}/../../Common/Conf.sh" "${MyDir}"/Pc_Configure.sh > tmp.sh
            if ! run_script_on_remote_pc "${MyDir}"/tmp.sh
            then
                    echo "${LogPrefix} Pc_Configure script failed"
                    exit 
            fi

            rm tmp.sh
            runTests
    done
fi
cleanOnExit