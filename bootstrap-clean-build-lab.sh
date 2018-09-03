#!/bin/bash

set -euo pipefail
###################################################################
#
# This script will perform a clean build of a machine running 10.13.>4
#
# The variable BUILD_ID should be provided with, the build ID of the
# version of 10.13 to be used to initiate the build. 
# 
# The requested build version will be downloaded prior to being used
# for the clean build
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

BUILD_ID="${4}" # Currently 17G65
DOWNLOADER="installinstallmacos.py"
DOWNLOADER_URL="https://raw.githubusercontent.com/grahampugh/macadmin-scripts/master/${DOWNLOADER}"
QUICKADD_PKG="/Library/MacSD/QuickAddLab-0.1-1.pkg" # Should have been installed before this script runs

tmpdir=$(mktemp -d /tmp/cleanbuild.XXXX)

function cleanup {
    rm -rf ${tmpdir}
    echo "Cleaned up"
}

# Cleanup if anything goes wrong
trap cleanup EXIT

function os_version_ok {
    # Now we can attempt the clean build. Check environment is sensible. We need:
    #       * 10.13.>4 already installed
    #       * An AFP formatted system volume
    os_version=$(sw_vers -productVersion)
    os_minor=$(echo ${os_version} | awk -F '.' '{print $2}')
    os_micro=$(echo ${os_version} | awk -F '.' '{print $3}')

    [ "${os_minor}" == "13" ] && [[ ${os_micro} -ge 4 ]]
}

function boot_vol_is_apfs {
    [ "$(diskutil info / | grep Personality | awk '{print $NF}')" == 'APFS' ]
}


if ! os_version_ok  
then
    echo "OS version is not 10.13 >= 10.13.4"
    exit 1
elif ! boot_vol_is_apfs 
then
    echo "Boot volume is not APFS"
    exit 1
elif [ ! -f ${QUICKADD_PKG} ]
then
    echo "Quickadd package not available at ${QUICKADD_PKG}"
    exit 1
fi

pushd ${tmpdir} 

# First, download the script that we will use to download 10.13 from Apple's servers
if curl -L "${DOWNLOADER_URL}" > "${DOWNLOADER}"
then
    echo "Downloaded installinstallmacos.py"
else
    echo "Failed to download installinstallmacos.py from ${DOWNLOADER_URL}"
    exit 1
fi

# Now, download the reqested build of 10.13
python ./installinstallmacos.py --build ${BUILD_ID} 

# That script leaves use with a disk image containing our installer
hdiutil attach "Install_macOS_10.13.6-${BUILD_ID}.sparseimage" 

# If that succeeded we should now have an installer - let's take a look
if [ ! -x "/Volumes/Install_macOS_10.13.6-17G65/Applications/Install macOS High Sierra.app/Contents/Resources/startosinstall" ]
then
    echo "Something went wrong - failed to find the installer!"
    exit 1
else
    /Volumes/Install_macOS_10.13.6-17G65/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall \
        --volume / \
        --newvolumename "Macintosh HD"
        --converttoapfs YES \
        --agreetolicense \
        --nointeraction \
        --installpackage ${QUICKADD_PACKAGE}
fi




