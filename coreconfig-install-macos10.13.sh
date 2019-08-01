#!/bin/bash

###################################################################
#
# Enable macOS re-install for Macs not on 10.13
#
# Date: Thu 1 Aug 2019 13:42:58 BST
# Version: 0.1.5
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
exit 0
fi

# Check if free space > 15GB
freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
if [[ ${freeSpace%.*} -ge 15 ]]; then
    spaceStatus="OK"
    /bin/echo "Disk Check: OK - ${freeSpace%.*} Free Space Detected"
else
    spaceStatus="ERROR"
    /bin/echo "Disk Check: ERROR - ${freeSpace%.*} Free Space Detected"
fi

username=$( python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");' )
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
if [ -f /Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/InstallAssistant.icns ]; then
	icon=/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/InstallAssistant.icns
else
	icon=/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns 
fi

##Launch jamfHelper
if [ $NoUser == False ]; then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "" -icon "$icon" -heading "$heading" -description "$description" &
jamfHelperPID=$(echo $!)
fi

##Start macOS Upgrade
macOS_app_vers=`defaults read "/Applications/Install macOS High Sierra.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1$2}'`
echo $macOS_app_vers
if [ -z $macOS_app_vers ]; then
	macOS_app_vers=126
fi

if [ $macOS_app_vers -ge 134 ]; then

    # delete the login banner as we are updating macOS
	rm -fR /Library/Security/PolicyBanner.rtfd
   
    #For Labs, remove receipt for the login banner so it gets put back after upgrade.
    rm -dfR "/Library/Application Support/JAMF/Receipts/SavingPolicyBanner*.pkg"
    
    # Create the upgrade flag to ensure a recon after the upgrade.
	touch /Library/MacSD/SUDONE
    if [ $NoUser == True ]; then
		/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense 
	else
        /Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
		osascript -e 'tell application "Self Service" to quit'
    fi
    
else

	# Do a delete incase an older version is there
	rm -fR "/Applications/Install macOS High Sierra.app"
    
    # Add the installer
    /usr/local/bin/jamf policy -event OS-Installer
    
    # Delete the login banner as we are updating macOS
	rm -fR /Library/Security/PolicyBanner.rtfd  
    
    #For Labs, remove receipt for the login banner so it gets put back after upgrade.
    rm -dfR "/Library/Application Support/JAMF/Receipts/SavingPolicyBanner*.pkg"
    
    # Create the upgrade flag to ensure a recon after the upgrade.
	touch /Library/MacSD/SUDONE   
    
    if [ $NoUser == True ]; then
		/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense 
	else
		/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
		osascript -e 'tell application "Self Service" to quit'
    fi
fi

exit 0;
