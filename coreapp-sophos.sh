#!/bin/sh

## Script to install Sophos Antivirus

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

# Check if Sophos has been previously installed
if [ -f "/Applications/Sophos Anti-Virus.app/Contents/MacOS/Sophos Anti-Virus" ]
then
        version=$(defaults read "/Applications/Sophos Anti-Virus.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1}')
        if [ $version == 9 ]
        then
                # Disable web protection - it leaks information and slows down web browsing
                defaults write /Library/Preferences/com.sophos.sav WebProtectionFilteringEnabled -bool false
                defaults write /Library/Preferences/com.sophos.sav WebProtectionScanningEnabled -bool false
		logger "$0: Found Sophos version 9 installed - will not attempt reinstall"
                fix_autoupdate_plist
		exit 0
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
    exit 0
else
    logger "$0: Failed to install Sophos. Error Code: ${?}"
    exit 255
fi

