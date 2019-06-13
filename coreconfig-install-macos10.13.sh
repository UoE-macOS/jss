#!/bin/bash

###################################################################
#
# Enable macOS re-install for Macs not on 10.13
#
# Date: Thu 13 Jun 2019 14:33:58 BST
# Version: 0.1.3
# Creator: ganders1
#
##################################################################

date > /Users/Shared/installTST.log

# # # # # # 
# SYSTEM CHECKS
# # # # # # 

# Check the install process isn't underway

if [ -e /macOS\ Install\ Data ]
then
# Install proces already underway
exit 0
fi

##Check if free space > 15GB
freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
if [[ ${freeSpace%.*} -ge 15 ]]; then
    spaceStatus="OK"
    /bin/echo "Disk Check: OK - ${freeSpace%.*} Free Space Detected" >> /Users/Shared/installTST.log
else
    spaceStatus="ERROR"
    /bin/echo "Disk Check: ERROR - ${freeSpace%.*} Free Space Detected" >> /Users/Shared/installTST.log
fi

username=`who | grep console | awk '{print $1}'`
if [ -z $username ]; then
	NoUser=True
else
	NoUser=False
fi

sleep 2

##Heading to be used for jamfHelper

heading="Please wait as we prepare your computer for macOS High Sierra..."

##Title to be used for jamfHelper

description="

This process will take approximately 10-15 minutes.

Once completed your computer will reboot and begin the install."

##Icon to be used for jamfHelper

icon=/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/InstallAssistant.icns

##Launch jamfHelper

if [ $NoUser == False ]; then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -title "" -icon "$icon" -heading "$heading" -description "$description" &
jamfHelperPID=$(echo $!)
fi
##Start macOS Upgrade
macOS_app_vers=`defaults read "/Applications/Install macOS High Sierra.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1$2}'`
macOS_loc_vers=`defaults read "/Library/MacSD/Install macOS High Sierra.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1$2}'`
echo $macOS_app_vers

if [ -z $macOS_app_vers ]; then
	macOS_app_vers=126
fi

if [ $macOS_app_vers -ge 134 ]; then
	echo "first test macOS 13.4 or newer present"
	# Check if we already have a copy of the installer
	if [ $macOS_loc_vers -ge 134 ]; then
    
    	echo "Second test local MacSD macOS 13.4 or newer present"
        # Copy the installer to our folder so we can retain it for future use
		ditto "/Applications/Install macOS High Sierra.app" "/Library/MacSD/Install macOS High Sierra.app"
        # delete the login banner as we are updating macOS
		rm -fR /Library/Security/PolicyBanner.rtfd
        # Create the upgrade flag to ensure a recon after the upgrade.
		touch /Library/MacSD/SUDONE

        if [ $NoUser == True ]; then
			/Library/MacSD/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense 
		else
            /Library/MacSD/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
			osascript -e 'tell application "Self Service" to quit'
        fi
	else
		# Do a delete incase an older version is there
		rm -fR "/Library/MacSD/Install macOS High Sierra.app"
        # Add the installer
        /usr/local/bin/jamf policy -event OS-Installer
		# Copy the installer to our folder so we can retain it for future use
		ditto "/Applications/Install macOS High Sierra.app" "/Library/MacSD/Install macOS High Sierra.app"
        # delete the login banner as we are updating macOS
		rm -fR /Library/Security/PolicyBanner.rtfd        
        # Create the upgrade flag to ensure a recon after the upgrade.
		touch /Library/MacSD/SUDONE
        
        if [ $NoUser == True ]; then
			/Library/MacSD/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense 
		else
			/Library/MacSD/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Library/MacSD/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
			osascript -e 'tell application "Self Service" to quit'
        fi
    fi
fi



exit 0;
