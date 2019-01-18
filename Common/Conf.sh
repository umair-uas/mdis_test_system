#! /bin/bash
#
#
# This script contains definition of all variables that have to be defined by user,
#
# Below information about all exit codes that can be used during tests
# Error code description (common for all test cases and this script):
ERR_OK=0                #  0 - no error
ERR_CREATE=1            #  1 - cannot create directory (e.g. no privileges)
ERR_SCAN=2              #  2 - error during scanning the hardware
ERR_MAKE=3              #  3 - error during make on MDIS sources
ERR_INSTALL=4           #  4 - error during install 
ERR_MODPROBE=5          #  5 - error while loading the driver via 'modprobe' command
ERR_RMMOD=6             #  6 - error while removing loaded driver via 'rmmod' command 
ERR_CLEANUP=7           #  7 - could not clean up test case directory
ERR_CONNECT=8           #  8 - could not connect to external device
ERR_SWITCH=9            #  9 - could not enable/disable outputs on external device
ERR_VALUE=10            # 10 - incorrect output value after test
ERR_NOEXIST=11          # 11 - requested file does not exists
ERR_RUN=12              # 12 - error while running example module program
ERR_LOCK_EXISTS=13      # 13 - lock file exists
ERR_LOCK_NO_EXISTS=14   # 14 - lock file not exists
ERR_LOCK_NO_RESULT=15   # 15 - lock, no result yet
ERR_LOCK_INVALID=16     # 16 - invalid lock file, wrong Test Case name, wrong value
ERR_SIMP_ERROR=17       # 17 - error while running module example script 
ERR_NOT_DEFINED=18      # 18 - error, some variable is not defined
ERR_DOWNLOAD=19         # 19 - error while downloading the sources
ERR_CONF=20             # 20 - configuration error
ERR_DIR_EXISTS=21       # 21 - directory exists
ERR_UNDEFINED=99        # 99 - undefined error

# Command code description (common for all test cases and this script)
IN_0_ENABLE=100         # change input 0 to enable (with BL51 stands for OPT1) 
IN_1_ENABLE=101         # change input 1 to enable (with BL51 stands for OPT2) 
IN_2_ENABLE=102         # change input 2 to enable (with BL51 stands for RELAY 1) 
IN_3_ENABLE=103         # change input 3 to enable (with BL51 stands for RELAY 2) 
IN_4_ENABLE=104         # change input 4 to enable
IN_0_DISABLE=200        # change input 0 to disable (with BL51 stands for OPT1) 
IN_1_DISABLE=201        # change input 1 to disable (with BL51 stands for OPT2) 
IN_2_DISABLE=202        # change input 2 to disable (with BL51 stands for RELAY 1)
IN_3_DISABLE=203        # change input 3 to disable (with BL51 stands for RELAY 2) 
IN_4_DISABLE=204        # change input 4 to disable

# Address of Pc that will be tested, Pc should contain all required hardware modules
MenPcIpAddr=""
# Credentials for Pc that will be tested - required by ssh connection and sudo cmds
MenPcLogin=""
MenPcPassword=""

# Address of device that will be changing status of inputs in tested device 
MenBoxPcIpAddr=""
InputSwitchTimeout=10 #seconds

# Credentials, address, and command to download Git repository with Test Cases source
GitTestSourcesMenUser=""
GitTestSourcesMenPassword=""
GitTestSourcesAddr=""
# Fill with proper Git clone command
GitTestSourcesCmd="sshpass -p ${GitTestSourcesMenPassword} \
git clone -b master "

# Credentials, address, and command to download Git repository with 13MD05-90 sources
GitMdisBranch="jpe-dev"
GitMdisCmd="git clone --recursive -b ${GitMdisBranch} https://github.com/MEN-Mikro-Elektronik/13MD05-90.git"
# This is optional if specific commit have to be tested !
# If Commit sha is not defined, then the most recent commit on branch is used. 
# Example: 
# GitMdisCommitSha="15fe1dd75ed20209e5a6165876ac4d6953987f55"
GitMdisCommitSha="" 

# Directory names that are used during tests
# Directory structure as below:
#       MDIS_Test/
#       |-- 13MD05-90
#       |-- Test_Sources
#       `-- Results
#               |--Commit_xxxx
#               `--Commit_xxxx
#
MainTestDirectoryPath="/home/men"
MdisSourcesDirectoryName="13MD05-90" 
TestSourcesDirectoryName="Test_Sources"
MainTestDirectoryName="MDIS_Test"
MdisResultsDirectoryName="Results"

MdisResultsDirectoryPath="${MainTestDirectoryPath}/${MainTestDirectoryName}/${MdisResultsDirectoryName}"
GitTestCommonDirPath="${MainTestDirectoryPath}/${MainTestDirectoryName}/${TestSourcesDirectoryName}/Common"
GitTestTargetDirPath="${MainTestDirectoryPath}/${MainTestDirectoryName}/${TestSourcesDirectoryName}/Target"
GitTestHostDirPath="${MainTestDirectoryPath}/${MainTestDirectoryName}/${TestSourcesDirectoryName}/Host/Jenkins"


ResultsFileLogName="Results_summary.log"

# LockFile can be created only in 
#       ${MainTestDirectoryName}/
#       `-- lock.change.input.tmp
#
# When input change is required - file is created and Test Case name and Command  
# code is written into file. When the change has been done, success / fail flag  
# is added after Command code. When the status is read, file have to be deleted.
# Lock file contains only ONE command code!
# example: 
#       TestCaseName : IN_0_ENABLE : success
# example1: 
#       TestCaseName : IN_2_DISABLE : failed
#
LockFileName="${MainTestDirectoryPath}/${MainTestDirectoryName}/lock.change.input.tmp"
LockFileNameResult="${MainTestDirectoryPath}/${MainTestDirectoryName}/lock.change.input.tmp.result"
LockFileSuccess="success"
LockFileFailed="failed"

# Number of request packets to send
PingPacketCount=3
# Time to wait for a response [s]
PingPacketTimeout=1
# Host to test
PingTestHost=www.google.com

# GRUB configuration file
GrubConfFile=/media/tests/boot.cfg
# Default OS to boot
GrubDefaultOs="Ubuntu"
# List of OSes to test (GRUB menu entries)
GrubOses=("Ubuntu, with Linux 4.15.0-34-generic (on /dev/sda4)" "CentOS Linux 7 (Core) (on /dev/sda6)")
