#!/bin/bash

###################################################################
#
# Enable macOS re-install for Macs not on 10.14
#
# Date: Thu  6 Jun 2019 15:52:10 BST
# Version: 0.1.2
# Creator: ganders1
#
##################################################################


# # # # # # 
# SYSTEM CHECKS
# # # # # # 

# Check the install process isn't underway

if [ -e /macOS\ Install\ Data ]
then
# Install proces already underway
exit 0;
fi

##Check if free space > 15GB
freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
if [[ ${freeSpace%.*} -ge 15 ]]; then
    spaceStatus="OK"
    /bin/echo "Disk Check: OK - ${freeSpace%.*} Free Space Detected"
else
    spaceStatus="ERROR"
    /bin/echo "Disk Check: ERROR - ${freeSpace%.*} Free Space Detected"
    exit 0;
fi

username=$( python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");' )
if [ -z $username ]; then
	UserLoggedIn="False"
else
	UserLoggedIn="True"
fi

sleep 2

##Heading to be used for jamfHelper

heading="Please wait as we prepare your computer for macOS Mojave..."

##Title to be used for jamfHelper

description="

This process will take approximately 10-15 minutes.

Once completed your computer will reboot and begin the install."

##Icon to be used for jamfHelper

icon=/Applications/Install\ macOS\ Mojave.app/Contents/Resources/InstallAssistant.icns

##Launch jamfHelper

if [ "${UserLoggedIn}" == "True" ]; then
echo "User present... Starting Jamf helper."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -title "" -icon "$icon" -heading "$heading" -description "$description" &
jamfHelperPID=$(echo $!)
fi
##Start macOS Upgrade
macOS_app_vers=`defaults read "/Applications/Install macOS Mojave.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1$2}'`
macOS_loc_vers=`defaults read "/Library/MacSD/Install macOS Mojave.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1$2}'`
echo $macOS_app_vers

if [ -z $macOS_app_vers ]; then
	macOS_app_vers=136
fi
if [ -z $macOS_loc_vers ]; then
	macOS_loc_vers=136
fi

# remove the receipt for the policy banner, so it gets re-installed.
rm -f /Library/Application\ Support/JAMF/Receipts/SavingPolicyBanner*

if [ $macOS_app_vers -ge 140 ]; then
	echo "first test macOS 14.0 or newer present"
	# Check if we already have a copy of the installer
	if [ $macOS_loc_vers -ge 140 ]; then
    	echo "Second test local MacSD macOS 14.0 or newer present"
        # Copy the installer to our folder so we can retain it for future use
		ditto "/Applications/Install macOS Mojave.app" "/Library/MacSD/Install macOS Mojave.app"
        # delete the login banner as we are updating macOS
		rm -fR /Library/Security/PolicyBanner.rtfd
		if [ "${UserLoggedIn}" == "False" ]; then
			/Library/MacSD/Install\ macOS\ Mojave.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ Mojave.app --nointeraction --agreetolicense 
		else
            /Library/MacSD/Install\ macOS\ Mojave.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ Mojave.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
			osascript -e 'tell application "Self Service" to quit'
        fi
	else
		# Do a delete incase an older version is there
		rm -fR "/Library/MacSD/Install macOS Mojave.app"
        # Add the installer
        echo "attempting to download the OS installer"
        /usr/local/bin/jamf policy -event OS-Installer
		# Copy the installer to our folder so we can retain it for future use
        echo "copying the OS installer to MacSD"
		ditto "/Applications/Install macOS Mojave.app" "/Library/MacSD/Install macOS Mojave.app"
        # delete the login banner as we are updating macOS
		rm -fR /Library/Security/PolicyBanner.rtfd
        if [ "${UserLoggedIn}" == "False" ]; then
			/Library/MacSD/Install\ macOS\ Mojave.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ Mojave.app --nointeraction --agreetolicense 
		else
			/Library/MacSD/Install\ macOS\ Mojave.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ Mojave.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
			osascript -e 'tell application "Self Service" to quit'
        fi
    fi
fi



exit 0;
