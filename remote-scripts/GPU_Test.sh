#!/bin/bash

########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################
########################################################################
#
# Description:
#	This script installs NVidia GPU drivers.
#
#	Steps:
#	1. Installs dependencies
#	2. Compiles and installs GPU Drievers
#	3. -logFolder parameter is supported (Optional)
#	
#
########################################################################

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

CUDADriverVersion="8.0.61-1"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error while performing the test
CONSTANTS_FILE="constants.sh"

if [ ! ${logFolder} ]; then
    logFolder="/root"
fi

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi


#######################################################################
# Adds a timestamp to the log file
#######################################################################
LogMsg() {
    echo $(date "+%a %b %d %T %Y") : ${1}
	echo $(date "+%a %b %d %T %Y") : ${1} >> $logFolder/GPU_Test_Logs.txt 
}

#######################################################################
# Updates the summary.log file
#######################################################################
UpdateSummary() {
    echo $1 >> $logFolder/summary.log
}

#######################################################################
# Keeps track of the state of the test
#######################################################################
UpdateTestState() {
    echo $1 > $logFolder/state.txt
}

#######################################################################
# Install dependencies and GPU Driver
#######################################################################
InstallGPUDrivers() {
		DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`

        if [[ $DISTRO =~ "Ubuntu 16.04" ]];
        then
                LogMsg "Detected UBUNUT1604"
				if [[ $enableProposedRepo == "yes" ]];
				then
					LogMsg "Enabling proposed repositry..."
					echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe" >> /etc/apt/sources.list
					rm -rf /etc/apt/preferences.d/proposed-updates
					LogMsg "Installing linux-image-generic from proposed repository."
					apt-get -y update
					apt-get -y upgrade linux-image-generic
				fi
				CUDA_REPO_PKG="cuda-repo-ubuntu1604_${CUDADriverVersion}_amd64.deb"
				LogMsg "Using ${CUDA_REPO_PKG}"
				wget http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG} -O /tmp/${CUDA_REPO_PKG}
				dpkg -i /tmp/${CUDA_REPO_PKG}
				rm -f /tmp/${CUDA_REPO_PKG}
				apt-get -y update
				apt-get -y install linux-tools-generic linux-cloud-tools-generic
				apt-get -y install cuda-drivers
				
        elif [[ $DISTRO =~ "Ubuntu 14.04" ]];
        then
                LogMsg "Detected UBUNTU1404"
				if [[ $enableProposedRepo == "yes" ]];
				then
					LogMsg "Enabling proposed repositry..."
					echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe" >> /etc/apt/sources.list
					rm -rf /etc/apt/preferences.d/proposed-updates
					LogMsg "Installing linux-image-generic from proposed repository."
					apt-get -y update
					apt-get -y upgrade linux-image-generic
				fi
				CUDA_REPO_PKG="cuda-repo-ubuntu1404_${CUDADriverVersion}_amd64.deb"
				LogMsg "Using ${CUDA_REPO_PKG}"				
				wget http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/${CUDA_REPO_PKG} -O /tmp/${CUDA_REPO_PKG}
				dpkg -i /tmp/${CUDA_REPO_PKG}
				rm -f /tmp/${CUDA_REPO_PKG}
				apt-get -y update
				apt-get -y install linux-tools-generic linux-cloud-tools-generic
				apt-get -y install cuda-drivers

        elif [[ $DISTRO =~ "CentOS Linux release 7.3" ]];
        then
                LogMsg "Detected CENTOS73"
				#sed -i '/# OS.EnableRDMA=y/c\  OS.EnableRDMA=y' /etc/waagent.conf
				yum -y update
				yum -y --nogpgcheck install kernel-devel
				rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm				
				yum --nogpgcheck -y install dkms
				CUDA_REPO_PKG="cuda-repo-rhel7-${CUDADriverVersion}.x86_64.rpm"
				LogMsg "Using ${CUDA_REPO_PKG}"					
				wget http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/${CUDA_REPO_PKG} -O /tmp/${CUDA_REPO_PKG}
				rpm -ivh /tmp/${CUDA_REPO_PKG}
				rm -f /tmp/${CUDA_REPO_PKG} 
				yum --nogpgcheck -y install cuda-drivers
        else
                LogMsg "Unknown Distro"
                UpdateTestState "TestAborted"
                UpdateSummary "Unknown Distro, test aborted"
                return 1
        fi
}

######################################################################
#MAIN
######################################################################

LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING
InstallGPUDrivers
if [[ $? == 0 ]];
then
	LogMsg "GPU_DRIVER_INSTALLATION_SUCCESSFUL"
else
	LogMsg "GPU_DRIVER_INSTALLATION_FAIL"
fi
UpdateTestState $ICA_TESTCOMPLETED
exit 0