#!/bin/bash

# Log file location
LOGFILE="/Library/Logs/desktop-name-and-bind.log"

# Jamf binary location
JAMF_BINARY=/usr/local/jamf/bin/jamf

# Function for obtaining timestamp
timestamp() {
    while read -r line
    do
        TIMESTAMP=$(date)
        echo "[$TIMESTAMP] $line"
    done
}

# Get model of device
get_mobility() {
    # Get the prodcut name
  	PRODUCT_NAME=$(ioreg -l | awk '/product-name/ { split($0, line, "\""); printf("%s\n", line[4]); }')
    # if "macbook" exists in the name, then it's a laptop.
  	if echo "${PRODUCT_NAME}" | grep -qi "macbook" 
  	then
    	MOBILITY=mobile
  	else
    	MOBILITY=desktop
  	fi
    # Return mobility
  	echo ${MOBILITY}  
}

# Wait for dock befor executing the rest of the script
# This prevents the script from executing before the
# setup assistant is finished
while true;	do
    # Get current logged in user
    CURRENT_USER=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
	DOCK_CHECK=$(ps -ef | grep [/]System/Library/CoreServices/Dock.app/Contents/MacOS/Dock)
	echo "Waiting for file as: ${CURRENT_USER}" | timestamp 2>&1 | tee -a $LOGFILE
	echo "regenerating dockcheck as ${DOCK_CHECK}." | timestamp 2>&1 | tee -a $LOGFILE
	if [ -n "${DOCK_CHECK}" ]; then
		echo "Dockcheck is ${DOCK_CHECK}, breaking." | timestamp 2>&1 | tee -a $LOGFILE
		break
	fi
	sleep 5
done

# Get model of device
MOBILITY=$(get_mobility)
case $MOBILITY in
    # If it's a laptop
    mobile)
    echo "Appears to be a laptop. Skip setting device name from DDI..." | timestamp 2>&1 | tee -a $LOGFILE
    ;;
    # If it's a desktop, run the triggers
    desktop)
    echo "Appears to be a desktop. Running trigger Set-Desktop-Name..." | timestamp 2>&1 | tee -a $LOGFILE
    $JAMF_BINARY policy -event Set-Desktop-Name
    sleep 5
    echo "Running trigger Bind-AD..."
    $JAMF_BINARY policy -event Bind-AD
    echo "Name and AD bind complete." | timestamp 2>&1 | tee -a $LOGFILE
    ;;
    *)
esac

echo "Set desktop name and bind now complete." | timestamp 2>&1 | tee -a $LOGFILE

exit 0;