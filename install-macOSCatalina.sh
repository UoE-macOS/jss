#!/bin/bash

# Created by rcoleman
# Main spine of the code taken from here: https://github.com/laurentpertois/BigSur-Compatibility-Checker/blob/master/BigSur-Compatibility-Checker.sh

#*********** GLOBAL VARIABLES ***********

# Log file location
LOGFILE="/Library/Logs/macOSCatalina-upgrade.log"

# Jamf binary location
JAMF_BINARY="/usr/local/jamf/bin/jamf"
# Declare jamf helper location
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# BigSur icon
BIGSUR_ICON="/usr/local/jamf/CatalinaInstallAssistant.png"

# Jamf helper title
JH_TITLE="macOS Catalina Upgrade"
# Jamf helper initial description
JH_DESCRIPTION="Checking your device meets the minimum requirements for upgrading to Catalina..."
# Error icon location
ERROR_ICON="/usr/local/jamf/Error.png"
# Warning icon
WARNING_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns"

# IBM Notifier options - in testing
# Notifier app
#NOTIFIER="/Applications/Utilities/IBM Notifier.app/Contents/MacOS/IBM Notifier"
# Notifier icon
#NOTIFIER_ICON="/Applications/Utilities/IBM Notifier.app/Contents/Resources/AppIcon.icns"
# Call notifier
#"$NOTIFIER" -type popup -bar_title "$JH_TITLE" -title "$JH_DESCRIPTION" -icon_path "$NOTIFIER_ICON" -no_button

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
"$JAMF_HELPER" -windowType utility -title "$JH_TITLE" -icon "$CATALINA_ICON" -heading "$JH_HEADING" -description "$JH_DESCRIPTION" &
# Wait a few seconds
sleep 5s
# Get build version
OS_VERSION_MAJOR=$(sw_vers -buildVersion | cut -c 1-2)
echo "Major build version of OS is $OS_VERSION_MAJOR" | timestamp 2>&1 | tee -a $LOGFILE
# Declare required minimum RAM
REQUIRED_MINIMUM_RAM=4
# Set default COMPATIBILITY to false
COMPATIBILITY="False"
# Global for MINIMUM_MODEL
MINIMUM_MODEL=""

# If we are running High Sierra or higher
if [[ "$OS_VERSION_MAJOR" -ge 16 ]]; then
	# For Sierra and higher required space is 12.3GB for the installer and 35.5GB for required disk space for installation which equals to 47.8GB, 50GB is giving a bit of extra free space for safety
	echo "Device running macOS 10.13 or higher. Minimum space required is 50GB." | timestamp 2>&1 | tee -a $LOGFILE
	REQUIRED_MINIMUM_SPACE=50
# Else we are running 10.12 or below
else
	echo "Device running a pre-10.12 macOS. Minimum space required is 60GB." | timestamp 2>&1 | tee -a $LOGFILE
	# For pre-Sierra required space is 12.3GB for the installer and 44.5GB for required disk space for installation which equals to 56.8GB, 60GB is giving a bit of extra free space for safety
	REQUIRED_MINIMUM_SPACE=60
fi

# Make sure we are not running Monterey or above!
if [[ "$OS_VERSION_MAJOR" -ge 20 ]]; then
	echo "Device appears to be running macOS 11 (Big Sur) or above. Quitting Catalina install." | timestamp 2>&1 | tee -a $LOGFILE
    jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Cannot upgrade!" "You already appear to be running macOS 11 (Big Sur) or above. Catalina is macOS 10.15 and would be a downgrade." "Cancel"
	# Make sure no instances of jamf helper are running
	killall jamfHelper 2> /dev/null
	exit 0;
fi

# See if we are already running BigSur
if [[ "$OS_VERSION_MAJOR" -eq 19 ]]; then
	echo "Device already appears to be running macOS 10.15 Catalina." | timestamp 2>&1 | tee -a $LOGFILE
    CATALINA_CONFIRM=$(jamf_helper_two_buttons "$JH_TITLE" "$CATALINA_ICON" "Detected current Catalina installation" "You already appear to be running macOS 10.15 (Catalina). You can continue with this installation if you wish, however please note that your Operating System will not be upgraded.
	
Re-installing Catalina may resolve some stability issues if you are experiencing performance problems.

Do you wish to continue?" "Continue" "Cancel" "2")
    # If user has canceled then quit
	if [ "$CATALINA_CONFIRM" = 2 ]; then
		echo "User has selected to cancel the process. Qutting..." | timestamp 2>&1 | tee -a $LOGFILE
		# Kill current jamf helper window
		killall jamfHelper 2> /dev/null
		exit 0;
	fi	
fi

# Make sure we are at least running 10.9 (Mavericks)
if ! [[ "$OS_VERSION_MAJOR" -ge 13 && "$OS_VERSION_MAJOR" -le 20 ]]; then
	echo "Device does not appear to be running at least 10.9." | timestamp 2>&1 | tee -a $LOGFILE
	OS=$(sw_vers -productVersion)
	echo "Appears to be running macOS $OS" | timestamp 2>&1 | tee -a $LOGFILE
	# Kill initial jamf helper window
	killall jamfHelper 2> /dev/null
	echo "Displaying error message and quitting." | timestamp 2>&1 | tee -a $LOGFILE
	# Display error message
    jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Cannot upgrade!" "This process cannot complete the upgrade.

Cause - Your device must currently be running macOS 10.9 (Mavericks) or later to install this upgrade.

Please upgrade your Operating System to at least 10.9." "Cancel"
	# Make sure all instances of jamf helper are closed
	killall jamfHelper 2> /dev/null
	# exit
	exit 0;
fi
# If we've not hit any issues so far then kill all jamfHelper windows
killall jamfHelper 2> /dev/null

# If the OS is between 10.9 and 10.14 inclusive
if [[ "$OS_VERSION_MAJOR" -ge 13 && "$OS_VERSION_MAJOR" -le 18 ]]; then
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
            # Get the current jamfHelper process as this will be the window above
            # JH_PID=$( ps -A | grep "jamfHelper" | awk '{print $1}')  
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
    
    # Transform GB into Bytes
	GB=$((1024 * 1024 * 1024))
	MINIMUM_RAM=$(($REQUIRED_MINIMUM_RAM * $GB))
	MINIMUM_SPACE=$(($REQUIRED_MINIMUM_SPACE * $GB))

	# Gets the Model Identifier, splits name and major version
	MODEL_IDENTIFIER=$(/usr/sbin/sysctl -n hw.model)
	MODEL_NAME=$(echo "$MODEL_IDENTIFIER" | sed 's/[^a-zA-Z]//g')
	MODEL_VERSION=$(echo "$MODEL_IDENTIFIER" | sed -e 's/[^0-9,]//g' -e 's/,//')
    
    # Gets amount of memory installed
	MEMORY_INSTALLED=$(/usr/sbin/sysctl -n hw.memsize)
	echo "Installed RAM is $MEMORY_INSTALLED." | timestamp 2>&1 | tee -a $LOGFILE
    
    # Gets free space on the boot drive
	FREE_SPACE=$(diskutil info / | awk -F '[()]' '/Free Space|Available Space/ {print $2}' | sed -e 's/\ Bytes//')
	echo "Free hard drive space is $FREE_SPACE." | timestamp 2>&1 | tee -a $LOGFILE
    
    # Get the model of mac, and set the name of the minimum model required for upgrade
    if [[ "$MODEL_NAME" == "iMac" ]]; then
        MINIMUM_MODEL="iMac (Late 2012 or newer)"        
    elif [[ "$MODEL_NAME" == "iMacPro" ]]; then
        MINIMUM_MODEL="iMac Pro (2017 or later)"
    elif [[ "$MODEL_NAME" == "Macmini" ]]; then
        MINIMUM_MODEL="Mac mini (Late 2012 or newer)"
    elif [[ "$MODEL_NAME" == "MacPro" ]]; then
        MINIMUM_MODEL="Mac Pro (Late 2013 or newer)"
    elif [[ "$MODEL_NAME" == "MacBook" ]]; then
        MINIMUM_MODEL="MacBook (Early 2015 or newer)"
    elif [[ "$MODEL_NAME" == "MacBookAir" ]]; then
        MINIMUM_MODEL="MacBook Air (Mid 2012 or newer)"
    elif [[ "$MODEL_NAME" == "MacBookPro" ]]; then 
        MINIMUM_MODEL="MacBook Pro (Mid 2012 or newer)"
    else
        # If we can't get a model then quit.
        echo "Cannot detect model." | timestamp 2>&1 | tee -a $LOGFILE
        jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Cannot upgrade!" "The upgrade has failed due to not being able to detect the model type of your device.

If the installer (Install macOS Catalina.app) exists in your Applications folder, then you can attempt to run this manually to upgrade.

If this still fails and you are unable to determine why, please contact IS Helpline for assistance:

https://edin.ac/helpline

This installer will now quit." "Quit"
            # Making sure all instances of jamf helper are closed
            killall jamfHelper 2> /dev/null
            # Exit
            exit 1;        
    fi
    
    # Checks if computer meets pre-requisites for Catalina
	if [[ "$MODEL_NAME" == "iMac" && "$MODEL_VERSION" -ge 131 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
		COMPATIBILITY="True"
        echo "Device is an iMac and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
	elif [[ "$MODEL_NAME" == "iMacPro" && "$MODEL_VERSION" -ge 10 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
		COMPATIBILITY="True"		
        echo "Device is an iMacPro and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
	elif [[ "$MODEL_NAME" == "Macmini" && "$MODEL_VERSION" -ge 61 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
		COMPATIBILITY="True"		
        echo "Device is a Macmini and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
	elif [[ "$MODEL_NAME" == "MacPro" && "$MODEL_VERSION" -ge 51 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
	    COMPATIBILITY="True"
        echo "Device is a MacPro and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
	elif [[ "$MODEL_NAME" == "MacBook" && "$MODEL_VERSION" -ge 80 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
	    COMPATIBILITY="True"
        echo "Device is a MacBook and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
	elif [[ "$MODEL_NAME" == "MacBookAir" && "$MODEL_VERSION" -ge 52 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
	    COMPATIBILITY="True"
        echo "Device is a MacBook Air and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
	elif [[ "$MODEL_NAME" == "MacBookPro" && "$MODEL_VERSION" -ge 102 && "$MEMORY_INSTALLED" -ge "$MINIMUM_RAM" && "$FREE_SPACE" -ge "$MINIMUM_SPACE" ]]; then
	    COMPATIBILITY="True"
        echo "Device is a MacBook Pro and appears to be compatible. Moving on..." | timestamp 2>&1 | tee -a $LOGFILE
    else
		# Convert bytes back to GB
		FREE_SPACE_GB=$(($FREE_SPACE / 1024 / 1024 / 1024))
		RAM_GB=$(($MEMORY_INSTALLED / 1024 / 1024 / 1024))
		echo "Currently installed OS appears to meet minimum requirements, however the device has failed to meet one of the following requirements:" | timestamp 2>&1 | tee -a $LOGFILE
		echo " " | tee -a $LOGFILE
		echo "        - The model of mac is not compatible with Catalina. Model required for Catalina - $MINIMUM_MODEL" | tee -a $LOGFILE
		echo "        - The device does not have a minimum of 4 GB RAM. Only has $RAM_GB GB." | tee -a $LOGFILE
		echo "        - The device does not have enough free space on the hard drive. Only has $FREE_SPACE_GB GB." | tee -a $LOGFILE        
		echo " " | tee -a $LOGFILE
		echo "Killing jamf helper window and quitting." | timestamp 2>&1 | tee -a $LOGFILE
		# Kill initial jamf helper window
		killall jamfHelper 2> /dev/null
        # If conditions above have not been met then most likely not compatible. Display error message.
        jamf_helper_one_button "$JH_TITLE" "$ERROR_ICON" "Cannot upgrade!" "This process cannot complete the upgrade due to one of the following reasons:
		
- Your model of Mac does not meet Apple's minimum requirement for installing Catalina. Minimum model required: $MINIMUM_MODEL

- Your device does not have a minimum of 4 GB RAM. Amount of installed RAM is: $RAM_GB GB

- You do not have enough free space on your hard drive (50GB required). Amount of free space available: $FREE_SPACE_GB GB.." "Quit"
	# Making sure all instances of jamf helper are closed
	killall jamfHelper 2> /dev/null
	# Exit
	exit 0;
	fi
fi

# If compatibility is true then start downloading the installer
if [[ "$COMPATIBILITY" == "True" ]]; then
	echo "Device appears to meet all minimum requirements. Getting confirmnation from user that we should proceed." | timestamp 2>&1 | tee -a $LOGFILE
	# Kill initial jamf helper window
	killall jamfHelper 2> /dev/null
	# Display confirmation jamf helper window
    BUTTON_CLICKED=$(jamf_helper_two_buttons "$JH_TITLE" "$CATALINA_ICON" "Installing Catalina" "The Catalina installer will now download to your Applications folder and then the process will begin. Please make sure you have done the following -
    
1 - Backed up any local data. Although this upgrade should keep all data intact, we would recommend you backup before running this process.
2 - Close all applications.
3 - Make sure the device is plugged into a mains power outlet.
4 - If you use any specialised applications, check the application manufacturer's website to make sure it is compatible with macOS Catalina.
	
Please note that this is a large installer (around 12 GB) that may take several hours to download and install depending on your network speed.

After downloading, the installer will begin in the background. The device will be restarted without warning. Please make sure you have saved your data.

After selecting to continue below, the process will begin and you will not be able to cancel.

Do you wish to continue?" "Continue" "Cancel" "2")
	# If 2 is returned then user has selected to cancel	
	if [ "$BUTTON_CLICKED" == 2 ]; then
		echo "User has selected to cancel the process. Qutting..." | timestamp 2>&1 | tee -a $LOGFILE
		# Kill current jamf helper window
		killall jamfHelper 2> /dev/null
		exit 0;
	else
		echo "User has continued with the process. Showing jamf helper download window." | timestamp 2>&1 | tee -a $LOGFILE
		# Kill current jamf helper window
		killall jamfHelper 2> /dev/null
		# Display jamf helper download window
        jamf_helper_no_buttons "$JH_TITLE" "$CATALINA_ICON" "Downloading Catalina" "Downloading the Catalina installer.
        
This window will close when the application starts to install.

Warning: This process will restart the computer without notification. Please save your data NOW.

Also, please make sure that your device is plugged in to a mains power outlet.

This may take a while. Please be patient." &     
        echo "Running jamf trigger to download Catalina." | timestamp 2>&1 | tee -a $LOGFILE
        "$JAMF_BINARY" policy -event upgrade-to-Catalina
        # Get exit status of last command
        POLICY_STATUS=$?
        echo "Download complete. Preparing Catalina install..." | timestamp 2>&1 | tee -a $LOGFILE
        # Kill current jamf helper window
        killall jamfHelper 2> /dev/null
        # Display jamf helper download window
        jamf_helper_no_buttons "Installing macOS Catalina" "$CATALINA_ICON" "Installing macOS Catalina" "Download is now complete. Preparing Catalina install...

Warning: This process will restart the computer without notification. Please save your data NOW.

Also, please make sure that your device is plugged in to a mains power outlet.

This may take a while. Please be patient." &
        # Check that last command executed successfully. If it's not equal to 0 then we have a problem.
        if [ "$POLICY_STATUS" -ne 0 ]; then
            echo "Installing from Self service has returned an error. Please check policy log in JSS for further details. " | timestamp 2>&1 | tee -a $LOGFILE
            # Quit all instances of jamf helper
            killall jamfHelper 2> /dev/null
            # Show new error window
            jamf_helper_one_button "$JH_TITLE" "$WARNING_ICON" "Possible issue upgrading!" "The upgrade has encountered a possible issue. If the device doesn't restart automatically within the next few minutes to begin the upgrade, you can check to see if the installer (Install macOS Catalina.app) exists in your Applications folder.

If so, then you can attempt to run this manually to upgrade.

If this still fails and you are unable to determine why, or if the installer does not exist within your Applications folder, please contact IS Helpline for assistance:

https://edin.ac/helpline

" "OK"
            # Making sure all instances of jamf helper are closed
            killall jamfHelper 2> /dev/null
            # Exit
            exit 1;
        fi
    fi   
else
    echo "Problem downloading installer. Check policy log in JSS for more details. Quitting..." | timestamp 2>&1 | tee -a $LOGFILE
    exit 1;
fi