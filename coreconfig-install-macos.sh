#!/bin/bash

###################################################################
#
# Enable users to upgrade macOS from Self Service without requiring admin rights
#
# Date: Mon 03 Jul 2017 11:30:33 BST
# Version: 0.1.1
# Creator: dsavage
#
##################################################################

echo testing > /Users/Shared/installTST.log

echo $macOS_app >> /Users/Shared/installTST.log

# # # # # # 
# SYSTEM CHECKS
# # # # # # 

# Check the install process isn't underway

if [ -e /macOS\ Install\ Data ]
then
# Install proces already underway
exit 0
fi

# Check what we are running on
SystemType=`system_profiler SPHardwareDataType | grep "Model Identifier" |  awk '{ print $3 }'`

# On supported desktops we need to disable the wifi, so check if machine is a MacBook
IsMacBook=`echo $SystemType | grep "MacBook"`

if ! [ -z $IsMacBook ]
then

##Check if device is on battery or ac power
pwrAdapter=$( /usr/bin/pmset -g ac )
if [[ ${pwrAdapter} == "No adapter attached." ]]; then
    pwrStatus="ERROR"
    /bin/echo "Power Check: ERROR - No Power Adapter Detected" >> /Users/Shared/installTST.log
else
    pwrStatus="OK"
    /bin/echo "Power Check: OK - Power Adapter Detected" >> /Users/Shared/installTST.log
fi

else
    pwrStatus="OK"
    /bin/echo "Power Check: OK - Desktop Mac" >> /Users/Shared/installTST.log
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


date >> /Users/Shared/installTST.log

if [[ ${pwrStatus} == "OK" ]] && [[ ${spaceStatus} == "OK" ]]; then

sleep 2

##Heading to be used for jamfHelper

heading="Please wait as we prepare your computer for macOS Sierra..."

##Title to be used for jamfHelper

description="

This process will take approximately 5-10 minutes.

Once completed your computer will reboot and begin the upgrade."

##Icon to be used for jamfHelper

icon=/Applications/Install\ macOS\ Sierra.app/Contents/Resources/InstallAssistant.icns

##Launch jamfHelper

/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -title "" -icon "$icon" -heading "$heading" -description "$description" &

jamfHelperPID=$(echo $!)

##Start macOS Upgrade

/Applications/Install\ macOS\ Sierra.app/Contents/Resources/startosinstall --applicationpath "/Applications/Install macOS Sierra.app" --nointeraction --pidtosignal $jamfHelperPID &

else
    /bin/echo "Launching AppleScript Dialog..."
    /usr/bin/osascript -e 'Tell application "System Events" to display dialog "Your computer does not meet the requirements necessary to continue.

    Please contact the help desk for assistance. " with title "macOS Sierra Upgrade" with text buttons {"OK"} default button "OK" with icon 2'

    exit 1
fi


exit 0
