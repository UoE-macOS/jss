#!/bin/sh

### Script for displaying end of support notification to devices incompatible with macOS 11 (Big Sur).
# Created by Ross Coleman
# 02/11/22

JAMF_BINARY="/usr/local/bin/jamf"

UOE_LOGO="/usr/local/jamf/UoELogo.png"

LOGFILE="/Library/Logs/end-of-support-notification.log"

USERS_ACKNOWLEDGED="/Users/Shared/.eos-acknowledgement"

# Declare jamf helper location
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

timestamp() {
    while read -r line
    do
        TIMESTAMP=$(date)
        echo "[$TIMESTAMP] $line"
    done
}

# Check to see if logfile exists. If so then delete as we only need log for the current user
#if [ -f "$LOGFILE" ]
#then
#    rm -f $LOGFILE
#fi

# Function for obtaining model directly from Apple
get_model_from_apple() {
    ## Check the length of the serial number and set an appropriate string to use for the lookup
    # If there are 12 or more characters in the serial then take the last 4
    #echo "$FULL_SERIAL_NUMBER"
    if [ ${#FULL_SERIAL_NUMBER} -ge 12 ]; then
        PART_SERIAL=$(echo "$FULL_SERIAL_NUMBER" | tail -c 5)
    # Else take the last 3
    else
        PART_SERIAL=$(echo "$FULL_SERIAL_NUMBER" | tail -c 4)
    fi
    # Get the full model from Apple
    MODEL=$(curl -s "https://support-sp.apple.com/sp/product?cc=${PART_SERIAL}" | xmllint --format - 2>/dev/null | awk -F'>|<' '/<configCode>/{print $3}')
    echo "$MODEL"    
}

# Get current logged in user
CURRENT_USER=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
echo "Logged in user is $CURRENT_USER" | timestamp 2>&1 | tee -a $LOGFILE

# Get computer name
COMPUTER_NAME=$(scutil --get ComputerName)
echo "Computer name: $COMPUTER_NAME" | timestamp 2>&1 | tee -a $LOGFILE

# Find out if the user has already acknowledged. If so then quit this script
if grep "$CURRENT_USER" "$USERS_ACKNOWLEDGED" #> dev/null
then
    echo "$CURRENT_USER already appears to have acknowledged the notification. Check JSS record attachments for $COMPUTER_NAME" | timestamp 2>&1 | tee -a $LOGFILE
    exit 0;
fi

# Get major version of OS
OS_MAJOR_VERSION=$(sw_vers -buildVersion | cut -c 1-2)
echo "OS Major Version: $OS_MAJOR_VERSION" | timestamp 2>&1 | tee -a $LOGFILE
# Serial
FULL_SERIAL_NUMBER=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
echo "Serial number: $FULL_SERIAL_NUMBER" | timestamp 2>&1 | tee -a $LOGFILE
# Get the model identifier
MODEL_IDENTIFIER=$(/usr/sbin/sysctl -n hw.model)
echo "Model Identifier: $MODEL_IDENTIFIER" | timestamp 2>&1 | tee -a $LOGFILE
# then get the model name
MODEL_NAME=$(echo "$MODEL_IDENTIFIER" | sed 's/[^a-zA-Z]//g')
echo "Model Name: $MODEL_NAME" | timestamp 2>&1 | tee -a $LOGFILE

# Get the model and year. Depending on OS, this is stored in a different .plist. Different path prior to 10.15
# If Major version of OS is lower than 19 (Catalina)
if [ "$OS_MAJOR_VERSION" -lt 19 ]; then
    MODEL=$(/usr/libexec/PlistBuddy -c "print :$(sysctl -n hw.model):_LOCALIZABLE_:marketingModel" /System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/English.lproj/SIMachineAttributes.plist)
else
    MODEL=$(/usr/libexec/PlistBuddy -c "print :$(sysctl -n hw.model):_LOCALIZABLE_:marketingModel" /System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/en.lproj/SIMachineAttributes.plist)
fi

# Log Model
echo "Model: $MODEL" | timestamp 2>&1 | tee -a $LOGFILE

# Get the model of mac, and set the name of the minimum model required for upgrade
if [ "$MODEL_NAME" = "iMac" ]; then
    MINIMUM_MODEL="iMac (2014 or later)"
elif [ "$MODEL_NAME" = "iMacPro" ]; then
    MINIMUM_MODEL="iMac Pro (2017 or later)"
elif [ "$MODEL_NAME" = "Macmini" ]; then
	MINIMUM_MODEL="Mac mini (2014 or later)"
elif [ "$MODEL_NAME" = "MacPro" ]; then
	MINIMUM_MODEL="Mac Pro (2013 or later)"
elif [ "$MODEL_NAME" = "MacBook" ]; then
	MINIMUM_MODEL="MacBook (2015 or later)"
elif [ "$MODEL_NAME" = "MacBookAir" ]; then
	MINIMUM_MODEL="MacBook Air (2013 or later)"
    # If it's a MacBook Air then the reported model may be incorrect. See here for more details: https://ideas.jamf.com/ideas/JN-I-19127
    # Performing solution in the post above    
    echo "Is a MacBook Air - performing further config." | timestamp 2>&1 | tee -a $LOGFILE
    MODEL=$(get_model_from_apple "FULL_SERIAL_NUMBER")
    echo "Model of MacBook Air after checking with Apple: $MODEL" | timestamp 2>&1 | tee -a $LOGFILE
elif [ "$MODEL_NAME" = "MacBookPro" ]; then 
	MINIMUM_MODEL="MacBook Pro (Late 2013 or later)"
else
    # If we can't detect a model, attempt to check with Apple directly
    MODEL=$(get_model_from_apple "FULL_SERIAL_NUMBER")
    echo "Cannot detect model!" | timestamp 2>&1 | tee -a $LOGFILE
    exit 1;
fi

# Log Minimum model required
echo "Minimum model of $MODEL_NAME required for macOS 11: $MINIMUM_MODEL" | timestamp 2>&1 | tee -a $LOGFILE

echo "Displaying end of support notification:" | timestamp 2>&1 | tee -a $LOGFILE
# Display jamf helper window
"$JAMF_HELPER" -windowType utility \
    -title 'End of support!' \
    -icon "$UOE_LOGO" \
    -heading '*** IMPORTANT MESSAGE FROM UoE INFORMATION SERVICES - PLEASE DO NOT IGNORE ***' \
    -description "The University of Edinburgh’s Sustainable IT programme has implemented a replacement cycle policy for macOS managed computers, where desktops older than 7 years and laptops older than 6 years will need to be replaced.

It has been brought to our attention that this device is now past its replacement cycle policy:

$MODEL

Please do not ignore this message. By the end of January 2023, this computer will be removed from the Information Services support structure and lead to certain features being removed from the device, along with any UoE registered wired network connection. We can only recommend that you replace this computer with a macOS device with more up to date hardware, so that you can receive full support from Information Services.

If you have any questions please contact IS Helpline - IS.Helpline@ed.ac.uk

Please select the button below to show that you have acknowledged this message." \
    -button1 "Understood"

# Grab acceptance and send to log
echo "Acknowledgement accepted by $CURRENT_USER" | timestamp 2>&1 | tee -a $LOGFILE

# Upload the log to the JSS - will appear in "Attachments" for the device record.
$JAMF_BINARY policy -event EOS-upload-log

# Add the username to the acknowledgement list
echo "$CURRENT_USER" >> "$USERS_ACKNOWLEDGED"

# Log has now been uploaded, so remove it
#rm -rf "$LOGFILE"

exit 0;