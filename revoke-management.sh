#!/bin/bash

#######################################################
#
# This script will remove the JAMF Binary components, Self Service, NoMAD & sysinfo apps and loginitems, custom dock items & dockutil.
# If reachable, it will also remove the JSS record for the device.
# IF THE DEVICE HAS BEEN ENCRYPTED THEN A WARNING MESSAGE WILL APPEAR ASKING IF YOU WISH TO CONTINUE.
# PLEASE MAKE SURE YOU HAVE A COPY OF THE RECOVERY KEY BEFORE EXECUTING THIS SCRIPT!!!!
# 
# Check log file here : /Library/Logs/revoke-management.log
# 
#######################################################

# Create log file
logFile="/Library/Logs/revoke-management.log"

# Check to see if log exists. If so then delete as we only require an up to date log
if [ -f "$logFile" ]
then
    rm -f $logFile
fi

# Function for creating timestamp
timestamp() {
	while read -r line
	do
        timestamp=`date`
        echo "[$timestamp] $line"
	done
}

# Decrypt JSS details
# Get computer name
compname="$2"
# Get encrypted api user name
apiuser="$4"
# Get encrypted api password
apipword="$5"
# Get salt phrase
salt="$6"
# Get passphrase
pphrase="$7"

# Function for killing process
killProcess() {
	echo "Checking to see if $1 process is running..."
	if pgrep $1 2>/dev/null;
	then
		echo "$1 process found. Terminating..."
		pkill $1
	else 
		echo "Cannot find a running $1 process. Checking 2nd time to make sure..."
	# Check 2nd time to make sure
		if pgrep $1 2>/dev/null;
		then
			echo "$1 process found. Terminating..."
			pkill $1
		else
			echo "$1 process not found. Moving on...." 
		fi
	fi	
}

# Function for removing login items.
removeLoginItem() {
	# Get current login items and store in array
	currentLoginItems=( `/usr/bin/osascript -e 'tell application "System Events" to get the name of every login item' `)
	echo "Checking to see if $1 login item exists..." | timestamp 2>&1 | tee -a $logFile
	# If the looked for item exists then remove it
	if [[ " ${currentLoginItems[@]} " =~ $1 ]]; 
	then
		echo "$1 login item exists. Removing...." | timestamp 2>&1 | tee -a $logFile
		osascript -e "tell application \"System Events\" to delete login item \"$1\""
	# Else item does not exist
	else
		echo "$1 login item does not exist. Moving on..." | timestamp 2>&1 | tee -a $logFile
	fi		
}

# Function for decrypting strings
function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}


# Function for removing application
removeApplication() {
	echo "Checking to see if $1 exists..." | timestamp 2>&1 | tee -a $logFile
	if [ -d $1 ];
	then
		echo "$1 exists. Removing..." | timestamp 2>&1 | tee -a $logFile
		rm -rf $1
		echo "$1 removed." | timestamp 2>&1 | tee -a $logFile
	else
		echo "$1 does not exist!" | timestamp 2>&1 | tee -a $logFile
	fi
}

# Declare jamfHelper location
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# Check to make sure jamfHelper exists
if [[ ! -x ${jamfHelper} ]]; then
		echo "******* jamfHelper not found. *******" | timestamp 2>&1 | tee -a $logFile
		echo "Exiting script as cannot display dialog." | timestamp 2>&1 | tee -a $logFile
        exit 1;
	else
		echo "jamfHelper found" | timestamp 2>&1 | tee -a $logFile
fi

# Icon location
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
# toolIcon
toolIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns"
# Create message to be displayed
fileVaultMessage="FileVault2 is currently enabled on this macOS device. Before continuing with this script, please make sure that you have a copy of the recovery key. Once this script completes there will be no way to view the key in the JSS as the record will be completely removed.

Are you sure you want to conitnue?"
fileVaultErrorMessage="This process is unable to obtain the encryption status of this device. Please be aware that if you continue, you could potentially permanently remove the FileVault2 recovery key which is stored in the JSS record.

Do you wish to continue?"

# Get current user
echo "Obtaining Currently logged in user..." | timestamp 2>&1 | tee -a $logFile
username=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

# Firstly, lets check if FileVault2 is enabled
encryptStatus=`fdesetup status`
echo ${encryptStatus} | timestamp 2>&1 | tee -a $logFile
# If encryption is set
if [ "${encryptStatus}" = "FileVault is On." ]
then 
	selection=$( "${jamfHelper}" -windowType utility -description "${fileVaultMessage}" -button1 "Quit" -button2 "Continue…" -icon "${icon}" -defaultButton 1 )
	# If user selects Quit, then quit script.
	if [ ${selection} -eq 0 ]
	then
		killProcess "jamfHelper"
		echo "Script exited by user." | timestamp 2>&1 | tee -a $logFile
		exit 0;
	# Else continue with the script
	else
        echo "User has selected to conitnue. Moving on...." | timestamp 2>&1 | tee -a $logFile
        killProcess "jamfHelper"
	fi
# Check Filevault2 is off
elif [ "${encryptStatus}" = "FileVault is Off." ]
then
    echo "FileVault is not enabled on this device. Moving on...." | timestamp 2>&1 | tee -a $logFile
else
    echo "UNABLE TO OBTAIN ENCRYPTION STATUS. Displaying message to user." | timestamp 2>&1 | tee -a $logFile
    errorMessage=$( "${jamfHelper}" -windowType utility -description "${fileVaultErrorMessage}" -button1 "Quit" -button2 "Continue..." -icon "${icon}" -defaultButton 1 )
    if [ ${errorMessage} -eq 0 ]
    then
        killProcess "jamfHelper"
        echo "Script exited by user." | timestamp 2>&1 | tee -a $logFile
		exit 0;
    else
        echo "User has selected to continue. Moving on...." | timestamp 2>&1 | tee -a $logFile
    fi
fi

# Kill processes
"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "Removing JAMF" -description "Stopping processes...." &
echo "Attempting to stop NoMAD process..." | timestamp 2>&1 | tee -a $logFile
killProcess "NoMAD" 
echo "Attempting to stop sysinfo process..." | timestamp 2>&1 | tee -a $logFile
killProcess "sysinfo"
killProcess "jamfHelper"

# Remove login items
"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "Removing JAMF" -description "Removing login items...." &
echo "Attempting to remove NoMAD login item..." | timestamp 2>&1 | tee -a $logFile
removeLoginItem "NoMAD"
echo "Attempting to remove sysinfo login item..." | timestamp 2>&1 | tee -a $logFile
removeLoginItem "sysinfo"
killProcess "jamfHelper"

# Remove dock items and dock util
"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "Removing JAMF" -description "Removing dock items and dockutil app....." &
echo "Removing dock items and dockutil app..." | timestamp 2>&1 | tee -a $logFile
# Declare DockUtil location
dockutil="/usr/local/bin/dockutil"
# If DockUtil exists then remove the dock items
if [ -e $dockutil ];
then
	# Remove dock items
	echo "dockutil exists! Removing dock items..." | timestamp 2>&1 | tee -a $logFile
    /usr/local/bin/jamf policy -event rmSupportIcons
    /usr/local/bin/dockutil --remove "Self Service"    
	sleep 2
	# Kill Finder
	killall Finder
	sleep 2
	# Remove dockutil app
	echo "Removing dockutil app..." | timestamp 2>&1 | tee -a $logFile
	rm -rfv $dockutil
else
	echo "Dockutil does not exist!" | timestamp 2>&1 | tee -a $logFile
fi
killProcess "jamfHelper"

# Removing local management components
"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "Removing JAMF" -description "Removing local management components...." &
echo "Removing MacSD folder and sub items...." | timestamp 2>&1 | tee -a $logFile
rm -rfv "/Library/MacSD"
killProcess "jamfHelper"

# Remove apps  
"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "Removing JAMF" -description "Removing management applications...." &
# Remove NoMAD Application
echo "Removing NoMAD app..." | timestamp 2>&1 | tee -a $logFile
removeApplication "/Applications/NoMAD.app"

# Remove sysinfo application
echo "Removing sysinfo app..." | timestamp 2>&1 | tee -a $logFile
removeApplication "/Applications/sysinfo.app"

# Remove Help & Support application
echo "Removing Help & Support app..." | timestamp 2>&1 | tee -a $logFile
removeApplication "/Applications/Support.app"

# Remove Remote support application
echo "Removing Remote Support app..." | timestamp 2>&1 | tee -a $logFile
removeApplication "/Applications/RemoteSupport.app"
killProcess "jamfHelper"

echo "Removing Recovery Agent..." | timestamp 2>&1 | tee -a $logFile
launchctl unload -w /Library/LaunchDaemons/ed.is.jamf-self-heal.plist
rm -f /Library/LaunchDaemons/ed.is.jamf-self-heal.plist 


# Remove managed preferences
"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "removing JAMF" -description "Removing Managed Preferences....." &
# Remove NoMAD preferences
echo "Removing NoMAD preferences..." | timestamp 2>&1 | tee -a $logFile
NoMADPrefs="/Users/$username/Library/Preferences/com.trusourcelabs.NoMAD.plist"
if [ -f $NoMADPrefs ];
then
	rm -rf $NoMADPrefs
	echo "NoMAD Prefs removed..." | timestamp 2>&1 | tee -a $logFile
else
	echo "NoMAD prefs not found." | timestamp 2>&1 | tee -a $logFile
fi
killProcess "jamfHelper"

# Removing JSS record
# Decrypt strings
JSSusername=`DecryptString "$apiuser" "$salt" "$pphrase"`
JSSpword=`DecryptString "$apipword" "$salt" "$pphrase"`

"${jamfHelper}" -windowType utility -icon "${toolIcon}" -title "Removing JAMF" -description "Attempting to remove $2 record from the JSS...." &
echo "Attempting to remove record from the JSS...." | timestamp 2>&1 | tee -a $logFile
echo "Name of record is $compname" | timestamp 2>&1 | tee -a $logFile
# Attmept to get record
jssRecordExists=$(curl https://uoe.jamfcloud.com/JSSResource/computers/name/"$compname" -u "$JSSusername":"$JSSpword" --write-out \\n%{http_code} --output - | awk 'END {print $NF}')
# If the http response equals 200, then record exists
if [ $jssRecordExists -eq 200 ];
	then
	echo "Found JSS record. Removing..." | timestamp 2>&1 | tee -a $logFile
	# Remove record
	jssRecordRemove=$(curl https://uoe.jamfcloud.com/JSSResource/computers/name/"$compname" -u "$JSSusername":"$JSSpword" -X DELETE --write-out \\n%{http_code} --output - | awk 'END {print $NF}')
	# If http reponse status equals 200 then record has been sucessfully removed
	if [ $jssRecordRemove -eq 200 ]
	then
		echo "$compname JSS record removed!" | timestamp 2>&1 | tee -a $logFile
	# Something went wrong - remove manually
	else
	   	echo "JSS record can be found but there is a problem deleting. Please remove manually." | timestamp 2>&1 | tee -a $logFile
	fi
elif [ $jssRecordExists -eq 404 ]
then
	echo "Unable to delete record. JSS unreachable." | timestamp 2>&1 | tee -a $logFile
else
	echo "Unable to find record. Please remove manually." | timestamp 2>&1 | tee -a $logFile
fi

killProcess "jamfHelper"

# Remove local jamf framework
osascript -e 'display notification "Removing local jamf framework" with title "Remove JAMF"'
echo "Removing local JAMF framework....." | timestamp 2>&1 | tee -a $logFile
/usr/local/bin/jamf removeFramework

# Remove uoemanage account
osascript -e 'display notification "Removing uoemanage account...." with title "Remove JAMF"'
echo "Removing uoemanage account object..." | timestamp 2>&1 | tee -a $logFile
dscl . delete /Users/uoemanage
echo "Deleting uoemanage home folder..." | timestamp 2>&1 | tee -a $logFile
rm -rf /Users/uoemanage

echo "Done." | timestamp 2>&1 | tee -a $logFile

osascript <<'END'
display dialog "Successfully removed JAMF components." with icon file ("System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertNoteIcon.icns") buttons {"Done"} default button "Done"
END

exit 0;
