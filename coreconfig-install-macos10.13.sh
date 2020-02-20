#!/bin/bash

###################################################################
#
# Enable macOS re-install for Macs not on 10.13
#
# Date: Thu 20 Feb 2020 15:06:23 GMT
# Version: 0.1.9
# Creator: ganders1
#
##################################################################


# # # # # # 
# SYSTEM CHECKS
# # # # # # 

# Check the install process isn't underway

if [ -e /macOS\ Install\ Data ]
then
# Install process already underway
exit 0
fi

if ! [ -e "/Library/Application Support/JAMF/Receipts/Install_macOS_High_Sierra-13.6.02-1.sig.pkg" ]
then
	rm -fR "/Applications/Install macOS High Sierra.app"
fi

osversion=`sw_vers -productVersion | awk -F . '{print $2}'`
if [ $osversion == "13" ]; then
    # Delete the login banner and receipt as OS is already on the one we want.
	rm -fR /Library/Security/PolicyBanner.rtfd      
    rm -dfR "/Library/Application Support/JAMF/Receipts/SavingPolicyBanner*.pkg"
    
    # Do a recon
    /usr/local/bin/jamf recon
fi

# Check if free space > 15GB
bootDisk=`diskutil info / | grep "Device Node:" | awk '{print $3}'`
freeSpace=`df -g | grep "${bootDisk}" | awk '{print $4}'`
if [[ ${freeSpace%.*} -ge 15 ]]; then
    spaceStatus="OK"
    /bin/echo "Disk Check: OK - ${freeSpace%.*} Free Space Detected"
else
    spaceStatus="ERROR"
    /bin/echo "Disk Check: ERROR - ${freeSpace%.*} Free Space Detected"
    
    # Trigger Yo notification on low disk space pointing users to https://edin.ac/mac-low-disk-space
    /usr/local/bin/jamf policy -event low-disk-space
    exit 1;
fi

username=$( python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");' )
if [ -z $username ]; then
	NoUser=True
else
	NoUser=False
fi

sleep 2

##Heading to be used for jamfHelper

heading='           Preparing for macOS install           '

# Title to be used for jamfHelper

description='Please wait as we prepare your computer for macOS High Sierra...

This process will take approximately 10-15 minutes.

Once completed your computer will reboot and begin the install.'

##Icon to be used for jamfHelper
if [ -f /Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/InstallAssistant.icns ]; then
	icon=/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/InstallAssistant.icns
else
	icon=/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns 
fi

##Launch jamfHelper
if [ $NoUser == False ]; then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "" -icon "$icon" -heading "$heading" -description "$description" &
jamfHelperPID=$(echo $!)
fi

##Start macOS Upgrade
macOS_app_vers=`defaults read "/Applications/Install macOS High Sierra.app/Contents/Info" CFBundleShortVersionString | awk -F "." '{print $1$2}'`
echo $macOS_app_vers
if [ -z $macOS_app_vers ]; then
	macOS_app_vers=126
fi

if [ $macOS_app_vers -ge 136 ]; then

    # delete the login banner as we are updating macOS
	rm -fR /Library/Security/PolicyBanner.rtfd
   
    #For Labs, remove receipt for the login banner so it gets put back after upgrade.
    rm -dfR "/Library/Application Support/JAMF/Receipts/SavingPolicyBanner*.pkg"
    
    # Create the upgrade flag to ensure a recon after the upgrade.
	touch /Library/MacSD/SUDONE
    if [ $NoUser == True ]; then
    	echo "No user present, starting osinstall"
		/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense 
	else
    	echo "User present, starting osinstall"
        /Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
		killall "Self Service"
    fi
    
else

	# Do a delete incase an older version is there
	rm -fR "/Applications/Install macOS High Sierra.app"
    
    # Add the installer
    /usr/local/bin/jamf policy -event OS-Installer-13
    
    # Delete the login banner as we are updating macOS
	rm -fR /Library/Security/PolicyBanner.rtfd  
    
    #For Labs, remove receipt for the login banner so it gets put back after upgrade.
    rm -dfR "/Library/Application Support/JAMF/Receipts/SavingPolicyBanner*.pkg"
    
    # Create the upgrade flag to ensure a recon after the upgrade.
	touch /Library/MacSD/SUDONE   
    
    if [ $NoUser == True ]; then
    	echo "No user present, starting osinstall"
		/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense 
	else
    	echo "User present, starting osinstall"
		/Applications/Install\ macOS\ High\ Sierra.app/Contents/Resources/startosinstall --applicationpath /Applications/Install\ macOS\ High\ Sierra.app --nointeraction --agreetolicense --pidtosignal $jamfHelperPID &
		killall "Self Service"
    fi
fi

exit 0;
