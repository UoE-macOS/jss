#!/bin/sh

LOGFILE="/Library/Logs/jamf-enrolment.log"  

# Function for obtaining timestamp
timestamp() {
    while read -r line
    do
        timestamp=`date`
        echo "[$timestamp] $line"
    done
}

# Check to see if logfile exists. It shouldn't, but if so delete
if [ -f "$LOGFILE" ]
then
    rm -f $LOGFILE
fi

## Make the main script executable
echo  "Setting main script permissions" | timestamp 2>&1 | tee -a $LOGFILE
chmod a+x /Library/MacSD/Scripts/dep-staff.sh

## Set permissions and ownership for launch daemon
echo  "Set LaunchDaemon permissions" | timestamp 2>&1 | tee -a $LOGFILE
chmod 644 /Library/LaunchDaemons/is.ed.launch.plist
chown root:wheel /Library/LaunchDaemons/is.ed.launch.plist

## Load launch daemon into the Launchd system
echo  "load LaunchDaemon" | timestamp 2>&1 | tee -a $LOGFILE
launchctl load /Library/LaunchDaemons/is.ed.launch.plist

exit 0		## Success
exit 1		## Failure