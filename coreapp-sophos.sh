#!/bin/sh

###################################################################
#
# Script to install Sophos Antivirus from local infratructure and
# configure autoupdate.
#
# This script is intended to be run on the JSS, with $4 - $6
# being provided by the policy that includes this script.
#
# Date: "Wed Mar 6 16:44:41 GMT 2018"
# Version: 0.1.5
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: ganders1
#
##################################################################

TEMP_DIR="/Library/Application Support/JAMF/tmp/sophos"
INSTALL_PROGRAM="/Sophos Installer.app/Contents/MacOS/tools/InstallationDeployer"

# These variables are passed via the JSS
UPDATE_SERVER="$4"
INSTALL_FILE="$5"

## Update every x UPDATE_INTERVALs
UPDATE_FREQUENCY="$6"

## In minutes, so 1440 is 24 hours
UPDATE_INTERVAL="$7"

# Create temporary work area if it doesn't exist
[ ! -d "${TEMP_DIR}" ] && mkdir -p "${TEMP_DIR}"

# Make sure it's empty
rm -rf "${TEMP_DIR}"/*

fix_autoupdate_plist() {
    cat > /Library/Preferences/com.sophos.sau.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>LastUpdated</key>
	<string></string>
	<key>OverrideCredentialsForSaas</key>
	<integer>0</integer>
	<key>PrimaryServerProxy</key>
	<integer>0</integer>
	<key>PrimaryServerProxyPort</key>
	<integer>8080</integer>
	<key>PrimaryServerProxyURL</key>
	<string></string>
	<key>PrimaryServerType</key>
	<integer>1</integer>
	<key>PrimaryServerURL</key>
	<string>${UPDATE_SERVER}</string>
	<key>SecondaryServer</key>
	<false/>
	<key>SecondaryServerProxy</key>
	<integer>0</integer>
	<key>SecondaryServerProxyPort</key>
	<integer>8080</integer>
	<key>SecondaryServerProxyURL</key>
	<string></string>
	<key>SecondaryServerType</key>
	<integer>0</integer>
	<key>SecondaryServerURL</key>
	<string></string>
	<key>UpdateFrequency</key>
	<integer>${UPDATE_FREQUENCY}</integer>
	<key>UpdateInterval</key>
	<integer>${UPDATE_INTERVAL}</integer>
	<key>UpdateLogIntoFile</key>
	<false/>
	<key>UpdateLogIntoSyslog</key>
	<false/>
	<key>UpdateOnConnection</key>
	<false/>
	<key>UpdateUnits</key>
	<integer>2</integer>
</dict>
</plist>
EOF
    ## Kick the config demon so that it picks up settings
    /usr/bin/killall -HUP SophosConfigD
}
    
# Check if Sophos has been previously installed
if [ -f "/Applications/Sophos Anti-Virus.app/Contents/MacOS/Sophos Anti-Virus" ]
then
        version=`defaults read "/Applications/Sophos Anti-Virus.app/Contents/Info" CFBundleShortVersionString)`
        compare_version=`echo "$version" | awk -F "." '{print $1$2}'`
        if [ $compare_version -gt 96 ]
        then
                # Disable web protection - it leaks information and slows down web browsing
                defaults write /Library/Preferences/com.sophos.sav.plist WebProtectionFilteringEnabled -bool false
                defaults write /Library/Preferences/com.sophos.sav.plist WebProtectionScanningEnabled -bool false
		logger "$0: Found Sophos version 9.6.x + installed - will not attempt reinstall"
                fix_autoupdate_plist
		exit 0
        else
	        logger "$0: Sophos < 9.6 found - will attempt to re-install"
	        	# Run Sophos' uninstall process to allow a clean version to be applied.
	        	SophosInstaller=`find "/Library/Application Support/Sophos" -type d -name "Installer.app"`
	        	"${SophosInstaller}"/Contents/MacOS/tools/InstallationDeployer --remove
                # Scrub the autoupdate cache and lockfile in preparation for our new installation
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
/usr/bin/curl ${UPDATE_SERVER}/${INSTALL_FILE} > ${TEMP_DIR}/${INSTALL_FILE}
cd "${TEMP_DIR}"
unzip ${INSTALL_FILE} 

# Install Sophos
# Inexplicably this ends up non-executable
chmod +x "${TEMP_DIR}/${INSTALL_PROGRAM}"
"${TEMP_DIR}/${INSTALL_PROGRAM}" --install

if [ "$?" == 0 ]
then
    logger "$0: Installed Sophos"

    fix_autoupdate_plist

    ## Clean up after ourselves
    rm -rf "${TEMP_DIR}"

    # Reset the com.sophos.sav file, just incase
    if test -e "/Library/Preferences/com.sophos.sav.plist"
    then
	    version=`defaults read /Applications/Sophos\ Anti-Virus.app/Contents/Info CFBundleShortVersionString | awk -F "." '{print $1}'`
	    if [ $version == 9 ]
	    then
		    # Disable web protection
		    defaults write /Library/Preferences/com.sophos.sav.plist WebProtectionFilteringEnabled -bool false
		    defaults write /Library/Preferences/com.sophos.sav.plist WebProtectionScanningEnabled -bool false
        fi
    fi

    ## Update Sophos
    /usr/local/bin/SophosUpdate

    exit 0
else
    logger "$0: Failed to install Sophos. Error Code: ${?}"
    # Don't clean up: allow support staff to try to work our what went wrong!
    # The script will clean up the temp area on its next invocation so we
    # don't need to worry about filling up the disk.
    exit 255
fi
