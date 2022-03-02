#!/bin/bash

# Created by rcoleman
# Main spine of the code taken from here: https://github.com/laurentpertois/BigSur-Compatibility-Checker/blob/master/BigSur-Compatibility-Checker.sh

#*********** GLOBAL VARIABLES ***********

# Log file location
LOGFILE="/Library/Logs/macOSBigSur-eraseInstall.log"

# Jamf binary location
JAMF_BINARY="/usr/local/jamf/bin/jamf"
# Declare jamf helper location
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# BigSur icon
BIGSUR_ICON="/usr/local/jamf/BigSurInstallAssistant.png"

# Jamf helper title
JH_TITLE="macOS Big Sur Upgrade"
# Jamf helper initial description
JH_DESCRIPTION="Checking your device meets the minimum requirements for running Big Sur..."
# Error icon location
ERROR_ICON="/usr/local/jamf/Error.png"
# Warning icon
WARNING_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns"

# Function for obtaining timestamp
timestamp() {
    while read -r line
    do
        TIMESTAMP=$(date)
        echo "[$TIMESTAMP] $line"
    done
}

# Function for dealing with jamf helper - no buttons
jamf_helper_no_buttons () {
    # Declare variables
    local TITLE="$1"
    local ICON="$2"
    local HEADING="$3"
    local DESCRIPTION="$4"
    # Display jamf helper window
    "$JAMF_HELPER" -windowType utility \
        -title "$TITLE" \
        -icon "$ICON" \
        -heading "$HEADING" \
        -description "$DESCRIPTION"
}

# Function for dealing with jamf helper - one button
jamf_helper_one_button () {
    # Declare variables
    local TITLE="$1"
    local ICON="$2"
    local HEADING="$3"
    local DESCRIPTION="$4"
    local BUTTON1="$5"
    # Display jamf helper window
    local RETURN_VALUE=$("$JAMF_HELPER" -windowType utility \
        -title "$TITLE" \
        -icon "$ICON" \
        -heading "$HEADING" \
        -description "$DESCRIPTION" \
        -button1 "$BUTTON1")
    # Return button value
    echo "${RETURN_VALUE}"
}

# Function for dealing with jamf helper - two buttons
jamf_helper_two_buttons () {
    # Declare variables
    local TITLE="$1"
    local ICON="$2"
    local HEADING="$3"
    local DESCRIPTION="$4"
    local BUTTON1="$5"
    local BUTTON2="$6"
    local DEFAULT_BUTTON="$7"
    # Display jamf helper window
    local RETURN_VALUE=$("$JAMF_HELPER" -windowType utility \
        -title "$TITLE" \
        -icon "$ICON" \
        -heading "$HEADING" \
        -description "$DESCRIPTION" \
        -button1 "$BUTTON1" \
        -button2 "$BUTTON2" \
        -defaultButton "$DEFAULT_BUTTON")
    # Return button value
    echo "${RETURN_VALUE}"
}


# ************ MAIN **************

echo "Displaying initial jamf helper window." | timestamp 2>&1 | tee -a $LOGFILE
# Display initial jamf helper window
"$JAMF_HELPER" -windowType utility -title "$JH_TITLE" -icon "$BIGSUR_ICON" -heading "$JH_HEADING" -description "$JH_DESCRIPTION" &
# Wait a few seconds
sleep 5s
# Get build version
OS_VERSION_MAJOR=$(sw_vers -buildVersion | cut -c 1-2)
echo "Major build version of OS is $OS_VERSION_MAJOR" | timestamp 2>&1 | tee -a $LOGFILE
# Set default COMPATIBILITY to false
COMPATIBILITY="False"
# Global for MINIMUM_MODEL
MINIMUM_MODEL=""

# If we are running High Sierra or higher
if [[ "$OS_VERSION_MAJOR" -ge 17 ]]; then
	# For Sierra and higher required space is 12.3GB for the installer and 35.5GB for required disk space for installation which equals to 47.8GB, 50GB is giving a bit of extra free space for safety
	echo "Device running macOS 10.14 or higher." | timestamp 2>&1 | tee -a $LOGFILE
# Else we are running 10.12 or below
else
	echo "Device running a pre-10.12 macOS. Cannot use startosinstall --eraseinstall. Quitting..." | timestamp 2>&1 | tee -a $LOGFILE
    # Kill initial jamf helper window
	killall jamfHelper 2> /dev/null
	# Display error message
    jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Failed!" "This process cannot continue. You must be running 10.14 Mojave or later to perform this process." "Cancel"
	# Make sure all instances of jamf helper are closed
	killall jamfHelper 2> /dev/null
    exit 0;
fi

# If we've not hit any issues so far then kill all jamfHelper windows
killall jamfHelper 2> /dev/null

# Make sure we are plugged in to mains power outlet
AC_POWER=$(pmset -g ps | grep "AC Power")
# If nothing is returned, then we are not on AC
if ! [[ "$AC_POWER" ]]; then
    echo "Not plugged in to AC Mains. Displaying notification to user and waiting until AC power is plugged in or cancel is selected..."  | timestamp 2>&1 | tee -a $LOGFILE
    # Show jamf helper window. Will didplay until either cancel is selected or mains power is plugged in
    jamf_helper_one_button "$JH_TITLE" "$WARNING_ICON" "Mains power warning" "The device does not appear to be plugged in to a mains power outlet!

The process will continue as soon as you plug the device into a mains power outlet.

If you wish to cancel the upgrade, please select cancel below." "Cancel" &
    # Loop until power is plugged in or cancel is selected
    while ! [[ "$AC_POWER" ]]; do                      
        # If user selects to cancel then there will be no jamfHelper process running. Check and see if it's running. If not then quit.
        if ! pgrep -x "jamfHelper" /dev/null; then
            echo "User has selected to cancel upgrade. Quitting." | timestamp 2>&1 | tee -a $LOGFILE
            # Just make sure all instances of jamfhelper are closed
            killall jamfHelper 2> /dev/null
            exit 0;            
        fi
        # Obtain AC_POWER value again
        AC_POWER=$(pmset -g ps | grep "AC Power")        
    done
    # Kill the jamfHelper window
    killall jamfHelper 2> /dev/null
    echo "Device now plugged in to AC power."  | timestamp 2>&1 | tee -a $LOGFILE
else
    echo "Device already plugged in to AC power."  | timestamp 2>&1 | tee -a $LOGFILE
fi
    
echo "We have a compatible OS. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
    
# Gets the Model Identifier, splits name and major version
MODEL_IDENTIFIER=$(/usr/sbin/sysctl -n hw.model)
MODEL_NAME=$(echo "$MODEL_IDENTIFIER" | sed 's/[^a-zA-Z]//g')
MODEL_VERSION=$(echo "$MODEL_IDENTIFIER" | sed -e 's/[^0-9,]//g' -e 's/,//')
    
# Get the model of mac, and set the name of the minimum model required for upgrade
if [[ "$MODEL_NAME" == "iMac" ]]; then
    MINIMUM_MODEL="iMac (2014 or later)"        
elif [[ "$MODEL_NAME" == "iMacPro" ]]; then
    MINIMUM_MODEL="iMac Pro (2017 or later)"
elif [[ "$MODEL_NAME" == "Macmini" ]]; then
	MINIMUM_MODEL="Mac mini (2014 or later)"
elif [[ "$MODEL_NAME" == "MacPro" ]]; then
	MINIMUM_MODEL="Mac Pro (2013 or later)"
elif [[ "$MODEL_NAME" == "MacBook" ]]; then
	MINIMUM_MODEL="MacBook (2015 or later)"
elif [[ "$MODEL_NAME" == "MacBookAir" ]]; then
	MINIMUM_MODEL="MacBook Air (2013 or later)"
elif [[ "$MODEL_NAME" == "MacBookPro" ]]; then 
	MINIMUM_MODEL="MacBook Pro (Late 2013 or later)"
else
    # If we can't get a model then quit.
    echo "Cannot detect model." | timestamp 2>&1 | tee -a $LOGFILE
    # Display message
    jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Cannot install!" "This process has failed due to not being able to detect the model type of your device.

Please contact IS Helpline for assistance:

https://edin.ac/helpline

This process will now quit." "Quit"
        # Making sure all instances of jamf helper are closed
        killall jamfHelper 2> /dev/null
        # Exit
        exit 1;
fi
    
# Checks if computer meets pre-requisites for Big Sur
if [[ "$MODEL_NAME" == "iMac" && "$MODEL_VERSION" -ge 144 ]]; then
    COMPATIBILITY="True"
    echo "Device is an iMac and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
elif [[ "$MODEL_NAME" == "iMacPro" && "$MODEL_VERSION" -ge 10 ]]; then
	COMPATIBILITY="True"		
    echo "Device is an iMacPro and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
elif [[ "$MODEL_NAME" == "Macmini" && "$MODEL_VERSION" -ge 70 ]]; then
    COMPATIBILITY="True"		
    echo "Device is a Macmini and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
elif [[ "$MODEL_NAME" == "MacPro" && "$MODEL_VERSION" -ge 60 ]]; then
    COMPATIBILITY="True"
    echo "Device is a MacPro and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
elif [[ "$MODEL_NAME" == "MacBook" && "$MODEL_VERSION" -ge 80 ]]; then
    COMPATIBILITY="True"
    echo "Device is a MacBook and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
elif [[ "$MODEL_NAME" == "MacBookAir" && "$MODEL_VERSION" -ge 60 ]]; then
    COMPATIBILITY="True"
    echo "Device is a MacBook Air and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
elif [[ "$MODEL_NAME" == "MacBookPro" && "$MODEL_VERSION" -ge 110 ]]; then
    COMPATIBILITY="True"
    echo "Device is a MacBook Pro and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
else
    echo "Device does not meet Apple's minimum hardware requirement to perform wipe and install. Typcially this is becuase device is too old. Minimum model required is $MINIMUM_MODEL" | timestamp 2>&1 | tee -a $LOGFILE
	echo "Killing jamf helper window and quitting." | timestamp 2>&1 | tee -a $LOGFILE
	# Kill initial jamf helper window
	killall jamfHelper 2> /dev/null
    # If conditions above have not been met then most likely not compatible. Display error message.
    jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Cannot install!" "This process cannot complete due to your model of Mac not meeting Apple's minimum requirement for macOS Big Sur:
		
Minimum model required: $MINIMUM_MODEL

This process will now quit." "Quit"
	# Making sure all instances of jamf helper are closed
	killall jamfHelper 2> /dev/null
	# Exit
	exit 0;
	fi

# If compatibility is true then start downloading the installer
if [[ "$COMPATIBILITY" == "True" ]]; then
	echo "Device appears to meet all minimum requirements. Getting confirmnation from user that we should proceed." | timestamp 2>&1 | tee -a $LOGFILE
	# Kill initial jamf helper window
	killall jamfHelper 2> /dev/null
	# Display confirmation jamf helper window
    BUTTON_CLICKED=$(jamf_helper_two_buttons "$JH_TITLE" "$BIGSUR_ICON" "Installing Big Sur" "The Big Sur installer will now download to your Applications folder and then the process will begin.

IMPORTANT - Please make sure that you have backed up all of your data, as this Hard Drive will be wiped and any data currently on the Hard Drive will not be recoverable after this process is complete!
	
Please note that this is a large installer (around 12 GB) that may take several hours to download and install depending on your network speed.

After downloading, the installer will begin in the background. The device will be restarted without warning. Please make sure you have saved your data.

After selecting to continue below, the process will begin and you will not be able to cancel.

Do you wish to continue?" "Continue" "Cancel" "2")
    # If user has selected cancel then quit.	
	if [ "$BUTTON_CLICKED" == 2 ]; then
		echo "User has selected to cancel the process. Qutting..." | timestamp 2>&1 | tee -a $LOGFILE
		# Kill current jamf helper window
		killall jamfHelper 2> /dev/null
		exit 0;
	else
		echo "User has continued with the process. Showing jamf helper download window." | timestamp 2>&1 | tee -a $LOGFILE
		# Kill current jamf helper window
        jamf_helper_no_buttons "$JH_TITLE" "$BIGSUR_ICON" "Downloading Big Sur" "Downloading the Big Sur installer.
        
This window will close when the erase & install process starts and the computer restarts.

Warning: This process will restart the computer without notification. Please save your data NOW.

Also, please make sure that your device is plugged in to a mains power outlet.

This may take a while. Please be patient." &
		    
        echo "Running jamf trigger to download Big Sur." | timestamp 2>&1 | tee -a $LOGFILE
        # Check if it's M1. If so, at the moment we can't go ahead with this.
        if [ $(arch) == arm64 ]; then
            echo "This is an M1 Mac. This process has not been implemented for this type of device yet. Quitting process." | timestamp 2>&1 | tee -a $LOGFILE
            jamf_helper_one_button "$JH_TITLE" "$WARNING_ICON" "Cannot install!" "This process cannot complete due to this type of device being an M1 Mac.
		
This process will now quit." "Quit"
            # Making sure all instances of jamf helper are closed
            killall jamfHelper 2> /dev/null
            # Exit
            exit 0;
        else
            echo "Not an M1 Mac." | timestamp 2>&1 | tee -a $LOGFILE
            echo "Running erase & install Trigger trigger to download and run"
            "$JAMF_BINARY" policy -event eraseInstall-BigSur
            # Get exit status of last command
            POLICY_STATUS=$?
            echo "Download complete. Preparing Big Sur install..." | timestamp 2>&1 | tee -a $LOGFILE
            # Kill current jamf helper window
            killall jamfHelper 2> /dev/null
            # Display jamf helper download window
            jamf_helper_no_buttons "Installing macOS Big Sur" "$BIGSUR_ICON" "Installing macOS Big Sur" "Download is now complete. Preparing Big Sur install...

Warning: This process will restart the computer without notification. Please save your data NOW.

Also, please make sure that your device is plugged in to a mains power outlet.

This may take a while. Please be patient." &            
        fi
	fi        
    # Check that trigger executed successfully. If it's not equal to 0 then we have a problem.
    if [ "$POLICY_STATUS" -ne 0 ]; then
        echo "Installing from Self service has returned an error. Please check policy log in JSS for further details. " | timestamp 2>&1 | tee -a $LOGFILE
        # Quit all instances of jamf helper
        killall jamfHelper 2> /dev/null
        # Show new error window
        jamf_helper_one_button "$JH_TITLE" "$WARNING_ICON" "Possible issue upgrading!" "The upgrade has encountered a possible issue. If the device doesn't restart automatically within the next few minutes then it's likely the process has failed.
            
If nothing happens within the next 10 minutes, please contact IS Helpline for assistance:

https://edin.ac/helpline

" "OK"
        # Making sure all instances of jamf helper are closed
        killall jamfHelper 2> /dev/null
        # Exit
        exit 1;
    fi
       
else
    echo "Problem downloading installer. Check policy log in JSS for more details. Quitting..." | timestamp 2>&1 | tee -a $LOGFILE
    exit 1;
fi