#!/bin/bash

###################################################################
#
# This script triggers a custom event ('filevault-init')
# if filevault is currently disabled and the user logging
# in is a valid user in our directory service.
#
# Date: Thu 20 Dec 2018 14:17:54 GMT
# Version: 0.1.7
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################


heading="FileVault Encryption Setup"

description="You need to log out and enter your password to complete the FileVault encryption process.

This is required on mobile devices which contain University data."

icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"


filevault_is_enabled() {
  fdesetup status | grep 'FileVault is On'
  [ $? == 0 ]
}

# in-built jamf variable $3, doesn't seem to be returning a valid username, even if a uun account is logged on.
user_name=`ls -l /dev/console | awk '{print $3}'`
# Volume format
VOL=`diskutil info / | grep Personality | awk -F':' ' { print $NF } ' | sed -e 's/^[[:space:]]*//'`

if ! filevault_is_enabled
then
    # Reset the filevault status incase the defered enablement is broken.
    fdesetup disable
    rm -f /Library/Preferences/com.apple.fdesetup.plist
    # Check if apfs
    if [ "$VOL" == "APFS" ]; then
    	diskutil apfs updatePreboot /
    fi
    # This causes the 'UoE - FileVault - Initialise' policy to
    # set things up such that FileVault will be enabled for the
    # current user on next logout
    /usr/local/bin/jamf policy -event filevault-init
    
    # Now force the user to log out to complete the enablement process
	HELPER=`"${jamfHelper}" -windowType utility -icon "$icon" -heading "$heading" -description "$description" -button1 "Log Out Now"`
	echo "$0: jamf helper result was $HELPER";

	if [ "$HELPER" == "0" ]; then
		# Perform a graceful logout
		result="$(sudo -u ${user_name} osascript -e 'tell application "loginwindow" to «event aevtrlgo»')"
	fi
else
  echo "$0: Filevault is active"
fi

exit 0;
