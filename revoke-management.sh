#!/bin/bash

#######################################################
#
# This script will remove the JAMF Binary components, Self Service, NoMAD & sysinfo apps and loginitems, custom dock items & dockutil.
# If reachable, it will also prompt to ask if you wish to remove the JSS record for the device.
# IF THE DEVICE HAS BEEN ENCRYPTED THEN A WARNING MESSAGE WILL APPEAR ASKING IF YOU WISH TO CONTINUE.
# PLEASE MAKE SURE YOU HAVE A COPY OF THE RECOVERY KEY BEFORE EXECUTING THIS SCRIPT!!!!
# THIS WILL ONLY OCCUR IF A USER IS CURRENTLY LOGGED IN TO THE DEVICE TO RESPOND TO THE PROMPT. IF NO USER IS LOGGED IN THEN THE JSS RECORD WILL NOT BE REMOVED AND THE SCRIPT WILL END.
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

# Function for killing process
killProcess() {
	echo "Checking to see if $1 process is running..." | timestamp 2>&1 | tee -a $logFile
	if pgrep $1 2>/dev/null;
	then
		echo "$1 process found. Terminating..." | timestamp 2>&1 | tee -a $logFile
		pkill $1
	else 
		echo "Cannot find a running $1 process. Checking 2nd time to make sure..."  | timestamp 2>&1 | tee -a $logFile
	# Check 2nd time to make sure
		if pgrep $1 2>/dev/null;
		then
			echo "$1 process found. Terminating..." | timestamp 2>&1 | tee -a $logFile
			pkill $1
		else
			echo "$1 process not found. Moving on...." | timestamp 2>&1 | tee -a $logFile
		fi
	fi	
}

# Function for removing login item
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

# Function for removing JSS record
removeJSSRecord(){
	jssRecordExists=$(curl https://uoe.jamfcloud.com/JSSResource/computers/name/$2 -u "$4":"$5" --write-out \\n%{http_code} --output - | awk 'END {print $NF}')
	# If the http response equals 200, then record exists
	if [ $jssRecordExists -eq 200 ];
	then
		echo "Found JSS record. Removing..." | timestamp 2>&1 | tee -a $logFile
		# Remove record
		jssRecordRemove=$(curl https://uoe.jamfcloud.com/JSSResource/computers/name/$2 -u "$4":"$5" -X DELETE --write-out \\n%{http_code} --output - | awk 'END {print $NF}')
		# If http reponse status equals 200 then record has been sucessfully removed
		if [ $jssRecordRemove -eq 200 ]
		then
			echo "$2 JSS record removed!" | timestamp 2>&1 | tee -a $logFile
		# Something went wrong - remove manually
		else
	    	echo "Unable to remove record. Please remove manually." | timestamp 2>&1 | tee -a $logFile
		fi
	fi
	if [ $jssRecordExists -eq 404 ]
	then
  		echo "Unable to delete record. JSS unreachable." | timestamp 2>&1 | tee -a $logFile
	fi	
}

# Declare Jamf Helper location
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# Check to make sure JamHelper exists
if [[ ! -x "$jamfHelper" ]]; then
		echo "******* jamfHelper not found. *******" | timestamp 2>&1 | tee -a $logFile
		jamfHelperStatus="NO"
	else
		echo "JamfHelper found" | timestamp 2>&1 | tee -a $logFile
fi

# Icon location
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
# Create message to be displayed
message="FileVault2 is currently enabled on this macOS device. Before continuing with this script, please make sure that you have a copy of the recovery key. Once this script completes there will be no way to view the key in the JSS as the record will be completely removed. Are you sure you want to conitnue?"

# Get current user
echo "Obtaining Currently logged in user..." | timestamp 2>&1 | tee -a $logFile
username=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

# Kill processes
echo "Attempting to stop NoMAD process..." | timestamp 2>&1 | tee -a $logFile
killProcess "NoMAD" 
echo "Attempting to stop sysinfo process..." | timestamp 2>&1 | tee -a $logFile
killProcess "sysinfo"

# Remove Login items
echo "Attempting to remove NoMAD login item..." | timestamp 2>&1 | tee -a $logFile
removeLoginItem "NoMAD"
echo "Attempting to remove sysinfo login item..." | timestamp 2>&1 | tee -a $logFile
removeLoginItem "sysinfo"

# Remove DockUtil application
echo "Removing dock items and dockutil app..." | timestamp 2>&1 | tee -a $logFile

# Declare DockUtil location
dockutil="/usr/local/bin/dockutil"
# If DockUtil exists then remove the dock items
if [ -e $dockutil ];
then
	# Remove dock items
	echo "dockutil exists! Removing dock items..." | timestamp 2>&1 | tee -a $logFile
	/usr/local/bin/dockutil --remove ed.ops.GetSupport
	/usr/local/bin/dockutil --remove com.jamfsoftware.selfservice
	/usr/local/bin/dockutil --remove ed.dst.RemoteSupport
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

# Remove NoMAD preferences
echo "Removing NoMAD preferences..." | timestamp 2>&1 | tee -a $logFile
NoMADPrefs="/Users/$User_Name/Library/Preferences/com.trusourcelabs.NoMAD.plist"
if [ -f $NoMADPrefs ];
then
	rm -rf $NoMADPrefs
	echo "NoMAD Prefs removed..." | timestamp 2>&1 | tee -a $logFile
else
	echo "NoMAD prefs not found." | timestamp 2>&1 | tee -a $logFile
fi

if [ "$jamfHelperStatus" = "NO" ]
then
	echo "JamfHelper not available. Quiting script as we don't want to delete the JSS Record if it's the only record we have of the recovery key." | timestamp 2>&1 | tee -a $logFile
	echo "Removing JAMF Framework before quiting script.." | timestamp 2>&1 | tee -a $logFile
	/usr/local/bin/jamf removeFramework
	echo "Done." | timestamp 2>&1 | tee -a $logFile
	exit 0;
fi

jssRecordSelection=$( "$jamfHelper" -windowType utility -description "Do you wish to also attempt to remove the JSS record?" -button1 "Yes" -button2 "No" -icon "$icon" -defaultButton 1 )
if [ "$jssRecordSelection" -eq 2 ]
then
	echo "JSS record will NOT be removed." | timestamp 2>&1 | tee -a $logFile
	killall jamfHelper 2> /dev/null
	echo "Now removing JAMF Framework..." | timestamp 2>&1 | tee -a $logFile
	/usr/local/bin/jamf removeFramework
	echo "Done." | timestamp 2>&1 | tee -a $logFile
	exit 0;
fi	
if [ "$jssRecordSelection" -eq 0 ]
then
	# First of all, check to make sure that the device is not encrypted. If so and if someone is logged in, then we can ask them to make sure that they have a copy of the recovery key before progressing.
	# Get encryption status
	encryptStatus=`fdesetup status`
	echo "$encryptStatus" | timestamp 2>&1 | tee -a $logFile
	# If encryption is set
	if [ "$encryptStatus" = "FileVault is On." ]
	then 
		# Check to see if a user is logged in. If so then we want GUI messages to inform. If not then output to log / console
		if [ ! -z ${username} ]
		then
			# Confirm current user
			echo "$username currently logged in." | timestamp 2>&1 | tee -a $logFile
			# Display warning message
			selection=$( "$jamfHelper" -windowType utility -description "$message" -button1 "Quit" -button2 "Continue…" -icon "$icon" -defaultButton 1 )
			# If user selects Quit, then quit script.
			if [ "$selection" -eq 0 ]
			then
				killall jamfHelper 2> /dev/null
				echo "Script exited by user. Removing JAMF Framework before quiting script.." | timestamp 2>&1 | tee -a $logFile
				/usr/local/bin/jamf removeFramework
				echo "Done." | timestamp 2>&1 | tee -a $logFile
				exit 0;
			# Else continue with the script
			else
				echo "User has selected to conitnue." | timestamp 2>&1 | tee -a $logFile
				killall jamfHelper 2> /dev/null
				echo "Removing local JAMF Framework before attempting to remove JSS record…" | timestamp 2>&1 | tee -a $logFile
				/usr/local/bin/jamf removeFramework
				echo "Attempting to remove JSS record…" | timestamp 2>&1 | tee -a $logFile
				removeJSSRecord
			fi
		# Else no user is logged in. Can't verify if a copy of the recovery key has been noted so we don't want to delete the record.	Quit script.
		else
			echo "No user is logged in. Quiting script as we don't want to delete the JSS Record if it's the only record we have of the recovery key." | timestamp 2>&1 | tee -a $logFile
			echo "Done." | timestamp 2>&1 | tee -a $logFile
			exit 0;
		fi
	else
		# Encryption must be disabled
		echo "Removing local JAMF Framework before attempting to remove JSS record…" | timestamp 2>&1 | tee -a $logFile
		killall jamfHelper 2> /dev/null
		/usr/local/bin/jamf removeFramework
		echo "Attempting to remove JSS record…" | timestamp 2>&1 | tee -a $logFile
		removeJSSRecord
	fi
fi
echo "Done." | timestamp 2>&1 | tee -a $logFile
exit 0;