#!/bin/sh

## Script to install Sophos Antivirus

TEMP_DIR="/Library/Application Support/JAMF/tmp/sophos"
UPDATE_SERVER="$4"
INSTALL_FILE="$5"

# Create temporary work area if it doesn't exist
[ ! -d "${TEMP_DIR}" ] && mkdir -p "${TEMP_DIR}"

# Check if Sophos has been previously installed
if [ -f "/Library/Caches/com.sophos.sau/CID/cidsync.upd" ]
then
        version=`defaults read /Applications/Sophos\ Anti-Virus.app/Contents/Info CFBundleShortVersionString | awk -F "." '{print $1}'`
        if [ $version == 9 ]
        then
                # Disable web protection - it leaks information and slows down web browsing
                defaults write /Library/Preferences/com.sophos.sav WebProtectionFilteringEnabled -bool false
                defaults write /Library/Preferences/com.sophos.sav WebProtectionScanningEnabled -bool false
		logger "$0: Found Sophos installed - will not attempt reinstall"
                exit 0;
        else
	        logger "$0: Sophos < 9 found - will attempt to re-install"
                # Scrub the autoupdate cache and lockfile then do an update (pkg installs new update server)
                rm -f /Library/Caches/com.sophos.sau/CID/cidsync.upd
                rm -f /Library/Caches/com.sophos.sau/sophosautoupdate.plist
                rm -f /Library/Preferences/com.sophos.sau.plist.lockfile                
                sleep 1
                rm -dfR /Library/Caches/com.sophos.sau
        fi      
else
    logger "$0: No previous sophos installation detected. Will attempt install."
fi

# Download and install Sophos AV

# Rather than try to keep up with Sophos upgrades, download the newest version from the local source
/usr/bin/curl ${UPDATE_SERVER}/${INSTALL_FILE} > ${TEMP_DIR}/
cd "${TEMP_DIR}"
unzip ${INSTALL_FILE} 

# Install Sophos

"${TEMP_DIR}/Sophos Installer.app/Contents/MacOS/tools/InstallationDeployer" --install

if [ "$?" == 0 ]
then
    logger "$0: Installed Sophos"
    exit 0
else
    logger "$0: Failed to install Sophos. Error Code: ${?}"
    exit 255
fi

