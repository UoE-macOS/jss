#!/bin/bash

# Function for obtaining timestamp
timestamp() {
    while read -r line
    do
        TIMESTAMP=`date`
        echo "[$TIMESTAMP] $line"
    done
}

LOGFILE="/Library/Logs/remove-DEP-Components.log"

# Jamf binary location
JAMF_BINARY="/usr/local/jamf/bin/jamf"

# BOM file to indicate setup has completed
SETUP_DONE="/var/db/receipts/is.ed.provisioning.done.bom"

# Lock file
LOCK_FILE="/var/run/UoEDEPRunning"

# Launch Daemon for DEP
DEP_DAEMON="/Library/LaunchDaemons/is.ed.launch.plist"

# Registration bom file for DEPNotify 
DEP_NOTIFY_REGISTER_DONE="/var/tmp/com.depnotify.registration.done"

# DEP Notify log location
DEP_NOTIFY_LOG="/Library/Logs/depnotify.log"

# DEPNotify app
DEP_NOTIFY="/Applications/Utilities/DEPNotify.app"

# DEPNotify main script
DEP_STAFF="/Library/MacSD/Scripts/dep-staff.sh"

# Message for invalid entry
INVALID="Invalid response. Please select y or n"

# Function to delete file or directory
remove_component(){
    COMPONENT=${1}
    if [ -e "$COMPONENT" ]; then
        rm -rf "$COMPONENT"
    else
        echo "$COMPONENT does not exist." | timestamp 2>&1 | tee -a $LOGFILE
    fi
}

# Get currently logged in user
CURRENT_USER=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
echo "Logged in user is $CURRENT_USER" | timestamp 2>&1 | tee -a $LOGFILE

# Kill the DEP Process if it's running
echo "Killing main DEP enrolment script..." | timestamp 2>&1 | tee -a $LOGFILE
pkill -9 -f "$DEP_STAFF"

# Kill the DEPNotify process if it's running
echo "Killing DEPNotify..." | timestamp 2>&1 | tee -a $LOGFILE
pkill -9 -f "$DEP_NOTIFY"

echo "Removing BOM file..." | timestamp 2>&1 | tee -a $LOGFILE
remove_component "$SETUP_DONE"

echo "Removing DEP lock file..." | timestamp 2>&1 | tee -a $LOGFILE
remove_component "$LOCK_FILE"

echo "Removing DEP Launch Daemon..." | timestamp 2>&1 | tee -a $LOGFILE
remove_component "$DEP_DAEMON"

echo "Removing DEPNotify log..." | timestamp 2>&1 | tee -a $LOGFILE
remove_component "$DEP_NOTIFY_LOG"

echo "Removing user preference files..." | timestamp 2>&1 | tee -a $LOGFILE
# User preference .plist files
DEP_NOTIFY_USER_INPUT_PLIST="/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotifyUserInput.plist"
DEP_NOTIFY_CONFIG_PLIST="/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotify.plist"
remove_component "$DEP_NOTIFY_USER_INPUT_PLIST"
remove_component "$DEP_NOTIFY_CONFIG_PLIST"

echo "Removing DEPNotify..." | timestamp 2>&1 | tee -a $LOGFILE
remove_component "$DEP_NOTIFY"

echo "Removing main DEP enrolment script..." | timestamp 2>&1 | tee -a $LOGFILE
remove_component "$DEP_STAFF"

echo "Removing NoMAD LoginAD..." | timestamp 2>&1 | tee -a $LOGFILE
NoLoAD_PATH="/Library/MacSD/Scripts/remove-NoLoAD.sh"
sh "$NoLoAD_PATH"

# Remove jamf framework components. Loop until a valid answer is supplied
while true; do
    read -p "Do you wish to remove the local jamf framework (y / n) ? : " CONFIRM
    case $CONFIRM in
        [Yy]* ) echo "Removing jamf framework components..." | timestamp 2>&1 | tee -a $LOGFILE; $JAMF_BINARY removeFramework; break;;
        [Nn]* ) echo "Not removing jamf framework components." | timestamp 2>&1 | tee -a $LOGFILE; break;;
        * ) echo "$INVALID";;
    esac
done

echo "DEP Components removed!" | timestamp 2>&1 | tee -a $LOGFILE

exit 0