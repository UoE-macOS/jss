#!/bin/bash

# Checks currently installed version of Operating System. If system can be upgraded to a more recent OS version, checks hard drive sapce and downloads installer.
# Only used as part of the DEP process - this is why output is sent to /Library/Logs/jamf-enrolment.log
# Original OS check didn't download installer for laptops as it was thought this would take too long over wifi. However, as DEP machines require wired connection this script has been ammended for all types of devices.

# Get log file
LOGFILE="/Library/Logs/jamf-enrolment.log"

# DEP Notify log
DNLOG="DNLOG=/var/tmp/depnotify.log"

# Variable to hold latest OS version
LATEST_OS=15

# Name of latest OS
LATEST_OS_NAME="10.15 (Catalina)"

# Function for obtaining timestamp
timestamp() {
    while read -r line
    do
        TIMESTAMP=$(date)
        echo "[$TIMESTAMP] $line"
    done
}

# What OS is currently installed?
OS_VERSION=$(sw_vers -productVersion | awk -F . '{print $2}')
echo "Operating System is $OS_VERSION." | timestamp 2>&1 | tee -a $LOGFILE
# DEPNotify message
echo "Status: Checking free space on HD..." >> $DNLOG
# Check if free space > 15GB
echo "Making sure more than 15 GB of free space on HD exists..." | timestamp 2>&1 | tee -a $LOGFILE
# Get Boot disk volume name
BOOT_DISK=$(diskutil info / | grep "Device Node:" | awk '{print $3}')
# The label for free space on the HD depends on the OS. If it's Catalina or above then set appropriate name
if [ "$OS_VERSION" -ge 15 ]; then
	FREE_SPACE_LABEL="Container Free Space:"
else
	FREE_SPACE_LABEL="Volume Free Space:"
fi

# Get available space
AVAILABLE_SPACE=$(/usr/sbin/diskutil info "${BOOT_DISK}" | grep "$FREE_SPACE_LABEL" | awk '{print $4}')

# We need to see if free space is in TB or GB. If it's TB, then multiply available space by 1000 as we need it in GB
AVAILABLE_SPACE_TYPE=$(diskutil info / | grep "$FREE_SPACE_LABEL" | awk '{print $5}')

if [ "$AVAILABLE_SPACE_TYPE" == "TB" ]; then
    echo "Free space is $AVAILABLE_SPACE TB. Converting to GB..." | timestamp 2>&1 | tee -a $LOGFILE
    # Get temporary float value
    FREE_SPACE_=$(echo "$AVAILABLE_SPACE * 1000" | bc)
    # Convert to whole integer
    FREE_SPACE=$(/bin/echo "($FREE_SPACE_+0.5)/1-1" | bc)
    echo "Converted free space is $FREE_SPACE" | timestamp 2>&1 | tee -a $LOGFILE
else
    FREE_SPACE=$(/bin/echo "($AVAILABLE_SPACE+0.5)/1-1" | bc)
    echo "Free space is $FREE_SPACE and already in GB." | timestamp 2>&1 | tee -a $LOGFILE
fi 

# Checking if OS installer is required
echo "Checking if OS installer is required..." | timestamp 2>&1 | tee -a $LOGFILE
if [ "$OS_VERSION" -ge "$LATEST_OS" ]; then
	echo "$LATEST_OS_NAME installer is already in-place or $LATEST_OS_NAME is currently installed." | timestamp 2>&1 | tee -a $LOGFILE
else    
    if [ "$FREE_SPACE" -ge 25 ]; then
    	echo "Command: MainText: Setup has detected a newer Operating System is available than what is currently installed. The newer Operating System is now being downloaded in preparation for installation at a later date. This may take around 20 minutes."
        echo "Setup has detected a newer Operating System is available than what is currently installed. The newer Operating System is now being downloaded in preparation for installation at a later date. This may take around 20 minutes." | timestamp 2>&1 | tee -a $LOGFILE
        /usr/local/bin/jamf policy -event OS-Installer-15
    else
        echo "Not enough free disk space to continue." | timestamp 2>&1 | tee -a $LOGFILE
    fi	
fi

exit 0;
