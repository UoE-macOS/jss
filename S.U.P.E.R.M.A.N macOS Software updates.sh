#!/bin/bash
#
# S.U.P.E.R.M.A.N.
# Software Update Policy Enforcement (with) Recursive Messaging And Notification
#
# S.U.P.E.R.M.A.N. optimizes the macOS software update experience.
# by Kevin M. White
#
# Version 3.0b3
# 2022/11/03
# https://github.com/Macjutsu/super
#
# NOTE: *** Debugging Stuff ***
################################################################################
#
# The next line disables specific ShellCheck codes for the entire script. https://github.com/koalaman/shellcheck
# shellcheck disable=SC2001,SC2207,SC2024
#
# Uncomment the next line for debugging code.
# set -x
#
# MARK: *** Usage & Help ***
################################################################################

# Show usage documentation. 
showUsage() {
echo "
  S.U.P.E.R.M.A.N.
  Software Update Policy Enforcement (with) Recursive Messaging And Notification

  Version 3.0b3
  2022/11/03
  https://github.com/Macjutsu/super

  Usage:
  sudo ./super

  Deferment Timer Options:
  [--default-defer=seconds] [--focus-defer=seconds]
  [--menu-defer=seconds,seconds,etc...] [--recheck-defer=seconds]
  [--delete-deferrals]

  Deferment Count Deadline Options:
  [--focus-count=number] [--soft-count=number] [--hard-count=number]
  [--restart-counts] [--delete-counts]

  Deferment Days Deadline Options:
  [--focus-days=number] [--soft-days=number] [--hard-days=number]
  [--zero-day=YYYY-MM-DD:hh:mm] [--restart-days] [--delete-days]

  Deferment Date Deadline Options:
  [--focus-date=YYYY-MM-DD:hh:mm] [--soft-date=YYYY-MM-DD:hh:mm]
  [--hard-date=YYYY-MM-DD:hh:mm] [--delete-dates]

  Display Options:
  [--display-timeout=seconds] [--display-redraw=seconds]
  [--display-icon=/local/path or URL] [--icon-size-ibm=pixels]
  [--icon-size-jamf=pixels ] [--prefer-jamf-helper] [--no-prefer-jamf-helper]

  Software Update Credential Options:
  [--local-account=AccountName] [--local-password=Password]
  [--admin-account=AccountName] [--admin-password=Password]
  [--super-account=AccountName] [--super-password=Password]
  [--jamf-account=AccountName] [--jamf-password=Password]
  [--delete-accounts]

  Update & Restart Options:
  [--policy-triggers=PolicyTrigger,PolicyTrigger,etc...]
  [--skip-updates] [--no-skip-updates] [--force-restart] [--no-force-restart]
  
  Upgrade Options:
  [--install-major-upgrade] [--no-install-major-upgrade] [--install-minor-update]
  [--no-install-minor-update] [--push-major-upgrade] [--no-push-major-upgrade]
  [--target-major-upgrade=version]

  Special Modes Options:
  [--test-mode ] [--no-test-mode ] [--test-mode-timeout=seconds]
  [--verbose-mode] [--no-verbose-mode] [--open-logs] [--reset-super] [--usage]
  [--help]

  * Managed preferences override local options via domain: com.macjutsu.super
  <key>DefaultDefer</key> <string>seconds</string>
  <key>FocusDefer</key> <string>seconds</string>
  <key>MenuDefer</key> <string>seconds,seconds,etc...</string>
  <key>RecheckDefer</key> <string>seconds</string>
  <key>FocusCount</key> <string>number</string>
  <key>SoftCount</key> <string>number</string>
  <key>HardCount</key> <string>number</string>
  <key>FocusDays</key> <string>number</string>
  <key>SoftDays</key> <string>number</string>
  <key>HardDays</key> <string>number</string>
  <key>ZeroDay</key> <string>YYYY-MM-DD:hh:mm</string>
  <key>FocusDate</key> <string>YYYY-MM-DD:hh:mm</string>
  <key>SoftDate</key> <string>YYYY-MM-DD:hh:mm</string>
  <key>HardDate</key> <string>YYYY-MM-DD:hh:mm</string>
  <key>DisplayTimeout</key> <string>seconds</string>
  <key>DisplayRedraw</key> <string>seconds</string>
  <key>DisplayIcon</key> <string>path</string>
  <key>IconSizeIbm</key> <string>number</string>
  <key>IconSizeJamf</key> <string>number</string>
  <key>PreferJamfHelper</key> <true/> | <false/>
  <key>PolicyTriggers</key> <string>PolicyTrigger,PolicyTrigger,etc...</string>
  <key>SkipUpdates</key> <true/> | <false/>
  <key>InstallMajorUpgrade</key> <true/> | <false/>
  <key>InstallMinorUpdate</key> <true/> | <false/>
  <key>PushMajorUpgrade</key> <true/> | <false/>
  <key>TargetMajorUpgrade</key> <string>version</string>
  <key>ForceRestart</key> <true/> | <false/>
  <key>TestMode</key> <true/> | <false/>
  <key>TestModeTimeout</key> <string>seconds</string>
  <key>VerboseMode</key> <true/> | <false/>
  
  ** For detailed documentation visit: https://github.com/Macjutsu/super/wiki
  ** Or use --help to automatically open the S.U.P.E.R.M.A.N. Wiki.
"
# Error log any unrecognized options.
if [[ -n ${unrecognizedOptionsARRAY[*]} ]]; then
	sendToLog  "Error: Unrecognized Options: ${unrecognizedOptionsARRAY[*]}"; parameterERROR="TRUE"
	[[ "$jamfPARENT" == "TRUE" ]] && sendToLog  "Error: Note that each Jamf Pro Policy Parameter can only contain a single option."
	sendToStatus "Inactive Error: Unrecognized Options: ${unrecognizedOptionsARRAY[*]}"
fi

sendToLog "Exit: Show usage."
sendToLog "**** S.U.P.E.R.M.A.N. EXIT ****"
exit 0
}

# Function for decrypting strings
function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

# If there is a real current user then open the S.U.P.E.R.M.A.N. Wiki, otherwise run the showUsage() function.
showHelp() {
checkCurrentUser
if [[ "$currentUSER" != "FALSE" ]]; then
	sendToLog "Starter: Opening S.U.P.E.R.M.A.N. Wiki for user $currentUSER..."
	sudo -u "$currentUSER" open "https://github.com/Macjutsu/super/wiki" &
else
	showUsage
fi

sendToLog "Exit: Show help."
sendToLog "**** S.U.P.E.R.M.A.N. EXIT ****"
exit 0
}

# MARK: *** Parameters ***
################################################################################

# Set default parameters that are used throughout the script.
setDefaults(){
	# Installation folder:
	superFOLDER="/Library/Management/super"

	# Symbolic link in default path for super.
	superLINK="/usr/local/bin/super"

	# Path to a PID file:
	superPIDFILE="/var/run/super.pid"

	# Path to a local property list file:
	superPLIST="$superFOLDER/com.macjutsu.super" # No trailing ".plist"

	# Path to a managed property list file:
	superMANAGEDPLIST="/Library/Managed Preferences/com.macjutsu.super" # No trailing ".plist"

	# Path to main workflow log file:
	superLOG="$superFOLDER/super.log"

	# Path to output of the current softwareupdate --list command:
	checkLOG="$superFOLDER/check.log"

	# Path to output of the softwareupdate command:
	asuLOG="$superFOLDER/asu.log"

	# Path to filtered MDM progress log file:
	mdmLOG="$superFOLDER/mdm.log"

	# Path to filtered softwareupdate daemon progress log file:
	updateLOG="$superFOLDER/update.log"

	# This is the name for the LaunchDaemon.
	launchDaemonNAME="com.macjutsu.super" # No trailing ".plist"

	# Path to the jamf binary:
	jamfBINARY="/usr/local/bin/jamf"

	# Path to the jamfHELPER binary:
	jamfHELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

	# URL to the IBM Notifier.app download:
	ibmNotifierURL="https://github.com/IBM/mac-ibm-notifications/releases/download/v-2.9.1-b-96/IBM.Notifier.zip"

	# Target version for IBM Notifier.app:
	ibmNotifierVERSION="2.9.1"

	# Path to the local IBM Notifier.app:
	ibmNotifierAPP="$superFOLDER/IBM Notifier.app"

	# Path to the local IBM Notifier.app binary:
	ibmNotifierBINARY="$ibmNotifierAPP/Contents/MacOS/IBM Notifier"

	# URL to the erase-install package installer:
	eraseInstallURL="https://github.com/grahampugh/erase-install/releases/download/v26.2/erase-install-depnotify-26.2.pkg"

	# Target version for erase-install.sh:
	eraseInstallVERSION="26.2"

	# Target checksum for erase-install.sh:
	eraseInstallCHECKSUM="02bea045a91ce96a31deddc2ee439832b56116f3"

	# Path to the local erase-install folder:
	eraseInstallFOLDER="/Library/Management/erase-install"

	# Path to the local copy of erase-install.sh:
	eraseInstallSCRIPT="$eraseInstallFOLDER/erase-install.sh"

	# Path to the local copy of installinstallmacos.py:
	installInstallMacOS="$eraseInstallFOLDER/installinstallmacos.py"

	# Path to the local copy of movable Python.framework:
	pythonFRAMEWORK="$eraseInstallFOLDER/Python.framework"

	# Path to the local DEPNotify.app:
	depNotifyAPP="/Applications/Utilities/DEPNotify.app"

	# Path to the local DEPNotify.app binary:
	depNotifyBINARY="$depNotifyAPP/Contents/MacOS/DEPNotify"

	# Path to a local softwareupdate property list file:
	asuPLIST="/Library/Preferences/com.apple.SoftwareUpdate" # No trailing ".plist"

	# The default number of seconds to defer if a user choses not to restart or a required service is temporarily unavailable.
	defaultDeferSECONDS=3600
	
	# Path to for the local cached display icon:
	cachedICON="$superFOLDER/icon.png"

	# The default icon in the if no $displayIconOPTION is specified or found.
	defaultICON="/System/Library/PrivateFrameworks/SoftwareUpdate.framework/Versions/A/Resources/SoftwareUpdate.icns"

	# Default icon size for IBM Notifier.app.
	ibmNotifierIconSIZE=96

	# Default icon size for jamfHelper.
	jamfHelperIconSIZE=96

	# Deadline date display format.
	dateFORMAT="+%B %d, %Y" # Formatting options can be found in the man page for the date command.

	# Deadline time display format.
	timeFORMAT="+%l:%M %p" # Formatting options can be found in the man page for the date command.

	# The default amount of time in seconds to leave test notifications and dialogs open before moving on in the workflow.
	testModeTimeoutSECONDS=10

	# The number of seconds to timeout the check for updates process if no progress is reported.
	checkTimeoutSECONDS=120

	# The number of seconds to timeout the recommended (non-restart) download/update process if no progress is reported.
	recommendedTimeoutSECONDS=300

	# The number of seconds to timeout the mdm push process if no progress is reported.
	mdmTimeoutSECONDS=120
	
	# The number of seconds to timeout the download update/upgrade process if no progress is reported.
	downloadTimeoutSECONDS=120

	# The number of seconds to timeout the preparing update process if no progress is reported.
	prepareTimeoutSECONDS=600

	# The number of seconds to timeout the applying update process if no progress is reported.
	applyTimeoutSECONDS=60

	# The number of seconds to timeout the legacy (macOS 10.x) system update process if no progress is reported.
	asuTimeoutSECONDS=300

	# These parameters identify the macOS version and architecture.
	macosMAJOR=$(sw_vers -productVersion | cut -d'.' -f1) # Expected output: 10, 11, 12
	macosMINOR=$(sw_vers -productVersion | cut -d'.' -f2) # Expected output: 14, 15, 06, 01
	macosVERSION=${macosMAJOR}$(printf "%02d" "$macosMINOR") # Expected output: 1014, 1015, 1106, 1200
	macosARCH=$(arch) # Expected output: i386, arm64
}



# Collect input options and set associated parameters.
getOptions() {
	# If super is running via Jamf Policy installation then the first 3 input parameters are skipped.
	if [[ $1 == "/" ]]; then
		shift 3
		jamfPARENT="TRUE"
	fi

	# This is a standard while/case loop to collect all the input parameters.
	while [[ -n $1 ]]; do
		case "$1" in
			--default-defer* )
				defaultDeferOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--focus-defer* )
				focusDeferOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--menu-defer* )
				menuDeferOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--recheck-defer* )
				recheckDeferOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--delete-deferrals )
				deleteDEFFERALS="TRUE"
			;;
			--focus-count* )
				focusCountOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--soft-count* )
				softCountOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--hard-count* )
				hardCountOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--restart-counts )
				restartCOUNTS="TRUE"
			;;
			--delete-counts )
				deleteCOUNTS="TRUE"
			;;
			--focus-days* )
				focusDaysOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--soft-days* )
				softDaysOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--hard-days* )
				hardDaysOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--zero-day* )
				zeroDayOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--restart-days )
				restartDAYS="TRUE"
			;;
			--delete-days )
				deleteDAYS="TRUE"
			;;
			--focus-date* )
				focusDateOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--soft-date* )
				softDateOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--hard-date* )
				hardDateOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--delete-dates )
				deleteDATES="TRUE"
			;;
			--display-timeout* )
				displayTimeoutOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--display-redraw* )
				displayRedrawOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--display-icon* )
				displayIconOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--icon-size-ibm* )
				iconSizeIbmOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--icon-size-jamf* )
				iconSizeJamfOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			-J|--prefer-jamf-helper )
				preferJamfHelperOPTION="TRUE"
			;;
			-j|--no-prefer-jamf-helper )
				preferJamfHelperOPTION="FALSE"
			;;
			--local-account* )
				localOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--local-password* )
				localPASSWORD=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--admin-account* )
				adminACCOUNT=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--admin-password* )
				adminPASSWORD=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--super-account* )
				superOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--super-password* )
				superPASSWORD=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--jamf-account* )
				jamfOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			--jamf-password* )
				jamfPASSWORD=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			-D|--delete-accounts )
				deleteACCOUNTS="TRUE"
			;;
			--policy-triggers* )
				policyTriggersOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			-S|--skip-updates )
				skipUpdatesOPTION="TRUE"
			;;
			-s|--no-skip-updates )
				skipUpdatesOPTION="FALSE"
			;;
			-F|--force-restart )
				forceRestartOPTION="TRUE"
			;;
			-f|--no-force-restart )
				forceRestartOPTION="FALSE"
			;;
			--install-major-upgrade )
				installMajorUpgradeOPTION="TRUE"
			;;
			--no-install-major-upgrade )
				installMajorUpgradeOPTION="FALSE"
			;;
			--install-minor-update )
				installMinorUpdateOPTION="TRUE"
			;;
			--no-install-minor-update )
				installMinorUpdateOPTION="FALSE"
			;;
			--push-major-upgrade )
				pushMajorUpgradeOPTION="TRUE"
			;;
			--no-push-major-upgrade )
				pushMajorUpgradeOPTION="FALSE"
			;;
			--target-major-upgrade* )
				targetMajorUpgradeOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			-T|--test-mode )
				testModeOPTION="TRUE"
			;;
			-t|--no-test-mode )
				testModeOPTION="FALSE"
			;;
			--test-mode-timeout* )
				testModeTimeoutOPTION=$(echo "$1" | sed -e 's|^[^=]*=||g')
			;;
			-V|--verbose-mode )
				verboseModeOPTION="TRUE"
			;;
			-v|--no-verbose-mode )
				verboseModeOPTION="FALSE"
			;;
			-o|-O|--open-logs )
				openLOGS="TRUE"
			;;
			-x|-X|--reset-super )
				resetLocalPROPERTIES="TRUE"
			;;
			-u|-U|--usage )
				showUsage
			;;
			-h|-H|--help )
				showHelp
			;;
			*)
				unrecognizedOptionsARRAY+=("$1")
			;;
		esac
		shift
	done

	# Error log any unrecognized options.
	[[ -n ${unrecognizedOptionsARRAY[*]} ]] && showUsage
}

# Collect any parameters stored in $superMANAGEDPLIST and/or $superPLIST.
getPreferences() {
# If $deleteDEFFERALS is specified, then delete all local deferral preferences.
if [[ "$deleteDEFFERALS" == "TRUE" ]]; then
	sendToLog "Starter: Deleting all local deferral preferences."
	defaults delete "$superPLIST" DefaultDefer 2> /dev/null
	defaults delete "$superPLIST" FocusDefer 2> /dev/null
	defaults delete "$superPLIST" MenuDefer 2> /dev/null
	defaults delete "$superPLIST" RecheckDefer 2> /dev/null
fi

# If $deleteCOUNTS is specified, then delete all local maximum deferral count deadline preferences.
if [[ "$deleteCOUNTS" == "TRUE" ]]; then
	sendToLog "Starter: Deleting all local maximum deferral count deadline preferences."
	defaults delete "$superPLIST" FocusCount 2> /dev/null
	defaults delete "$superPLIST" SoftCount 2> /dev/null
	defaults delete "$superPLIST" HardCount 2> /dev/null
fi

# If $deleteDAYS is specified, then delete all local maximum day deadline preferences.
if [[ "$deleteDAYS" == "TRUE" ]]; then
	sendToLog "Starter: Deleting all local maximum day deadline preferences."
	defaults delete "$superPLIST" FocusDays 2> /dev/null
	defaults delete "$superPLIST" SoftDays 2> /dev/null
	defaults delete "$superPLIST" HardDays 2> /dev/null
	defaults delete "$superPLIST" ZeroDay 2> /dev/null
fi

# If $deleteDATES is specified, then delete all local date deadline preferences.
if [[ "$deleteDATES" == "TRUE" ]]; then
	sendToLog "Starter: Deleting all local date deadline preferences."
	defaults delete "$superPLIST" FocusDate 2> /dev/null
	defaults delete "$superPLIST" SoftDate 2> /dev/null
	defaults delete "$superPLIST" HardDate 2> /dev/null
fi

# If $resetLocalPROPERTIES is specified, then delete all local non-account preferences.
if [[ "$resetLocalPROPERTIES" == "TRUE" ]]; then
	sendToLog "Starter: Deleting all local non-account preferences."
	defaults delete "$superPLIST" DefaultDefer 2> /dev/null
	defaults delete "$superPLIST" FocusDefer 2> /dev/null
	defaults delete "$superPLIST" MenuDefer 2> /dev/null
	defaults delete "$superPLIST" RecheckDefer 2> /dev/null
	defaults delete "$superPLIST" FocusCount 2> /dev/null
	defaults delete "$superPLIST" SoftCount 2> /dev/null
	defaults delete "$superPLIST" HardCount 2> /dev/null
	defaults delete "$superPLIST" FocusDays 2> /dev/null
	defaults delete "$superPLIST" SoftDays 2> /dev/null
	defaults delete "$superPLIST" HardDays 2> /dev/null
	defaults delete "$superPLIST" ZeroDay 2> /dev/null
	defaults delete "$superPLIST" FocusDate 2> /dev/null
	defaults delete "$superPLIST" SoftDate 2> /dev/null
	defaults delete "$superPLIST" HardDate 2> /dev/null
	defaults delete "$superPLIST" DisplayTimeout 2> /dev/null
	defaults delete "$superPLIST" DisplayRedraw 2> /dev/null
	defaults delete "$superPLIST" DisplayIcon 2> /dev/null
	rm -r "$cachedICON" > /dev/null 2>&1
	defaults delete "$superPLIST" IconSizeIbm 2> /dev/null
	defaults delete "$superPLIST" IconSizeJamf 2> /dev/null
	defaults delete "$superPLIST" PreferJamfHelper 2> /dev/null
	defaults delete "$superPLIST" PolicyTriggers 2> /dev/null
	defaults delete "$superPLIST" SkipUpdates 2> /dev/null
	defaults delete "$superPLIST" InstallMajorUpgrade 2> /dev/null
	defaults delete "$superPLIST" InstallMinorUpdate 2> /dev/null
	defaults delete "$superPLIST" PushMajorUpgrade 2> /dev/null
	defaults delete "$superPLIST" TargetMajorUpgrade 2> /dev/null
	defaults delete "$superPLIST" ForceRestart 2> /dev/null
	defaults delete "$superPLIST" TestMode 2> /dev/null
	defaults delete "$superPLIST" TestModeTimeout 2> /dev/null
	defaults delete "$superPLIST" VerboseMode 2> /dev/null
	restartZeroDay
	restartDeferralCounters
	fullCheckREQUIRED="TRUE"
	defaults delete "$superPLIST" UpdatesAvailable 2> /dev/null
	defaults delete "$superPLIST" SystemUpdateAvailable 2> /dev/null
	defaults delete "$superPLIST" UpdatesList 2> /dev/null
	defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
	defaults delete "$superPLIST" MajorUpgradeDownload 2> /dev/null
	defaults delete "$superPLIST" UpdateValidate 2> /dev/null
fi

# Collect any managed preferences from $superMANAGEDPLIST.
if [[ -f "$superMANAGEDPLIST.plist" ]]; then
	jamfProIdMANAGED=$(defaults read "$superMANAGEDPLIST" JamfProID 2> /dev/null)
	defaultDeferMANAGED=$(defaults read "$superMANAGEDPLIST" DefaultDefer 2> /dev/null)
	focusDeferMANAGED=$(defaults read "$superMANAGEDPLIST" FocusDefer 2> /dev/null)
	menuDeferMANAGED=$(defaults read "$superMANAGEDPLIST" MenuDefer 2> /dev/null)
	recheckDeferMANAGED=$(defaults read "$superMANAGEDPLIST" RecheckDefer 2> /dev/null)
	focusCountMANAGED=$(defaults read "$superMANAGEDPLIST" FocusCount 2> /dev/null)
	softCountMANAGED=$(defaults read "$superMANAGEDPLIST" SoftCount 2> /dev/null)
	hardCountMANAGED=$(defaults read "$superMANAGEDPLIST" HardCount 2> /dev/null)
	focusDaysMANAGED=$(defaults read "$superMANAGEDPLIST" FocusDays 2> /dev/null)
	softDaysMANAGED=$(defaults read "$superMANAGEDPLIST" SoftDays 2> /dev/null)
	hardDaysMANAGED=$(defaults read "$superMANAGEDPLIST" HardDays 2> /dev/null)
	zeroDayMANAGED=$(defaults read "$superMANAGEDPLIST" ZeroDay 2> /dev/null)
	focusDateMANAGED=$(defaults read "$superMANAGEDPLIST" FocusDate 2> /dev/null)
	softDateMANAGED=$(defaults read "$superMANAGEDPLIST" SoftDate 2> /dev/null)
	hardDateMANAGED=$(defaults read "$superMANAGEDPLIST" HardDate 2> /dev/null)
	displayTimeoutMANAGED=$(defaults read "$superMANAGEDPLIST" DisplayTimeout 2> /dev/null)
	displayRedrawMANAGED=$(defaults read "$superMANAGEDPLIST" DisplayRedraw 2> /dev/null)
	displayIconMANAGED=$(defaults read "$superMANAGEDPLIST" DisplayIcon 2> /dev/null)
	iconSizeIbmMANAGED=$(defaults read "$superMANAGEDPLIST" IconSizeIbm 2> /dev/null)
	iconSizeJamfMANAGED=$(defaults read "$superMANAGEDPLIST" IconSizeJamf 2> /dev/null)
	preferJamfHelperMANAGED=$(defaults read "$superMANAGEDPLIST" PreferJamfHelper 2> /dev/null)
	policyTriggersMANAGED=$(defaults read "$superMANAGEDPLIST" PolicyTriggers 2> /dev/null)
	skipUpdatesMANAGED=$(defaults read "$superMANAGEDPLIST" SkipUpdates 2> /dev/null)
	forceRestartMANAGED=$(defaults read "$superMANAGEDPLIST" ForceRestart 2> /dev/null)
	installMajorUpgradeMANAGED=$(defaults read "$superMANAGEDPLIST" InstallMajorUpgrade 2> /dev/null)
	installMinorUpdateMANAGED=$(defaults read "$superMANAGEDPLIST" InstallMinorUpdate 2> /dev/null)
	pushMajorUpgradeMANAGED=$(defaults read "$superMANAGEDPLIST" PushMajorUpgrade 2> /dev/null)
	targetMajorUpgradeMANAGED=$(defaults read "$superMANAGEDPLIST" TargetMajorUpgrade 2> /dev/null)
	testModeMANAGED=$(defaults read "$superMANAGEDPLIST" TestMode 2> /dev/null)
	testModeTimeoutMANAGED=$(defaults read "$superMANAGEDPLIST" TestModeTimeout 2> /dev/null)
	verboseModeMANAGED=$(defaults read "$superMANAGEDPLIST" VerboseMode 2> /dev/null)
fi

# Collect any local preferences from $superPLIST.
if [[ -f "$superPLIST.plist" ]]; then
	defaultDeferPROPERTY=$(defaults read "$superPLIST" DefaultDefer 2> /dev/null)
	focusDeferPROPERTY=$(defaults read "$superPLIST" FocusDefer 2> /dev/null)
	menuDeferPROPERTY=$(defaults read "$superPLIST" MenuDefer 2> /dev/null)
	recheckDeferPROPERTY=$(defaults read "$superPLIST" RecheckDefer 2> /dev/null)
	focusCountPROPERTY=$(defaults read "$superPLIST" FocusCount 2> /dev/null)
	softCountPROPERTY=$(defaults read "$superPLIST" SoftCount 2> /dev/null)
	hardCountPROPERTY=$(defaults read "$superPLIST" HardCount 2> /dev/null)
	focusDaysPROPERTY=$(defaults read "$superPLIST" FocusDays 2> /dev/null)
	softDaysPROPERTY=$(defaults read "$superPLIST" SoftDays 2> /dev/null)
	hardDaysPROPERTY=$(defaults read "$superPLIST" HardDays 2> /dev/null)
	zeroDayPROPERTY=$(defaults read "$superPLIST" ZeroDay 2> /dev/null)
	focusDatePROPERTY=$(defaults read "$superPLIST" FocusDate 2> /dev/null)
	softDatePROPERTY=$(defaults read "$superPLIST" SoftDate 2> /dev/null)
	hardDatePROPERTY=$(defaults read "$superPLIST" HardDate 2> /dev/null)
	displayTimeoutPROPERTY=$(defaults read "$superPLIST" DisplayTimeout 2> /dev/null)
	displayRedrawPROPERTY=$(defaults read "$superPLIST" DisplayRedraw 2> /dev/null)
	iconSizeIbmPROPERTY=$(defaults read "$superPLIST" IconSizeIbm 2> /dev/null)
	iconSizeJamfPROPERTY=$(defaults read "$superPLIST" IconSizeJamf 2> /dev/null)
	preferJamfHelperPROPERTY=$(defaults read "$superPLIST" PreferJamfHelper 2> /dev/null)
	policyTriggersPROPERTY=$(defaults read "$superPLIST" PolicyTriggers 2> /dev/null)
	skipUpdatesPROPERTY=$(defaults read "$superPLIST" SkipUpdates 2> /dev/null)
	forceRestartPROPERTY=$(defaults read "$superPLIST" ForceRestart 2> /dev/null)
	installMajorUpgradePROPERTY=$(defaults read "$superPLIST" InstallMajorUpgrade 2> /dev/null)
	installMinorUpdatePROPERTY=$(defaults read "$superPLIST" InstallMinorUpdate 2> /dev/null)
	pushMajorUpgradePROPERTY=$(defaults read "$superPLIST" PushMajorUpgrade 2> /dev/null)
	targetMajorUpgradePROPERTY=$(defaults read "$superPLIST" TargetMajorUpgrade 2> /dev/null)
	testModePROPERTY=$(defaults read "$superPLIST" TestMode 2> /dev/null)
	testModeTimeoutPROPERTY=$(defaults read "$superPLIST" TestModeTimeout 2> /dev/null)
	verboseModePROPERTY=$(defaults read "$superPLIST" VerboseMode 2> /dev/null)
fi

# This logic ensures the priority order of managed preference overrides the new input option which overrides the saved local preference.
if [[ -n $defaultDeferMANAGED ]]; then
	defaultDeferOPTION="$defaultDeferMANAGED"
elif [[ -z $defaultDeferOPTION ]] && [[ -n $defaultDeferPROPERTY ]]; then
	defaultDeferOPTION="$defaultDeferPROPERTY"
fi
if [[ -n $focusDeferMANAGED ]]; then
	focusDeferOPTION="$focusDeferMANAGED"
elif [[ -z $focusDeferOPTION ]] && [[ -n $focusDeferPROPERTY ]]; then
	focusDeferOPTION="$focusDeferPROPERTY"
fi
if [[ -n $menuDeferMANAGED ]]; then
	menuDeferOPTION="$menuDeferMANAGED"
elif [[ -z $menuDeferOPTION ]] && [[ -n $menuDeferPROPERTY ]]; then
	menuDeferOPTION="$menuDeferPROPERTY"
fi
if [[ -n $recheckDeferMANAGED ]]; then
	recheckDeferOPTION="$recheckDeferMANAGED"
elif [[ -z $recheckDeferOPTION ]] && [[ -n $recheckDeferPROPERTY ]]; then
	recheckDeferOPTION="$recheckDeferPROPERTY"
fi
if [[ -n $focusCountMANAGED ]]; then
	focusCountOPTION="$focusCountMANAGED"
elif [[ -z $focusCountOPTION ]] && [[ -n $focusCountPROPERTY ]]; then
	focusCountOPTION="$focusCountPROPERTY"
fi
if [[ -n $softCountMANAGED ]]; then
	softCountOPTION="$softCountMANAGED"
elif [[ -z $softCountOPTION ]] && [[ -n $softCountPROPERTY ]]; then
	softCountOPTION="$softCountPROPERTY"
fi
if [[ -n $hardCountMANAGED ]]; then
	hardCountOPTION="$hardCountMANAGED"
elif [[ -z $hardCountOPTION ]] && [[ -n $hardCountPROPERTY ]]; then
	hardCountOPTION="$hardCountPROPERTY"
fi
if [[ -n $focusDaysMANAGED ]]; then
	focusDaysOPTION="$focusDaysMANAGED"
elif [[ -z $focusDaysOPTION ]] && [[ -n $focusDaysPROPERTY ]]; then
	focusDaysOPTION="$focusDaysPROPERTY"
fi
if [[ -n $softDaysMANAGED ]]; then
	softDaysOPTION="$softDaysMANAGED"
elif [[ -z $softDaysOPTION ]] && [[ -n $softDaysPROPERTY ]]; then
	softDaysOPTION="$softDaysPROPERTY"
fi
if [[ -n $hardDaysMANAGED ]]; then
	hardDaysOPTION="$hardDaysMANAGED"
elif [[ -z $hardDaysOPTION ]] && [[ -n $hardDaysPROPERTY ]]; then
	hardDaysOPTION="$hardDaysPROPERTY"
fi
if [[ -n $zeroDayMANAGED ]]; then
	zeroDayOPTION="$zeroDayMANAGED"
elif [[ -z $zeroDayOPTION ]] && [[ -n $zeroDayPROPERTY ]]; then
	zeroDayOPTION="$zeroDayPROPERTY"
fi
if [[ -n $focusDateMANAGED ]]; then
	focusDateOPTION="$focusDateMANAGED"
elif [[ -z $focusDateOPTION ]] && [[ -n $focusDatePROPERTY ]]; then
	focusDateOPTION="$focusDatePROPERTY"
fi
if [[ -n $softDateMANAGED ]]; then
	softDateOPTION="$softDateMANAGED"
elif [[ -z $softDateOPTION ]] && [[ -n $softDatePROPERTY ]]; then
	softDateOPTION="$softDatePROPERTY"
fi
if [[ -n $hardDateMANAGED ]]; then
	hardDateOPTION="$hardDateMANAGED"
elif [[ -z $hardDateOPTION ]] && [[ -n $hardDatePROPERTY ]]; then
	hardDateOPTION="$hardDatePROPERTY"
fi
if [[ -n $displayTimeoutMANAGED ]]; then
	displayTimeoutOPTION="$displayTimeoutMANAGED"
elif [[ -z $displayTimeoutOPTION ]] && [[ -n $displayTimeoutPROPERTY ]]; then
	displayTimeoutOPTION="$displayTimeoutPROPERTY"
fi
if [[ -n $displayRedrawMANAGED ]]; then
	displayRedrawOPTION="$displayRedrawMANAGED"
elif [[ -z $displayRedrawOPTION ]] && [[ -n $displayRedrawPROPERTY ]]; then
	displayRedrawOPTION="$displayRedrawPROPERTY"
fi
[[ -n $displayIconMANAGED ]] && displayIconOPTION="$displayIconMANAGED"
if [[ -n $iconSizeIbmMANAGED ]]; then
	iconSizeIbmOPTION="$iconSizeIbmMANAGED"
elif [[ -z $iconSizeIbmOPTION ]] && [[ -n $iconSizeIbmPROPERTY ]]; then
	iconSizeIbmOPTION="$iconSizeIbmPROPERTY"
fi
if [[ -n $iconSizeJamfMANAGED ]]; then
	iconSizeJamfOPTION="$iconSizeJamfMANAGED"
elif [[ -z $iconSizeJamfOPTION ]] && [[ -n $iconSizeJamfPROPERTY ]]; then
	iconSizeJamfOPTION="$iconSizeJamfPROPERTY"
fi
if [[ -n $preferJamfHelperMANAGED ]]; then
	preferJamfHelperOPTION="$preferJamfHelperMANAGED"
elif [[ -z $preferJamfHelperOPTION ]] && [[ -n $preferJamfHelperPROPERTY ]]; then
	preferJamfHelperOPTION="$preferJamfHelperPROPERTY"
fi
if [[ -n $policyTriggersMANAGED ]]; then
	policyTriggersOPTION="$policyTriggersMANAGED"
elif [[ -z $policyTriggersOPTION ]] && [[ -n $policyTriggersPROPERTY ]]; then
	policyTriggersOPTION="$policyTriggersPROPERTY"
fi
if [[ -n $skipUpdatesMANAGED ]]; then
	skipUpdatesOPTION="$skipUpdatesMANAGED"
elif [[ -z $skipUpdatesOPTION ]] && [[ -n $skipUpdatesPROPERTY ]]; then
	skipUpdatesOPTION="$skipUpdatesPROPERTY"
fi
if [[ -n $forceRestartMANAGED ]]; then
	forceRestartOPTION="$forceRestartMANAGED"
elif [[ -z $forceRestartOPTION ]] && [[ -n $forceRestartPROPERTY ]]; then
	forceRestartOPTION="$forceRestartPROPERTY"
fi
if [[ -n $installMajorUpgradeMANAGED ]]; then
	installMajorUpgradeOPTION="$installMajorUpgradeMANAGED"
elif [[ -z $installMajorUpgradeOPTION ]] && [[ -n $installMajorUpgradePROPERTY ]]; then
	installMajorUpgradeOPTION="$installMajorUpgradePROPERTY"
fi
if [[ -n $installMinorUpdateMANAGED ]]; then
	installMinorUpdateOPTION="$installMinorUpdateMANAGED"
elif [[ -z $installMinorUpdateOPTION ]] && [[ -n $installMinorUpdatePROPERTY ]]; then
	installMinorUpdateOPTION="$installMinorUpdatePROPERTY"
fi
if [[ -n $pushMajorUpgradeMANAGED ]]; then
	pushMajorUpgradeOPTION="$pushMajorUpgradeMANAGED"
elif [[ -z $pushMajorUpgradeOPTION ]] && [[ -n $pushMajorUpgradePROPERTY ]]; then
	pushMajorUpgradeOPTION="$pushMajorUpgradePROPERTY"
fi
if [[ -n $targetMajorUpgradeMANAGED ]]; then
	targetMajorUpgradeOPTION="$targetMajorUpgradeMANAGED"
elif [[ -z $targetMajorUpgradeOPTION ]] && [[ -n $targetMajorUpgradePROPERTY ]]; then
	targetMajorUpgradeOPTION="$targetMajorUpgradePROPERTY"
fi
if [[ -n $testModeMANAGED ]]; then
	testModeOPTION="$testModeMANAGED"
elif [[ -z $testModeOPTION ]] && [[ -n $testModePROPERTY ]]; then
	testModeOPTION="$testModePROPERTY"
fi
if [[ -n $testModeTimeoutMANAGED ]]; then
	testModeTimeoutOPTION="$testModeTimeoutMANAGED"
elif [[ -z $testModeTimeoutOPTION ]] && [[ -n $testModeTimeoutPROPERTY ]]; then
	testModeTimeoutOPTION="$testModeTimeoutPROPERTY"
fi
if [[ -n $verboseModeMANAGED ]]; then
	verboseModeOPTION="$verboseModeMANAGED"
elif [[ -z $verboseModeOPTION ]] && [[ -n $verboseModePROPERTY ]]; then
	verboseModeOPTION="$verboseModePROPERTY"
fi
}

# Validate non-credential parameters and manage $superPLIST. Any errors set $parameterERROR.
manageParameters() {
parameterERROR="FALSE"

# Various regular expressions used for parameter validation.
regexNUMBER="^[0-9]+$"
regexMENU="^[0-9*,]+$"
regexDATE="^[0-9][0-9][0-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])$"
regexTIME="^(2[0-3]|[01][0-9]):[0-5][0-9]$"
regexDATETIME="^[0-9][0-9][0-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]):(2[0-3]|[01][0-9]):[0-5][0-9]$"
regexMACOSMAJORVERSION="^([1][1-3])$"

# Validate $defaultDeferOPTION input and if valid override default $defaultDeferSECONDS parameter and save to $superPLIST.
if [[ "$defaultDeferOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for default deferral."
	defaults delete "$superPLIST" DefaultDefer 2> /dev/null
elif [[ -n $defaultDeferOPTION ]] && [[ $defaultDeferOPTION =~ $regexNUMBER ]]; then
	if [[ $defaultDeferOPTION -lt 120 ]]; then
		sendToLog "Warning: Specified default deferral time of $defaultDeferOPTION seconds is too low, rounding up to 120 seconds."
		defaultDeferSECONDS="120"
	elif [[ $defaultDeferOPTION -gt 86400 ]]; then
		sendToLog "Warning: Specified default deferral time of $defaultDeferOPTION seconds is too high, rounding down to 86400 seconds (1 day)."
		defaultDeferSECONDS="86400"
	else
		defaultDeferSECONDS="$defaultDeferOPTION"
	fi
	defaults write "$superPLIST" DefaultDefer -string "$defaultDeferSECONDS"
elif [[ -n $defaultDeferOPTION ]] && ! [[ $defaultDeferOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The default deferral time must only be a number."; parameterERROR="TRUE"
fi

# Validate $focusDeferOPTION input and if valid set $focusDeferSECONDS and save to $superPLIST.
if [[ "$focusDeferOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for Focus deferral."
	defaults delete "$superPLIST" FocusDefer 2> /dev/null
elif [[ -n $focusDeferOPTION ]] && [[ $focusDeferOPTION =~ $regexNUMBER ]]; then
	if [[ $focusDeferOPTION -lt 120 ]]; then
		sendToLog "Warning: Specified focus deferral time of $focusDeferOPTION seconds is too low, rounding up to 120 seconds."
		focusDeferSECONDS="120"
	elif [[ $focusDeferOPTION -gt 86400 ]]; then
		sendToLog "Warning: Specified focus deferral time of $focusDeferOPTION seconds is too high, rounding down to 86400 seconds (1 day)."
		focusDeferSECONDS="86400"
	else
		focusDeferSECONDS="$focusDeferOPTION"
	fi
	defaults write "$superPLIST" FocusDefer -string "$focusDeferSECONDS"
elif [[ -n $focusDeferOPTION ]] && ! [[ $focusDeferOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The focus deferral time must only be a number."; parameterERROR="TRUE"
fi

# Validate $menuDeferOPTION input and if valid set $menuDeferSECONDS and save to $superPLIST.
if [[ "$menuDeferOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for menu deferral."
	defaults delete "$superPLIST" MenuDefer 2> /dev/null
elif [[ -n $menuDeferOPTION ]] && [[ $menuDeferOPTION =~ $regexMENU ]]; then
	oldIFS="$IFS"; IFS=','
	read -r -a menuDeferARRAY <<< "$menuDeferOPTION"
	for i in "${!menuDeferARRAY[@]}"; do
		if [[ ${menuDeferARRAY[i]} -lt 120 ]]; then
			sendToLog "Warning: Specified menu deferral time of ${menuDeferARRAY[i]} seconds is too low, rounding up to 120 seconds."
			menuDeferARRAY[i]="120"
		elif [[ ${menuDeferARRAY[i]} -gt 86400 ]]; then
			sendToLog "Warning: Specified menu deferral time of ${menuDeferARRAY[i]} seconds is too high, rounding down to 86400 seconds (1 day)."
			menuDeferARRAY[i]="86400"
		fi
	done
	menuDeferSECONDS="${menuDeferARRAY[*]}"
	defaults write "$superPLIST" MenuDefer -string "$menuDeferSECONDS"
	IFS="$oldIFS"
elif [[ -n $menuDeferOPTION ]] && ! [[ $menuDeferOPTION =~ $regexMENU ]]; then
	sendToLog "Parameter Error: The defer pop-up menu time(s) must only contain numbers and commas (no spaces)."; parameterERROR="TRUE"
fi

# Validate $recheckDeferOPTION input and if valid set $recheckDeferSECONDS and save to $superPLIST.
if [[ "$recheckDeferOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for recheck deferral."
	defaults delete "$superPLIST" RecheckDefer 2> /dev/null
elif [[ -n $recheckDeferOPTION ]] && [[ $recheckDeferOPTION =~ $regexNUMBER ]]; then
	if [[ $recheckDeferOPTION -lt 120 ]]; then
		sendToLog "Warning: Specified recheck deferral time of $recheckDeferOPTION seconds is too low, rounding up to 120 seconds."
		recheckDeferSECONDS="120"
	elif [[ $recheckDeferOPTION -gt 2628288 ]]; then
		sendToLog "Warning: Specified recheck deferral time of $recheckDeferOPTION seconds is too high, rounding down to 2628288 seconds (30 days)."
		recheckDeferSECONDS="2628288"
	else
		recheckDeferSECONDS="$recheckDeferOPTION"
	fi
	defaults write "$superPLIST" RecheckDefer -string "$recheckDeferSECONDS"
elif [[ -n $recheckDeferOPTION ]] && ! [[ $recheckDeferOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The recheck deferral time must only be a number."; parameterERROR="TRUE"
fi

# Validated that $recheckDeferOPTION and $skipUpdatesOPTION are not both active.
if [[ -n $recheckDeferOPTION ]] && [[ "$skipUpdatesOPTION" == "TRUE" ]]; then
	sendToLog "Parameter Error: You can not specify both the --recheck-defer and --skip-updates options at the same time."; parameterERROR="TRUE"
fi

# Validate $focusCountOPTION input and if valid set $focusCountMAX and save to $superPLIST.
if [[ "$focusCountOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for focus count deadline."
	defaults delete "$superPLIST" FocusCount 2> /dev/null
elif [[ -n $focusCountOPTION ]] && [[ $focusCountOPTION =~ $regexNUMBER ]]; then
	focusCountMAX="$focusCountOPTION"
	defaults write "$superPLIST" FocusCount -string "$focusCountMAX"
elif [[ -n $focusCountOPTION ]] && ! [[ $focusCountOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The focus count deadline must only be a number."; parameterERROR="TRUE"
fi

# Validate $softCountOPTION input and if valid set $softCountMAX.
if [[ "$softCountOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for soft count deadline."
	defaults delete "$superPLIST" SoftCount 2> /dev/null
elif [[ -n $softCountOPTION ]] && [[ $softCountOPTION =~ $regexNUMBER ]]; then
	softCountMAX="$softCountOPTION"
elif [[ -n $softCountOPTION ]] && ! [[ $softCountOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The soft count deadline must only be a number."; parameterERROR="TRUE"
fi

# Validate $hardCountOPTION input and if valid set $hardCountMAX.
if [[ "$hardCountOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for hard count deadline."
	defaults delete "$superPLIST" HardCount 2> /dev/null
elif [[ -n $hardCountOPTION ]] && [[ $hardCountOPTION =~ $regexNUMBER ]]; then
	hardCountMAX="$hardCountOPTION"
elif [[ -n $hardCountOPTION ]] && ! [[ $hardCountOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The hard count deadline must only be a number."; parameterERROR="TRUE"
fi

# Validated that $softCountMAX and $hardCountMAX are not both active, if not then save $softCountMAX or $hardCountMAX to $superPLIST.
if [[ -n $softCountMAX ]] && [[ -n $hardCountMAX ]]; then
	sendToLog "Parameter Error: There cannot be simultaneous deferral maximums for both soft count and hard count deadlines. You must pick one maximum deferral count behavior."; parameterERROR="TRUE"
else
	[[ -n $softCountMAX ]] && defaults write "$superPLIST" SoftCount -string "$softCountMAX"
	[[ -n $hardCountMAX ]] && defaults write "$superPLIST" HardCount -string "$hardCountMAX"
fi

# Validate $focusDaysOPTION input and if valid set $focusDaysMAX and $focusDaysSECONDS.
if [[ "$focusDaysOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for focus days deadline."
	defaults delete "$superPLIST" FocusDays 2> /dev/null
elif [[ -n $focusDaysOPTION ]] && [[ $focusDaysOPTION =~ $regexNUMBER ]]; then
	focusDaysMAX="$focusDaysOPTION"
	focusDaysSECONDS=$((focusDaysMAX*86400))
elif [[ -n $focusDaysOPTION ]] && ! [[ $focusDaysOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The focus days deadline must only be a number."; parameterERROR="TRUE"
fi

# Validate $softDaysOPTION input and if valid set $softDaysMAX and $softDaysSECONDS.
if [[ "$softDaysOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for soft days deadline."
	defaults delete "$superPLIST" SoftDays 2> /dev/null
elif [[ -n $softDaysOPTION ]] && [[ $softDaysOPTION =~ $regexNUMBER ]]; then
	softDaysMAX="$softDaysOPTION"
	softDaysSECONDS=$((softDaysMAX*86400))
elif [[ -n $softDaysOPTION ]] && ! [[ $softDaysOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The soft days deadline must only be a number."; parameterERROR="TRUE"
fi

# Validate $hardDaysOPTION input and if valid set $hardDaysMAX and $hardDaysSECONDS.
if [[ "$hardDaysOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for hard days deadline."
	defaults delete "$superPLIST" HardDays 2> /dev/null
elif [[ -n $hardDaysOPTION ]] && [[ $hardDaysOPTION =~ $regexNUMBER ]]; then
	hardDaysMAX="$hardDaysOPTION"
	hardDaysSECONDS=$((hardDaysMAX*86400))
elif [[ -n $hardDaysOPTION ]] && ! [[ $hardDaysOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The hard days deadline must only be a number."; parameterERROR="TRUE"
fi

# Validate $focusDaysMAX, $softDaysMAX, and $hardDaysMAX in relation to each other. If valid then save maximum day deadlines to $superPLIST.
if [[ -n $hardDaysMAX ]] && [[ -n $softDaysMAX ]] && [[ $hardDaysMAX -le $softDaysMAX ]]; then
	sendToLog "Parameter Error: The maximum hard days deadline of $hardDaysMAX day(s) must be more than the maximum soft days deadline of $softDaysMAX day(s)."; parameterERROR="TRUE"
fi
if [[ -n $hardDaysMAX ]] && [[ -n $focusDaysMAX ]] && [[ $hardDaysMAX -le $focusDaysMAX ]]; then
	sendToLog "Parameter Error: The maximum hard days deadline of $hardDaysMAX day(s) must be more than the maximum focus days deadline of $focusDaysMAX day(s)."; parameterERROR="TRUE"
fi
if [[ -n $softDaysMAX ]] && [[ -n $focusDaysMAX ]] && [[ $softDaysMAX -le $focusDaysMAX ]]; then
	sendToLog "Parameter Error: The maximum soft days deadline of $softDaysMAX day(s) must be more than the maximum focus days deadline of $focusDaysMAX day(s)."; parameterERROR="TRUE"
fi
if [[ "$parameterERROR" != "TRUE" ]]; then
	[[ -n $focusDaysMAX ]] && defaults write "$superPLIST" FocusDays -string "$focusDaysMAX"
	[[ -n $softDaysMAX ]] && defaults write "$superPLIST" SoftDays -string "$softDaysMAX"
	[[ -n $hardDaysMAX ]] && defaults write "$superPLIST" HardDays -string "$hardDaysMAX"
fi

# Validate $zeroDayOPTION, and if valid set $zeroDayOVERRIDE.
if [[ "$zeroDayOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for manual zero day override date."
	defaults delete "$superPLIST" ZeroDay 2> /dev/null
elif [[ -n $zeroDayOPTION ]]; then
	extractDATE=$(echo "$zeroDayOPTION" | cut -c-10 )
	if [[ $extractDATE =~ $regexDATE ]]; then
		extractTIME=$(echo "$zeroDayOPTION" | cut -c11- )
		if [[ -n $extractTIME ]]; then
			extractHOURS=$(echo "$extractTIME" | cut -d: -f2)
			[[ -z $extractHOURS ]] && extractHOURS="00"
			extractMINUTES=$(echo "$extractTIME" | cut -d: -f3)
			[[ -z $extractMINUTES ]] && extractMINUTES="00"
			extractTIME="$extractHOURS:$extractMINUTES"
		else
			extractTIME="00:00"
		fi
		if [[ $extractTIME =~ $regexTIME ]]; then
			calculatedDEADLINE="$extractDATE:$extractTIME"
		else
			sendToLog "Parameter Error: The manual zero day override date time must be a valid 24-hour time formatted as hh:mm."; parameterERROR="TRUE"
		fi
	else
		sendToLog "Parameter Error: The manual zero day override date must be a valid date formatted as YYYY-MM-DD."; parameterERROR="TRUE"
	fi
	if [[ $calculatedDEADLINE =~ $regexDATETIME ]]; then
		zeroDayOVERRIDE="$calculatedDEADLINE"
	else
		sendToLog "Parameter Error: The manual zero day override date must be a valid and formatted as YYYY-MM-DD:hh:mm."; parameterERROR="TRUE"
	fi
fi

# Validate that any $zeroDayOVERRIDE also includes a day deadline, if valid save to $superPLIST.
if { [[ -z $focusDaysMAX ]] && [[ -z $softDaysMAX ]] && [[ -z $hardDaysMAX ]]; } && [[ -n $zeroDayOVERRIDE ]]; then
	sendToLog "Parameter Error: Specifying a manual zero day date also requires that you set a day deadline."; parameterERROR="TRUE"
fi
if [[ "$parameterERROR" != "TRUE" ]]; then
	[[ -n $zeroDayOVERRIDE ]] && defaults write "$superPLIST" ZeroDay -string "$zeroDayOVERRIDE"
fi

# Validate $focusDateOPTION, if valid set $focusDateMAX and $focusDateEPOCH.
if [[ "$focusDateOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for focus date deadline."
	defaults delete "$superPLIST" FocusDate 2> /dev/null
elif [[ -n $focusDateOPTION ]]; then
	extractDATE=$(echo "$focusDateOPTION" | cut -c-10 )
	if [[ $extractDATE =~ $regexDATE ]]; then
		extractTIME=$(echo "$focusDateOPTION" | cut -c11- )
		if [[ -n $extractTIME ]]; then
			extractHOURS=$(echo "$extractTIME" | cut -d: -f2)
			[[ -z $extractHOURS ]] && extractHOURS="00"
			extractMINUTES=$(echo "$extractTIME" | cut -d: -f3)
			[[ -z $extractMINUTES ]] && extractMINUTES="00"
			extractTIME="$extractHOURS:$extractMINUTES"
		else
			extractTIME="00:00"
		fi
		if [[ $extractTIME =~ $regexTIME ]]; then
			calculatedDEADLINE="$extractDATE:$extractTIME"
		else
			sendToLog "Parameter Error: The focus date deadline time must be a valid 24-hour time formatted as hh:mm."; parameterERROR="TRUE"
		fi
	else
		sendToLog "Parameter Error: The focus date deadline date must be a valid date formatted as YYYY-MM-DD."; parameterERROR="TRUE"
	fi
	if [[ $calculatedDEADLINE =~ $regexDATETIME ]]; then
		focusDateMAX="$calculatedDEADLINE"
		focusDateEPOCH=$(date -j -f "%Y-%m-%d:%H:%M" "$calculatedDEADLINE" +"%s")
	else
		sendToLog "Parameter Error: The focus date deadline must be a valid and formatted as YYYY-MM-DD:hh:mm."; parameterERROR="TRUE"
	fi
fi

# Validate $softDateOPTION, if valid set $softDateMAX and $softDateEPOCH.
if [[ "$softDateOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for soft date deadline."
	defaults delete "$superPLIST" SoftDate 2> /dev/null
elif [[ -n $softDateOPTION ]]; then
	extractDATE=$(echo "$softDateOPTION" | cut -c-10 )
	if [[ $extractDATE =~ $regexDATE ]]; then
		extractTIME=$(echo "$softDateOPTION" | cut -c11- )
		if [[ -n $extractTIME ]]; then
			extractHOURS=$(echo "$extractTIME" | cut -d: -f2)
			[[ -z $extractHOURS ]] && extractHOURS="00"
			extractMINUTES=$(echo "$extractTIME" | cut -d: -f3)
			[[ -z $extractMINUTES ]] && extractMINUTES="00"
			extractTIME="$extractHOURS:$extractMINUTES"
		else
			extractTIME="00:00"
		fi
		if [[ $extractTIME =~ $regexTIME ]]; then
			calculatedDEADLINE="$extractDATE:$extractTIME"
		else
			sendToLog "Parameter Error: The soft date deadline time must be a valid 24-hour time formatted as hh:mm."; parameterERROR="TRUE"
		fi
	else
		sendToLog "Parameter Error: The soft date deadline date must be a valid date formatted as YYYY-MM-DD."; parameterERROR="TRUE"
	fi
	if [[ $calculatedDEADLINE =~ $regexDATETIME ]]; then
		softDateMAX="$calculatedDEADLINE"
		softDateEPOCH=$(date -j -f "%Y-%m-%d:%H:%M" "$calculatedDEADLINE" +"%s")
	else
		sendToLog "Parameter Error: The soft date deadline must be a valid and formatted as YYYY-MM-DD:hh:mm."; parameterERROR="TRUE"
	fi
fi

# Validate $hardDateOPTION, if valid set $hardDateMAX and $hardDateEPOCH.
if [[ "$hardDateOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for hard date deadline."
	defaults delete "$superPLIST" HardDate 2> /dev/null
elif [[ -n $hardDateOPTION ]]; then
	extractDATE=$(echo "$hardDateOPTION" | cut -c-10 )
	if [[ $extractDATE =~ $regexDATE ]]; then
		extractTIME=$(echo "$hardDateOPTION" | cut -c11- )
		if [[ -n $extractTIME ]]; then
			extractHOURS=$(echo "$extractTIME" | cut -d: -f2)
			[[ -z $extractHOURS ]] && extractHOURS="00"
			extractMINUTES=$(echo "$extractTIME" | cut -d: -f3)
			[[ -z $extractMINUTES ]] && extractMINUTES="00"
			extractTIME="$extractHOURS:$extractMINUTES"
		else
			extractTIME="00:00"
		fi
		if [[ $extractTIME =~ $regexTIME ]]; then
			calculatedDEADLINE="$extractDATE:$extractTIME"
		else
			sendToLog "Parameter Error: The hard date deadline time must be a valid 24-hour time formatted as hh:mm."; parameterERROR="TRUE"
		fi
	else
		sendToLog "Parameter Error: The hard date deadline date must be a valid date formatted as YYYY-MM-DD."; parameterERROR="TRUE"
	fi
	if [[ $calculatedDEADLINE =~ $regexDATETIME ]]; then
		hardDateMAX="$calculatedDEADLINE"
		hardDateEPOCH=$(date -j -f "%Y-%m-%d:%H:%M" "$calculatedDEADLINE" +"%s")
	else
		sendToLog "Parameter Error: The hard date deadline must be a valid and formatted as YYYY-MM-DD:hh:mm."; parameterERROR="TRUE"
	fi
fi

# Validate $focusDateEPOCH, $softDateEPOCH, and $hardDateEPOCH in relation to each other. If valid then save date deadlines to $superPLIST.
if [[ -n $hardDateEPOCH ]] && [[ -n $softDateEPOCH ]] && [[ $hardDateEPOCH -le $softDateEPOCH ]]; then
	sendToLog "Parameter Error: The hard date deadline of $hardDateMAX must be later than the soft date deadline of $softDateMAX."; parameterERROR="TRUE"
fi
if [[ -n $hardDateEPOCH ]] && [[ -n $focusDateEPOCH ]] && [[ $hardDateEPOCH -le $focusDateEPOCH ]]; then
	sendToLog "Parameter Error: The hard date deadline of $hardDateMAX must be later than the focus date deadline of $focusDateMAX."; parameterERROR="TRUE"
fi
if [[ -n $softDateEPOCH ]] && [[ -n $focusDateEPOCH ]] && [[ $softDateEPOCH -le $focusDateEPOCH ]]; then
	sendToLog "Parameter Error: The soft date deadline of $softDateMAX must be later than the focus date deadline of $focusDateMAX."; parameterERROR="TRUE"
fi
if [[ "$parameterERROR" != "TRUE" ]]; then
	[[ -n $focusDateMAX ]] && defaults write "$superPLIST" FocusDate -string "$focusDateMAX"
	[[ -n $softDateMAX ]] && defaults write "$superPLIST" SoftDate -string "$softDateMAX"
	[[ -n $hardDateMAX ]] && defaults write "$superPLIST" HardDate -string "$hardDateMAX"
fi

# Validate that any focus deadlines also include a coordinating $focusDeferSECONDS, if not then set $focusDeferSECONDS to $defaultDeferSECONDS.
if { [[ -n $focusCountMAX ]] || [[ -n $focusDaysMAX ]] || [[ -n $focusDateMAX ]]; } && [[ -z $focusDeferSECONDS ]]; then
	sendToLog "Warning: No focus defer seconds specified, setting to default defer of $defaultDeferSECONDS seconds."
	focusDeferSECONDS="$defaultDeferSECONDS"
fi

# Validate $displayTimeoutOPTION and $displayRedrawOPTION inputs and if valid set $displayTimeoutSECONDS and $displayRedrawSECONDS and save to $superPLIST.
if [[ "$displayTimeoutOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for display timeout."
	defaults delete "$superPLIST" DisplayTimeout 2> /dev/null
elif [[ -n $displayTimeoutOPTION ]] && [[ $displayTimeoutOPTION =~ $regexNUMBER ]]; then
	displayTimeoutSECONDS="$displayTimeoutOPTION"
	defaults write "$superPLIST" DisplayTimeout -string "$displayTimeoutSECONDS"
elif [[ -n $displayTimeoutOPTION ]] && ! [[ $displayTimeoutOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The display timeout must only be a number."; parameterERROR="TRUE"
fi
if [[ "$displayRedrawOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for display redraw."
	defaults delete "$superPLIST" DisplayRedraw 2> /dev/null
elif [[ -n $displayRedrawOPTION ]] && [[ $displayRedrawOPTION =~ $regexNUMBER ]]; then
	displayRedrawSECONDS="$displayRedrawOPTION"
	defaults write "$superPLIST" DisplayRedraw -string "$displayRedrawSECONDS"
elif [[ -n $displayRedrawOPTION ]] && ! [[ $displayRedrawOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The display redraw time must only be a number."; parameterERROR="TRUE"
fi
if [[ "$parameterERROR" != "TRUE" ]] && [[ -n $displayTimeoutSECONDS ]] && [[ -n $displayRedrawSECONDS ]]; then
	displayMinimumTIMEOUT=$((displayRedrawSECONDS * 3))
	if [[ $displayTimeoutSECONDS -lt $displayMinimumTIMEOUT ]];then
		sendToLog "Warning: Specified display timeout of $displayTimeoutSECONDS seconds is too low given a display redraw of $displayRedrawSECONDS seconds, changing display timeout to $displayMinimumTIMEOUT seconds."
		displayTimeoutSECONDS=$displayMinimumTIMEOUT
		defaults write "$superPLIST" DisplayTimeout -string "$displayTimeoutSECONDS"
	fi
fi

# Verify the $displayIconOPTION to be used for the super service account and in notifications and dialogs, and if valid copy and set $cachedICON and save to $superPLIST.
if [[ "$displayIconOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting cached display icon."
	[[ -f "$cachedICON" ]] && rm -f "$cachedICON"
elif [[ -n "$displayIconOPTION" ]] && [[ "$displayIconOPTION" != "$(defaults read "$superPLIST" DisplayIconCache 2> /dev/null)" ]]; then
	if [[ $(echo "$displayIconOPTION" | grep '^http://\|^https://' -c) -eq 1 ]]; then
		sendToLog "Starter: Attempting to download requested icon from: $displayIconOPTION"
		downloadRESULT=$(curl "$displayIconOPTION" -L -o "/tmp/cachedICON" 2>&1)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: downloadRESULT: \n$downloadRESULT"
		if [[ -f "/tmp/cachedICON" ]]; then
			sipsRESULT=$(sips -s format png "/tmp/cachedICON" --out "$cachedICON" 2>&1)
			[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: sipsRESULT: \n$sipsRESULT"
			defaults write "$superPLIST" DisplayIconCache -string "$displayIconOPTION"
		else
			sendToLog "Warning: Unable to download specified icon from: $displayIconOPTION"
		fi
	elif [[ -e "$displayIconOPTION" ]]; then
		sendToLog "Starter: Copying requested icon from: $displayIconOPTION"
		sipsRESULT=$(sips -s format png "$displayIconOPTION" --out "$cachedICON" 2>&1)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: sipsRESULT: \n$sipsRESULT"
		defaults write "$superPLIST" DisplayIconCache -string "$displayIconOPTION"
	else
		sendToLog "Warning: Unable to locate specified icon from: $displayIconOPTION"
	fi
fi
if [[ ! -f "$cachedICON" ]]; then
	sendToLog "Starter: No custom display icon found, copying default icon from: $defaultICON"
	sipsRESULT=$(sips -s format png "$defaultICON" --out "$cachedICON" 2>&1)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: sipsRESULT: \n$sipsRESULT"
	defaults write "$superPLIST" DisplayIconCache -string "$defaultICON"
fi

# Validate $iconSizeIbmOPTION input and if valid override default $ibmNotifierIconSIZE parameter and save to $superPLIST.
if [[ "$iconSizeIbmOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for IBM Notifier icon size."
	defaults delete "$superPLIST" IconSizeIbm 2> /dev/null
elif [[ -n $iconSizeIbmOPTION ]] && [[ $iconSizeIbmOPTION =~ $regexNUMBER ]]; then
	if [[ $iconSizeIbmOPTION -lt 32 ]]; then
		sendToLog "Warning: Specified IBM Notifier icon size of $iconSizeIbmOPTION pixels is too low, rounding up to 32 pixels."
		ibmNotifierIconSIZE="32"
	elif [[ $iconSizeIbmOPTION -gt 150 ]]; then
		sendToLog "Warning: Specified IBM Notifier icon size of $iconSizeIbmOPTION pixels is too high, rounding down to 150 pixels."
		ibmNotifierIconSIZE="150"
	else
		ibmNotifierIconSIZE="$iconSizeIbmOPTION"
	fi
	defaults write "$superPLIST" IconSizeIbm -string "$ibmNotifierIconSIZE"
elif [[ -n $iconSizeIbmOPTION ]] && ! [[ $iconSizeIbmOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The IBM Notifier icon size must only be a number."; parameterERROR="TRUE"
fi

# Validate $iconSizeJamfOPTION input and if valid override default $jamfHelperIconSIZE parameter and save to $superPLIST.
if [[ "$iconSizeJamfOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for IBM Notifier icon size."
	defaults delete "$superPLIST" IconSizeJamf 2> /dev/null
elif [[ -n $iconSizeJamfOPTION ]] && [[ $iconSizeJamfOPTION =~ $regexNUMBER ]]; then
	if [[ $iconSizeJamfOPTION -lt 32 ]]; then
		sendToLog "Warning: Specified IBM Notifier icon size of $iconSizeJamfOPTION pixels is too low, rounding up to 32 pixels."
		jamfHelperIconSIZE="32"
	elif [[ $iconSizeJamfOPTION -gt 150 ]]; then
		sendToLog "Warning: Specified IBM Notifier icon size of $iconSizeJamfOPTION pixels is too high, rounding down to 150 pixels."
		jamfHelperIconSIZE="150"
	else
		jamfHelperIconSIZE="$iconSizeJamfOPTION"
	fi
	defaults write "$superPLIST" IconSizeJamf -string "$jamfHelperIconSIZE"
elif [[ -n $iconSizeJamfOPTION ]] && ! [[ $iconSizeJamfOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The IBM Notifier icon size must only be a number."; parameterERROR="TRUE"
fi

# Validate $policyTriggersOPTION input and if valid set $policyTRIGGERS and save to $superPLIST.
if [[ "$policyTriggersOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for Jamf Pro Policy triggers."
	defaults delete "$superPLIST" PolicyTriggers 2> /dev/null
elif [[ -n $policyTriggersOPTION ]]; then
	policyTRIGGERS="$policyTriggersOPTION"
	defaults write "$superPLIST" PolicyTriggers -string "$policyTRIGGERS"
fi
if [[ "$jamfVERSION" == "FALSE" ]] && [[ -n $policyTRIGGERS ]]; then
	sendToLog "Parameter Error: Unable to run Jamf Pro Policy Triggers due to missing Jamf binary."; parameterERROR="TRUE"
fi

# Manage $skipUpdatesOPTION and save to $superPLIST.
if [[ $skipUpdatesOPTION -eq 1 ]] || [[ "$skipUpdatesOPTION" == "TRUE" ]]; then
	skipUpdatesOPTION="TRUE"
	defaults write "$superPLIST" SkipUpdates -bool "$skipUpdatesOPTION"
else
	skipUpdatesOPTION="FALSE"
	defaults delete "$superPLIST" SkipUpdates 2> /dev/null
fi

# Manage $forceRestartOPTION and save to $superPLIST.
if [[ $forceRestartOPTION -eq 1 ]] || [[ "$forceRestartOPTION" == "TRUE" ]]; then
	forceRestartOPTION="TRUE"
	defaults write "$superPLIST" ForceRestart -bool "$forceRestartOPTION"
else
	forceRestartOPTION="FALSE"
	defaults delete "$superPLIST" ForceRestart 2> /dev/null
fi

# Manage $installMajorUpgradeOPTION and save to $superPLIST.
if [[ $installMajorUpgradeOPTION -eq 1 ]] || [[ "$installMajorUpgradeOPTION" == "TRUE" ]]; then
	installMajorUpgradeOPTION="TRUE"
	defaults write "$superPLIST" InstallMajorUpgrade -bool "$installMajorUpgradeOPTION"
else
	installMajorUpgradeOPTION="FALSE"
	defaults delete "$superPLIST" InstallMajorUpgrade 2> /dev/null
fi

# Manage $pushMajorUpgradeOPTION and save to $superPLIST.
if [[ $pushMajorUpgradeOPTION -eq 1 ]] || [[ "$pushMajorUpgradeOPTION" == "TRUE" ]]; then
	pushMajorUpgradeOPTION="TRUE"
	defaults write "$superPLIST" PushMajorUpgrade -bool "$pushMajorUpgradeOPTION"
else
	pushMajorUpgradeOPTION="FALSE"
	defaults delete "$superPLIST" PushMajorUpgrade 2> /dev/null
fi

# Manage $installMinorUpdateOPTION and save to $superPLIST.
if [[ $installMinorUpdateOPTION -eq 1 ]] || [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
	installMinorUpdateOPTION="TRUE"
	defaults write "$superPLIST" InstallMinorUpdate -bool "$installMinorUpdateOPTION"
else
	installMinorUpdateOPTION="FALSE"
	defaults delete "$superPLIST" InstallMinorUpdate 2> /dev/null
fi

# Manage $targetMajorUpgradeOPTION and if a valid macOS version then save to $superPLIST.
if [[ "$targetMajorUpgradeOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for macOS target upgrade version."
	defaults delete "$superPLIST" TargetMajorUpgrade 2> /dev/null
	unset targetMajorUpgradeOPTION
elif [[ -n $targetMajorUpgradeOPTION ]] && ! [[ $targetMajorUpgradeOPTION =~ $regexMACOSMAJORVERSION ]]; then
	sendToLog "Parameter Error: The upgrade target version must be a recent major macOS version number (11 - 13)."; parameterERROR="TRUE"
elif [[ -n $targetMajorUpgradeOPTION ]] && [[ $targetMajorUpgradeOPTION =~ $regexMACOSMAJORVERSION ]]; then
	if [[ "$pushMajorUpgradeOPTION" == "TRUE" ]]; then
		sendToLog "Parameter Error: Major system upgrades via MDM can only target the latest macOS version. To target a specific major upgrade version you must use the --install-major-upgrade option."; parameterERROR="TRUE"
		defaults delete "$superPLIST" TargetMajorUpgrade 2> /dev/null
	elif [[ "$installMajorUpgradeOPTION" == "TRUE" ]]; then
		targetMajorUpgradeVERSION="$targetMajorUpgradeOPTION"
		defaults write "$superPLIST" TargetMajorUpgrade -string "$targetMajorUpgradeOPTION"
	else
		sendToLog "Parameter Error: To specify a target major upgrade version you must also use --install-major-upgrade."; parameterERROR="TRUE"
		defaults delete "$superPLIST" TargetMajorUpgrade 2> /dev/null
	fi
fi

# Manage $testModeOPTION and save to $superPLIST.
if [[ $testModeOPTION -eq 1 ]] || [[ "$testModeOPTION" == "TRUE" ]]; then
	testModeOPTION="TRUE"
	defaults write "$superPLIST" TestMode -bool "$testModeOPTION"
else
	testModeOPTION="FALSE"
	defaults delete "$superPLIST" TestMode 2> /dev/null
fi
if [[ "$testModeOPTION" == "TRUE" ]] && [[ "$currentUSER" == "FALSE" ]]; then
	sendToLog "Parameter Error: Test mode requires that a valid user is logged in."; parameterERROR="TRUE"
fi

# Validate $testModeTimeoutOPTION input and if valid set $testModeTimeoutSECONDS and save to $superPLIST.
if [[ "$testModeTimeoutOPTION" == "X" ]]; then
	sendToLog "Starter: Deleting local preference for test mode timeout."
	defaults delete "$superPLIST" TestModeTimeout 2> /dev/null
elif [[ -n $testModeTimeoutOPTION ]] && [[ $testModeTimeoutOPTION =~ $regexNUMBER ]]; then
	testModeTimeoutSECONDS="$testModeTimeoutOPTION"
	defaults write "$superPLIST" TestModeTimeout -string "$testModeTimeoutSECONDS"
elif [[ -n $testModeTimeoutOPTION ]] && ! [[ $testModeTimeoutOPTION =~ $regexNUMBER ]]; then
	sendToLog "Parameter Error: The test mode timeout must only be a number."; parameterERROR="TRUE"
fi
}

# Manage update credentials given $deleteACCOUNTS, $localACCOUNT, $adminACCOUNT, $superACCOUNT, or $jamfACCOUNT. Any errors set $parameterERROR.
manageUpdateCredentials () {
credentialERROR="FALSE"

# Local update credentials are only validated for Apple Silicon computers.
if [[ "$macosARCH" == "arm64" ]]; then
	# Validate that $localOPTION and $localPASSWORD are simultaneously provided.
	if [[ -n $localOPTION ]] && [[ -z $localPASSWORD ]]; then
		sendToLog "Credential Error: A local volume owner account name requires that you also set a local volume owner password."; credentialERROR="TRUE"
	fi
	if [[ -z $localOPTION ]] && [[ -n $localPASSWORD ]]; then
		sendToLog "Credential Error: A local volume owner password requires that you also set a local volume owner account name."; credentialERROR="TRUE"
	fi

	# Validate that $localOPTION exists, is a volume owner, and that $localPASSWORD is correct.
	if [[ -n $localOPTION ]] && [[ "$credentialERROR" != "TRUE" ]]; then
		localGUID=$(dscl . read "/Users/$localOPTION" GeneratedUID 2> /dev/null | awk '{print $2;}')
		if [[ -n $localGUID ]]; then
			if ! [[ $(diskutil apfs listcryptousers / | grep -c "$localGUID") -ne 0 ]]; then
				sendToLog "Credential Error: Provided account \"$localOPTION\" is not a system volume owner."; credentialERROR="TRUE"
			fi
			localVALID=$(dscl /Local/Default -authonly "$localOPTION" "$localPASSWORD" 2>&1)
			if ! [[ "$localVALID" == "" ]];then
				sendToLog "Credential Error: The provided password for account \"$localOPTION\" is not valid."; credentialERROR="TRUE"
			fi
		else
			sendToLog "Credential Error: Could not retrieve GUID for account \"$localOPTION\". Verify that account exists locally."; credentialERROR="TRUE"
		fi
	fi

	# Validate that $adminACCOUNT and $adminPASSWORD are simultaneously provided.
	if [[ -n $adminACCOUNT ]] && [[ -z $adminPASSWORD ]]; then
		sendToLog "Credential Error: A local admin account name requires that you also set a local admin password."; credentialERROR="TRUE"
	fi
	if [[ -z $adminACCOUNT ]] && [[ -n $adminPASSWORD ]]; then
		sendToLog "Credential Error: A local admin password requires that you also set a local admin account name."; credentialERROR="TRUE"
	fi

	# Validate that $adminACCOUNT is also specified with $superOPTION.
	if [[ -n $superOPTION ]] && [[ -z $adminACCOUNT ]]; then
		sendToLog "Credential Error: Local admin credentials are required to set a custom super service account name."; credentialERROR="TRUE"
	fi

	# Validate that $adminACCOUNT exists, is a volume owner, a local admin, and that $adminPASSWORD is correct.
	if [[ -n $adminACCOUNT ]] && [[ "$credentialERROR" != "TRUE" ]]; then
		adminGUID=$(dscl . read "/Users/$adminACCOUNT" GeneratedUID 2> /dev/null | awk '{print $2;}')
		if [[ -n $adminGUID ]]; then
			if [[ $(groups "$adminACCOUNT" | grep "admin" -c) -eq 0 ]]; then
				sendToLog "Credential Error: Provided account \"$adminACCOUNT\" is not a local administrator."; credentialERROR="TRUE"
			fi
			if ! [[ $(diskutil apfs listcryptousers / | grep -c "$adminGUID") -ne 0 ]]; then
				sendToLog "Credential Error: Provided account \"$adminACCOUNT\" is not a system volume owner."; credentialERROR="TRUE"
			fi
			adminVALID=$(dscl /Local/Default -authonly "$adminACCOUNT" "$adminPASSWORD" 2>&1)
			if ! [[ "$adminVALID" == "" ]];then
				sendToLog "Credential Error: The provided password for account \"$adminACCOUNT\" is not valid."; credentialERROR="TRUE"
			fi
		else
			sendToLog "Credential Error: Could not retrieve GUID for account \"$adminACCOUNT\". Verify that account exists locally."; credentialERROR="TRUE"
		fi
	fi
fi

# Validate that $jamfOPTION is only used on computers with the jamf binary installed.
if [[ -n $jamfOPTION ]] && [[ "$jamfVERSION" == "FALSE" ]]; then
	sendToLog "Credential Error: A Jamf Pro API account name requires that this computer is enrolled in Jamf Pro."; credentialERROR="TRUE"
fi

# Validate that $jamfOPTION and $jamfPASSWORD are simultaneously provided.
if [[ -n $jamfOPTION ]] && [[ -z $jamfPASSWORD ]]; then
	sendToLog "Credential Error: A Jamf Pro API account name requires that you also set a Jamf Pro API password."; credentialERROR="TRUE"
fi
if [[ -z $jamfOPTION ]] && [[ -n $jamfPASSWORD ]]; then
	sendToLog "Credential Error: A Jamf Pro API password requires that you also set a Jamf Pro API account name."; credentialERROR="TRUE"
fi

# Validate that the account $jamfOPTION and $jamfPASSWORD are valid.
if [[ -n $jamfOPTION ]] && [[ "$credentialERROR" != "TRUE" ]]; then
	jamfACCOUNT="$jamfOPTION"
	jamfKEYCHAIN="$jamfPASSWORD"
	if [[ "$jamfSERVER" != "FALSE" ]]; then
		getJamfProAccount
		[[ "$jamfERROR" == "TRUE" ]] && credentialERROR="TRUE"
	else
		sendToLog "Credential Error: Unable to connect to Jamf Pro to validate user account."; credentialERROR="TRUE"
	fi
	unset jamfACCOUNT
	unset jamfKEYCHAIN
fi

# Collect any previously saved account names from $superPLIST.
localPROPERTY=$(defaults read "$superPLIST" LocalAccount 2> /dev/null)
superPROPERTY=$(defaults read "$superPLIST" SuperAccount 2> /dev/null)
jamfPROPERTY=$(defaults read "$superPLIST" JamfAccount 2> /dev/null)

# Some messaging to indicate if there are no saved accounts when a delete is requested.
{ [[ -z $localPROPERTY ]] && [[ -z $superPROPERTY ]] && [[ -z $jamfPROPERTY ]] && [[ -n $deleteACCOUNTS ]]; } && sendToLog "Starter: No saved accounts to delete."

# If there was a previous $localPROPERTY account and the user specified $localOPTION or $deleteACCOUNTS then delete any previously saved local account credentials.
if [[ -n $localPROPERTY ]] && { [[ -n $localOPTION ]] || [[ "$deleteACCOUNTS" == "TRUE" ]]; }; then
	sendToLog "Starter: Deleting saved credentials for local account \"$localPROPERTY\"."
	defaults delete "$superPLIST" LocalAccount > /dev/null 2>&1
	security delete-generic-password -a "$localPROPERTY" -s "Super Local Account" /Library/Keychains/System.keychain > /dev/null 2>&1
	unset localPROPERTY
	localCREDENTIAL="FALSE"
fi

# If there was a previous $superPROPERTY account and the user specified $adminACCOUNT or $deleteACCOUNTS then delete any previously saved super service account and credentials.
if [[ -n $superPROPERTY ]] && { [[ -n $adminACCOUNT ]] || [[ "$deleteACCOUNTS" == "TRUE" ]]; } then
	sendToLog "Starter: Deleting local account and saved credentials for super service account \"$superPROPERTY\"."
	sysadminctl -deleteUser "$superPROPERTY" > /dev/null 2>&1
	defaults delete "$superPLIST" SuperAccount > /dev/null 2>&1
	security delete-generic-password -a "$superPROPERTY" -s "Super Service Account" /Library/Keychains/System.keychain > /dev/null 2>&1
	unset superPROPERTY
	superCREDENTIAL="FALSE"
fi

# If there was a previous $jamfPROPERTY account and the user specified $jamfOPTION or $deleteACCOUNTS then delete any previously saved Jamf Pro API credentials.
if [[ -n $jamfPROPERTY ]] && { [[ -n $jamfOPTION ]] || [[ "$deleteACCOUNTS" == "TRUE" ]]; } then
	sendToLog "Starter: Deleting saved credentials for Jamf Pro API account \"$jamfPROPERTY\"."
	defaults delete "$superPLIST" JamfAccount > /dev/null 2>&1
	security delete-generic-password -a "$jamfPROPERTY" -s "Super MDM Account" /Library/Keychains/System.keychain > /dev/null 2>&1
	unset jamfPROPERTY
	jamfCREDENTIAL="FALSE"
fi

# If any previous validation generated a $credentialERROR then it's not necessary to continue this function.
[[ $credentialERROR == "TRUE" ]] && return 0

# On Apple Silicon, if a new local account was specified, save $localOPTION and $localPASSWORD credentials and then validate retrieval.
if [[ "$macosARCH" == "arm64" ]] && [[ -n $localOPTION ]]; then
	sendToLog "Starter: Saving new credentials for local account \"$localOPTION\"..."
	defaults write "$superPLIST" LocalAccount -string "$localOPTION"
	localACCOUNT=$(defaults read "$superPLIST" LocalAccount 2> /dev/null)
	if [[ "$localOPTION" == "$localACCOUNT" ]]; then
		security add-generic-password -a "$localACCOUNT" -s "Super Local Account" -w "$localPASSWORD" -T /usr/bin/security /Library/Keychains/System.keychain
		localKEYCHAIN=$(security find-generic-password -w -a "$localACCOUNT" -s "Super Local Account" /Library/Keychains/System.keychain 2> /dev/null)
		if [[ "$localPASSWORD" == "$localKEYCHAIN" ]]; then
			sendToLog "Starter: Validated saved credentials for local account \"$localACCOUNT\"."
			localCREDENTIAL="TRUE"
		else
			sendToLog "Credential Error: Unable to validate saved password for local account \"$localACCOUNT\", deleting saved password."; credentialERROR="TRUE"
			security delete-generic-password -a "$localACCOUNT" -s "Super Local Account" /Library/Keychains/System.keychain > /dev/null 2>&1
		fi
	else
		sendToLog "Credential Error: Unable to validate saved name for local account \"$localOPTION\", deleting saved name."; credentialERROR="TRUE"
		defaults delete "$superPLIST" LocalAccount > /dev/null 2>&1
	fi
fi

# On Apple Silicon, if an $adminACCOUNT was specified then a new super service account needs to be created and its credentials saved.
if [[ "$macosARCH" == "arm64" ]] && [[ -n $adminACCOUNT ]]; then
	# If the a custom super service account name is requested via $superOPTION.
	if [[ -n $superOPTION ]]; then
		superNEWACCT="$superOPTION"
		superNEWFULL="$superOPTION"
	else # Use the default names for the super service account.
		superNEWACCT="super"
		superNEWFULL="Super Update Service"
	fi
	
	# If a custom super service account password is requested via $superPASSWORD.
	if [[ -n $superPASSWORD ]]; then
		superNEWPASS="$superPASSWORD"
	else # Use the default random password for the super service account.
		superNEWPASS=$(uuidgen)
	fi
	
	# Save and validate new super service account credentials, and validate retrieval.
	sendToLog "Starter: Saving new credentials for super service account \"$superNEWACCT\"..."
	defaults write "$superPLIST" SuperAccount -string "$superNEWACCT"
	superACCOUNT=$(defaults read "$superPLIST" SuperAccount 2> /dev/null)
	if [[ "$superNEWACCT" == "$superACCOUNT" ]]; then
		security add-generic-password -a "$superACCOUNT" -s "Super Service Account" -w "$superNEWPASS" -T /usr/bin/security /Library/Keychains/System.keychain
		superKEYCHAIN=$(security find-generic-password -w -a "$superACCOUNT" -s "Super Service Account" /Library/Keychains/System.keychain 2> /dev/null)
		if [[ "$superNEWPASS" == "$superKEYCHAIN" ]]; then # Only if saved credentials are valid do we create the new super service account.
			sendToLog "Starter: Validated saved credentials for new super service account \"$superACCOUNT\"."
			if [[ $(id "$superACCOUNT" 2>&1 | grep "no such user" -c) -eq 1 ]]; then
				sendToLog "Starter: Deleting existing super service account \"$superACCOUNT\" in preparation for new account."
				sysadminctl -deleteUser "$superACCOUNT" > /dev/null 2>&1
			fi
			# Loop through local IDs to find the first vacant id after 500.
			newUID=501
			while [[ $(id $newUID 2>&1 | grep "no such user" -c) -ne 1 ]]; do
				newUID=$((newUID + 1))
			done
			sendToLog "Starter: Creating new super service account \"$superNEWACCT\" with full name \"$superNEWFULL\" and UID $newUID..."
			addRESULT=$(sysadminctl -addUser "$superNEWACCT" -fullName "$superNEWFULL" -password "$superNEWPASS" -UID $newUID -GID 20 -shell /dev/null -home /dev/null -picture "$cachedICON" -adminUser "$adminACCOUNT" -adminPassword "$adminPASSWORD" 2>&1)
			[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: addRESULT: \n$addRESULT"
			dscl . create /Users/"$superNEWACCT" IsHidden 1
			updateACCOUNT="$superACCOUNT"
			updateKEYCHAIN="$superKEYCHAIN"
			checkLocalUpdateAccount
			if [[ "$accountERROR" != "TRUE" ]]; then
				sendToLog "Starter: Validated the creation of new super service account \"$superACCOUNT\"."
				superCREDENTIAL="TRUE"
			else
				sendToLog "Credential Error: Unable to validate newly created super service account \"$superACCOUNT\", deleting account"; credentialERROR="TRUE"
				sysadminctl -deleteUser "$superACCOUNT" > /dev/null 2>&1
				defaults delete "$superPLIST" SuperAccount > /dev/null 2>&1
				security delete-generic-password -a "$superACCOUNT" -s "Super Service Account" /Library/Keychains/System.keychain > /dev/null 2>&1
				unset superPROPERTY
			fi
		else
			sendToLog "Credential Error: Unable to validate saved password for new super service account \"$superNEWACCT\", deleting saved password."; credentialERROR="TRUE"
			security delete-generic-password -a "$superACCOUNT" -s "Super Service Account" /Library/Keychains/System.keychain > /dev/null 2>&1
		fi
	else
		sendToLog "Credential Error: Unable to validate saved name for new super service account \"$superNEWACCT\",deleting saved name."; credentialERROR="TRUE"
		defaults delete "$superPLIST" SuperAccount > /dev/null 2>&1
	fi
fi

# If a new Jamf Pro API account was specified, save $jamfOPTION and $jamfPASSWORD credentials and then validate retrieval.
if [[ -n $jamfOPTION ]]; then
	sendToLog "Starter: Saving new credentials for Jamf Pro API account \"$jamfOPTION\"..."
	defaults write "$superPLIST" JamfAccount -string "$jamfOPTION"
	jamfACCOUNT=$(defaults read "$superPLIST" JamfAccount 2> /dev/null)
	if [[ "$jamfOPTION" == "$jamfACCOUNT" ]]; then
		security add-generic-password -a "$jamfACCOUNT" -s "Super MDM Account" -w "$jamfPASSWORD" -T /usr/bin/security /Library/Keychains/System.keychain
		jamfKEYCHAIN=$(security find-generic-password -w -a "$jamfACCOUNT" -s "Super MDM Account" /Library/Keychains/System.keychain 2> /dev/null)
		if [[ "$jamfPASSWORD" == "$jamfKEYCHAIN" ]]; then
			sendToLog "Starter: Validated saved credentials for Jamf Pro API account \"$jamfACCOUNT\"."
			jamfCREDENTIAL="TRUE"
		else
			sendToLog "Credential Error: Unable to validate saved password for Jamf Pro API account \"$jamfACCOUNT\", deleting saved password."; credentialERROR="TRUE"
			security delete-generic-password -a "$jamfACCOUNT" -s "Super MDM Account" /Library/Keychains/System.keychain > /dev/null 2>&1
		fi
	else
		sendToLog "Credential Error: Unable to validate saved name for Jamf Pro API account \"$jamfOPTION\", deleting saved name."; credentialERROR="TRUE"
		defaults delete "$superPLIST" JamfAccount > /dev/null 2>&1
	fi
fi

# On Apple Silicon, if there is a previously saved local account (that wasn't just deleted), validate the account and set $localACCOUNT and $localPASSWORD.
if [[ "$macosARCH" == "arm64" ]] && [[ -n $localPROPERTY ]]; then
	localACCOUNT="$localPROPERTY"
	localKEYCHAIN=$(security find-generic-password -w -a "$localACCOUNT" -s "Super Local Account" /Library/Keychains/System.keychain 2> /dev/null)
	if [[ -n $localKEYCHAIN ]]; then
		sendToLog "Starter: Found saved credentials for local account \"$localACCOUNT\"."
		updateACCOUNT="$localACCOUNT"
		updateKEYCHAIN="$localKEYCHAIN"
		checkLocalUpdateAccount
		if [[ "$accountERROR" != "TRUE" ]]; then
			sendToLog "Starter: Validated saved credentials for local account \"$localACCOUNT\"."
			localCREDENTIAL="TRUE"
		else
			sendToLog "Credential Error: Unable to validate saved credentials for local account \"$localACCOUNT\"."; credentialERROR="TRUE"
		fi
	else
		sendToLog "Credential Error: Unable to retrieve password for saved local account \"$localACCOUNT\"."; credentialERROR="TRUE"
	fi
fi

# On Apple Silicon, if there is a previously saved super service account (that wasn't just deleted), validate the account and set $superACCOUNT and $superPASSWORD.
if [[ "$macosARCH" == "arm64" ]] && [[ -n $superPROPERTY ]]; then
	superACCOUNT="$superPROPERTY"
	superKEYCHAIN=$(security find-generic-password -w -a "$superACCOUNT" -s "Super Service Account" /Library/Keychains/System.keychain 2> /dev/null)
	if [[ -n $superKEYCHAIN ]]; then
		sendToLog "Starter: Found saved credentials for super service account \"$superACCOUNT\"."
		updateACCOUNT="$superACCOUNT"
		updateKEYCHAIN="$superKEYCHAIN"
		checkLocalUpdateAccount
		if [[ "$accountERROR" != "TRUE" ]]; then
			sendToLog "Starter: Validated saved credentials for super service account \"$superACCOUNT\"."
			superCREDENTIAL="TRUE"
		else
			sendToLog "Credential Error: Unable to validate saved credentials for super service account \"$superACCOUNT\"."; credentialERROR="TRUE"
		fi
	else
		sendToLog "Credential Error: Unable to retrieve password for saved super service account \"$superACCOUNT\"."; credentialERROR="TRUE"
	fi
fi

# If there is a previously saved Jamf PRO API account (that wasn't just deleted), validate the account and set $jamfACCOUNT and $jamfPASSWORD.
if [[ -n $jamfPROPERTY ]]; then
	jamfACCOUNT="$jamfPROPERTY"
	jamfKEYCHAIN=$(security find-generic-password -w -a "$jamfACCOUNT" -s "Super MDM Account" /Library/Keychains/System.keychain 2> /dev/null)
	if [[ -n $jamfKEYCHAIN ]]; then
		sendToLog "Starter: Found saved credentials for Jamf Pro API account \"$jamfACCOUNT\"."
		if [[ "$jamfSERVER" != "FALSE" ]]; then
			getJamfProAccount
			if [[ "$jamfERROR" != "TRUE" ]]; then
				sendToLog "Starter: Validated saved credentials for Jamf Pro API account \"$jamfACCOUNT\"."
				if [[ $(profiles status -type bootstraptoken 2> /dev/null | grep "YES" -c) -eq 2 ]]; then
					sendToLog "Starter: Bootstrap token escrow validated."
					jamfCREDENTIAL="TRUE"
				else
					sendToLog "Credential Error: Can not use MDM update workflow because this computer's Bootstrap token is not escrowed."; credentialERROR="TRUE"
				fi
			else
				sendToLog "Error: Unable to validate Jamf Pro user account, trying again in $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Unable to validate Jamf Pro user account, trying again in $defaultDeferSECONDS seconds."
				makeLaunchDaemonCalendar
			fi
		else
			sendToLog "Error: Unable to connect to Jamf Pro to validate user account, trying again in $defaultDeferSECONDS seconds."
			sendToStatus "Pending: Unable to connect to Jamf Pro to validate user account, trying again in $defaultDeferSECONDS seconds."
			makeLaunchDaemonCalendar
		fi
	else
		sendToLog "Credential Error: Unable to retrieve password for saved Jamf Pro API account \"$jamfACCOUNT\"."; credentialERROR="TRUE"
	fi
fi
}

# This function determines what $minorUpdateWORKFLOW and $majorUpgradeWORKFLOW are possible given the architecture and options.
manageWorkflowOptions() {
workflowERROR="FALSE"
minorUpdateWORKFLOW="FALSE" # Minor update modes: FALSE, JAMF, ASU, APP, or USER
majorUpgradeWORKFLOW="FALSE" # Major upgrade modes: FALSE, JAMF, APP, or USER

if [[ "$macosARCH" == "arm64" ]]; then
	sendToLog "Starter: Apple Silicon Mac computer running $(sw_vers -productName) $(sw_vers -productVersion) build $(sw_vers -buildVersion)."
	if [[ "$localCREDENTIAL" == "TRUE" ]]; then
		sendToLog "Starter: S.U.P.E.R.M.A.N. workflow authenticated via local account."
		asuACCOUNT="$localACCOUNT"
		asuPASSWORD="$localKEYCHAIN"
		if [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
			minorUpdateWORKFLOW="APP"
		else
			minorUpdateWORKFLOW="ASU"
		fi
		[[ "$installMajorUpgradeOPTION" == "TRUE" ]] && majorUpgradeWORKFLOW="APP"
	elif [[ "$superCREDENTIAL" == "TRUE" ]]; then
		sendToLog "Starter: S.U.P.E.R.M.A.N. workflow authenticated via super service account."
		asuACCOUNT="$superACCOUNT"
		asuPASSWORD="$superKEYCHAIN"
		if [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
			minorUpdateWORKFLOW="APP"
		else
			minorUpdateWORKFLOW="ASU"
		fi
		[[ "$installMajorUpgradeOPTION" == "TRUE" ]] && majorUpgradeWORKFLOW="APP"
	elif [[ "$jamfCREDENTIAL" == "TRUE" ]]; then
		if [[ "$macosVERSION" -ge 1105 ]]; then
			sendToLog "Starter: S.U.P.E.R.M.A.N. workflow authenticated via Jamf Pro API."
			minorUpdateWORKFLOW="JAMF"
			[[ "$pushMajorUpgradeOPTION" == "TRUE" ]] && majorUpgradeWORKFLOW="JAMF"
		else
			sendToLog "Warning: System updates via MDM can only be enforced on Apple Silicon computers with macOS 11.5 or later."
			sendToLog "Starter: S.U.P.E.R.M.A.N. workflow via user request."
			if [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
				minorUpdateWORKFLOW="APP"
			else
				minorUpdateWORKFLOW="USER"
			fi
			{ [[ "$installMajorUpgradeOPTION" == "TRUE" ]] || [[ "$pushMajorUpgradeOPTION" == "TRUE" ]]; } && majorUpgradeWORKFLOW="USER"
		fi
	else
		sendToLog "Starter: S.U.P.E.R.M.A.N. workflow via user request."
		if [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
			minorUpdateWORKFLOW="APP"
		else
			minorUpdateWORKFLOW="USER"
		fi
		{ [[ "$installMajorUpgradeOPTION" == "TRUE" ]] || [[ "$pushMajorUpgradeOPTION" == "TRUE" ]]; } && majorUpgradeWORKFLOW="USER"
		[[ "$pushMajorUpgradeOPTION" == "TRUE" ]] && sendToLog "Warning: System updates via MDM require Jamf Pro API credentials."
	fi
else # Mac computers with Intel.
	sendToLog "Starter: Intel Mac computer running macOS $(sw_vers -productVersion) build $(sw_vers -buildVersion)."
	if [[ "$jamfCREDENTIAL" == "TRUE" ]]; then
		if [[ "$macosVERSION" -ge 1105 ]]; then
			sendToLog "Starter: S.U.P.E.R.M.A.N. workflow authenticated via Jamf Pro API."
			minorUpdateWORKFLOW="JAMF"
			[[ "$pushMajorUpgradeOPTION" == "TRUE" ]] && majorUpgradeWORKFLOW="JAMF"
		else
			sendToLog "Warning: System updates via MDM can only be enforced on Apple Silicon computers with macOS 11.5 or later."
			sendToLog "Starter: S.U.P.E.R.M.A.N. workflow authenticated via system account (root)."
			if [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
				if [[ $macosMAJOR -ge 11 ]]; then
					minorUpdateWORKFLOW="APP"
				else
					sendToLog "Warning: Minor system updates via Installer is only supported on macOS 11 or later."
					minorUpdateWORKFLOW="ASU"
				fi
			else
				minorUpdateWORKFLOW="ASU"
			fi
			{ [[ "$installMajorUpgradeOPTION" == "TRUE" ]] || [[ "$pushMajorUpgradeOPTION" == "TRUE" ]]; } && majorUpgradeWORKFLOW="APP"
		fi
	else
		sendToLog "Starter: S.U.P.E.R.M.A.N. workflow authenticated via system account (root)."
		if [[ "$installMinorUpdateOPTION" == "TRUE" ]]; then
			if [[ $macosMAJOR -ge 11 ]]; then
				minorUpdateWORKFLOW="APP"
			else
				sendToLog "Warning: Minor system updatates via Installer is only supported on macOS 11 or later."
				minorUpdateWORKFLOW="ASU"
			fi
		else
			minorUpdateWORKFLOW="ASU"
		fi
		{ [[ "$installMajorUpgradeOPTION" == "TRUE" ]] || [[ "$pushMajorUpgradeOPTION" == "TRUE" ]]; } && majorUpgradeWORKFLOW="APP"
		[[ "$pushMajorUpgradeOPTION" == "TRUE" ]] && sendToLog "Warning: System updates via MDM require Jamf Pro API credentials."
	fi
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: minorUpdateWORKFLOW: $minorUpdateWORKFLOW"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: majorUpgradeWORKFLOW: $majorUpgradeWORKFLOW"

# !!!: Future super v3.0 beta will remove this limitation.
if [[ "$majorUpgradeWORKFLOW" == "APP" ]] || [[ "$majorUpgradeWORKFLOW" == "USER" ]] || [[ "$minorUpdateWORKFLOW" == "APP" ]]; then
	sendToLog "Warning: Update/upgrade workflows via macOS Installer are not supported with this version of super... https://github.com/Macjutsu/super/releases"
	betaERROR="TRUE"
fi
}

# MARK: *** super Installation & Startup ***
################################################################################

# Download and install the IBM Notifier.app.
getIbmNotifier() {
sendToLog "Starter: Attempting to download and install IBM Notifier.app..."
downloadRESULT=$(curl "$ibmNotifierURL" -L -o "/tmp/IBM.Notifier.zip" 2>&1)
if [[ -f "/tmp/IBM.Notifier.zip" ]]; then
	unzipRESULT=$(unzip "/tmp/IBM.Notifier.zip" -d "$superFOLDER/" 2>&1)
	if [[ -d "$ibmNotifierAPP" ]]; then
		[[ -d "$superFOLDER/__MACOSX" ]] && rm -Rf "$superFOLDER/__MACOSX" > /dev/null 2>&1
		chmod -R a+rx "$ibmNotifierAPP"
		ibmNotifierVALID="TRUE"
		rm -Rf "/tmp/IBM.Notifier.zip"
	else
		sendToLog "Error: Unable to install IBM Notifier.app."
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: unzipRESULT: \n$unzipRESULT"
	fi
else
	sendToLog "Error: Unable to download IBM Notifier.app from: $ibmNotifierURL"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: downloadRESULT: \n$downloadRESULT"
fi
}

# Check the IBM Notifier.app for validity.
checkIbmNotifier() {
ibmNotifierVALID="FALSE"
ibmNotifierCODESIGN=$(codesign --verify --verbose "$ibmNotifierAPP" 2>&1)
if [[ $(echo "$ibmNotifierCODESIGN" | grep -c "valid on disk") -eq 1 ]]; then
	ibmNotifierRESULT=$(defaults read "$ibmNotifierAPP/Contents/Info.plist" CFBundleShortVersionString)
	if [[ "$ibmNotifierVERSION" == "$ibmNotifierRESULT" ]]; then
		ibmNotifierVALID="TRUE"
	else
		sendToLog "Warning: IBM Notifier at path: $ibmNotifierAPP is version $ibmNotifierRESULT, this does not match target version $ibmNotifierVERSION"
	fi
else
	sendToLog "Warning: unable validate signature for IBM Notifier at path: $ibmNotifierAPP."
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: ibmNotifierCODESIGN: \n$ibmNotifierCODESIGN"
fi
}

# Download and install the erase-install.pkg.
getEraseInstall() {
sendToLog "Starter: Attempting to download and install erase-install.pkg..."
downloadRESULT=$(curl "$eraseInstallURL" -L -o "/tmp/erase-install.pkg" 2>&1)
if [[ -f "/tmp/erase-install.pkg" ]]; then
	installRESULT=$(installer -verboseR -pkg "/tmp/erase-install.pkg" -target / 2>&1)
	if [[ $(echo "$installRESULT" | grep -c "installer:PHASE:The software was successfully installed.") -eq 1 ]]; then
		eraseInstallVALID="TRUE"
		rm -Rf "/tmp/erase-install.pkg"
	else
		sendToLog "Error: Unable to install erase-install.pkg."
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: installRESULT: \n$installRESULT"
	fi
else
	sendToLog "Error: Unable to download erase-install.pkg from: $eraseInstallURL."
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: downloadRESULT: \n$downloadRESULT"
fi
}

# Check all erase-install items for validity.
checkEraseInstall() {
eraseInstallVALID="FALSE"
eraseInstallRESULT=$(grep -w "version=" "$eraseInstallSCRIPT" | awk -F '"' '{print $2}')
if [[ "$eraseInstallVERSION" == "$eraseInstallRESULT" ]]; then
	eraseInstallSHASUM=$(echo "$eraseInstallCHECKSUM  $eraseInstallSCRIPT" | shasum -c 2>&1)
	if echo "$eraseInstallSHASUM" | grep -q -w 'OK'; then
		eraseInstallVALID="TRUE"
	else
		sendToLog "Warning: Unable validate checksum for erase-install.sh at path: $eraseInstallSCRIPT."
		[[ "$eraseInstallSHASUM" == "TRUE" ]] && sendToLog "Verbose Mode: eraseInstallSHASUM: \n$eraseInstallSHASUM"
	fi
else
	sendToLog "Warning: erase-install.sh at path: $eraseInstallSCRIPT is version $eraseInstallRESULT, this does not match target version $eraseInstallVERSION."
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: eraseInstallRESULT: \n$eraseInstallRESULT"
fi
if [[ "$eraseInstallVALID" == "TRUE" ]] && [[ ! -e "$installInstallMacOS" ]]; then
	sendToLog "Warning: Unable to locate installinstallmacos.py at path: $installInstallMacOS"
	eraseInstallVALID="FALSE"
fi
if [[ "$eraseInstallVALID" == "TRUE" ]] && [[ ! -d "$pythonFRAMEWORK" ]]; then
	sendToLog "Warning: Unable to locate Python.framework at path: $pythonFRAMEWORK"
	eraseInstallVALID="FALSE"
fi
if [[ "$eraseInstallVALID" == "TRUE" ]]; then
	if [[ -d "$depNotifyAPP" ]]; then
		depNotifyCODESIGN=$(codesign --verify --verbose "$depNotifyAPP" 2>&1)
		if [[ $(echo "$depNotifyCODESIGN" | grep -c "valid on disk") -eq 0 ]]; then
			sendToLog "Warning: Unable validate signature for DEPNotify at path: $depNotifyAPP."
			eraseInstallVALID="FALSE"
		fi
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: depNotifyCODESIGN: \n$depNotifyCODESIGN"
	else
		sendToLog "Warning: Unable to locate DEPNotify.app at path: $depNotifyAPP"
		eraseInstallVALID="FALSE"
	fi
fi
}

# Install and validate helper items that may be used by super.
manageHelpers() {
helperERROR="FALSE"

# Validate $jamfBINARY if installed and set $jamfVERSION and $jamfSERVER accordingly.
jamfVERSION="FALSE"
if [[ -e "$jamfBINARY" ]]; then
	getJamfProServer
	jamfMAJOR=$("$jamfBINARY" -version | cut -c 9- | cut -d'.' -f1) # Expected output: 10
	jamfMINOR=$("$jamfBINARY" -version | cut -c 9- | cut -d'.' -f2) # Expected output: 30, 31, 32, etc.
	jamfVERSION=${jamfMAJOR}$(printf "%02d" "$jamfMINOR") # Expected output: 1030, 1031, 1032, etc.
	if [[ "$macosARCH" == "arm64" ]] && [[ "$jamfVERSION" -lt 1035 ]]; then
		sendToLog "Helper Error: Jamf Pro $jamfVERSION not supported for Apple Silicon."; helperERROR="TRUE"
	elif [[ "$macosARCH" == "i386" ]] && [[ "$jamfVERSION" -lt 1000 ]]; then
		sendToLog "Helper Error: Jamf Pro $jamfVERSION not supported for Intel."; helperERROR="TRUE"
	fi
	if [[ "$pushMajorUpgradeOPTION" == "TRUE" ]] && [[ $jamfVERSION -lt 1038 ]]; then
		sendToLog "Helper Error: Jamf Pro $jamfVERSION does not support pushing major system upgrades via MDM."; helperERROR="TRUE"
	fi
else
	sendToLog "Starter: Unable to locate jamf binary at: $jamfBINARY"
fi

# Manage $preferJamfHelperOPTION and save to $superPLIST.
if [[ -n $preferJamfHelperOPTION ]]; then
	if [[ $preferJamfHelperOPTION -eq 1 ]] || [[ "$preferJamfHelperOPTION" == "TRUE" ]]; then
		if [[ "$jamfVERSION" != "FALSE" ]]; then
			preferJamfHelperOPTION="TRUE"
			defaults write "$superPLIST" PreferJamfHelper -bool "$preferJamfHelperOPTION"
		else
			sendToLog "Helper Error: No local Jamf binary found, thus can not prefer jamfHelper."; helperERROR="TRUE"
		fi
	else
		preferJamfHelperOPTION="FALSE"
		defaults delete "$superPLIST" PreferJamfHelper 2> /dev/null
	fi
fi

# If needed, validate the IBM Notifier.app, if missing or invalid then install and check again.
if [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	ibmNotifierVALID="FALSE"
	if [[ $macosMAJOR -ge 11 ]] || { [[ $macosMAJOR -eq 10 ]] && [[ $macosMINOR -ge 15 ]]; }; then
		if [[ ! -d "$ibmNotifierAPP" ]]; then
			getIbmNotifier
			[[ -d "$ibmNotifierAPP" ]] && checkIbmNotifier
			[[ "$ibmNotifierVALID" == "FALSE" ]] && sendToLog "Error: Unable to validate IBM Notifier.app after installation, attempting fallback to jamfHelper."
		else
			checkIbmNotifier
			if [[ "$ibmNotifierVALID" == "FALSE" ]]; then
				sendToLog "Starter: Removing existing IBM Notifier.app."
				rm -Rf "$ibmNotifierAPP" > /dev/null 2>&1
				[[ -d "$superFOLDER/__MACOSX" ]] && rm -Rf "$superFOLDER/__MACOSX" > /dev/null 2>&1
				getIbmNotifier
				[[ -d "$ibmNotifierAPP" ]] && checkIbmNotifier
			fi
			[[ "$ibmNotifierVALID" == "FALSE" ]] && sendToLog "Error: Unable to validate IBM Notifier.app after re-installation, attempting fallback to jamfHelper."
		fi
	else
		sendToLog "Warning: IBM Notifier.app is not compatible with this version of macOS, attempting fallback to jamfHelper."
	fi
else
	[[ "$helperERROR" == "FALSE" ]] && sendToLog "Starter: Prefer jamfHelper mode enabled."
fi

# If there is no IBM Notifier.app, then validate $jamfHelper.
if [[ "$ibmNotifierVALID" == "FALSE" ]]; then
	if [[ ! -e "$jamfHELPER" ]]; then
		sendToLog "Helper Error: Cannot locate fallback jamfHelper at: $jamfHELPER"; helperERROR="TRUE"
	fi
fi

# If needed, validate erase-install items, if missing or invalid then install and check again.
if [[ "$minorUpdateWORKFLOW" == "APP" ]] || [[ "$majorUpgradeWORKFLOW" == "APP" ]] || [[ "$majorUpgradeWORKFLOW" == "USER" ]]; then
	eraseInstallVALID="FALSE"
	if [[ ! -d "$eraseInstallFOLDER" ]]; then
		getEraseInstall
		[[ -d "$eraseInstallFOLDER" ]] && checkEraseInstall
		[[ "$eraseInstallVALID" == "FALSE" ]] && sendToLog "Error: Unable to validate erase-install items after installation, can not upgrade system."
	else
		checkEraseInstall
		if [[ "$eraseInstallVALID" == "FALSE" ]]; then
			sendToLog "Starter: Removing existing erase-install items."
			rm -Rf "$eraseInstallFOLDER" > /dev/null 2>&1
			getEraseInstall
			[[ -d "$eraseInstallFOLDER" ]] && checkEraseInstall
		fi
		[[ "$eraseInstallVALID" == "FALSE" ]] && sendToLog "Error: Unable to validate erase-install items after re-installation, can not upgrade system."
	fi
	[[ "$eraseInstallVALID" == "FALSE" ]] && helperERROR="TRUE"
fi
}

# Install items required by super.
superInstaller() {
# Figure out where super is running from and start Installer log if anything needs to be installed.
superPATH="$(dirname "$0")"
{ [[ ! -d "$superFOLDER" ]] || ! { [[ "$superPATH" == "$superFOLDER" ]] || [[ "$superPATH" == "$(dirname "$superLINK")" ]]; } } && sendToLog "**** S.U.P.E.R.M.A.N. INSTALLER ****"

# Make sure the $superFOLDER exists.
if [[ ! -d "$superFOLDER" ]]; then
	mkdir -p "$superFOLDER"
	sendToLog "Installer: Made working folder: $superFOLDER"
fi

# Install super if it's running from any location that is not in the $superFOLDER or from the $superLINK.
if ! { [[ "$superPATH" == "$superFOLDER" ]] || [[ "$superPATH" == "$(dirname "$superLINK")" ]]; }; then
	sendToLog "Installer: Copying file: $superFOLDER/super"
	cp "$0" "$superFOLDER/super" > /dev/null 2>&1
	sendToLog "Installer: Creating default path link: $superLINK"
	ln -s "$superFOLDER/super" "$superLINK" > /dev/null 2>&1
	sendToLog "Installer: Creating file: $superFOLDER/super-starter"
/bin/cat <<EOSS > "$superFOLDER/super-starter"
#!/bin/sh
echo "\$(date +"%a %b %d %T") \$(hostname -s) \$(basename "\$0")[\$\$]: **** S.U.P.E.R.M.A.N. LAUNCHDAEMON ****" | tee -a "$superLOG"
"$superFOLDER/super" "\$@" &
disown -a -h
exit 0
EOSS
	touch "$asuLOG"
	touch "$mdmLOG"
	touch "$updateLOG"
	sendToLog "Installer: Setting permissions in: $superFOLDER"
	chown -R root:wheel "$superFOLDER"
	chown root:wheel "$superLINK"
	chmod -R a+r "$superFOLDER"
	chmod a+r "$superLINK"
	chmod a+x "$superFOLDER/super"
	chmod a+x "$superFOLDER/super-starter"
	chmod a+x "$superLINK"
	sendToLog "**** S.U.P.E.R.M.A.N. INSTALLER COMPLETED ****"
fi
}

# Prepare super by cleaning after previous super runs, record various maintenance modes, validate parameters, and liberate super from Jamf Policy runs.
superStarter() {
sendToLog "**** S.U.P.E.R.M.A.N. STARTER ****"
sendToStatus "Running: Startup workflow..."
sendToPending "Currently running."

# Check for any previous super process still running, if so kill it.
if [[ -f "$superPIDFILE" ]]; then
	previousPID=$(cat "$superPIDFILE")
	sendToLog "Starter: Found previous super instance running with PID $previousPID, killing..."
	kill -9 "$previousPID" > /dev/null 2>&1
fi

# Kill any already running helper processes.
killall -9 "softwareupdate" > /dev/null 2>&1
killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
killall -9 "jamfHelper" > /dev/null 2>&1

# Create $superPIDFILE for this instance of super.
echo $$ > "$superPIDFILE"

# This unloads and deletes any previous LaunchDaemons.
if [[ -f "/Library/LaunchDaemons/$launchDaemonNAME.plist" ]]; then
	sendToLog "Starter: Removing previous LaunchDaemon $launchDaemonNAME.plist."
	launchctl bootout system "/Library/LaunchDaemons/$launchDaemonNAME.plist" 2> /dev/null
	rm -f "/Library/LaunchDaemons/$launchDaemonNAME.plist"
fi

# Manage the $verboseModeOPTION and if enabled start additional logging.
if [[ $verboseModeOPTION -eq 1 ]] || [[ "$verboseModeOPTION" == "TRUE" ]]; then
	verboseModeOPTION="TRUE"
	defaults write "$superPLIST" VerboseMode -bool "$verboseModeOPTION"
else
	verboseModeOPTION="FALSE"
	defaults delete "$superPLIST" VerboseMode 2> /dev/null
fi
if [[ "$verboseModeOPTION" == "TRUE" ]]; then
	sendToLog "Starter: Verbose mode enabled."
	sendToLog "Starter: Uptime: $(uptime)"
	sendToLog "Starter: Managed preference file $superMANAGEDPLIST:\n$(defaults read "$superMANAGEDPLIST" 2> /dev/null)"
	sendToLog "Starter: Local preference file before validation $superPLIST:\n$(defaults read "$superPLIST" 2> /dev/null)"
fi

# Main parameter validation and management.
checkCurrentUser
manageParameters

# Workflow for for $openLOGS.
if [[ "$openLOGS" == "TRUE" ]]; then
	if [[ "$currentUSER" != "FALSE" ]]; then
		sendToLog "Starter: Opening logs for user $currentUSER..."
		if [[ $macosMAJOR -ge 11 ]]; then
			sudo -u "$currentUSER" open "$updateLOG"
			sudo -u "$currentUSER" open "$mdmLOG"
		fi
		sudo -u "$currentUSER" open "$asuLOG"
		sudo -u "$currentUSER" open "$superLOG"
	else
		sendToLog "Starter: Open logs request denied because there is currently no local user logged into the GUI."
	fi
fi

# Feedback for various alternate workflow modes.
[[ "$skipUpdatesOPTION" == "TRUE" ]] && sendToLog "Starter: Skip Apple software updates mode enabled."
[[ "$forceRestartOPTION" == "TRUE" ]] && sendToLog "Starter: Forced restart mode enabled."
[[ "$testModeOPTION" == "TRUE" ]] && sendToLog "Starter: Test mode enabled with $testModeTimeoutSECONDS second timeout."
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Starter: Local preference file after validation $superPLIST:\n$(defaults read "$superPLIST" 2> /dev/null)"

# Additional validation and management.
manageUpdateCredentials
manageWorkflowOptions
manageHelpers
[[ "$verboseModeOPTION" == "TRUE" ]] && logParameters
if [[ "$parameterERROR" == "TRUE" ]] || [[ "$credentialERROR" == "TRUE" ]] || [[ "$workflowERROR" == "TRUE" ]] || [[ "$helperERROR" == "TRUE" ]] || [[ "$betaERROR" == "TRUE" ]]; then
	sendToLog "Exit: Startup validation failed."
	sendToStatus "Inactive Error: Startup validation failed."
	[[ -n "$jamfProTOKEN" ]] && deleteJamfProServerToken
	rm -f "$superPIDFILE"
	sendToLog "**** S.U.P.E.R.M.A.N. EXIT ****"
	exit 1
fi

# If super is running via Jamf, then restart via LaunchDaemon to release the jamf process.
# This is late in the starter workflow so as to only create a valid LaunchDaemon after parameter validation and housekeeping.
if [[ $1 == "/" ]] || [[ $(ps -p "$PPID" | awk '{print $4;}' | grep -c "jamf") -gt 0 ]]; then
	sendToLog "Starter: Found that Jamf is installing or is the parent process, restarting with new LaunchDaemon..."
	sendToStatus "Pending: Found that Jamf is installing or is the parent process, restarting with new LaunchDaemon."
	makeLaunchDaemonRestartNow
fi

# If super is running from outside the $superFOLDER, then restart via LaunchDaemon to release any parent installer process.
if ! { [[ "$superPATH" == "$superFOLDER" ]] || [[ "$superPATH" == "$(dirname "$superLINK")" ]]; }; then
	sendToLog "Starter: Found that super is installing, restarting with new LaunchDaemon..."
	sendToStatus "Pending: Found that super is installing, restarting with new LaunchDaemon."
	makeLaunchDaemonRestartNow
fi

# Make sure we have a network connection before moving on.
# If there is still no network after two minutes, an automatic deferral is started.
networkTIMEOUT=0
while [[ $(ifconfig -a inet 2>/dev/null | sed -n -e '/127.0.0.1/d' -e '/0.0.0.0/d' -e '/inet/p' | wc -l) -le 0 ]] && [[ $networkTIMEOUT -lt 120 ]]; do
	sendToLog "Starter: Waiting for network..."
	sleep 5
	networkTIMEOUT=$((networkTIMEOUT + 5))
done
if [[ $(ifconfig -a inet 2>/dev/null | sed -n -e '/127.0.0.1/d' -e '/0.0.0.0/d' -e '/inet/p' | wc -l) -le 0 ]]; then
	sendToLog "Error: Network unavailable, trying again in $defaultDeferSECONDS seconds."
	sendToStatus "Pending: Network unavailable, trying again in $defaultDeferSECONDS seconds."
	makeLaunchDaemonCalendar
fi

# If super is running after an update restart and set $updateVALIDATE appropriately.
[[ $(defaults read "$superPLIST" UpdateValidate 2> /dev/null) ]] && updateVALIDATE="TRUE"

# With startup complete, create a fail-safe system startup LaunchDaemon in case the system is restarted (via the user or something else) wile super is active.
sendToLog "Starter: Creating fail-safe system startup LaunchDaemon."
makeLaunchDaemonOnStartup
defaults write "$superPLIST" FailSafeActive -bool true
}

# MARK: *** Logging ***
################################################################################

# Append input to the command line and log located at $superLOG.
sendToLog() {
echo -e "$(date +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: $*" | tee -a "$superLOG"
}

# Append input to the command line only, so as not to save secrets to the $superLOG.
sendToEcho() {
echo -e "$(date +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: Not Logged: $*"
}

# Append input to a log located at $asuLOG.
sendToASULog() {
echo -e "$(date +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: $*" >> "$asuLOG"
}

# Append input to a log located at $mdmLOG.
sendToMDMLog() {
echo -e "$(date +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: $*" >> "$mdmLOG"
}

# Append input to a log located at $updateLOG.
sendToUpdateLog() {
echo -e "$(date +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: $*" >> "$updateLOG"
}

# Update the SuperStatus key in the $superPLIST.
sendToStatus() {
defaults write "$superPLIST" SuperStatus -string "$(date +"%a %b %d %T"): $*"
}

# Update the SuperPending key in the $superPLIST.
sendToPending() {
defaults write "$superPLIST" SuperPending -string "$*"
}

# Log any parameters that have values.
logParameters() {
sendToLog "Verbose Mode: macosMAJOR: $macosMAJOR"
sendToLog "Verbose Mode: macosMINOR: $macosMINOR"
sendToLog "Verbose Mode: macosVERSION: $macosVERSION"
sendToLog "Verbose Mode: macosARCH: $macosARCH"
sendToLog "Verbose Mode: parameterERROR: $parameterERROR"
sendToLog "Verbose Mode: credentialERROR: $credentialERROR"
sendToLog "Verbose Mode: workflowERROR: $workflowERROR"
sendToLog "Verbose Mode: helperERROR: $helperERROR"
[[ -n $jamfVERSION ]] && sendToLog "Verbose Mode: jamfVERSION: $jamfVERSION"
[[ -n $jamfSERVER ]] && sendToLog "Verbose Mode: jamfSERVER: $jamfSERVER"
[[ -n $ibmNotifierVALID ]] && sendToLog "Verbose Mode: ibmNotifierVALID: $ibmNotifierVALID"
[[ -n $eraseInstallVALID ]] && sendToLog "Verbose Mode: eraseInstallVALID: $eraseInstallVALID"
[[ -n $defaultDeferSECONDS ]] && sendToLog "Verbose Mode: defaultDeferSECONDS: $defaultDeferSECONDS"
[[ -n $focusDeferSECONDS ]] && sendToLog "Verbose Mode: focusDeferSECONDS: $focusDeferSECONDS"
[[ -n $menuDeferSECONDS ]] && sendToLog "Verbose Mode: menuDeferSECONDS: $menuDeferSECONDS"
[[ -n $recheckDeferSECONDS ]] && sendToLog "Verbose Mode: recheckDeferSECONDS: $recheckDeferSECONDS"
[[ -n $focusCountMAX ]] && sendToLog "Verbose Mode: focusCountMAX: $focusCountMAX"
[[ -n $softCountMAX ]] && sendToLog "Verbose Mode: softCountMAX: $softCountMAX"
[[ -n $hardCountMAX ]] && sendToLog "Verbose Mode: hardCountMAX: $hardCountMAX"
[[ -n $focusDaysMAX ]] && sendToLog "Verbose Mode: focusDaysMAX: $focusDaysMAX"
[[ -n $softDaysMAX ]] && sendToLog "Verbose Mode: softDaysMAX: $softDaysMAX"
[[ -n $hardDaysMAX ]] && sendToLog "Verbose Mode: hardDaysMAX: $hardDaysMAX"
[[ -n $zeroDayOVERRIDE ]] && sendToLog "Verbose Mode: zeroDayOVERRIDE: $zeroDayOVERRIDE"
[[ -n $focusDateMAX ]] && sendToLog "Verbose Mode: focusDateMAX: $focusDateMAX"
[[ -n $softDateMAX ]] && sendToLog "Verbose Mode: softDateMAX: $softDateMAX"
[[ -n $hardDateMAX ]] && sendToLog "Verbose Mode: hardDateMAX: $hardDateMAX"
[[ -n $displayTimeoutSECONDS ]] && sendToLog "Verbose Mode: displayTimeoutSECONDS: $displayTimeoutSECONDS"
[[ -n $displayRedrawSECONDS ]] && sendToLog "Verbose Mode: displayRedrawSECONDS: $displayRedrawSECONDS"
[[ -n $ibmNotifierIconSIZE ]] && sendToLog "Verbose Mode: ibmNotifierIconSIZE: $ibmNotifierIconSIZE"
[[ -n $jamfHelperIconSIZE ]] && sendToLog "Verbose Mode: jamfHelperIconSIZE: $jamfHelperIconSIZE"
[[ -n $preferJamfHelperOPTION ]] && sendToLog "Verbose Mode: preferJamfHelperOPTION: $preferJamfHelperOPTION"
[[ -n $localOPTION ]] && sendToLog "Verbose Mode: localOPTION: $localOPTION"
[[ -n $localPASSWORD ]] && sendToEcho "Verbose Mode: localPASSWORD: $localPASSWORD"
[[ -n $localACCOUNT ]] && sendToLog "Verbose Mode: localACCOUNT: $localACCOUNT"
[[ -n $localKEYCHAIN ]] && sendToEcho "Verbose Mode: localKEYCHAIN: $localKEYCHAIN"
[[ -n $localCREDENTIAL ]] && sendToLog "Verbose Mode: localCREDENTIAL: $localCREDENTIAL"
[[ -n $adminACCOUNT ]] && sendToLog "Verbose Mode: adminACCOUNT: $adminACCOUNT"
[[ -n $adminPASSWORD ]] && sendToEcho "Verbose Mode: adminPASSWORD: $adminPASSWORD"
[[ -n $superOPTION ]] && sendToLog "Verbose Mode: superOPTION: $superOPTION"
[[ -n $superPASSWORD ]] && sendToEcho "Verbose Mode: superPASSWORD: $superPASSWORD"
[[ -n $superACCOUNT ]] && sendToLog "Verbose Mode: superACCOUNT: $superACCOUNT"
[[ -n $superKEYCHAIN ]] && sendToEcho "Verbose Mode: superKEYCHAIN: $superKEYCHAIN"
[[ -n $superCREDENTIAL ]] && sendToLog "Verbose Mode: superCREDENTIAL: $superCREDENTIAL"
[[ -n $JamfProID ]] && sendToLog "Verbose Mode: JamfProID: $JamfProID"
[[ -n $jamfOPTION ]] && sendToLog "Verbose Mode: jamfOPTION: $jamfOPTION"
[[ -n $jamfPASSWORD ]] && sendToEcho "Verbose Mode: jamfPASSWORD: $jamfPASSWORD"
[[ -n $jamfACCOUNT ]] && sendToLog "Verbose Mode: jamfACCOUNT: $jamfACCOUNT"
[[ -n $jamfKEYCHAIN ]] && sendToEcho "Verbose Mode: jamfKEYCHAIN: $jamfKEYCHAIN"
[[ -n $jamfCREDENTIAL ]] && sendToLog "Verbose Mode: jamfCREDENTIAL: $jamfCREDENTIAL"
[[ -n $deleteACCOUNTS ]] && sendToLog "Verbose Mode: deleteACCOUNTS: $deleteACCOUNTS"
[[ -n $policyTRIGGERS ]] && sendToLog "Verbose Mode: policyTRIGGERS: $policyTRIGGERS"
[[ -n $skipUpdatesOPTION ]] && sendToLog "Verbose Mode: skipUpdatesOPTION: $skipUpdatesOPTION"
[[ -n $installMajorUpgradeOPTION ]] && sendToLog "Verbose Mode: installMajorUpgradeOPTION: $installMajorUpgradeOPTION"
[[ -n $installMinorUpdateOPTION ]] && sendToLog "Verbose Mode: installMinorUpdateOPTION: $installMinorUpdateOPTION"
[[ -n $pushMajorUpgradeOPTION ]] && sendToLog "Verbose Mode: pushMajorUpgradeOPTION: $pushMajorUpgradeOPTION"
[[ -n $targetMajorUpgradeVERSION ]] && sendToLog "Verbose Mode: targetMajorUpgradeVERSION: $targetMajorUpgradeVERSION"
[[ -n $forceRestartOPTION ]] && sendToLog "Verbose Mode: forceRestartOPTION: $forceRestartOPTION"
[[ -n $testModeOPTION ]] && sendToLog "Verbose Mode: testModeOPTION: $testModeOPTION"
[[ -n $testModeTimeoutSECONDS ]] && sendToLog "Verbose Mode: testModeTimeoutSECONDS: $testModeTimeoutSECONDS"
[[ -n $verboseModeOPTION ]] && sendToLog "Verbose Mode: verboseModeOPTION: $verboseModeOPTION"
}

# MARK: *** Jamf Pro API ***
################################################################################

# Validate the connection to a managed computer's Jamf Pro service and set $jamfSERVER accordingly.
getJamfProServer() {
jamfSTATUS=$("$jamfBINARY" checkJSSConnection -retry 1)
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: jamfSTATUS is: $jamfSTATUS"
if [[ $(echo "$jamfSTATUS" | grep -c "available") -ne 0 ]]; then
	jamfSERVER=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
else
	sendToLog "Status: Jamf Pro service unavailable."; jamfSERVER="FALSE"; jamfERROR="TRUE"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: jamfSTATUS is: $jamfSTATUS"
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: jamfSERVER is: $jamfSERVER"
}

# Attempt to acquire a Jamf Pro $jamfProTOKEN via $jamfACCOUNT and $jamfKEYCHAIN credentials.
getJamfProToken() {
getJamfProServer
if [[ "$jamfSERVER" != "FALSE" ]]; then
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: Attempting Jamf Pro API authentication with username: $jamfACCOUNT"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToEcho "Verbose Mode: Attempting Jamf Pro API authentication with password: $jamfKEYCHAIN"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: Attempting Jamf Pro API via service URL: $jamfSERVER"
	commandRESULT=$(curl -X POST -u "$jamfACCOUNT:$jamfKEYCHAIN" -s "${jamfSERVER}api/v1/auth/token")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: commandRESULT is: \n$commandRESULT"
	if [[ $(echo "$commandRESULT" | grep "token" -c) -eq 1 ]]; then
		if [[ $macosMAJOR -ge 12 ]]; then
			jamfProTOKEN=$(echo "$commandRESULT" | plutil -extract token raw -)
		else
			jamfProTOKEN=$(echo "$commandRESULT" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
		fi
	else
		sendToLog "Error: Response from Jamf Pro API token request did not contain a token."; jamfERROR="TRUE"
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: jamfProTOKEN is: \n$jamfProTOKEN"
fi
}

# Validate that the account $jamfACCOUNT and $jamfKEYCHAIN are valid credentials and has appropriate permissions to send MDM push commands. If not set $jamfERROR.
getJamfProAccount() {
getJamfProToken
if [[ -n $jamfProTOKEN ]]; then
	getJamfProComputerID
	if [[ -n $jamfProID ]]; then
		sendBlankPush
			if [[ $commandRESULT != 201 ]]; then
				sendToLog "Error: Unable to request Blank Push via Jamf Pro API user account \"$jamfACCOUNT\". Verify this account has has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\"."; jamfERROR="TRUE"
			fi
	else
		sendToLog "Error: Unable to acquire Jamf Pro ID for computer with UDID \"$computerUDID\". Verify that this computer is enrolled in Jamf Pro."
		sendToLog "Error: Also verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\"."; jamfERROR="TRUE"
	fi
else
	sendToLog "Error: Unable to acquire authentication token via Jamf Pro API user account \"$jamfACCOUNT\". Verify account name and password."; jamfERROR="TRUE"
fi
}

# Use $jamfProIdMANAGED or $jamfProTOKEN to find the computer's Jamf Pro ID and set $jamfProID.
getJamfProComputerID() {
computerUDID=$(system_profiler SPHardwareDataType | awk '/UUID/ { print $3; }')
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: computerUDID is: $computerUDID"
if [[ -n $jamfProIdMANAGED ]]; then
	jamfProID="$jamfProIdMANAGED"
else
	sendToLog "Warning: Using a Jamf Pro API account with \"Computers > Read\" privileges to collect the computer ID is a security risk. Instead use a custom Configuration Profile with the following; Preference Domain \"com.macjutsu.super\", Key \"JamfProID\", String \"\$JSSID\"."
	jamfProID=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --header "Accept: application/xml" --request GET --url "${jamfSERVER}JSSResource/computers/udid/${computerUDID}/subset/General" 2> /dev/null | xpath -e /computer/general/id 2>&1 | awk -F'<id>|</id>' '{print $2}' | xargs)
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: jamfProID is: $jamfProID"
}

# Attempt to send a Blank Push to Jamf Pro.
sendBlankPush() {
commandRESULT=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --write-out "%{http_code}" --silent --output /dev/null --request POST --url "${jamfSERVER}JSSResource/computercommands/command/BlankPush/id/${jamfProID}")
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: commandRESULT is: \n$commandRESULT"
}

# Validate existing $jamfProTOKEN and if found invalid, a new token is requested and again validated.
checkJamfProServerToken() {
tokenCHECK=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --write-out "%{http_code}" --silent --output /dev/null --request GET --url "${jamfSERVER}api/v1/auth")
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: tokenCHECK is: $tokenCHECK"
if [[ $tokenCHECK -ne 200 ]]; then
	getJamfProToken
	tokenCHECK=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --write-out "%{http_code}" --silent --output /dev/null --request GET --url "${jamfSERVER}api/v1/auth")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: tokenCHECK is: $tokenCHECK"
	if [[ $tokenCHECK -ne 200 ]]; then
		sendToLog "Error: Could not request Jamf Pro API token for account \"$jamfACCOUNT\", trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Could not request Jamf Pro API token for account \"$jamfACCOUNT\", trying again in $defaultDeferSECONDS seconds."
		makeLaunchDaemonCalendar
	fi
fi
}

# Invalidate and remove from local memory the $jamfProTOKEN.
deleteJamfProServerToken() {
invalidateTOKEN=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --write-out "%{http_code}" --silent --output /dev/null --request POST --url "${jamfSERVER}api/v1/auth/invalidate-token")
if [[ $invalidateTOKEN -eq 204 ]]; then
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: Jamf Pro API token successfully invalidated."
	unset jamfProTOKEN
elif [[ $invalidateTOKEN -eq 401 ]]; then
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: Jamf Pro API token already invalid."
	unset jamfProTOKEN
else
	sendToLog "Error: Invalidating Jamf Pro API token."
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: invalidateTOKEN is: $invalidateTOKEN"
fi
}

# MARK: *** Local Users ***
################################################################################

# Verify that super is running with root privileges.
checkRoot() {
if [[ "$(id -u)" -ne 0 ]]; then
	sendToEcho "Exit: $(basename "$0") must run with root privileges."
	exit 1
fi
}

# Set $currentUSER and $currentUID to the currently logged in GUI user or "FALSE" if there is none or a system account.
checkCurrentUser() {
currentUSER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')
if [[ -z $currentUSER ]]; then
	sendToLog "Status: No GUI user currently logged in."
	currentUSER="FALSE"
	currentUID="FALSE"
elif [[ "$currentUSER" = "root" ]] || [[ "$currentUSER" = "_mbsetupuser" ]] || [[ "$currentUSER" = "loginwindow" ]]; then
	sendToLog "Status: Current GUI user is system account $currentUSER."
	currentUSER="FALSE"
	currentUID="0"
else
	currentUID=$(id -u "$currentUSER")
	sendToLog "Status: Current GUI user is $currentUSER with a UID of $currentUID."
fi
}

# Validate that the account $updateACCOUNT and $updateKEYCHAIN are valid credentials is a volume owner. If not set $accountERROR.
checkLocalUpdateAccount() {
accountGUID=$(dscl . read "/Users/$updateACCOUNT" GeneratedUID 2> /dev/null | awk '{print $2;}')
if [[ -n $accountGUID ]]; then
	if ! [[ $(diskutil apfs listcryptousers / | grep -c "$accountGUID") -ne 0 ]]; then
		sendToLog "Error: Provided account \"$updateACCOUNT\" is not a system volume owner."; accountERROR="TRUE"
	fi
	accountVALID=$(dscl /Local/Default -authonly "$updateACCOUNT" "$updateKEYCHAIN" 2>&1)
	if ! [[ "$accountVALID" == "" ]];then
		sendToLog "Error: The provided password for account \"$updateACCOUNT\" is not valid."; accountERROR="TRUE"
	fi
else
	sendToLog "Error: Could not retrieve GUID for account \"$updateACCOUNT\". Verify that account exists locally."; accountERROR="TRUE"
fi
}

# MARK: *** Deferrals & Deadlines ***
################################################################################

# Delete the maximum deferral counters in $superPLIST to restart the counters.
restartZeroDay() {
sendToLog "Status: Restarting automatically set zero day date."
defaults delete "$superPLIST" ZeroDayAuto 2> /dev/null
}

# Delete the maximum deferral counters in $superPLIST to restart the counters.
restartDeferralCounters() {
sendToLog "Status: Restarting maximum deferral counters."
defaults delete "$superPLIST" FocusCounter 2> /dev/null
defaults delete "$superPLIST" SoftCounter 2> /dev/null
defaults delete "$superPLIST" HardCounter 2> /dev/null
}

# Evaluate $zeroDayOVERRIDE and $zeroDayPREVIOUS, then set $zeroDaySTART, $zeroDayEPOCH, and $zeroDayDISPLAY accordingly.
checkZeroDay() {
if [[ -n $zeroDayOVERRIDE ]]; then # If there is a $zeroDayOVERRIDE then use that first.
	zeroDaySTART="$zeroDayOVERRIDE"
	sendToLog "Status: Using manually set zero day date of $zeroDaySTART."
else
	zeroDayPREVIOUS=$(defaults read "$superPLIST" ZeroDayAuto 2> /dev/null)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: zeroDayPREVIOUS: $zeroDayPREVIOUS"
	if [[ -n $zeroDayPREVIOUS ]]; then # If there was a previously saved zero day date then use that.
		zeroDaySTART="$zeroDayPREVIOUS"
		sendToLog "Status: Using previously set automatic zero day date of $zeroDaySTART."
	else # Otherwise this is a new zero day date, so save to $superPLIST.
		zeroDaySTART=$(date +"%Y-%m-%d:%H:%M")
		sendToLog "Status: Setting new automatic day zero date to $zeroDaySTART."
		defaults write "$superPLIST" ZeroDayAuto -string "$zeroDaySTART"
	fi
fi
zeroDayEPOCH=$(date -j -f "%Y-%m-%d:%H:%M" "$zeroDaySTART" +"%s")
zeroDayDATE=$(date -r "$zeroDayEPOCH" "$dateFORMAT")
zeroDayTIME=$(date -r "$zeroDayEPOCH" "$timeFORMAT" | sed 's/^ *//g')
if [[ $(date -r "$zeroDayEPOCH" "+%H:%M") == "00:00" ]]; then
	zeroDayDISPLAY="$zeroDayDATE"
else
	zeroDayDISPLAY="$zeroDayDATE - $zeroDayTIME"
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: zeroDayEPOCH: $zeroDayEPOCH"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: zeroDayDATE: $zeroDayDATE"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: zeroDayTIME: $zeroDayTIME"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: zeroDayDISPLAY: $zeroDayDISPLAY"
}

# Evaluate if a process has told the display to not sleep or the user has enabled Focus or Do Not Disturb, and set $focusDEFER accordingly.
checkUserFocus() {
focusDEFER="FALSE"
if [[ -n $focusDeferSECONDS ]]; then
	if [[ $macosMAJOR -eq 10 ]]; then
		focusSTATUS=$(sudo -u "$currentUSER" defaults -currentHost read "/Users/$currentUSER/Library/Preferences/ByHost/com.apple.notificationcenterui" doNotDisturb 2>/dev/null)
	elif [[ $macosMAJOR -eq 11 ]]; then
		focusSTATUS=$(plutil -extract dnd_prefs xml1 -o - "/Users/$currentUSER/Library/Preferences/com.apple.ncprefs.plist" | xmllint --xpath "string(//data)" - | base64 --decode | plutil -convert xml1 - -o - | grep -ic userPref)
	else
		focusSTATUS=$(plutil -extract data.0.storeAssertionRecords.0.assertionDetails.assertionDetailsModeIdentifier raw -o - "/Users/$currentUSER/Library/DoNotDisturb/DB/Assertions.json" | grep -ic com.apple.)
	fi
	if [[ $focusSTATUS -gt 0 ]]; then
		sendToLog "Status: Focus or Do Not Disturb enabled for user $currentUSER."
		focusDEFER="TRUE"
	fi
	oldIFS="$IFS"; IFS=$'\n'
	displayASSERTIONS=($(pmset -g assertions | awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^\ +/,"",$0); print};'))
	if [[ -n ${displayASSERTIONS[*]} ]]; then
		for assertionITEM in "${displayASSERTIONS[@]}"; do
			sendToLog "Status: The following Display Sleep Assertions found: $(echo "${assertionITEM}" | awk -F: '{print $1}')"
		done
		focusDEFER="TRUE"
	fi
	IFS="$oldIFS"
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: focusDEFER is: $focusDEFER"
}

# Evaluate $focusDateMAX, $softDateMAX, and $hardDateMAX, then set $deadlineDateSTATUS, $deadlineDateEPOCH, and $deadlineDateDISPLAY accordingly.
checkDateDeadlines() {
deadlineDateSTATUS="FALSE"
if [[ -n $focusDateMAX ]]; then
	if [[ $focusDateEPOCH -lt $(date +%s) ]]; then
		sendToLog "Status: Focus date deadline of $focusDateMAX HAS passed."
		deadlineDateSTATUS="FOCUS"
	else
		sendToLog "Status: Focus date deadline of $focusDateMAX NOT passed."
	fi
fi
if [[ -n $softDateMAX ]]; then
	if [[ $softDateEPOCH -lt $(date +%s) ]]; then
		sendToLog "Status: Soft date deadline of $softDateMAX HAS passed."
		deadlineDateSTATUS="SOFT"
	else
		sendToLog "Status: Soft date deadline of $softDateMAX NOT passed."
	fi
fi
if [[ -n $hardDateMAX ]]; then
	if [[ $hardDateEPOCH -lt $(date +%s) ]]; then
		sendToLog "Status: Hard date deadline of $hardDateMAX HAS passed."
		deadlineDateSTATUS="HARD"
	else
		sendToLog "Status: Hard date deadline of $hardDateMAX NOT passed."
	fi
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDateSTATUS is: $deadlineDateSTATUS"

# For display the $softDateMAX always results in a sooner date than the $hardDateMAX.
[[ -n $hardDateMAX ]] && deadlineDateEPOCH="$hardDateEPOCH"
[[ -n $softDateMAX ]] && deadlineDateEPOCH="$softDateEPOCH"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDateEPOCH is: $deadlineDateEPOCH"
if [[ -n $deadlineDateEPOCH ]]; then
	deadlineDateDATE=$(date -r "$deadlineDateEPOCH" "$dateFORMAT")
	deadlineDateTIME=$(date -r "$deadlineDateEPOCH" "$timeFORMAT" | sed 's/^ *//g')
	if [[ $(date -r "$deadlineDateEPOCH" "+%H:%M") == "00:00" ]]; then
		deadlineDateDISPLAY="$deadlineDateDATE"
	else
		deadlineDateDISPLAY="$deadlineDateDATE - $deadlineDateTIME"
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDateDATE is: $deadlineDateDATE"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDateTIME is: $deadlineDateTIME"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDateDISPLAY is: $deadlineDateDISPLAY"
fi
}

# Evaluate $focusDaysMAX, $softDaysMAX, and $hardDaysMAX, then set $deadlineDaysSTATUS, $deadlineDaysEPOCH, and $deadlineDaysDISPLAY accordingly.
checkDaysDeadlines() {
deadlineDaysSTATUS="FALSE"
if [[ -n $focusDaysMAX ]]; then
	focusDaysEPOCH=$((zeroDayEPOCH + focusDaysSECONDS))
	focusDaysDATE=$(date -r "$focusDaysEPOCH" +%Y-%m-%d:%H:%M)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: focusDaysEPOCH: $focusDaysEPOCH"
	if [[ $focusDaysEPOCH -lt $(date +%s) ]]; then
		sendToLog "Status: Focus days deadline of $focusDaysDATE ($focusDaysMAX day(s) after $zeroDaySTART) HAS passed."
		deadlineDaysSTATUS="FOCUS"
	else
		sendToLog "Status: Focus days deadline of $focusDaysDATE ($focusDaysMAX day(s) after $zeroDaySTART) NOT passed."
	fi
fi
if [[ -n $softDaysMAX ]]; then
	softDaysEPOCH=$((zeroDayEPOCH + softDaysSECONDS))
	softDaysDATE=$(date -r "$softDaysEPOCH" +%Y-%m-%d:%H:%M)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: softDaysEPOCH: $softDaysEPOCH"
	if [[ $softDaysEPOCH -lt $(date +%s) ]]; then
		sendToLog "Status: Soft days deadline of $softDaysDATE ($softDaysMAX day(s) after $zeroDaySTART) HAS passed."
		deadlineDaysSTATUS="SOFT"
	else
		sendToLog "Status: Soft days deadline of $softDaysDATE ($softDaysMAX day(s) after $zeroDaySTART) NOT passed."
	fi
fi
if [[ -n $hardDaysMAX ]]; then
	hardDaysEPOCH=$((zeroDayEPOCH + hardDaysSECONDS))
	hardDaysDATE=$(date -r "$hardDaysEPOCH" +%Y-%m-%d:%H:%M)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: hardDaysEPOCH: $hardDaysEPOCH"
	if [[ $hardDaysEPOCH -lt $(date +%s) ]]; then
		sendToLog "Status: Hard days deadline of $hardDaysDATE ($hardDaysMAX day(s) after $zeroDaySTART) HAS passed."
		deadlineDaysSTATUS="HARD"
	else
		sendToLog "Status: Hard days deadline of $hardDaysDATE ($hardDaysMAX day(s) after $zeroDaySTART) NOT passed."
	fi
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDaysSTATUS is: $deadlineDaysSTATUS"

# For display the $softDaysMAX always results in a sooner date than the $hardDaysMAX.
[[ -n $hardDaysMAX ]] && deadlineDaysEPOCH="$hardDaysEPOCH"
[[ -n $softDaysMAX ]] && deadlineDaysEPOCH="$softDaysEPOCH"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDaysEPOCH is: $deadlineDaysEPOCH"
if [[ -n $deadlineDaysEPOCH ]]; then
	deadlineDaysDATE=$(date -r "$deadlineDaysEPOCH" "$dateFORMAT")
	deadlineDaysTIME=$(date -r "$deadlineDaysEPOCH" "$timeFORMAT" | sed 's/^ *//g')
	if [[ $(date -r "$deadlineDaysEPOCH" "+%H:%M") == "00:00" ]]; then
		deadlineDaysDISPLAY="$deadlineDaysDATE"
	else
		deadlineDaysDISPLAY="$deadlineDaysDATE - $deadlineDaysTIME"
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDaysDATE is: $deadlineDaysDATE"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDaysTIME is: $deadlineDaysTIME"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDaysDISPLAY is: $deadlineDaysDISPLAY"
fi

# For display this sets $deadlineDISPLAY based on the soonest available date or days deadline.
if [[ -n $deadlineDateDISPLAY ]] && [[ -n $deadlineDaysDISPLAY ]]; then
	if [[ $deadlineDateEPOCH -le $deadlineDaysEPOCH ]]; then
		deadlineDISPLAY="$deadlineDateDISPLAY"
	else
		deadlineDISPLAY="$deadlineDaysDISPLAY"
	fi
elif [[ -n $deadlineDateDISPLAY ]]; then
	deadlineDISPLAY="$deadlineDateDISPLAY"
elif [[ -n $deadlineDaysDISPLAY ]]; then
	deadlineDISPLAY="$deadlineDaysDISPLAY"
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineDISPLAY is: $deadlineDISPLAY"
}

# Evaluate $focusCountMAX, $softCountMAX, and $hardCountMAX, then set $focusDEFER, $deadlineCountSTATUS, $countDISPLAY, and $countMaxDISPLAY accordingly.
checkCountDeadlines() {
deadlineCountSTATUS="FALSE"
if [[ "$focusDEFER" == "TRUE" ]]; then
	if [[ -n $focusCountMAX ]]; then
		focusCounterPREVIOUS=$(defaults read "$superPLIST" FocusCounter 2> /dev/null)
		if [[ -z $focusCounterPREVIOUS ]]; then
			sendToLog "Status: Creating new focus deferral counter in $superPLIST."
			focusCounterCURRENT=0
			defaults write "$superPLIST" FocusCounter -int $focusCounterCURRENT
		else
			focusCounterCURRENT=$((focusCounterPREVIOUS + 1))
			defaults write "$superPLIST" FocusCounter -int $focusCounterCURRENT
		fi
		if [[ $focusCounterCURRENT -ge $focusCountMAX ]]; then
			sendToLog "Status: Focus maximum deferral count of $focusCountMAX HAS passed."
			deadlineCountSTATUS="FOCUS"
			focusDEFER="FALSE"
		else
			focusCountDISPLAY=$((focusCountMAX - focusCounterCURRENT))
			sendToLog "Status: Focus maximum deferral count of $focusCountMAX NOT passed with $focusCountDISPLAY remaining."
		fi
	else
		sendToLog "Status: Focus or Do Not Disturb active, and no maximum focus deferral, so not incrementing deferral counters."
	fi
fi
if [[ "$focusDEFER" == "FALSE" ]]; then
	if [[ -n $softCountMAX ]]; then
		softCounterPREVIOUS=$(defaults read "$superPLIST" SoftCounter 2> /dev/null)
		if [[ -z $softCounterPREVIOUS ]]; then
			sendToLog "Status: Creating new soft deferral counter in $superPLIST."
			softCounterCURRENT=0
			defaults write "$superPLIST" SoftCounter -int $softCounterCURRENT
		else
			softCounterCURRENT=$((softCounterPREVIOUS + 1))
			defaults write "$superPLIST" SoftCounter -int $softCounterCURRENT
		fi
		if [[ $softCounterCURRENT -ge $softCountMAX ]]; then
			sendToLog "Status: Soft maximum deferral count of $softCountMAX HAS passed."
			deadlineCountSTATUS="SOFT"
		else
			softCountDISPLAY=$((softCountMAX - softCounterCURRENT))
			sendToLog "Status: Soft maximum deferral count of $softCountMAX NOT passed with $softCountDISPLAY remaining."
		fi
		countDISPLAY="$softCountDISPLAY"
		countMaxDISPLAY="$softCountMAX"
	fi
	if [[ -n $hardCountMAX ]]; then
		hardCounterPREVIOUS=$(defaults read "$superPLIST" HardCounter 2> /dev/null)
		if [[ -z $hardCounterPREVIOUS ]]; then
			sendToLog "Status: Creating new hard deferral counter in $superPLIST."
			hardCounterCURRENT=0
			defaults write "$superPLIST" HardCounter -int $hardCounterCURRENT
		else
			hardCounterCURRENT=$((hardCounterPREVIOUS + 1))
			defaults write "$superPLIST" HardCounter -int $hardCounterCURRENT
		fi
		if [[ $hardCounterCURRENT -ge $hardCountMAX ]]; then
			sendToLog "Status: Hard maximum deferral count of $hardCountMAX HAS passed."
			deadlineCountSTATUS="HARD"
		else
			hardCountDISPLAY=$((hardCountMAX - hardCounterCURRENT))
			sendToLog "Status: Hard maximum deferral count of $hardCountMAX NOT passed with $hardCountDISPLAY remaining."
		fi
		countDISPLAY="$hardCountDISPLAY"
		countMaxDISPLAY="$hardCountMAX"
	fi
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: deadlineCountSTATUS is: $deadlineCountSTATUS"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: focusDEFER is: $focusDEFER"
}

# MARK: *** Apple Software Update ***
################################################################################

# This restarts various softwareupdate daemon processes.
kickAppleSoftwareUpdate(){
sendToLog "Status: Restarting various softwareupdate daemon processes..."

defaults delete /Library/Preferences/com.apple.Softwareupdate.plist > /dev/null 2>&1

if ! launchctl kickstart -k "system/com.apple.mobile.softwareupdated"; then
	sendToLog "Warning: Restarting mobile softwareupdate daemon didn't respond, trying again in 10 seconds..."
	sleep 10
	launchctl kickstart -k "system/com.apple.mobile.softwareupdated"
fi

if ! launchctl kickstart -k "system/com.apple.softwareupdated"; then
	sendToLog "Warning: Restarting system softwareupdate daemon didn't respond, trying again in 10 seconds..."
	sleep 10
	launchctl kickstart -k "system/com.apple.softwareupdated"
fi

# If a user is logged in then also restart the Software Update Notification Manager daemon.
if [[ "$currentUSER" != "FALSE" ]]; then
	if ! launchctl kickstart -k "gui/$currentUID/com.apple.SoftwareUpdateNotificationManager"; then
		sendToLog "Warning: Restarting Software Update Notification Manager didn't respond, trying again in 10 seconds..."
		sleep 10
		launchctl kickstart -k "gui/$currentUID/com.apple.SoftwareUpdateNotificationManager"
	fi
fi
}

# Check for updates via softwareupdate and set $updatesAVAILABLE and $updatesRESULT accordingly.
checkSoftwareUpdate() {
updatesAVAILABLE="FALSE"
checkTIMEOUT="TRUE"

# Background the softwareupdate checking progress and send to $listLOG.
sudo -u root softwareupdate --list > "$checkLOG" 2>&1 &
checkPID=$!

# Watch $checkLOG while waiting for the softwareupdate check workflow to complete. Note this while read loop has a timeout based on $checkTimeoutSECONDS.
while read -t $checkTimeoutSECONDS -r logLINE ; do
	if echo "$logLINE" | grep -w 'Finding available software'; then
		sendToLog "Status: Waiting for softwareupdate check..."
	elif echo "$logLINE" | grep -w 'Software Update found'; then
		updatesAVAILABLE="TRUE"
		checkTIMEOUT="FALSE"
		wait $checkPID
		break
	elif echo "$logLINE" | grep -w 'No new software available.'; then
		updatesAVAILABLE="FALSE"
		checkTIMEOUT="FALSE"
		break
	fi
done < <(tail -n 0 -F "$checkLOG")

# If the softwareupdate check completed, then collect information. However, if the softwareupdate check did not complete after $checkTimeoutSECONDS seconds, then clean-up.
if [[ "$checkTIMEOUT" == "FALSE" ]]; then
	updatesRESULT=$(<"$checkLOG")
else # The softwareupdate check timed out so clean-up and try again later.
	sendToLog "Error: softwareupdate check timed out after $checkTimeoutSECONDS seconds."
	kill -9 "$checkPID" > /dev/null 2>&1
	kickAppleSoftwareUpdate
	sleep 10
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: $checkLOG is:\n$(cat "$checkLOG")"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: updatesAVAILABLE is: $updatesAVAILABLE"
}

# Collect all available Apple software and set $minorUpdatesRECOMMENDED, $recommendedLABLES[], $minorUpdatesRESTART, majorUpgradeTARGET, $minorUpdatesDownloadREQUIRED, $majorUpgradeDownloadREQUIRED accordingly.
checkAllAvailableSoftware() {
sendToLog "Status: Checking for all available Apple software..."
sendToStatus "Running: Checking for all available Apple software..."
minorUpdatesRECOMMENDED="FALSE"
minorUpdatesRESTART="FALSE"
minorUpdatesDownloadREQUIRED="FALSE"
majorUpgradeTARGET="FALSE"
majorUpgradeDownloadREQUIRED="FALSE"

# If a previous softwareupdate check has run in the last six hours then a full update check isn't necessary.
if [[ "$fullCheckREQUIRED" != "TRUE" ]]; then
	asuCheckDATE=$(defaults read "$asuPLIST" LastSuccessfulDate 2> /dev/null)
	[[ -n $asuCheckDATE ]] && asuCheckEPOCH=$(date -j -u -f "%Y-%m-%d %H:%M:%S %z" "$asuCheckDATE" "+%s")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: asuCheckDATE is: $asuCheckDATE"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: asuCheckEPOCH is: $asuCheckEPOCH"
	if [[ $asuCheckEPOCH -gt $(($(date "+%s")-21600)) ]]; then
		sendToLog "Status: Last softwareupdate check was less than 6 hours ago."
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: $asuPLIST is:\n$(defaults read "$asuPLIST"  2> /dev/null)"
		propertyUpdatesAVAILABLE=$(defaults read "$asuPLIST" LastUpdatesAvailable 2> /dev/null)
		propertySystemUpdateAVAILABLE=$(defaults read "$asuPLIST" RecommendedUpdates 2> /dev/null | awk '/MobileSoftwareUpdate/ { print $3 }' | sed 's/;//g')
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertyUpdatesAVAILABLE is: $propertyUpdatesAVAILABLE"
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertySystemUpdateAVAILABLE is: $propertySystemUpdateAVAILABLE"
		if [[ $propertyUpdatesAVAILABLE -eq 0 ]]; then # No updates available.
			fullCheckREQUIRED="FALSE"
			updatesAVAILABLE="FALSE"
		else # Updates available. Evaluate previous update list and compare them to currently available updates, setting $fullCheckREQUIRED, $updatesRESULT, and $updatesAVAILABLE accordingly.
			previousUpdatesLIST=$(defaults read "$superPLIST" UpdatesList 2> /dev/null)
			if [[ -n $previousUpdatesLIST ]]; then
				previousUpdatesLIST=$(echo "$previousUpdatesLIST" | tail -n +2 | sed -e 's/    //g' -e 's/"//g' -e 's/",//g' -e 's/,//g' -e '$d')
				[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: previousUpdatesLIST is: \n$previousUpdatesLIST"
				propertyUpdatesLIST=$(defaults read "$asuPLIST" RecommendedUpdates | grep "Identifier" | sed -e 's/        Identifier = //g' -e 's/"//g' -e 's/;//g')
				[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertyUpdatesLIST is: \n$propertyUpdatesLIST"
				if [[ "$previousUpdatesLIST" == "$propertyUpdatesLIST" ]]; then # Previous update list matches current update list.
					updatesRESULT=$(<"$checkLOG")
					[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: $checkLOG is:\n$(cat "$checkLOG")"
					if [[ $(echo "$updatesRESULT" | grep -c 'Software Update found') -eq 0 ]] || [[ $(echo "$updatesRESULT" | grep -c 'No new software available.') -eq 1 ]]; then # Previous update list has updates but the $checkLOG does not.
						sendToLog "Status: Previously saved $checkLOG does not contain any updates, checking for Apple software updates via softwareupdate..."
						fullCheckREQUIRED="TRUE"
					else
						sendToLog "Status: Previously saved softwareudpate list matches the current list."
						fullCheckREQUIRED="FALSE"
						updatesAVAILABLE="TRUE"
					fi
				else
					sendToLog "Status: Previously saved softwareudpate list does not match the current list, checking for Apple software updates via softwareupdate..."
					kickAppleSoftwareUpdate
					fullCheckREQUIRED="TRUE"
				fi
			else # No previously saved $propertyUpdatesLIST to compare.
				sendToLog "Status: No previous update list cache, checking for Apple software updates via softwareupdate..."
				fullCheckREQUIRED="TRUE"
			fi
		fi
	else
		sendToLog "Status: Last software update check is older than 6 hours, checking for Apple software updates via softwareupdate..."
		fullCheckREQUIRED="TRUE"
	fi
	[[ "$updatesAVAILABLE" == "FALSE" ]] && sendToLog "Status: No available Apple software updates. Some may be deferred via MDM."
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: fullCheckREQUIRED is: $fullCheckREQUIRED"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: updatesAVAILABLE is: $updatesAVAILABLE"

# If a full softwareupdate check is required.
if [[ "$fullCheckREQUIRED" == "TRUE" ]]; then
	checkSoftwareUpdate
	
	# Various double-checking and validation when softwareupdate misbehaves.
	if [[ "$checkTIMEOUT" == "TRUE" ]]; then
		sendToLog "Status: Re-checking for Apple software updates via softwareupdate..."
		checkSoftwareUpdate
	elif [[ $macosMAJOR -ge 11 ]] && [[ "$updatesAVAILABLE" == "FALSE" ]]; then
		sendToLog "Status: macOS 11 or later, double-checking Apple software updates via softwareupdate..."
		kickAppleSoftwareUpdate
		sleep 10
		checkSoftwareUpdate
	fi
	if [[ "$checkTIMEOUT" == "FALSE" ]]; then
		if [[ "$updatesAVAILABLE" == "FALSE" ]]; then
			previousMinorUpdateDOWNLOADS=$(defaults read "$superPLIST" UpdateDownloads 2> /dev/null)
			previousMajorUpgradeDOWNLOAD=$(defaults read "$superPLIST" MajorUpgradeDownload 2> /dev/null)
			if [[ -n $previousMinorUpdateDOWNLOADS ]] || [[ -n $previousMajorUpgradeDOWNLOAD ]]; then
				sendToLog "Error: A system update/upgrade was previously downloaded but softwareupdate is not finding any available updates, trying again in $defaultDeferSECONDS seconds."
				sendToStatus "Pending: A system update/upgrade was previously downloaded but softwareupdate is not finding any available updates, trying again in $defaultDeferSECONDS seconds."
				kickAppleSoftwareUpdate
				makeLaunchDaemonCalendar
			else
				sendToLog "Status: No available Apple software updates. Some may be deferred via MDM."
			fi
		fi
	else
		sendToLog "Error: Checking for Apple software updates via softwareupdate timed after multiple attempts, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Checking for Apple software updates via softwareupdate timed after multiple attempts, trying again in $defaultDeferSECONDS seconds."
		makeLaunchDaemonCalendar
	fi
fi

# Get information from $asuPLIST and $checkLOG.
if [[ "$updatesAVAILABLE" == "TRUE" ]]; then
	# Extract relevant information from $asuPLIST and save to $superPLIST.
	propertyUpdatesAVAILABLE=$(defaults read "$asuPLIST" LastUpdatesAvailable 2> /dev/null)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertyUpdatesAVAILABLE is: $propertyUpdatesAVAILABLE"
	defaults delete "$superPLIST" UpdatesAvailable 2> /dev/null
	defaults write "$superPLIST" UpdatesAvailable -string "$propertyUpdatesAVAILABLE"
	
	if [[ $macosMAJOR -ge 11 ]]; then
		propertySystemUpdateAVAILABLE=$(defaults read "$asuPLIST" RecommendedUpdates 2> /dev/null | awk '/MobileSoftwareUpdate/ { print $3 }' | sed 's/;//g')
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertySystemUpdateAVAILABLE is: $propertySystemUpdateAVAILABLE"
		defaults delete "$superPLIST" SystemUpdateAvailable 2> /dev/null
		defaults write "$superPLIST" SystemUpdateAvailable -string "$propertySystemUpdateAVAILABLE"
	fi
	
	oldIFS="$IFS"; IFS=$'\n'
	propertyUpdatesARRAY=($(defaults read "$asuPLIST" RecommendedUpdates | grep "Identifier" | sed -e 's/        Identifier = //g' -e 's/"//g' -e 's/;//g'))
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertyUpdatesARRAY[] is: \n${propertyUpdatesARRAY[*]}"
	defaults delete "$superPLIST" UpdatesList 2> /dev/null
	for i in "${!propertyUpdatesARRAY[@]}"; do
		defaults write "$superPLIST" UpdatesList -array-add "${propertyUpdatesARRAY[i]}"
	done

	# Parse $updatesRESULT for individual update labels and save to $allLABLES[], $restartLABLES[], and $recommendedLABLES[].
	allLABLES=()
	allTITLES=()
	restartLABLES=()
	recommendedLABLES=()
	if [[ $macosMAJOR -ge 11 ]] || { [[ $macosMAJOR -eq 10 ]] && [[ $macosMINOR -ge 15 ]]; }; then
		allLABLES=($(echo "$updatesRESULT" | awk -F': ' '/Label:/{print $2}'))
		allTITLES=($(echo "$updatesRESULT" | awk -F',' '/Title:/ {print $1}' | cut -d ' ' -f 2-))
		restartLABLES=($(echo "$updatesRESULT" | grep -B 1 "restart" | awk -F': ' '/Label:/{print $2}'))
	else
		allLABLES=($(echo "$updatesRESULT" | awk -F'*' '/\*/{print $2}' | sed 's/^ //'))
		allTITLES=($(echo "$updatesRESULT" | awk -F'(' '/\t/ {print $1}' | cut -d $'\t' -f 2 | sed 's/.$//'))
		restartLABLES=($(echo "$updatesRESULT" | grep -B 1 "restart" | awk -F'*' '/\*/{print $2}' | sed 's/^ //'))
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: allLABLES[] is: \n${allLABLES[*]}"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: allTITLES[] is: \n${allTITLES[*]}"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: restartLABLES[] is: \n${restartLABLES[*]}"
	[[ "${allLABLES[*]}" != "${restartLABLES[*]}" ]] && recommendedLABLES=($(echo -e "${allLABLES[*]}\n${restartLABLES[*]}" | sort | uniq -u))
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: recommendedLABLES[] is: \n${recommendedLABLES[*]}"
	if [[ -n ${allLABLES[*]} ]]; then
		if [[ -n ${recommendedLABLES[*]} ]]; then
			sendToLog "Status: ${#recommendedLABLES[@]} available recommended (non-system) Apple software update(s)."
			for i in "${!recommendedLABLES[@]}"; do
				sendToLog "Status: Recommended (non-system) Apple software update $((i + 1)): ${recommendedLABLES[i]}"
			done
			minorUpdatesRECOMMENDED="TRUE"
		else
			sendToLog "Status: No available recommended (non-system) Apple software update(s). Some may be deferred via MDM."
		fi
		if [[ -n ${restartLABLES[*]} ]]; then
			sendToLog "Status: ${#restartLABLES[@]} available minor system update(s)."
			for i in "${!restartLABLES[@]}"; do
				sendToLog "Status: Minor system update $((i + 1)): ${restartLABLES[i]}"
			done
			minorUpdatesRESTART="TRUE"
		fi
		# Evaluate previously downloaded minor system updates and compare them to currently available, setting $minorUpdatesDownloadREQUIRED accordingly.
		previousMinorUpdateDOWNLOADS=$(defaults read "$superPLIST" UpdateDownloads 2> /dev/null)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: previousMinorUpdateDOWNLOADS is: \n$previousMinorUpdateDOWNLOADS"
		if [[ -n $previousMinorUpdateDOWNLOADS ]]; then
			downloadedTITLES=($(echo "$previousMinorUpdateDOWNLOADS" | grep -wv -e '(' -e ')' | sed -e 's/    //g' -e 's/"//g' -e 's/,//g'))
			[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: downloadedTITLES is: \n${downloadedTITLES[*]}"
			if [[ ! $(echo -e "${downloadedTITLES[*]}\n${allTITLES[*]}" | sort | uniq -u) ]]; then
				sendToLog "Status: Previously downloaded Apple softwareupdate title(s) match currently available updates."
			else
				sendToLog "Status: Previously downloaded Apple softwareupdate title(s) do not match currently available updates."
				minorUpdatesDownloadREQUIRED="TRUE"
				defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
				restartZeroDay
			fi
		else
			minorUpdatesDownloadREQUIRED="TRUE"
		fi
	else
		IFS="$oldIFS"
		sendToLog "Error: Unable to parse Apple softwareupdate results, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Unable to parse Apple softwareupdate results, trying again in $defaultDeferSECONDS seconds."
		makeLaunchDaemonCalendar
	fi
	IFS="$oldIFS"
else # No minor system updates, so clean-up any potential $superPLIST leftovers.
	defaults delete "$superPLIST" UpdatesAvailable 2> /dev/null
	defaults delete "$superPLIST" UpdatesList 2> /dev/null
	defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: minorUpdatesRECOMMENDED is: $minorUpdatesRECOMMENDED"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: minorUpdatesRESTART is: $minorUpdatesRESTART"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: minorUpdatesDownloadREQUIRED is: $minorUpdatesDownloadREQUIRED"

# At this point we can reliably check for major system upgrades, evaluate $targetMajorUpgradeOPTION, and set $majorUpgradeTARGET.
# First check to see if there was any previously available major upgrade information saved.
if [[ "$fullCheckREQUIRED" != "TRUE" ]]; then
	previousMajorUpgradeVERSION=$(defaults read "$superPLIST" MajorUpgradeVersion 2> /dev/null)
	previousMajorUpgradeNAME=$(defaults read "$superPLIST" MajorUpgradeName 2> /dev/null)
	if [[ -n $previousMajorUpgradeVERSION ]] && [[ -n $previousMajorUpgradeNAME ]]; then
		majorUpgradeVERSION="$previousMajorUpgradeVERSION"
		majorUpgradeNAME="$previousMajorUpgradeNAME"
		sendToLog "Status: Major system upgrade available: $majorUpgradeNAME $majorUpgradeVERSION"
	else
		fullCheckREQUIRED="TRUE"
	fi
fi
if [[ "$fullCheckREQUIRED" == "TRUE" ]]; then
	sendToLog "Status: Waiting for major system upgrade check..."
	if [[ $macosMAJOR -ge 11 ]]; then
		availableOSUPDATES=$(/usr/libexec/mdmclient AvailableOSUpdates 2> /dev/null)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: availableOSUPDATES is: $availableOSUPDATES"
		majorUpgradeNAMES=$(echo "$availableOSUPDATES" | grep "Major BundleID:" | sed -e 's/  Major BundleID:          com.apple.InstallAssistant.//' -e 's/macOS/macOS /' | sort | uniq)
	elif [[ $macosMAJOR -eq 10 ]] && [[ $macosMINOR -ge 15 ]]; then
		availableOSUPDATES=$(/usr/libexec/mdmclient AvailableOSUpdates 2> /dev/null)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: availableOSUPDATES is: $availableOSUPDATES"
		majorUpgradeNAMES=$(echo "$availableOSUPDATES" | grep -v 'Security\|Supplemental\|Installer' | grep 'HumanReadableName = "macOS' | sed -e 's/        HumanReadableName = "//' -e 's/[0-9]*//g' -e 's/\.//g' -e 's/";//' -e 's/ $//' | sort | uniq)
	else
		propertyMajorUpgradeAVAILABLE=$(defaults read "$asuPLIST" LastRecommendedMajorOSBundleIdentifier 2> /dev/null)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: propertyMajorUpgradeAVAILABLE is: $propertyMajorUpgradeAVAILABLE"
		majorUpgradeNAMES=$(echo "$propertyMajorUpgradeAVAILABLE" | sed -e 's/com.apple.InstallAssistant.//' -e 's/macOS/macOS /')
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: majorUpgradeNAMES is: $majorUpgradeNAMES"

	if [[ -n $majorUpgradeNAMES ]]; then
		if [[ $(echo "$majorUpgradeNAMES" | grep -c "Ventura") -ge 1 ]]; then
			majorUpgradeVERSION=13
			majorUpgradeNAME="macOS Ventura"
		elif [[ $(echo "$majorUpgradeNAMES" | grep -c "Monterey") -ge 1 ]]; then
			majorUpgradeVERSION=12
			majorUpgradeNAME="macOS Monterey"
		elif [[ $(echo "$majorUpgradeNAMES" | grep -c "Big Sur") -ge 1 ]]; then
			majorUpgradeVERSION=11
			majorUpgradeNAME="macOS Big Sur"
		else
			sendToLog "Warning: Unable to resolve macOS major upgrade version number based on the currently availalbe macOS major upgrade names: \n$majorUpgradeNAMES."
			majorUpgradeVERSION="FALSE"
		fi
		sendToLog "Status: Major system upgrade available: $majorUpgradeNAME $majorUpgradeVERSION"
		[[ "$majorUpgradeVERSION" != "FALSE" ]] && defaults write "$superPLIST" MajorUpgradeVersion -string "$majorUpgradeVERSION"
		[[ "$majorUpgradeVERSION" != "FALSE" ]] && defaults write "$superPLIST" MajorUpgradeName -string "$majorUpgradeNAME"
	else # No major system upgrades, so clean-up any potential $superPLIST leftovers.
		sendToLog "Status: No available major system upgrade. May be deferred via MDM."
		majorUpgradeVERSION="FALSE"
		defaults delete "$superPLIST" MajorUpgradeVersion 2> /dev/null
		defaults delete "$superPLIST" MajorUpgradeName 2> /dev/null
	fi
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: majorUpgradeVERSION is: $majorUpgradeVERSION"
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: majorUpgradeNAME is: $majorUpgradeNAME"

# If the user has selected an option to perform a major system upgrade, then resolve the appropriate target $majorUpgradeTARGET.
if [[ "$majorUpgradeWORKFLOW" != "FALSE" ]] && [[ "$majorUpgradeVERSION" != "FALSE" ]]; then
	if [[ -n $targetMajorUpgradeOPTION ]]; then
		if [[ $majorUpgradeVERSION =~ $regexMACOSMAJORVERSION ]]; then
			if [[ $targetMajorUpgradeOPTION -lt $macosMAJOR ]]; then
				sendToLog "Warning: Target macOS upgrade version of $targetMajorUpgradeOPTION is less than current macOS version of $macosMAJOR."
				majorUpgradeTARGET="FALSE"
			elif [[ $targetMajorUpgradeOPTION -eq $macosMAJOR ]]; then
				sendToLog "Status: Target macOS upgrade version of $targetMajorUpgradeOPTION is the same as current macOS version of $macosMAJOR."
				majorUpgradeTARGET="FALSE"
			else # Major upgrade target is greater than current macOS version, so this is the only time it would matter.
				if [[ $targetMajorUpgradeOPTION -gt $majorUpgradeVERSION ]]; then
					sendToLog "Warning: Requested target macOS major upgrade version of $targetMajorUpgradeOPTION is greater than the currently availalbe macOS major upgrade version of $majorUpgradeVERSION."
					majorUpgradeTARGET=$majorUpgradeVERSION
				else # Major upgrade target is greater than available macOS upgrade.
					sendToLog "Status: Targeting specific macOS major upgrade version: $targetMajorUpgradeOPTION."
					majorUpgradeTARGET=$targetMajorUpgradeOPTION
				fi
			fi
		else
			sendToLog "Warning: Unable set target macOS major upgrade version based on the currently availalbe macOS major upgrade version of $majorUpgradeVERSION."
			majorUpgradeTARGET="$majorUpgradeVERSION"
		fi
	else
		if [[ $majorUpgradeVERSION =~ $regexMACOSMAJORVERSION ]]; then
			majorUpgradeTARGET=$majorUpgradeVERSION
		else
			majorUpgradeTARGET="$majorUpgradeVERSION"
		fi
	fi
else
	majorUpgradeTARGET="FALSE"
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: majorUpgradeTARGET is: $majorUpgradeTARGET"

# Evaluate previously downloaded major system upgrade and compare it to $majorUpgradeTARGET, setting $majorUpgradeDownloadREQUIRED accordingly.
if [[ "$majorUpgradeTARGET" != "FALSE" ]]; then
	previousMajorUpgradeDOWNLOAD=$(defaults read "$superPLIST" MajorUpgradeDownload 2> /dev/null)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: previousMajorUpgradeDOWNLOAD is: \n$previousMajorUpgradeDOWNLOAD"
	if [[ -n $previousMajorUpgradeDOWNLOAD ]]; then
		if [[ $previousMajorUpgradeDOWNLOAD -eq $majorUpgradeTARGET ]]; then
			sendToLog "Status: Previously downloaded macOS major upgrade version matches current target macOS major upgrade version."
		else
			sendToLog "Status: Previously downloaded macOS major upgrade version does not match current target macOS major upgrade version."
			majorUpgradeDownloadREQUIRED="TRUE"
			defaults delete "$superPLIST" MajorUpgradeDownload 2> /dev/null
			restartZeroDay
		fi
	else
		majorUpgradeDownloadREQUIRED="TRUE"
	fi
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: majorUpgradeDownloadREQUIRED is: $majorUpgradeDownloadREQUIRED"
}

# This function checks the update status after recommended/non-restart software updates are installed.
checkAfterRecommended() {
fullCheckREQUIRED="TRUE"
checkAllAvailableSoftware
if [[ "$minorUpdatesRECOMMENDED" == "FALSE" ]]; then
	if [[ "$jamfVERSION" != "FALSE" ]]; then
		if [[ "$jamfSERVER" != "FALSE" ]]; then
			sendToLog "Status: Submitting updated inventory to Jamf Pro. Use \"--verbose-mode\" or check /var/log/jamf.log for more detail..."
			if [[ "$verboseModeOPTION" == "TRUE" ]]; then
				jamfRESULT=$("$jamfBINARY" recon -verbose 2>&1)
				sendToLog "Verbose Mode: jamfRESULT is: \n$jamfRESULT"
			else
				"$jamfBINARY" recon > /dev/null 2>&1
			fi
		else
			sendToLog "Status: Unable to submit inventory to Jamf Pro, continuing update workflow."
		fi
	else
		sendToLog "Status: All recommended (non-system) updates complete, but Jamf binary not present, continuing update workflow."
	fi
else
	sendToLog "Error: All system updates/upgrades did not complete after attempted installation, trying again in $defaultDeferSECONDS seconds."
	sendToStatus "Pending: All system updates/upgrades did not complete after attempted installation, trying again in $defaultDeferSECONDS seconds."
	defaults delete "$superPLIST" UpdatesList 2> /dev/null
	makeLaunchDaemonCalendar
fi
}

# This function checks the system upgrade/update status after a previous super system update.
checkAfterRestart() {
defaults delete "$superPLIST" UpdateValidate 2> /dev/null
fullCheckREQUIRED="TRUE"
checkAllAvailableSoftware
if [[ "$minorUpdatesRECOMMENDED" == "FALSE" ]] && [[ "$minorUpdatesRESTART" == "FALSE" ]] && [[ "$majorUpgradeTARGET" == "FALSE" ]]; then
	if [[ "$jamfVERSION" != "FALSE" ]]; then
		if [[ "$jamfSERVER" != "FALSE" ]]; then
			sendToLog "Status: Submitting updated inventory to Jamf Pro. Use \"--verbose-mode\" or check /var/log/jamf.log for more detail..."
			if [[ "$verboseModeOPTION" == "TRUE" ]]; then
				jamfRESULT=$("$jamfBINARY" recon -verbose 2>&1)
				sendToLog "Verbose Mode: jamfRESULT is: \n$jamfRESULT"
			else
				"$jamfBINARY" recon > /dev/null 2>&1
			fi
			sleep 5
			sendToLog "Status: Running Jamf Pro check-in policies. Use \"--verbose-mode\" or check /var/log/jamf.log for more detail..."
			if [[ "$verboseModeOPTION" == "TRUE" ]]; then
				jamfRESULT=$("$jamfBINARY" policy -verbose 2>&1)
				sendToLog "Verbose Mode: jamfRESULT is: \n$jamfRESULT"
			else
				"$jamfBINARY" policy > /dev/null 2>&1
			fi
		else
			sendToLog "Error: Unable to submit inventory to Jamf Pro, trying again in $defaultDeferSECONDS seconds."
			sendToStatus "Pending: Unable to submit inventory to Jamf Pro, trying again in $defaultDeferSECONDS seconds."
			makeLaunchDaemonCalendar
		fi
	else
		sendToLog "Status: All Apple software updates complete, but Jamf binary not present."
	fi
else
	sendToLog "Status: All Apple software updates did not complete after last restart, continuing update workflow."
fi
}

# MARK: *** Pre-Install Workflows ***
################################################################################

# Install only recommended (non-restart) updates via the softwareupdate command, and also save results to $superLOG, $asuLOG, and $updateLOG.
installRecommendedUpdatesASU() {
sendToLog "Status: Starting softwareupdate workflow to install recommended (non-system) Apple software updates..."
sendToStatus "Running: Starting softwareupdate workflow to install recommended (non-system) Apple software updates..."
sendToASULog "**** S.U.P.E.R.M.A.N. ASU RECOMMENDED UPDATES START ****"

# For macOS 11 or later, start log streaming for softwareupdate progress and send to $updateLOG.
if [[ $macosMAJOR -ge 11 ]]; then
	sendToLog "Status: Check $asuLOG, $updateLOG, or /var/log/install.log for more detail."
	sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU RECOMMENDED UPDATES START ****"
	log stream --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress")' >> "$updateLOG" &
	updateStreamPID=$!
else
	sendToLog "Status: Check $asuLOG or /var/log/install.log for more detail."
fi

# Loop through and install only recommended/non-restart updates.
oldIFS="$IFS"; IFS=$'\n'
for i in "${!recommendedLABLES[@]}"; do
	sendToLog "Status: Installing Apple software update $((i + 1)): ${recommendedLABLES[i]}..."
	sendToASULog "Status: Installing Apple software update $((i + 1)): ${recommendedLABLES[i]}..."
	
	# The update process is backgrounded and will be watched via a while loop later on. Also note the different requirements between macOS versions.
	if [[ $macosMAJOR -ge 12 ]]; then
			if [[ "$currentUSER" == "FALSE" ]]; then
				sudo -i softwareupdate --install "${recommendedLABLES[i]}" --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
				asuPID=$!
			else # Local user is logged in.
				launchctl asuser "$currentUID" sudo -i softwareupdate --install "${recommendedLABLES[i]}" --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
				asuPID=$!
			fi
	elif [[ $macosMAJOR -eq 11 ]]; then
		softwareupdate --install "${recommendedLABLES[i]}" --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
		asuPID=$!
	else # macOS 10.X
		softwareupdate --install "${recommendedLABLES[i]}" --force --no-scan --verbose >> "$asuLOG" 2>&1 &
		asuPID=$!
	fi
	recommendedTIMEOUT="TRUE"
	
	# Watch $asuLOG while waiting for the update workflow to complete. Note this while read loop has a timeout based on $recommendedTimeoutSECONDS.
	while read -t $recommendedTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -w 'Done with'; then
			updateRECOMMENDED=$(echo "$logLINE" | cut -c 11-)
			sendToLog "Status: Installed Apple software update: $updateRECOMMENDED."
			sendToASULog "Status: Installed Apple software update: $updateRECOMMENDED."
		elif echo "$logLINE" | grep -w 'Done.'; then
			sendToASULog "Status: Recommended software update done."
			recommendedTIMEOUT="FALSE"
			break
		fi
	done < <(tail -n 0 -F "$asuLOG")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: recommendedTIMEOUT: $recommendedTIMEOUT"
	
	# If the update workflow did not complete after $recommendedTimeoutSECONDS seconds, then clean-up and record error.
	if [[ "$recommendedTIMEOUT" == "TRUE" ]] || [[ -z $updateRECOMMENDED ]]; then
		if [[ "$recommendedTIMEOUT" == "TRUE" ]]; then 
			sendToLog "Error: Apple softwareupdate timed out after $recommendedTimeoutSECONDS seconds while trying to install Apple software update: ${recommendedLABLES[i]}"
			sendToASULog "Error: Apple softwareupdate timed out after $recommendedTimeoutSECONDS seconds while trying to install Apple software update: ${recommendedLABLES[i]}"
			updateERROR="TRUE"
		fi
		if [[ -z $updateRECOMMENDED ]]; then
			sendToLog "Error: Apple softwareupdate failed to install Apple software update: ${recommendedLABLES[i]}."
			sendToASULog "Error: Apple softwareupdate failed to install Apple software update: ${recommendedLABLES[i]}."
			updateERROR="TRUE"
		fi
		kill -9 "$asuPID" > /dev/null 2>&1
		kickAppleSoftwareUpdate
	fi
done
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: updateERROR: $updateERROR"

# Wrap-up logging.
if [[ "$updateERROR" != "TRUE" ]]; then
	sendToASULog "**** S.U.P.E.R.M.A.N. ASU RECOMMENDED UPDATES COMPLETED ****"
	if [[ $macosMAJOR -ge 11 ]]; then
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU RECOMMENDED UPDATES COMPLETED ****"
	fi
else
	sendToASULog "**** S.U.P.E.R.M.A.N. ASU RECOMMENDED UPDATES FAILURE ****"
	if [[ $macosMAJOR -ge 11 ]]; then
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU RECOMMENDED UPDATES FAILURE ****"
	fi
fi
}

# Download minor system update via softwareupdate command, and also save results to $superLOG, $asuLOG, $updateLOG, and $superPLIST.
downloadMinorSystemUpdateASU() {
sendToLog "Status: Starting download workflow of minor system update via softwareupdate command..."
sendToStatus "Running: Starting download workflow of minor system update via softwareupdate command..."
sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD START ****"

# For macOS 11 or later, start log streaming for softwareupdate progress and send to $updateLOG.
if [[ $macosMAJOR -ge 11 ]]; then
	sendToLog "Status: Check $asuLOG, $updateLOG, or /var/log/install.log for more detail."
	[[ $macosMAJOR -ge 11 ]] && kickAppleSoftwareUpdate # For macOS 11 or later restarting the softwareupdate processes helps to prevent system updates from hanging.
	sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD START ****"
	log stream --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress")' >> "$updateLOG" &
	updateStreamPID=$!
else
	sendToLog "Status: Check $asuLOG or /var/log/install.log for more detail."
fi

# The download process is backgrounded and will be watched via while loops later on. Also note the different requirements between macOS versions.
if [[ $macosMAJOR -ge 12 ]]; then
	if [[ "$macosARCH" == "arm64" ]]; then
		launchctl asuser "$currentUID" sudo -u root softwareupdate --download --all --force --no-scan --agree-to-license --user "$asuACCOUNT" --stdinpass "$asuPASSWORD" --verbose >> "$asuLOG" 2>&1 &
		asuPID=$!
	else # Intel.
		launchctl asuser "$currentUID" sudo -u root softwareupdate --download --all --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
		asuPID=$!
	fi
elif [[ $macosMAJOR -eq 11 ]]; then
	if [[ "$macosARCH" == "arm64" ]]; then
		expect -c "
		set timeout -1
		spawn softwareupdate --download --all --force --no-scan --agree-to-license --verbose >> ${asuLOG} 2>&1
		expect \"Password:\"
		send {${asuPASSWORD}}
		send \r
		expect eof
		wait
		" &
		asuPID=$!
	else # Intel.
		softwareupdate --download --all --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
		asuPID=$!
	fi
else # macOS 10.X
	softwareupdate --download --all --force --no-scan --verbose >> "$asuLOG" 2>&1 &
	asuPID=$!
fi

# For macOS 11 or later, watch $updateLOG while waiting for the download workflow to complete.
if [[ $macosMAJOR -ge 11 ]]; then
	logPROGRESS=""
	downloadTIMEOUT="TRUE"
	# Note this while read loop has a timeout based on $downloadTimeoutSECONDS.
	while read -t $downloadTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -q -w '(start): phase:DOWNLOADING_UPDATE stalled:NO'; then
			[[ "$logPROGRESS" != "Downloading" ]] && sendToLog "Status: Downloading minor system update..."
			[[ "$logPROGRESS" != "Downloading" ]] && sendToUpdateLog "Status: Downloading minor system update..."
			logPROGRESS="Downloading"
		elif echo "$logLINE" | grep -q -w '(start): phase:PREPARING_UPDATE stalled:NO'; then
			[[ "$logPROGRESS" != "Preparing" ]] && sendToLog "Status: Download complete, now preparing minor system update, should be done in a few minutes..."
			[[ "$logPROGRESS" != "Preparing" ]] && sendToUpdateLog "Status: Download complete, now preparing minor system update, should be done in a few minutes..."
			logPROGRESS="Preparing"
			downloadTIMEOUT="FALSE"
			break
		fi
	done < <(tail -n 0 -F "$updateLOG")
	
	# If the preparing process did not start after $downloadTimeoutSECONDS seconds, then clean-up and try again later.
	if [[ "$downloadTIMEOUT" == "TRUE" ]]; then
		sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
		sendToASULog "Error: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
		sendToUpdateLog "Error: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToLog "Error: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		kill -9 "$asuPID" > /dev/null 2>&1
		kickAppleSoftwareUpdate
		makeLaunchDaemonCalendar
	fi
	
	workflowTIMEOUT="TRUE"
	# Note this while read loop has a timeout based on $prepareTimeoutSECONDS.
	while read -t $prepareTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -q -w '(end): phase:PREPARED stalled:NO'; then
			kill -9 "$updateStreamPID" > /dev/null 2>&1
			sendToLog "Status: Minor system update is downloaded and prepared."
			sendToUpdateLog "Status: Minor system update is downloaded and prepared."
			workflowTIMEOUT="FALSE"
			break
		fi
	done < <(tail -n 0 -F "$updateLOG")
else # For macOS 10.x, watch $asuLOG while waiting for the download workflow to complete. Note this while read loop has a timeout based on $asuTimeoutSECONDS.
	while read -t $asuTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -w 'Downloaded'; then
			sendToLog "Status: Minor system update is downloaded and prepared."
			sendToASULog "Status: Minor system update is downloaded and prepared."
			workflowTIMEOUT="FALSE"
			break
		fi
	done < <(tail -n 0 -F "$asuLOG")
fi

# If the system download workflow completed, then collect information.
if [[ "$workflowTIMEOUT" == "FALSE" ]]; then
	[[ $macosMAJOR -ge 11 ]] && sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD COMPLETED ****"
	sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD COMPLETED ****"
	defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
	oldIFS="$IFS"; IFS=$'\n'
	for i in "${!allTITLES[@]}"; do
		sendToLog "Status: Downloaded Minor System Update $((i + 1)): ${allTITLES[i]}"
		defaults write "$superPLIST" UpdateDownloads -array-add "${allTITLES[i]}"
	done
	IFS="$oldIFS"
	minorUpdatesDownloadREQUIRED="FALSE"
else # The system download workflow timed out so clean-up and try again later.
	sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
	sendToASULog "Error: Download/preparation of minor system update via softwareupdate timed out after $asuTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
	if [[ $macosMAJOR -ge 11 ]]; then
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
		sendToUpdateLog "Error: Preparation of minor system update via softwareupdate timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToLog "Error: Preparation of minor system update via softwareupdate timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Preparation of minor system update via softwareupdate timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
	else
		sendToLog "Error: Download/preparation of minor system update via softwareupdate timed out after $asuTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Download/preparation of minor system update via softwareupdate timed out after $asuTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
	fi
	kill -9 "$asuPID" > /dev/null 2>&1
	kickAppleSoftwareUpdate
	makeLaunchDaemonCalendar
fi
}

# Download system update/upgrade via MDM push command, and also save results to $superLOG, $mdmLOG, $updateLOG, and $superPLIST.
downloadSystemMDM() {
if [[ "$majorUpgradeWORKFLOW" == "JAMF" ]]; then
	sendToLog "Status: Starting download workflow of major system upgrade via MDM push command..."
	sendToStatus "Running: Starting download workflow of major system upgrade via MDM push command..."
else # Minor system update.
	sendToLog "Status: Starting download workflow of minor system update via MDM push command..."
	sendToStatus "Running: Starting download workflow of system update via MDM push command..."
fi
sendToLog "Status: Check $mdmLOG, $updateLOG, or /var/log/install.log for more detail."

# For macOS 11 or later restarting the softwareupdate processes helps to prevent system updates/upgrades from hanging.
kickAppleSoftwareUpdate

# This pre-flights the MDM query locally and may also be useful for troubleshooting.
availableOSUPDATES=$(/usr/libexec/mdmclient AvailableOSUpdates 2> /dev/null)
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: availableOSUPDATES is: \n$availableOSUPDATES"

# Make sure we still have a valid Jamf Pro API token.
checkJamfProServerToken

# Start log streaming for MDM push acknowledgements and send to $mdmLOG.
sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD START ****"
log stream --predicate '(subsystem == "com.apple.ManagedClient") && (category == "HTTPUtil")' >> "$mdmLOG" &
mdmStreamPID=$!

# Start log streaming for softwareupdate progress and send to $updateLOG.
sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD START ****"
log stream --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress")' >> "$updateLOG" &
updateStreamPID=$!

# Send the Jamf Pro API command to download via MDM.
if [[ $jamfVERSION -ge 1038 ]]; then
	jamfAPIURL="${jamfSERVER}api/v1/macos-managed-software-updates/send-updates"
	if [[ "$majorUpgradeWORKFLOW" == "JAMF" ]]; then
		jamfJSON='{ "deviceIds": ["'${jamfProID}'"], "skipVersionVerification": false, "applyMajorUpdate": true, "updateAction": "DOWNLOAD_ONLY" }'
	else # Minor system update.
		jamfJSON='{ "deviceIds": ["'${jamfProID}'"], "skipVersionVerification": false, "applyMajorUpdate": false, "updateAction": "DOWNLOAD_ONLY" }'
	fi
	commandRESULT=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --header "Content-Type: application/json" --write-out "%{http_code}" --silent --output /dev/null --request POST --url "$jamfAPIURL" --data "$jamfJSON")
else
	sendToLog "Warning: Using legacy Jamf Pro Classic API. You should upgrade your Jamf Pro instance to 10.38 or later."
	commandRESULT=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --write-out "%{http_code}" --silent --output /dev/null --request POST --url "${jamfSERVER}JSSResource/computercommands/command/ScheduleOSUpdate/action/download/id/${jamfProID}")
fi
[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: commandRESULT is: \n$commandRESULT"

# If the Jamf Pro API command was successfully created, monitor the download progress.
if [[ $commandRESULT -eq 200 ]] || [[ $commandRESULT -eq 201 ]]; then
	sendToLog "Status: Successful MDM system download command request."
	sendBlankPush
	mdmTIMEOUT="TRUE"
	
	# Some helpfull logging while waiting for Jamf Pro's mandatory 5 minute delay. Note this while read loop has a timeout based on $mdmTimeoutSECONDS.
	while read -t $mdmTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Acknowledged(ScheduleOSUpdateScan)'; then
			sendToLog "Status: Received MDM push command \"ScheduleOSUpdateScan\", checking back after Jamf Pro's mandatory 5 minute delay..."
			mdmTIMEOUT="FALSE"
			pkill -P $$ tail
			break
		fi
	done < <(tail -n 0 -F "$mdmLOG")
	
	# Only continue workflow if it did not timeout.
	if [[ "$mdmTIMEOUT" == "FALSE" ]]; then
		timerEND=300
		while [[ $timerEND -ge 0 ]]; do
			echo -ne "Waiting for Jamf Pro's mandatory 5 minute delay: -$(date -u -r $timerEND +%M:%S)\r"
			timerEND=$((timerEND - 1))
			sleep 1
		done
		echo
		sendToLog "Status: Jamf Pro's mandatory 5 minute delay should be complete, sending Blank Push..."
		sendBlankPush
		mdmTIMEOUT="TRUE"
	
		# Watch $mdmLOG while waiting for the MDM workflow to complete. Note this while read loop has a timeout based on $mdmTimeoutSECONDS.
		while read -t $mdmTimeoutSECONDS -r logLINE ; do
			if echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Error'; then
				sendToLog "Warning: Received MDM workflow error."
			elif echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Idle\]'; then
				sendToLog "Status: Received MDM blank push."
			elif echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Acknowledged(AvailableOSUpdates)'; then
				sendToLog "Status: Received MDM push command \"AvailableOSUpdates\"."
			elif echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Acknowledged(ScheduleOSUpdate)'; then
				kill -9 "$mdmStreamPID" > /dev/null 2>&1
				sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD PUSH WORKFLOW COMPLETED ****"
				sendToLog "Status: Received MDM push command \"ScheduleOSUpdate\", download should start soon..."
				mdmTIMEOUT="FALSE"
				break
			fi
		done < <(tail -n 0 -F "$mdmLOG")
	fi
	
	# If the MDM push commands did not complete after $mdmTimeoutSECONDS seconds, then clean-up and try again later.
	if [[ "$mdmTIMEOUT" == "TRUE" ]]; then
		kill -9 "$mdmStreamPID" > /dev/null 2>&1
		sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW TIMEOUT FAILURE ****"
		sendToMDMLog "Error: Push workflow for download of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW TIMEOUT FAILURE ****"
		sendToUpdateLog "Error: Push workflow for download of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToLog "Error: Push workflow for download of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Push workflow for download of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		kickAppleSoftwareUpdate
		makeLaunchDaemonCalendar
	fi
	
	logPROGRESS=""
	downloadTIMEOUT="TRUE"
	# Note this while read loop has a timeout based on $downloadTimeoutSECONDS.
	while read -t $downloadTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -q -w '(start): phase:DOWNLOADING_UPDATE stalled:NO'; then
			[[ "$logPROGRESS" != "Downloading" ]] && sendToLog "Status: Downloading system update/upgrade..."
			logPROGRESS="Downloading"
		elif echo "$logLINE" | grep -q -w '(start): phase:PREPARING_UPDATE stalled:NO'; then
			[[ "$logPROGRESS" != "Preparing" ]] && sendToLog "Status: Download complete, now preparing system update/upgrade, should be done in a few minutes..."
			logPROGRESS="Preparing"
			downloadTIMEOUT="FALSE"
			break
		fi
	done < <(tail -n 0 -F "$updateLOG")
	
	# If the preparing process did not start after $downloadTimeoutSECONDS seconds, then clean-up and try again later.
	if [[ "$downloadTIMEOUT" == "TRUE" ]]; then
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
		sendToUpdateLog "Error: Download of system update/upgrade via MDM timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToLog "Error: Download of system update/upgrade via MDM timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Download of system update/upgrade via MDM timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		kickAppleSoftwareUpdate
		makeLaunchDaemonCalendar
	fi
	
	workflowTIMEOUT="TRUE"
	# Note this while read loop has a timeout based on $prepareTimeoutSECONDS.
	while read -t $prepareTimeoutSECONDS -r logLINE ; do
		if echo "$logLINE" | grep -q -w '(end): phase:PREPARED stalled:NO'; then
			kill -9 "$updateStreamPID" > /dev/null 2>&1
			sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD COMPLETED ****"
			sendToLog "Status: System update/upgrade is downloaded and prepared."
			workflowTIMEOUT="FALSE"
			break
		fi
	done < <(tail -n 0 -F "$updateLOG")
	
	# If the system download completed.
	if [[ "$workflowTIMEOUT" == "FALSE" ]]; then
		if [[ "$majorUpgradeWORKFLOW" == "JAMF" ]]; then
			defaults write "$superPLIST" MajorUpgradeDownload -string "$majorUpgradeTARGET"
			sendToLog "Status: Downloaded major system upgrade: $majorUpgradeNAME $majorUpgradeVERSION."
			majorUpgradeDownloadREQUIRED="FALSE"
		else # Minor system update.
			defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
			oldIFS="$IFS"; IFS=$'\n'
			for i in "${!allTITLES[@]}"; do
				sendToLog "Status: Downloaded minor system update $((i + 1)): ${allTITLES[i]}"
				defaults write "$superPLIST" UpdateDownloads -array-add "${allTITLES[i]}"
			done
			IFS="$oldIFS"
			minorUpdatesDownloadREQUIRED="FALSE"
		fi
	else # The system download workflow timed out so clean-up and try again later.
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD FAILURE ****"
		sendToUpdateLog "Error: Preparation of system update/upgrade via MDM push command timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToLog "Error: Preparation of system update/upgrade via MDM push command timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Preparation of system update/upgrade via MDM push command timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		kickAppleSoftwareUpdate
		makeLaunchDaemonCalendar
	fi
else # The MDM push workflow failed so clean-up and try again later.
	kill -9 "$mdmStreamPID" > /dev/null 2>&1
	sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW FAILURE ****"
	sendToMDMLog "Error: Failed to send MDM download request. Verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\" and \"Jamf Pro Server Actions > Send Computer Remote Command to Download and Install macOS Update\"."
	kill -9 "$updateStreamPID" > /dev/null 2>&1
	sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW FAILURE ****"
	sendToUpdateLog "Error: Failed to send MDM download request. Verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\" and \"Jamf Pro Server Actions > Send Computer Remote Command to Download and Install macOS Update\"."
	sendToLog "Error: Failed to send MDM download request. Verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\" and \"Jamf Pro Server Actions > Send Computer Remote Command to Download and Install macOS Update\"."
	sendToLog "Error: Push workflow for download of system update/upgrade via MDM failed, trying again in $defaultDeferSECONDS seconds."
	sendToStatus "Pending: Push workflow for download of system update/upgrade via MDM failed, trying again in $defaultDeferSECONDS seconds."
	kickAppleSoftwareUpdate
	makeLaunchDaemonCalendar
fi
}

# Install any optional $policyTRIGGERS.
runJamfPolicies() {
sendToLog "Status: Starting Jamf Policy triggers. Use \"--verbose-mode\" or check /var/log/jamf.log for more detail..."
sendToStatus "Running: Starting Jamf Policy triggers..."
oldIFS="$IFS"; IFS=','
read -r -a triggerARRAY <<< "$policyTRIGGERS"
for trigger in "${triggerARRAY[@]}"; do
	if [[ "$testModeOPTION" != "TRUE" ]]; then
		sendToLog "Status: Jamf Policy with Trigger \"$trigger\" is starting..."
		if [[ "$verboseModeOPTION" == "TRUE" ]]; then
			jamfRESULT=$("$jamfBINARY" policy -event "$trigger" -verbose 2>&1)
			jamfRETURN=$?
			sendToLog "Verbose Mode: jamfRESULT is: \n$jamfRESULT"
			sendToLog "Verbose Mode: jamfRETURN is: $jamfRETURN"
		else
			"$jamfBINARY" policy -event "$trigger" > /dev/null 2>&1
			jamfRETURN=$?
		fi
		if [ $jamfRETURN -ne 0 ]; then
			sendToLog "Error: Jamf Policy with Trigger \"$trigger\" failed!"; jamfERROR="TRUE"
		else
			sendToLog "Status: Jamf Policy with Trigger \"$trigger\" was successful."
		fi
	else
		sendToLog "Test Mode: Skipping Jamf Policy with Trigger: $trigger."
	fi
done
IFS="$oldIFS"
if [[ "$testModeOPTION" != "TRUE" ]]; then
	if [[ "$jamfERROR" != "TRUE" ]]; then
		sendToLog "Status: All Jamf Policies completed, deleting local policy triggers preference."
		defaults delete "$superPLIST" PolicyTriggers 2> /dev/null
	else
		sendToLog "Status: Some Jamf Policies failed, not deleting local policy triggers preference."
	fi
else
	sendToLog "Test Mode: Killing update restart notification in $testModeTimeoutSECONDS seconds..."
	sleep "$testModeTimeoutSECONDS"
	kill -9 "$notifyPID" > /dev/null 2>&1
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
	else
		killall -9 "jamfHelper" > /dev/null 2>&1
	fi
fi
}

# MARK: *** Install & Restart Workflows ***
################################################################################

# This is the install and restart workflow when a user is NOT logged in.
installRestartNoUser(){
if [[ "$minorUpdatesRESTART" == "TRUE" ]]; then # Install restart required system updates if needed.
	if [[ "$minorUpdateWORKFLOW" == "ASU" ]]; then
		[[ -n $policyTRIGGERS ]] && runJamfPolicies # If requested, run Jamf Policy Triggers before system update.
		installMinorSystemUpdateASU
	elif [[ "$majorUpgradeWORKFLOW" == "JAMF" ]] || [[ "$minorUpdateWORKFLOW" == "JAMF" ]]; then
		[[ -n $policyTRIGGERS ]] && runJamfPolicies # If requested, run Jamf Policy Triggers before system update.
		installSystemMDM
	else # Apple Silicon with no valid update credentials.
		sendToLog "Status: No valid Apple Silicon credentials and no current local user, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: No valid Apple Silicon credentials and no current local user, trying again in $defaultDeferSECONDS seconds."
		makeLaunchDaemonCalendar
	fi
else # Otherwise, this is the workflow when there are no restart required system updates.
	if [[ -n $policyTRIGGERS ]]; then # If requested then run Jamf Policy Triggers, but...
		if [[ "$skipUpdatesOPTION" == "TRUE" ]]; then # Only when in skip updates mode.
			runJamfPolicies
		else
			sendToLog "Warning: Jamf Policy Triggers only run before a restart required system update or you specify the --skip-updates option."
		fi
	fi
	if [[ "$forceRestartOPTION" == "TRUE" ]]; then # If requested, force the computer to restart.
		if [[ "$testModeOPTION" != "TRUE" ]]; then
			sendToLog "Forced Restart Mode: Restarting computer..."
			shutdown -o -r +1 &
			disown -h
		else
			sendToLog "Test Mode: Skipping forced restart."
		fi
	fi
fi
}

# This is the install and restart workflow when a user is logged in.
installRestartMain(){
if [[ "$minorUpdatesRESTART" == "TRUE" ]]; then # Install restart required system updates if needed.
	if [[ "$minorUpdateWORKFLOW" == "ASU" ]]; then
		notifyRestart
		[[ -n $policyTRIGGERS ]] && runJamfPolicies # If needed run Jamf Policy Triggers.
		installMinorSystemUpdateASU
	elif [[ "$majorUpgradeWORKFLOW" == "JAMF" ]] || [[ "$minorUpdateWORKFLOW" == "JAMF" ]]; then
		notifyPrepMDM
		[[ -n $policyTRIGGERS ]] && runJamfPolicies # If needed run Jamf Policy Triggers.
		installSystemMDM
	else # Can only encourage manual self-update if Apple Silicon with no valid update credentials.
		[[ -n $policyTRIGGERS ]] && sendToLog "Warning: Skipping Jamf Policy triggers because there are no valid Apple Silicon update credentials to ensure a proper workflow."
		notifySelfUpdate &
		disown -h
	fi
else # Otherwise, this is the workflow when there are no restart required system updates.
	notifyRestart
	if [[ -n $policyTRIGGERS ]]; then # If requested then run Jamf Policy Triggers, but...
		if [[ "$skipUpdatesOPTION" == "TRUE" ]]; then # Only when in skip updates mode.
			runJamfPolicies
		else
			sendToLog "Warning: Jamf Policy Triggers only run before a restart required system update or you specify the --skip-updates option."
		fi
	fi
	if [[ "$forceRestartOPTION" == "TRUE" ]]; then # If requested, force the computer to restart.
		if [[ "$testModeOPTION" != "TRUE" ]]; then
			sendToLog "Forced Restart Mode: Restarting computer..."
			shutdown -o -r +1 &
			disown -h
		else
			sendToLog "Test Mode: Skipping forced restart, killing restart notification in $testModeTimeoutSECONDS seconds..."
			sleep "$testModeTimeoutSECONDS"
			kill -9 "$notifyPID" > /dev/null 2>&1
			if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
				killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
			else
				killall -9 "jamfHelper" > /dev/null 2>&1
			fi
		fi
	fi
fi
}

# Install minor system update via the softwareupdate command, and also save results to $superLOG, $asuLOG, $updateLOG, and $superPLIST.
installMinorSystemUpdateASU() {
if [[ "$testModeOPTION" != "TRUE" ]]; then # Not in test mode.
	# If no $currentUSER then the sytem update was not pre-downloaded.
	if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
		sendToLog "Status: Starting download and install workflow of minor system update via softwareupdate command..."
		sendToStatus "Running: Starting download and install workflow of minor system update via softwareupdate command..."
		sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD AND UPDATE START ****"
	else
		sendToLog "Status: Starting install workflow of minor system update via softwareupdate command..."
		sendToStatus "Running: Starting install workflow of minor system update via softwareupdate command..."
		sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM UPDATE START ****"
	fi
	
	# For macOS 11 or later, start log streaming for softwareupdate progress and send to $updateLOG.
	if [[ $macosMAJOR -ge 11 ]]; then
		sendToLog "Status: Check $asuLOG, $updateLOG, or /var/log/install.log for more detail."
		kickAppleSoftwareUpdate # For macOS 11 or later restarting the softwareupdate processes helps to prevent system updates from hanging.
		[[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]] && sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD AND UPDATE START ****"
		[[ "$minorUpdatesDownloadREQUIRED" == "FALSE" ]] && sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM UPDATE START ****"
		log stream --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress")' >> "$updateLOG" &
		updateStreamPID=$!
	else
		sendToLog "Status: Check $asuLOG or /var/log/install.log for more detail."
	fi
	
	# The update process is backgrounded and will be watched via while loops later on. Also note the different requirements between macOS versions.
	if [[ $macosMAJOR -ge 12 ]]; then
		if [[ "$currentUSER" == "FALSE" ]]; then
			if [[ "$macosARCH" == "arm64" ]]; then
				sudo -u root softwareupdate --install --all --restart --force --no-scan --agree-to-license --user "$asuACCOUNT" --stdinpass "$asuPASSWORD" --verbose >> "$asuLOG" 2>&1 &
				asuPID=$!
				disown -h
			else # Intel.
				sudo -u root softwareupdate --install --all --restart --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
				asuPID=$!
				disown -h
			fi
		else # Local user is logged in.
			if [[ "$macosARCH" == "arm64" ]]; then
				launchctl asuser "$currentUID" sudo -u root softwareupdate --install --all --restart --force --no-scan --agree-to-license --user "$asuACCOUNT" --stdinpass "$asuPASSWORD" --verbose >> "$asuLOG" 2>&1 &
				asuPID=$!
				disown -h
			else # Intel.
				launchctl asuser "$currentUID" sudo -u root softwareupdate --install --all --restart --force --no-scan --agree-to-license --verbose >> "$asuLOG" 2>&1 &
				asuPID=$!
				disown -h
			fi
		fi
	elif [[ $macosMAJOR -eq 11 ]]; then
		if [[ "$macosARCH" == "arm64" ]]; then
			expect -c "
			set timeout -1
			spawn softwareupdate --install --all --restart --force --no-scan --agree-to-license --verbose >> ${asuLOG} 2>&1
			expect \"Password:\"
			send {${asuPASSWORD}}
			expect eof
			wait
			" &
			asuPID=$!
			disown -h
		else # Intel.
			softwareupdate --install --all --restart --force --no-scan --verbose >> "$asuLOG" 2>&1 &
			asuPID=$!
			disown -h
		fi
	else # macOS 10.X
		softwareupdate --install --all --restart --force --no-scan --verbose >> "$asuLOG" 2>&1 &
		asuPID=$!
		disown -h
	fi
	workflowTIMEOUT="TRUE"
	
	# For macOS 11 or later, watch $updateLOG while waiting for the download/install workflow to complete.
	if [[ $macosMAJOR -ge 11 ]]; then
		# This is the workflow if the download/prepare is still required.
		if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
			logPROGRESS=""
			downloadTIMEOUT="TRUE"
			# Note this while read loop has a timeout based on $downloadTimeoutSECONDS.
			while read -t $downloadTimeoutSECONDS -r logLINE ; do
				if echo "$logLINE" | grep -q -w '(start): phase:DOWNLOADING_UPDATE stalled:NO'; then
					[[ "$logPROGRESS" != "Downloading" ]] && sendToLog "Status: Downloading minor system update..."
					logPROGRESS="Downloading"
				elif echo "$logLINE" | grep -q -w '(start): phase:PREPARING_UPDATE stalled:NO'; then
					[[ "$logPROGRESS" != "Preparing" ]] && sendToLog "Status: Download complete, now preparing minor system update, should be done in a few minutes..."
					logPROGRESS="Preparing"
					downloadTIMEOUT="FALSE"
					break
				fi
			done < <(tail -n 0 -F "$updateLOG")
			
			# If the preparing process did not start after $downloadTimeoutSECONDS seconds, then clean-up and try again later.
			if [[ "$downloadTIMEOUT" == "TRUE" ]]; then
				kill -9 "$updateStreamPID" > /dev/null 2>&1
				sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
				sendToUpdateLog "Error: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToLog "Error: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Download of minor system update via softwareupdate timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				kickAppleSoftwareUpdate
				makeLaunchDaemonCalendar
			fi
			
			# Note this while read loop has a timeout based on $prepareTimeoutSECONDS.
			prepareTIMEOUT="TRUE"
			while read -t $prepareTimeoutSECONDS -r logLINE ; do
				if echo "$logLINE" | grep -q -w '(end): phase:PREPARED stalled:NO'; then
					kill -9 "$updateStreamPID" > /dev/null 2>&1
					sendToLog "Status: Minor system update is downloaded and prepared."
					prepareTIMEOUT="FALSE"
					break
				fi
			done < <(tail -n 0 -F "$updateLOG")
			
			# If the preparing process did not complete after $prepareTimeoutSECONDS seconds, then clean-up and try again later.
			if [[ "$prepareTIMEOUT" == "TRUE" ]]; then
				kill -9 "$updateStreamPID" > /dev/null 2>&1
				sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM PREPARE TIMEOUT FAILURE ****"
				sendToUpdateLog "Error: Preparation of minor system update via softwareupdate timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToLog "Error: Preparation of minor system update via softwareupdate timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Preparation of minor system update via softwareupdate timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				kickAppleSoftwareUpdate
				makeLaunchDaemonCalendar
			fi
		fi
		
		# This is the workflow once the download/prepare has been completed. Note this while read loop has a timeout based on $applyTimeoutSECONDS.
		while read -t $applyTimeoutSECONDS -r logLINE ; do
			if echo "$logLINE" | grep -q -w '(start): phase:APPLYING stalled:NO'; then
				kill -9 "$updateStreamPID" > /dev/null 2>&1
				sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM UPDATE COMPLETED ****"
				sendToLog "Status: Minor system update is applying, restart is imminent..."
				workflowTIMEOUT="FALSE"
				break
			fi
		done < <(tail -n 0 -F "$updateLOG")
	else # For macOS 10.x, watch $asuLOG while waiting for the download/install workflow to complete. Note this while read loop has a timeout based on $asuTimeoutSECONDS.
		while read -t $asuTimeoutSECONDS -r logLINE ; do
			[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Evaluating asu.log line: $logLINE"
			if echo "$logLINE" | grep -w 'Downloaded'; then
				sendToLog "Status: Minor system update is installing, restart is imminent..."
				sendToASULog "Status: Minor system update is installing, restart is imminent..."
				workflowTIMEOUT="FALSE"
				break
			fi
		done < <(tail -n 0 -F "$asuLOG")
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: workflowTIMEOUT: $workflowTIMEOUT"
	
	# If the minor system update workflow completed, then prepare for restart.
	if [[ "$workflowTIMEOUT" == "FALSE" ]]; then
		[[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]] && sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM DOWNLOAD AND UPDATE COMPLETED ****"
		[[ "$minorUpdatesDownloadREQUIRED" == "FALSE" ]] && sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM UPDATE COMPLETED ****"
		sendToLog "Status: Resetting update/upgrade cached settings."
		defaults write "$superPLIST" UpdateValidate -bool true
		unset recheckDeferSECONDS
		defaults delete "$superPLIST" UpdatesAvailable 2> /dev/null
		defaults delete "$superPLIST" UpdatesList 2> /dev/null
		defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
		restartZeroDay
		restartDeferralCounters
		sendToStatus "Pending: At next system startup."
		makeLaunchDaemonOnStartup
	else # The minor system update workflow timed out so clean-up and try again later.
		sendToASULog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM UPDATE TIMEOUT FAILURE ****"
		sendToASULog "Error: Minor system update via softwareupdate timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		if [[ $macosMAJOR -ge 11 ]]; then
			kill -9 "$updateStreamPID" > /dev/null 2>&1
			sendToUpdateLog "**** S.U.P.E.R.M.A.N. ASU MINOR SYSTEM UPDATE TIMEOUT FAILURE ****"
			sendToUpdateLog "Error: Minor system update via softwareupdate timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToLog "Error: Minor system update via softwareupdate timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToStatus "Pending: Minor system update via softwareupdate timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		else
			sendToLog "Error: Minor system update via softwareupdate timed out after $asuTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToStatus "Pending: Minor system update via softwareupdate timed out after $asuTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
		fi
		[[ "$currentUSER" != "FALSE" ]] && notifyFailure
		kill -9 "$asuPID" > /dev/null 2>&1
		kickAppleSoftwareUpdate
		makeLaunchDaemonCalendar
	fi
else # Test Mode workflow.
	sendToLog "Test Mode: Skipping softwareupdate install of all updates and restart."
	if [[ "$currentUSER" != "FALSE" ]]; then
		sendToLog "Test Mode: Killing update restart notification in $testModeTimeoutSECONDS seconds..."
		sleep "$testModeTimeoutSECONDS"
		sendToLog "Test Mode: Opening update failure notification..."
		notifyFailure
	fi
	# Reset various items after test system update is complete.
	restartZeroDay
	restartDeferralCounters
fi
}

# Install system update/upgrade via MDM push command, and also save results to $superLOG, $mdmLOG, $updateLOG, and $superPLIST.
installSystemMDM() {
if [[ "$testModeOPTION" != "TRUE" ]]; then # Not in test mode.
	if [[ "$majorUpgradeWORKFLOW" == "JAMF" ]]; then
		if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
			sendToLog "Status: Starting download and install workflow of major system upgrade via MDM push command..."
			sendToStatus "Running: Starting download and install workflow of major system upgrade via MDM push command..."
		else
			sendToLog "Status: Starting install workflow of major system upgrade via MDM push command..."
			sendToStatus "Running: Starting install workflow of major system upgrade via MDM push command..."
		fi
	else # Minor system update.
		if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
			sendToLog "Status: Starting download and install workflow of minor system update via MDM push command..."
			sendToStatus "Running: Starting download and install workflow of minor system update via MDM push command..."
		else
			sendToLog "Status: Starting install workflow of minor system update via MDM push command..."
			sendToStatus "Running: Starting install workflow of minor system update via MDM push command..."
		fi
	fi
	sendToLog "Status: Check $mdmLOG, $updateLOG, or /var/log/install.log for more detail."
	
	# For macOS 11 or later restarting the softwareupdate processes helps to prevent system updates from hanging.
	kickAppleSoftwareUpdate
	
	# This pre-flights the MDM query locally and may also be useful for troubleshooting.
	availableOSUPDATES=$(/usr/libexec/mdmclient AvailableOSUpdates 2> /dev/null)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: availableOSUPDATES is: $availableOSUPDATES"
	
	# Make sure we still have a valid Jamf Pro API token.
	checkJamfProServerToken
	
	# Start log streaming for MDM push acknowledgements and send to $mdmLOG.
	if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
		sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD AND UPDATE/UPGRADE START ****"
	else
		sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM UPDATE/UPGRADE START ****"
	fi
	log stream --predicate '(subsystem == "com.apple.ManagedClient") && (category == "HTTPUtil")' >> "$mdmLOG" &
	mdmStreamPID=$!
	
	# Start log streaming for softwareupdate progress and send to $updateLOG.
	if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD AND UPDATE/UPGRADE START ****"
	else
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM UPDATE/UPGRADE START ****"
	fi
	log stream --predicate '(subsystem == "com.apple.SoftwareUpdateMacController") && (eventMessage CONTAINS[c] "reported progress")' >> "$updateLOG" &
	updateStreamPID=$!
	
	
	# Send the Jamf Pro API command to update and restart via MDM.
	if [[ $jamfVERSION -ge 1038 ]]; then
		jamfAPIURL="${jamfSERVER}api/v1/macos-managed-software-updates/send-updates"
		if [[ "$majorUpgradeWORKFLOW" == "JAMF" ]]; then
			jamfJSON='{ "deviceIds": ["'${jamfProID}'"], "skipVersionVerification": false, "applyMajorUpdate": true, "updateAction": "DOWNLOAD_AND_INSTALL", "forceRestart": true }'
		else # Minor system update.
			jamfJSON='{ "deviceIds": ["'${jamfProID}'"], "skipVersionVerification": false, "applyMajorUpdate": false, "updateAction": "DOWNLOAD_AND_INSTALL", "forceRestart": true }'
		fi
		commandRESULT=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --header "Content-Type: application/json" --write-out "%{http_code}" --silent --output /dev/null --request POST --url "${jamfAPIURL}" --data "${jamfJSON}")
	else
		sendToLog "Warning: Using legacy Jamf Pro Classic API. You should upgrade your Jamf Pro instance to 10.38 or later."
		commandRESULT=$(curl --header "Authorization: Bearer ${jamfProTOKEN}" --write-out "%{http_code}" --silent --output /dev/null --request POST --url "${jamfSERVER}JSSResource/computercommands/command/ScheduleOSUpdate/action/install/id/${jamfProID}")
	fi
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Verbose Mode: Function ${FUNCNAME[0]}: commandRESULT is: \n$commandRESULT"
	
	# If the Jamf Pro API command was successfully created, monitor the update progress.
	if [[ $commandRESULT -eq 200 ]] || [[ $commandRESULT -eq 201 ]]; then
		sendToLog "Status: Successful MDM system update/upgrade command request."
		sendBlankPush
		mdmTIMEOUT="TRUE"
		
		# Some helpfull logging while waiting for Jamf Pro's mandatory 5 minute delay. Note this while read loop has a timeout based on $mdmTimeoutSECONDS.
		while read -t $mdmTimeoutSECONDS -r logLINE ; do
			if echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Acknowledged(ScheduleOSUpdateScan)'; then
				sendToLog "Status: Received MDM push command \"ScheduleOSUpdateScan\", checking back after Jamf Pro's mandatory 5 minute delay..."
				mdmTIMEOUT="FALSE"
				pkill -P $$ tail
				break
			fi
		done < <(tail -n 0 -F "$mdmLOG")
		
		# Only continue workflow if it did not timeout.
		if [[ "$mdmTIMEOUT" == "FALSE" ]]; then
			timerEND=300
			while [[ $timerEND -ge 0 ]]; do
				echo -ne "Waiting for Jamf Pro's mandatory 5 minute delay: -$(date -u -r $timerEND +%M:%S)\r"
				timerEND=$((timerEND - 1))
				sleep 1
			done
			echo
			kill -9 "$notifyPID" > /dev/null 2>&1
			if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
				killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
			else
				killall -9 "jamfHelper" > /dev/null 2>&1
			fi
			sendToLog "Status: Jamf Pro's mandatory 5 minute delay should be complete, sending Blank Push..."
			sendBlankPush
			mdmTIMEOUT="TRUE"
			[[ "$currentUSER" != "FALSE" ]] && notifyRestart
		
			# Watch $mdmLOG while waiting for the MDM workflow to complete. Note this while read loop has a timeout based on $mdmTimeoutSECONDS.
			while read -t $mdmTimeoutSECONDS -r logLINE ; do
				if echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Error'; then
					sendToLog "Warning: Received MDM workflow error."
				elif echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Idle\]'; then
					sendToLog "Status: Received MDM blank push."
				elif echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Acknowledged(AvailableOSUpdates)'; then
					sendToLog "Status: Received MDM push command \"AvailableOSUpdates\"."
				elif echo "$logLINE" | grep -q -w 'Received HTTP response (200) \[Acknowledged(ScheduleOSUpdate)'; then
					kill -9 "$mdmStreamPID" > /dev/null 2>&1
					if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
						sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD AND UPDATE/UPGRADE PUSH WORKFLOW COMPLETED ****"
						sendToLog "Status: Received MDM push command \"ScheduleOSUpdate\", download and update/upgrade should start soon..."
					else
						sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM UPDATE/UPGRADE PUSH WORKFLOW COMPLETED ****"
						sendToLog "Status: Received MDM push command \"ScheduleOSUpdate\", restart should be soon..."
					fi
					mdmTIMEOUT="FALSE"
					break
				fi
			done < <(tail -n 0 -F "$mdmLOG")
		fi
		
		# If the MDM push commands did not complete after $mdmTimeoutSECONDS seconds, then clean-up and try again later.
		if [[ "$mdmTIMEOUT" == "TRUE" ]]; then
			kill -9 "$mdmStreamPID" > /dev/null 2>&1
			sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW TIMEOUT FAILURE ****"
			sendToMDMLog "Error: Push workflow for install of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			kill -9 "$updateStreamPID" > /dev/null 2>&1
			sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW TIMEOUT FAILURE ****"
			sendToUpdateLog "Error: Push workflow for install of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToLog "Error: Push workflow for install of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToStatus "Pending: Push workflow for install of system update/upgrade via MDM timed out after $mdmTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			[[ "$currentUSER" != "FALSE" ]] && notifyFailure
			kickAppleSoftwareUpdate
			makeLaunchDaemonCalendar
		fi
		
		# This is the workflow if the download/prepare is still required.
		if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]]; then
			logPROGRESS=""
			downloadTIMEOUT="TRUE"
			# Note this while read loop has a timeout based on $downloadTimeoutSECONDS.
			while read -t $downloadTimeoutSECONDS -r logLINE ; do
				if echo "$logLINE" | grep -q -w '(start): phase:DOWNLOADING_UPDATE stalled:NO'; then
					[[ "$logPROGRESS" != "Downloading" ]] && sendToLog "Status: Downloading system update/upgrade..."
					logPROGRESS="Downloading"
				elif echo "$logLINE" | grep -q -w '(start): phase:PREPARING_UPDATE stalled:NO'; then
					[[ "$logPROGRESS" != "Preparing" ]] && sendToLog "Status: Download complete, now preparing system update/upgrade, should be done in a few minutes..."
					logPROGRESS="Preparing"
					downloadTIMEOUT="FALSE"
					break
				fi
			done < <(tail -n 0 -F "$updateLOG")
	
			# If the preparing process did not start after $downloadTimeoutSECONDS seconds, then clean-up and try again later.
			if [[ "$downloadTIMEOUT" == "TRUE" ]]; then
				kill -9 "$updateStreamPID" > /dev/null 2>&1
				sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM DOWNLOAD TIMEOUT FAILURE ****"
				sendToUpdateLog "Error: Download of system update/upgrade via MDM timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToLog "Error: Download of system update/upgrade via MDM timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Download of system update/upgrade via MDM timed out after $downloadTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				kickAppleSoftwareUpdate
				makeLaunchDaemonCalendar
			fi
			
			# Note this while read loop has a timeout based on $prepareTimeoutSECONDS.
			prepareTIMEOUT="TRUE"
			while read -t $prepareTimeoutSECONDS -r logLINE ; do
				if echo "$logLINE" | grep -q -w '(end): phase:PREPARED stalled:NO'; then
					kill -9 "$updateStreamPID" > /dev/null 2>&1
					sendToLog "Status: System update/upgrade is downloaded and prepared."
					prepareTIMEOUT="FALSE"
					break
				fi
			done < <(tail -n 0 -F "$updateLOG")
			
			# If the preparing process did not complete after $prepareTimeoutSECONDS seconds, then clean-up and try again later.
			if [[ "$prepareTIMEOUT" == "TRUE" ]]; then
				kill -9 "$updateStreamPID" > /dev/null 2>&1
				sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM PREPARE TIMEOUT FAILURE ****"
				sendToUpdateLog "Error: Preparation of system update/upgrade via mdm timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToLog "Error: Preparation of system update/upgrade via mdm timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Preparation of system update/upgrade via mdm timed out after $prepareTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
				kickAppleSoftwareUpdate
				makeLaunchDaemonCalendar
			fi
		fi
		
		workflowTIMEOUT="TRUE"
		# This is the workflow once the download/prepare has been completed. Note this while read loop has a timeout based on $applyTimeoutSECONDS.
		while read -t $applyTimeoutSECONDS -r logLINE ; do
			if echo "$logLINE" | grep -q -w '(start): phase:APPLYING stalled:NO'; then
				kill -9 "$updateStreamPID" > /dev/null 2>&1
				sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM UPDATE/UPGRADE COMPLETED ****"
				sendToLog "Status: System update/upgrade is applying, restart is imminent..."
				workflowTIMEOUT="FALSE"
				break
			fi
		done < <(tail -n 0 -F "$updateLOG")
		
		# If the system update/upgrade completed, then prepare for restart.
		if [[ "$workflowTIMEOUT" == "FALSE" ]]; then
			sendToLog "Status: Resetting update/upgrade cached settings."
			defaults write "$superPLIST" UpdateValidate -bool true
			unset recheckDeferSECONDS
			defaults delete "$superPLIST" UpdatesAvailable 2> /dev/null
			defaults delete "$superPLIST" UpdatesList 2> /dev/null
			defaults delete "$superPLIST" UpdateDownloads 2> /dev/null
			[[ "$majorUpgradeWORKFLOW" == "JAMF" ]] && defaults delete "$superPLIST" MajorUpgradeDownload 2> /dev/null
			restartZeroDay
			restartDeferralCounters
			sendToStatus "Pending: At next system startup."
			makeLaunchDaemonOnStartup
		else # The system update/upgrade workflow timed out so clean-up and try again later.
			kill -9 "$updateStreamPID" > /dev/null 2>&1
			sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM SYSTEM UPDATE/UPGRADE TIMEOUT FAILURE ****"
			sendToUpdateLog "Error: Applying update/upgrade via MDM timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToLog "Error: Applying update/upgrade via MDM timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			sendToStatus "Pending: Applying update/upgrade via MDM timed out after $applyTimeoutSECONDS seconds, trying again in $defaultDeferSECONDS seconds."
			[[ "$currentUSER" != "FALSE" ]] && notifyFailure
			kickAppleSoftwareUpdate
			makeLaunchDaemonCalendar
		fi
	else # The MDM push workflow failed so clean-up and try again later.
		kill -9 "$mdmStreamPID" > /dev/null 2>&1
		sendToMDMLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW FAILURE ****"
		sendToMDMLog "Error: Failed to send MDM install update/upgrade request. Verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\" and \"Jamf Pro Server Actions > Send Computer Remote Command to Download and Install macOS Update\"."
		kill -9 "$updateStreamPID" > /dev/null 2>&1
		sendToUpdateLog "**** S.U.P.E.R.M.A.N. MDM PUSH WORKFLOW FAILURE ****"
		sendToUpdateLog "Error: Failed to send MDM install update/upgrade request. Verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\" and \"Jamf Pro Server Actions > Send Computer Remote Command to Download and Install macOS Update\"."
		sendToLog "Error: Failed to send MDM install update/upgrade request. Verify that the Jamf Pro API account \"$jamfACCOUNT\" has the privileges \"Jamf Pro Server Objects > Computers > Create & Read\" and \"Jamf Pro Server Actions > Send Computer Remote Command to Download and Install macOS Update\"."
		sendToLog "Error: Push workflow for install of system update/upgrade via MDM failed, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Push workflow for install of system update/upgrade via MDM failed, trying again in $defaultDeferSECONDS seconds."
		[[ "$currentUSER" != "FALSE" ]] && notifyFailure
		kickAppleSoftwareUpdate
		makeLaunchDaemonCalendar
	fi
else # Test mode workflow.
	sendToLog "Test Mode: Skipping MDM update/upgrade request."
	if [[ "$currentUSER" != "FALSE" ]]; then
		sendToLog "Test Mode: Killing MDM preparation notification in $testModeTimeoutSECONDS seconds..."
		sleep "$testModeTimeoutSECONDS"
		kill -9 "$notifyPID" > /dev/null 2>&1
		if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
			killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
		else
			killall -9 "jamfHelper" > /dev/null 2>&1
		fi
		notifyRestart
		sendToLog "Test Mode: Killing update/upgrade restart notification in $testModeTimeoutSECONDS seconds..."
		sleep "$testModeTimeoutSECONDS"
		sendToLog "Test Mode: Opening update/upgrade failure notification..."
		notifyFailure
	fi
	# Reset various items after test system update is complete.
	restartZeroDay
	restartDeferralCounters
fi
}

# MARK: *** LaunchDaemons ***
################################################################################

# This unloads and deletes any previous LaunchDaemons.
removeLaunchDaemon(){
if [[ -f "/Library/LaunchDaemons/$launchDaemonNAME.plist" ]]; then
	sendToLog "Status: Removing previous LaunchDaemon $launchDaemonNAME.plist."
	launchctl bootout system "/Library/LaunchDaemons/$launchDaemonNAME.plist" 2> /dev/null
	rm -f "/Library/LaunchDaemons/$launchDaemonNAME.plist"
fi
defaults delete "$superPLIST" FailSafeActive 2> /dev/null
}

# Create a LaunchDaemon to run super-starter again right now, thus releasing any Jamf Pro Policy that may have started super.
makeLaunchDaemonRestartNow() {
removeLaunchDaemon

# This creates a LaunchDaemon.plist file.
/bin/cat <<EOLDL > "/Library/LaunchDaemons/$launchDaemonNAME.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$launchDaemonNAME</string>
	<key>LaunchOnlyOnce</key>
	<true/>
	<key>AbandonProcessGroup</key>
	<true/>
	<key>UserName</key>
	<string>root</string>
	<key>ProgramArguments</key>
	<array>
		<string>$superFOLDER/super-starter</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOLDL

[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "LaunchDaemon: $launchDaemonNAME.plist...\n$(cat "/Library/LaunchDaemons/$launchDaemonNAME.plist")"

# Set proper permissions and load the LaunchDaemon.
chmod 644 "/Library/LaunchDaemons/$launchDaemonNAME.plist"
chown root:wheel "/Library/LaunchDaemons/$launchDaemonNAME.plist"
sendToLog "Exit: LaunchDaemon $launchDaemonNAME.plist is scheduled to start right now."
sendToPending "Right Now."
launchctl bootstrap system "/Library/LaunchDaemons/$launchDaemonNAME.plist"
[[ -n "$jamfProTOKEN" ]] && deleteJamfProServerToken
rm -f "$superPIDFILE"
sendToLog "**** S.U.P.E.R.M.A.N. EXIT ****"
exit 0
}

# Create a LaunchDaemon to run super-starter again after system restart.
makeLaunchDaemonOnStartup() {
removeLaunchDaemon

# This creates a LaunchDaemon.plist file.
/bin/cat <<EOLDL > "/Library/LaunchDaemons/$launchDaemonNAME.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$launchDaemonNAME</string>
	<key>LaunchOnlyOnce</key>
	<true/>
	<key>AbandonProcessGroup</key>
	<true/>
	<key>UserName</key>
	<string>root</string>
	<key>ProgramArguments</key>
	<array>
		<string>$superFOLDER/super-starter</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOLDL

[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "LaunchDaemon: $launchDaemonNAME.plist...\n$(cat "/Library/LaunchDaemons/$launchDaemonNAME.plist")"

# Set proper permissions for the LaunchDaemon.
chmod 644 "/Library/LaunchDaemons/$launchDaemonNAME.plist"
chown root:wheel "/Library/LaunchDaemons/$launchDaemonNAME.plist"
sendToLog "Status: LaunchDaemon $launchDaemonNAME.plist is scheduled at next startup."
sendToPending "At next system startup."
}

# Create a LaunchDaemon to run super-starter again $defaultDeferSECONDS from now.
makeLaunchDaemonCalendar() {
removeLaunchDaemon

# Calculate the appropriate deferment timer for the LaunchDaemon.
deferCALC=$(($(date +%s) + defaultDeferSECONDS))
month=$(date -j -f "%s" "$deferCALC" "+%m" | xargs)
day=$(date -j -f "%s" "$deferCALC" "+%e" | xargs)
hour=$(date -j -f "%s" "$deferCALC" "+%H" | xargs)
minute=$(date -j -f "%s" "$deferCALC" "+%M" | xargs)

# This creates a LaunchDaemon.plist file.
/bin/cat <<EOLDL > "/Library/LaunchDaemons/$launchDaemonNAME.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$launchDaemonNAME</string>
	<key>LaunchOnlyOnce</key>
	<true/>
	<key>AbandonProcessGroup</key>
	<true/>
	<key>UserName</key>
	<string>root</string>
	<key>ProgramArguments</key>
	<array>
		<string>$superFOLDER/super-starter</string>
	</array>
	<key>StartCalendarInterval</key>
	<array>
		<dict>
		<key>Month</key>
		<integer>$month</integer>
		<key>Day</key>
		<integer>$day</integer>
		<key>Hour</key>
		<integer>$hour</integer>
		<key>Minute</key>
		<integer>$minute</integer>
		</dict>
	</array>
</dict>
</plist>
EOLDL

[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "LaunchDaemon: $launchDaemonNAME.plist...\n$(cat "/Library/LaunchDaemons/$launchDaemonNAME.plist")"

# Set proper permissions and load the LaunchDaemon.
chmod 644 "/Library/LaunchDaemons/$launchDaemonNAME.plist"
chown root:wheel "/Library/LaunchDaemons/$launchDaemonNAME.plist"
sendToLog "Exit: LaunchDaemon $launchDaemonNAME.plist is scheduled to start at $hour:$minute on $month/$day."
sendToPending "$(date -j -f "%s" "$deferCALC" "+%F %T" | xargs)"
launchctl bootstrap system "/Library/LaunchDaemons/$launchDaemonNAME.plist"
[[ -n "$jamfProTOKEN" ]] && deleteJamfProServerToken
rm -f "$superPIDFILE"
sendToLog "**** S.U.P.E.R.M.A.N. EXIT ****"
exit 0
}

# MARK: *** Dialogs & Notifications ***
################################################################################

# Set language strings for notifications and dialogs.
setDisplayLanguage(){
#### Langauge for the restart button in dialogs. Note that for deadline dialogs this is the default button.
restartButtonTEXT="Restart"

#### Language for the deferral button in dialogs. Note that for non-deadline dialogs this is the default button.
deferButtonTEXT="Defer"

#### Useful display variables:
# $countDISPLAY is the current number of user soft/hard deferrals.
# $countMaxDISPLAY is the maximum number of user soft/hard deferrals.
# $softDaysMAX is the maximum number of deferral days before a soft deadline.
# $hardDaysMAX is the maximum number of deferral days before a hard deadline.
# $zeroDayDISPLAY is the date:time of the zero day that is used for calculating the maximum days deferral deadlines.
# $deadlineDaysDISPLAY is the soonest date:time based on evaluating the maximum days deferral deadlines.
# $deadlineDateDISPLAY is the soonest date:time based on evaluating the maximum date deferral deadlines.
# $deadlineDISPLAY is the soonest date:time based on evaluating both the maximum date and days deferral deadlines.
# See $dateFORMAT and $timeFORMAT in the setDefaults() function to adjust how the date:time is shown.

#### Language for dialogAskForUpdate(), an interactive dialog giving the user a choice to defer the update or restart.
dialogAskForUpdateTITLE="Software Updates Require Restart"
dialogAskForUpdateDeferMenuTitleIBM="Defer software update for:" # jamfHelper does not allow for customizing the deferral menu language.
dialogAskForUpdateDeferMenuMinutesIBM="minutes"
dialogAskForUpdateDeferMenuHourIBM="hour"
dialogAskForUpdateDeferMenuHoursIBM="hours"
dialogAskForUpdateDeferMenuDayIBM="day"
dialogAskForUpdateTimeoutTEXT="Please make selection in" # jamfHelper does not allow for customizing the display timeout language.
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
dialogAskForUpdateBodyUnlimitedIBM="• No deadline date and unlimited deferrals.\n"
dialogAskForUpdateBodyUnlimitedJAMF="• No deadline date and unlimited deferrals."
dialogAskForUpdateBodyDateIBM="• Deferral available until $deadlineDISPLAY.\n"
dialogAskForUpdateBodyDateJAMF="• Deferral available until $deadlineDISPLAY."
dialogAskForUpdateBodyCountIBM="• $countDISPLAY out of $countMaxDISPLAY deferrals remaining.\n"
dialogAskForUpdateBodyCountJAMF="• $countDISPLAY out of $countMaxDISPLAY deferrals remaining."
dialogAskForUpdateBodyDateCountIBM="• Deferral available until $deadlineDISPLAY.\n\n• $countDISPLAY out of $countMaxDISPLAY deferrals remaining.\n"
dialogAskForUpdateBodyDateCountJAMF="• Deferral available until $deadlineDISPLAY.

• $countDISPLAY out of $countMaxDISPLAY deferrals remaining."

#### Language for dialogSoftDeadline(), an interactive dialog when a soft deadline has passed, giving the user only one button to continue the workflow.
dialogSoftDeadlineTITLE="Software Updates Require Restart"
dialogSoftDeadlineTimeoutTEXT="Update will automatically start in" # jamfHelper does not allow for customizing the display timeout language.
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
dialogSoftDeadlineBodyCountIBM="You have deferred the maximum number of $countMaxDISPLAY times."
dialogSoftDeadlineBodyCountJAMF="You have deferred the maximum number of $countMaxDISPLAY times."
dialogSoftDeadlineBodyDaysIBM="You have deferred the maximum number of $softDaysMAX days."
dialogSoftDeadlineBodyDaysJAMF="You have deferred the maximum number of $softDaysMAX days."
dialogSoftDeadlineBodyDateIBM="The deferrment deadline has passed:\n$deadlineDateDISPLAY."
dialogSoftDeadlineBodyDateJAMF="The deferrment deadline has passed:

$deadlineDateDISPLAY."

#### Language for notifyPrepMDM(), a non-interactive notification informing the user that the MDM update process has started.
# This is used for both non-deadline and hard deadline workflows.
notifyPrepTITLE="Software Updates Require Restart"
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
notifyPrepBodyDefaultIBM="A required software update will automatically restart this computer in about 5 minutes.\n\nDuring this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyDefaultJAMF="A required software update will automatically restart this computer in about 5 minutes.

During this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyHardCountIBM="You have deferred the maximum number of $countMaxDISPLAY times.\n\nA required software update will automatically restart this computer in about 5 minutes.\n\nDuring this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyHardCountJAMF="You have deferred the maximum number of $countMaxDISPLAY times.

A required software update will automatically restart this computer in about 5 minutes.

During this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyHardDaysIBM="You have deferred the maximum number of $hardDaysMAX days.\n\nA required software update will automatically restart this computer in about 5 minutes.\n\nDuring this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyHardDaysJAMF="You have deferred the maximum number of $hardDaysMAX days.

A required software update will automatically restart this computer in about 5 minutes.

During this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyHardDateIBM="The deferrment deadline of $deadlineDateDISPLAY has passed.\n\nA required software update will automatically restart this computer in about 5 minutes.\n\nDuring this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."
notifyPrepBodyHardDateJAMF="The deferrment deadline of $deadlineDateDISPLAY has passed.

A required software update will automatically restart this computer in about 5 minutes.

During this time you can continue to use the computer or lock the screen, but please do not restart or sleep the computer as it will prolong the update process."

#### Language for notifyFailure(), a notification informing the user that the managed update process has failed.
# This is used for all update workflows if they fail to start or timeout after a pending restart notification has been shown.
notifyFailureTITLE="Software Update Failed"
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
notifyFailureBodyIBM="The software update failed to complete.\n\nThe system will not restart right now, but you will be notified later when the software update is attempted again."
notifyFailureBodyJAMF="The software update failed to complete.

The system will not restart right now, but you will be notified later when the software update is attempted again."

#### Language for notifySelfUpdate(), a non-interactive notification informing the user that they must perform their own update.
# This is used if there is no valid system update enforcement workflow possible.
notifySelfUpdateTITLE="Software Updates Require Restart"
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
notifySelfUpdateBodyIBM="You need to update this Mac as soon as possible by clicking the \"Update Now\" or \"Restart Now\" button in Software Update."
notifySelfUpdateBodyJAMF="You need to update this Mac as soon as possible by clicking the \"Update Now\" or \"Restart Now\" button in Software Update."

#### Language for notifyRestart(), a non-interactive notification informing the user that the computer is going to restart very soon.
# This is used for all softwareupdate workflows and near the end of the MDM workflow.
# This is used for both non-deadline and hard deadline workflows.
notifyRestartTITLE="Software Updates Require Restart"
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
notifyRestartBodyDefaultIBM="This computer will automatically restart very soon.\n\nSave any open documents now."
notifyRestartBodyDefaultJAMF="This computer will automatically restart very soon.

Save any open documents now."
notifyRestartBodyHardCountIBM="You have deferred the maximum number of $countMaxDISPLAY times.\n\nThis computer will automatically restart very soon.\n\nSave any open documents now."
notifyRestartBodyHardCountJAMF="You have deferred the maximum number of $countMaxDISPLAY times.

This computer will automatically restart very soon.

Save any open documents now."
notifyRestartBodyHardDaysIBM="You have deferred the maximum number of $hardDaysMAX days.\n\nThis computer will automatically restart very soon.\n\nSave any open documents now."
notifyRestartBodyHardDaysJAMF="You have deferred the maximum number of $hardDaysMAX days.

This computer will automatically restart very soon.

Save any open documents now."
notifyRestartBodyHardDateIBM="The deferrment deadline of $deadlineDateDISPLAY has passed.\n\nThis computer will automatically restart very soon.\n\nSave any open documents now."
notifyRestartBodyHardDateJAMF="The deferrment deadline of $deadlineDateDISPLAY has passed.

This computer will automatically restart very soon.

Save any open documents now."

#### Language for notifySelfUpdate(), a non-interactive notification informing the user that they must perform their own update.
# This is used if there is no valid system update enforcement workflow possible.
notifySelfUpdateTITLE="Software Updates Require Restart"
# Note that IBM Notifier interprets "\n" as a return, while jamfHelper interprets "real" returns.
notifySelfUpdateBodyIBM="You need to update this Mac as soon as possible by clicking the \"Update Now\" or \"Restart Now\" button in Software Update."
notifySelfUpdateBodyJAMF="You need to update this Mac as soon as possible by clicking the \"Update Now\" or \"Restart Now\" button in Software Update."
}

# Open $ibmNotifierBINARY using the $ibmNotifierARRAY[] options including the handling of any $displayTimeoutSECONDS and $displayRedrawSECONDS options.
openIbmNotifier() {
unset dialogRESULT
unset dialogRETURN
if [[ -n $displayRedrawSECONDS ]]; then
	[[ -n $displayTimeoutSECONDS ]] && displayTimeoutSECONDS=$((displayTimeoutSECONDS - 1))
	while [[ -z $dialogRETURN ]] || [[ "$dialogRETURN" -eq 137 ]]; do
		{ [[ -n $displayTimeoutSECONDS ]] && [[ -z $menuDeferSECONDS ]]; } && ibmNotifierARRAY+=(-accessory_view_type timer -accessory_view_payload "$displayTimeoutTEXT %@" -timeout "$displayTimeoutSECONDS")
		{ [[ -n $displayTimeoutSECONDS ]] && [[ -n $menuDeferSECONDS ]]; } && ibmNotifierARRAY+=(-secondary_accessory_view_type timer -secondary_accessory_view_payload "$displayTimeoutTEXT %@" -timeout "$displayTimeoutSECONDS")
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "IBM Notifier.app options: ${ibmNotifierARRAY[*]}"
		(sleep "$displayRedrawSECONDS"; killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1) &
		killerPID=$!
		dialogRESULT=$("$ibmNotifierBINARY" "${ibmNotifierARRAY[@]}")
		dialogRETURN="$?"
		kill -0 "$killerPID" && kill -9 "$killerPID" > /dev/null 2>&1
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog result: $dialogRESULT"
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog return: $dialogRETURN"
		[[ -n $displayTimeoutSECONDS ]] && displayTimeoutSECONDS=$((displayTimeoutSECONDS - displayRedrawSECONDS))
	done
else
	{ [[ -n $displayTimeoutSECONDS ]] && [[ -z $menuDeferSECONDS ]]; } && ibmNotifierARRAY+=(-accessory_view_type timer -accessory_view_payload "$displayTimeoutTEXT %@" -timeout "$displayTimeoutSECONDS")
	{ [[ -n $displayTimeoutSECONDS ]] && [[ -n $menuDeferSECONDS ]]; } && ibmNotifierARRAY+=(-secondary_accessory_view_type timer -secondary_accessory_view_payload "$displayTimeoutTEXT %@" -timeout "$displayTimeoutSECONDS")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "IBM Notifier.app options: ${ibmNotifierARRAY[*]}"
	dialogRESULT=$("$ibmNotifierBINARY" "${ibmNotifierARRAY[@]}")
	dialogRETURN="$?"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog result: $dialogRESULT"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog return: $dialogRETURN"
fi
}

# Open $jamfHELPER using the $jamfHelperARRAY[] options including the handling of any $displayTimeoutSECONDS and $displayRedrawSECONDS options.
openJamfHelper() {
unset dialogRESULT
unset dialogRETURN
if [[ -n $displayRedrawSECONDS ]]; then
	[[ -n $displayTimeoutSECONDS ]] && displayTimeoutSECONDS=$((displayTimeoutSECONDS - 1))
	while [[ -z $dialogRESULT ]]; do
		[[ -n $displayTimeoutSECONDS ]] && jamfHelperARRAY+=(-timeout "$displayTimeoutSECONDS" -countdown)
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "jamfHelper options: ${jamfHelperARRAY[*]}"
		(sleep "$displayRedrawSECONDS"; killall -9 "jamfHelper" > /dev/null 2>&1) &
		killerPID=$!
		dialogRESULT=$("$jamfHELPER" "${jamfHelperARRAY[@]}")
		dialogRETURN="$?"
		kill -0 "$killerPID" && kill -9 "$killerPID" > /dev/null 2>&1
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog result: $dialogRESULT"
		[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog return: $dialogRETURN"
		[[ -n $displayTimeoutSECONDS ]] && displayTimeoutSECONDS=$((displayTimeoutSECONDS - displayRedrawSECONDS))
	done
else
	[[ -n $displayTimeoutSECONDS ]] && jamfHelperARRAY+=(-timeout "$displayTimeoutSECONDS" -countdown)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "jamfHelper options: ${jamfHelperARRAY[*]}"
	dialogRESULT=$("$jamfHELPER" "${jamfHelperARRAY[@]}")
	dialogRETURN="$?"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog result: $dialogRESULT"
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "Dialog return: $dialogRETURN"
fi
}

# Display a non-interactive notification informing the user that the MDM update process has started.
# This is used for both non-deadline and hard deadline workflows.
notifyPrepMDM() {
# The initial $ibmNotifierARRAY[] settings for the MDM update notification.
ibmNotifierARRAY=(-type popup -always_on_top -position top_right -bar_title "$notifyPrepTITLE" -icon_path "$cachedICON" -icon_width "$ibmNotifierIconSIZE" -icon_height "$ibmNotifierIconSIZE" -accessory_view_type progressbar -accessory_view_payload "/percent indeterminate")

# The initial $jamfHelperARRAY[] settings for the MDM update notification.
jamfHelperARRAY=(-windowType hud -windowPosition ur -lockHUD -title "$notifyPrepTITLE" -icon "$cachedICON" -iconSize "$jamfHelperIconSIZE")

# Variations for the main body text of the MDM update notification.
if [[ "$deadlineDateSTATUS" == "HARD" ]]; then # Hard date deadline MDM update notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Hard date deadline MDM update notification."
		ibmNotifierARRAY+=(-subtitle "$notifyPrepBodyHardDateIBM")
	else
		sendToLog "jamfHelper Notification: Hard date deadline MDM update notification."
		jamfHelperARRAY+=(-description "$notifyPrepBodyHardDateJAMF")
	fi
elif [[ "$deadlineDaysSTATUS" == "HARD" ]]; then # Hard days deadline MDM update notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Hard days deadline MDM update notification."
		ibmNotifierARRAY+=(-subtitle "$notifyPrepBodyHardDaysIBM")
	else
		sendToLog "jamfHelper Notification: Hard days deadline MDM update notification."
		jamfHelperARRAY+=(-description "$notifyPrepBodyHardDaysJAMF")
	fi
elif [[ "$deadlineCountSTATUS" == "HARD" ]]; then # Hard count deadline MDM update notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Hard count deadline MDM update notification."
		ibmNotifierARRAY+=(-subtitle "$notifyPrepBodyHardCountIBM")
	else
		sendToLog "jamfHelper Notification: Hard count deadline MDM update notification."
		jamfHelperARRAY+=(-description "$notifyPrepBodyHardCountJAMF")
	fi
else # No deadlines, this is the default MDM update notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Default MDM update notification."
		ibmNotifierARRAY+=(-subtitle "$notifyPrepBodyDefaultIBM")
	else
		sendToLog "jamfHelper: Default MDM update notification."
		jamfHelperARRAY+=(-description "$notifyPrepBodyDefaultJAMF")
	fi
fi

# Non-interactive notifications do not need a redraw or timeout.
unset displayRedrawSECONDS
unset displayTimeoutSECONDS

# Open notification in the background allowing super to continue.
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	openIbmNotifier &
	notifyPID=$!
else
	openJamfHelper &
	notifyPID=$!
fi
}

# Display a non-interactive notification informing the user that the computer going to restart soon.
# This is used for both non-deadline and hard deadline workflows.
notifyRestart() {
# Kill any previous notifications so new ones can take its place.
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
else
	killall -9 "jamfHelper" > /dev/null 2>&1
fi

# The initial $ibmNotifierARRAY[] settings for the restart notification.
ibmNotifierARRAY=(-type popup -always_on_top -position top_right -bar_title "$notifyRestartTITLE" -icon_path "$cachedICON" -icon_width "$ibmNotifierIconSIZE" -icon_height "$ibmNotifierIconSIZE" -accessory_view_type progressbar -accessory_view_payload "/percent indeterminate")

# The initial $jamfHelperARRAY[] settings for the restart notification.
jamfHelperARRAY=(-windowType hud -windowPosition ur -lockHUD -title "$notifyRestartTITLE" -icon "$cachedICON" -iconSize "$jamfHelperIconSIZE")

# Variations for the main body text of the restart notification.
if [[ "$deadlineDateSTATUS" == "HARD" ]]; then # Hard date deadline restart notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Hard date deadline restart soon notification."
		ibmNotifierARRAY+=(-subtitle "$notifyRestartBodyHardDateIBM")
	else
		sendToLog "jamfHelper Notification: Hard date deadline restart soon notification."
		jamfHelperARRAY+=(-description "$notifyRestartBodyHardDateJAMF")
	fi
elif [[ "$deadlineDaysSTATUS" == "HARD" ]]; then # Hard days deadline restart notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Hard days deadline restart soon notification."
		ibmNotifierARRAY+=(-subtitle "$notifyRestartBodyHardDaysIBM")
	else
		sendToLog "jamfHelper Notification: Hard days deadline restart soon notification."
		jamfHelperARRAY+=(-description "$notifyRestartBodyHardDaysJAMF")
	fi
elif [[ "$deadlineCountSTATUS" == "HARD" ]]; then # Hard count deadline restart notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Hard count deadline restart soon notification."
		ibmNotifierARRAY+=(-subtitle "$notifyRestartBodyHardCountIBM")
	else
		sendToLog "jamfHelper Notification: Hard count deadline restart soon notification."
		jamfHelperARRAY+=(-description "$notifyRestartBodyHardCountJAMF")
	fi
else # No deadlines, this is the default restart notification.
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		sendToLog "IBM Notifier: Default restart soon notification."
		ibmNotifierARRAY+=(-subtitle "$notifyRestartBodyDefaultIBM")
	else
		sendToLog "jamfHelper: Default restart soon notification."
		jamfHelperARRAY+=(-description "$notifyRestartBodyDefaultJAMF")
	fi
fi

# Non-interactive notifications do not need a redraw or timeout.
unset displayRedrawSECONDS
unset displayTimeoutSECONDS

# Open notification in the background allowing super to continue.
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	openIbmNotifier &
	notifyPID=$!
	disown -h
else
	openJamfHelper &
	notifyPID=$!
	disown -h
fi
}

# Display a non-interactive notification informing the user that update process has failed.
notifyFailure() {
# Kill any previous notifications so new ones can take its place.
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
else
	killall -9 "jamfHelper" > /dev/null 2>&1
fi

# This notification does not need a redraw or timeout.
unset displayRedrawSECONDS
unset displayTimeoutSECONDS

# Open notification in the background allowing super to continue.
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	sendToLog "IBM Notifier: Opening update failure notification..."
	# Create initial $ibmNotifierARRAY[] settings for the notification.
	ibmNotifierARRAY=(-type popup -always_on_top -position top_right -bar_title "$notifyFailureTITLE" -subtitle "$notifyFailureBodyIBM" -icon_path "$cachedICON" -icon_width "$ibmNotifierIconSIZE" -icon_height "$ibmNotifierIconSIZE" -main_button_label "$deferButtonTEXT")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "IBM Notifier.app options: ${ibmNotifierARRAY[*]}"
	openIbmNotifier &
	notifyPID=$!
	disown -h
else
	sendToLog "jamfHelper: Opening update failure notification..."
	# Create initial $jamfHelperARRAY[] settings for the dialog.
	jamfHelperARRAY=(-windowType hud -windowPosition ur -lockHUD -title "$notifyFailureTITLE" -description "$notifyFailureBodyJAMF" -icon "$cachedICON" -iconSize "$jamfHelperIconSIZE" -button1 "$deferButtonTEXT" -defaultButton 1)
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "jamfHelper Options: ${jamfHelperARRAY[*]}"
	openJamfHelper &
	notifyPID=$!
	disown -h
fi
}

# Open both a non-interactive notification and the Software Update System Setting/Preference in the case where there is no valid system update enforcement workflow possible.
notifySelfUpdate() {
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	sendToLog "IBM Notifier: Opening self-update notification..."
	# Create initial $ibmNotifierARRAY[] settings for the notification.
	ibmNotifierARRAY=(-type popup -always_on_top -position top_left -bar_title "$notifySelfUpdateTITLE" -icon_path "$cachedICON" -icon_width "$ibmNotifierIconSIZE" -icon_height "$ibmNotifierIconSIZE" -accessory_view_type progressbar -accessory_view_payload "/percent indeterminate")
	ibmNotifierARRAY+=(-subtitle "$notifySelfUpdateBodyIBM")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "IBM Notifier.app options: ${ibmNotifierARRAY[*]}"
else
	sendToLog "jamfHelper: Opening self-update notification..."
	# Create initial $jamfHelperARRAY[] settings for the dialog.
	jamfHelperARRAY=(-windowType hud -windowPosition ul -lockHUD -title "$notifySelfUpdateTITLE" -icon "$cachedICON" -iconSize "$jamfHelperIconSIZE")
	jamfHelperARRAY+=(-description "$notifySelfUpdateBodyJAMF")
	[[ "$verboseModeOPTION" == "TRUE" ]] && sendToLog "jamfHelper Options: ${jamfHelperARRAY[*]}"
fi
sendToStatus "Running: Notification self update..."

# Reset various items for the self update notification.
unset dialogRESULT
unset displayTimeoutSECONDS
restartZeroDay
restartDeferralCounters

# Start System Settings/Preferences and the notification.
if [[ -n $displayRedrawSECONDS ]]; then
	[[ "$testModeOPTION" == "TRUE" ]] && redrawCOUNTER=0
	[[ "$testModeOPTION" == "TRUE" ]] && sendToLog "Test Mode: Killing self-update notification after 3 attempts..."
	[[ "$testModeOPTION" != "TRUE" ]] && sendToLog "Warning: The self-update notification will re-display every $displayRedrawSECONDS seconds until the user restarts the computer."
	while [[ -z $dialogRESULT ]] && [[ redrawCOUNTER -lt 3 ]]; do
		if [[ $macosMAJOR -ge 13 ]]; then
			sudo -u "$currentUSER" open "/System/Library/PreferencePanes/SoftwareUpdate.prefPane" -a "/System/Applications/System Settings.app"
		else
			sudo -u "$currentUSER" open "/System/Library/PreferencePanes/SoftwareUpdate.prefPane" -a "/System/Applications/System Preferences.app"
		fi
		if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
			"$ibmNotifierBINARY" "${ibmNotifierARRAY[@]}" &
		else
			"$jamfHELPER" "${jamfHelperARRAY[@]}" &
		fi
		sleep "$displayRedrawSECONDS"
		[[ "$testModeOPTION" == "TRUE" ]] && redrawCOUNTER=$((redrawCOUNTER + 1))
		if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
			killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
		else
			killall -9 "jamfHelper" > /dev/null 2>&1
		fi
		killall -9 "System Preferences" > /dev/null 2>&1
	done
else
	[[ "$testModeOPTION" != "TRUE" ]] && sendToLog "Warning: The self-update notification does not close until the user restarts the computer."
	if [[ $macosMAJOR -ge 13 ]]; then
		sudo -u "$currentUSER" open "/System/Library/PreferencePanes/SoftwareUpdate.prefPane" -a "/System/Applications/System Settings.app"
	else
		sudo -u "$currentUSER" open "/System/Library/PreferencePanes/SoftwareUpdate.prefPane" -a "/System/Applications/System Preferences.app"
	fi
	if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
		"$ibmNotifierBINARY" "${ibmNotifierARRAY[@]}" &
	else
		"$jamfHELPER" "${jamfHelperARRAY[@]}" &
	fi
	if [[ "$testModeOPTION" == "TRUE" ]]; then
		sendToLog "Test Mode: Killing self-update notification in $testModeTimeoutSECONDS seconds..."
		sleep "$testModeTimeoutSECONDS"
		if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
			killall -9 "IBM Notifier" "IBM Notifier Popup" > /dev/null 2>&1
		else
			killall -9 "jamfHelper" > /dev/null 2>&1
		fi
		if [[ $macosMAJOR -ge 13 ]]; then
			killall -9 "System Settings" > /dev/null 2>&1
		else
			killall -9 "System Preferences" > /dev/null 2>&1
		fi
	fi
fi
}

# Display an interactive dialog when a soft deadline has passed, giving the user only one button to continue the workflow.
dialogSoftDeadline() {
sendToStatus "Running: Dialog soft deadline..."
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	# The initial $ibmNotifierARRAY[] settings for the soft deadline dialog.
	ibmNotifierARRAY=(-type popup -always_on_top -bar_title "$dialogSoftDeadlineTITLE" -icon_path "$cachedICON" -icon_width "$ibmNotifierIconSIZE" -icon_height "$ibmNotifierIconSIZE" -main_button_label "$restartButtonTEXT")

	# Variations for the main body text of the soft deadline dialog.
	if [[ "$deadlineDateSTATUS" == "SOFT" ]]; then
		sendToLog "IBM Notifier: soft date deadline dialog..."
		ibmNotifierARRAY+=(-subtitle "$dialogSoftDeadlineBodyDateIBM")
	elif [[ "$deadlineDaysSTATUS" == "SOFT" ]]; then
		sendToLog "IBM Notifier: soft days deadline dialog..."
		ibmNotifierARRAY+=(-subtitle "$dialogSoftDeadlineBodyDaysIBM")
	elif [[ "$deadlineCountSTATUS" == "SOFT" ]]; then
		sendToLog "IBM Notifier: soft count deadline dialog..."
		ibmNotifierARRAY+=(-subtitle "$dialogSoftDeadlineBodyCountIBM")
	fi
	displayTimeoutTEXT="$dialogSoftDeadlineTimeoutTEXT"
	
	# Start the dialog.
	openIbmNotifier

	# The $dialogRETURN contains the IBM Notifier.app return code.
	case "$dialogRETURN" in
		0)
			sendToLog "Status: User chose to restart."
		;;
		255)
			sendToLog "Status: Display timeout automatically chose to restart."
		;;
	esac
else
	# The initial $jamfHelperARRAY[] settings for the soft deadline dialog.
	jamfHelperARRAY=(-windowType utility -title "$dialogSoftDeadlineTITLE" -icon "$cachedICON" -iconSize "$jamfHelperIconSIZE" -button1 "$restartButtonTEXT" -defaultButton 1)

	# Variations for the main body text of the soft deadline dialog
	if [[ "$deadlineDateSTATUS" == "SOFT" ]]; then
		sendToLog "jamfHelper: soft date deadline dialog..."
		jamfHelperARRAY+=(-description "$dialogSoftDeadlineBodyDateJAMF")
	elif [[ "$deadlineDaysSTATUS" == "SOFT" ]]; then
		sendToLog "jamfHelper: soft days deadline dialog..."
		jamfHelperARRAY+=(-description "$dialogSoftDeadlineBodyDaysJAMF")
	elif [[ "$deadlineCountSTATUS" == "SOFT" ]]; then
		sendToLog "jamfHelper soft count deadline dialog..."
		jamfHelperARRAY+=(-description "$dialogSoftDeadlineBodyCountJAMF")
	fi

	# Start the dialog.
	openJamfHelper
	sendToLog "Status: User or display timeout accepted soft deadline dialog."
fi
}

# Generate the $jamfHelperARRAY[] to display an interactive dialog with deferral options. This sets $choiceINSTALL and if $menuDeferSECONDS then also sets $defaultDeferSECONDS.
dialogAskForUpdate() {
sendToStatus "Running: Dialog ask for update..."
if [[ "$ibmNotifierVALID" == "TRUE" ]] && [[ "$preferJamfHelperOPTION" != "TRUE" ]]; then
	sendToLog "IBM Notifier: Ask for restart or defer dialog..."
	# Create initial $ibmNotifierARRAY[] settings for the dialog.
	ibmNotifierARRAY=(-type popup -always_on_top -bar_title "$dialogAskForUpdateTITLE" -icon_path "$cachedICON" -icon_width "$ibmNotifierIconSIZE" -icon_height "$ibmNotifierIconSIZE" -main_button_label "$deferButtonTEXT" -secondary_button_label "$restartButtonTEXT")

	# Body text variations based on deadline options.
	if [[ -n "$deadlineDISPLAY" ]] && [[ -n "$countDISPLAY" ]]; then # Show both date and maximum deferral count deadlines.
		ibmNotifierARRAY+=(-subtitle "$dialogAskForUpdateBodyDateCountIBM")
	elif [[ -n "$deadlineDISPLAY" ]]; then # Show only date deadline.
		ibmNotifierARRAY+=(-subtitle "$dialogAskForUpdateBodyDateIBM")
	elif [[ -n "$countDISPLAY" ]]; then # Show only maximum deferral count deadline.
		ibmNotifierARRAY+=(-subtitle "$dialogAskForUpdateBodyCountIBM")
	else # Show no deadlines.
		ibmNotifierARRAY+=(-subtitle "$dialogAskForUpdateBodyUnlimitedIBM")
	fi
	displayTimeoutTEXT="$dialogAskForUpdateTimeoutTEXT"
	
	# If needed, add the $menuDeferSECONDS option to the $ibmNotifierARRAY[].
	if [[ -n $menuDeferSECONDS ]]; then
		oldIFS="$IFS"; IFS=','
		read -r -a menuDeferSecondsARRAY <<< "$menuDeferSECONDS"
		read -r -a menuDeferDisplayARRAY <<< "$menuDeferSECONDS"
		for i in "${!menuDeferDisplayARRAY[@]}"; do
			if [[ ${menuDeferDisplayARRAY[i]} -lt 3600 ]]; then
				menuDeferDisplayARRAY[i]="$((menuDeferDisplayARRAY[i] / 60)) $dialogAskForUpdateDeferMenuMinutesIBM"
			elif [[ ${menuDeferDisplayARRAY[i]} -eq 3600 ]]; then
				menuDeferDisplayARRAY[i]="1 $dialogAskForUpdateDeferMenuHourIBM"
			elif [[ ${menuDeferDisplayARRAY[i]} -gt 3600 ]] && [[ ${menuDeferDisplayARRAY[i]} -lt 7200 ]]; then
				menuDeferDisplayARRAY[i]="1 $dialogAskForUpdateDeferMenuHourIBM $((menuDeferDisplayARRAY[i] % 3600 / 60)) $dialogAskForUpdateDeferMenuMinutesIBM"
			elif [[ ${menuDeferDisplayARRAY[i]} -ge 7200 ]] && [[ ${menuDeferDisplayARRAY[i]} -lt 86400 ]] && [[ $((menuDeferDisplayARRAY[i] % 3600)) -eq 0 ]]; then
				menuDeferDisplayARRAY[i]="$((menuDeferDisplayARRAY[i] / 3600)) $dialogAskForUpdateDeferMenuHoursIBM"
			elif [[ ${menuDeferDisplayARRAY[i]} -gt 7200 ]] && [[ ${menuDeferDisplayARRAY[i]} -lt 86400 ]] && [[ $((menuDeferDisplayARRAY[i] % 3600)) -ne 0 ]]; then
				menuDeferDisplayARRAY[i]="$((menuDeferDisplayARRAY[i] / 3600)) $dialogAskForUpdateDeferMenuHoursIBM $((menuDeferDisplayARRAY[i] % 3600 / 60)) $dialogAskForUpdateDeferMenuMinutesIBM"
			elif [[ ${menuDeferDisplayARRAY[i]} -eq 86400 ]]; then
				menuDeferDisplayARRAY[i]="1 $dialogAskForUpdateDeferMenuDayIBM"
			fi
		done
		IFS=$'\n'
		menuDisplayTEXT="${menuDeferDisplayARRAY[*]}"
		IFS="$oldIFS"
		ibmNotifierARRAY+=(-accessory_view_type dropdown -accessory_view_payload "/title $dialogAskForUpdateDeferMenuTitleIBM /list $menuDisplayTEXT /selected 0")
	fi

	# Start the dialog.
	openIbmNotifier

	# The $dialogRETURN contains the IBM Notifier.app return code. If $menuDeferSECONDS was enabled then set $defaultDeferSECONDS.
	case "$dialogRETURN" in
		0)
			choiceINSTALL="FALSE"
			if [[ -n $menuDeferSECONDS ]]; then
				defaultDeferSECONDS="${menuDeferSecondsARRAY[$dialogRESULT]}"
				sendToLog "Status: User chose to defer update for $defaultDeferSECONDS seconds."
				sendToStatus "Pending: User chose to defer update for $defaultDeferSECONDS seconds."
			else
				sendToLog "Status: User chose to defer update, using the default defer of $defaultDeferSECONDS seconds."
				sendToStatus "Pending: User chose to defer update, using the default defer of $defaultDeferSECONDS seconds."
			fi
		;;
		255)
			choiceINSTALL="FALSE"
			if [[ -n $menuDeferSECONDS ]]; then
				defaultDeferSECONDS="${menuDeferSecondsARRAY[$dialogRESULT]}"
				sendToLog "Status: Display timeout automatically chose to defer update for $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Display timeout automatically chose to defer update for $defaultDeferSECONDS seconds."
			else
				sendToLog "Status: Display timeout automatically chose to defer update, using the default defer of $defaultDeferSECONDS seconds."
				sendToStatus "Pending: Display timeout automatically chose to defer update, using the default defer of $defaultDeferSECONDS seconds."
			fi
		;;
		2)
			sendToLog "Status: User chose to restart now."
			choiceINSTALL="TRUE"
		;;
	esac
else
	sendToLog "jamfHelper: Ask for restart or defer dialog..."
	# Create initial $jamfHelperARRAY[] settings for the dialog.
	jamfHelperARRAY=(-windowType utility -title "$dialogAskForUpdateTITLE" -icon "$cachedICON" -iconSize "$jamfHelperIconSIZE" -button1 "$deferButtonTEXT" -button2 "$restartButtonTEXT" -defaultButton 1 -cancelButton 2)

	# Body text variations based on deadline options. Note that any invisible characters (tabs and new line) are "shown" in the jamfHelper dialog.
	if [[ -n "$deadlineDISPLAY" ]] && [[ -n "$countDISPLAY" ]]; then # Show both date and maximum deferral count deadlines.
		jamfHelperARRAY+=(-description "$dialogAskForUpdateBodyDateCountJAMF")
	elif [[ -n "$deadlineDISPLAY" ]]; then # Show only date deadline.
		jamfHelperARRAY+=(-description "$dialogAskForUpdateBodyDateJAMF")
	elif [[ -n "$countDISPLAY" ]]; then # Show only maximum deferral count deadline.
		jamfHelperARRAY+=(-description "$dialogAskForUpdateBodyCountJAMF")
	else # Show no deadlines.
		jamfHelperARRAY+=(-description "$dialogAskForUpdateBodyUnlimitedJAMF")
	fi

	# If needed, add the $menuDeferSECONDS option to the $jamfHelperARRAY[].
	if [[ -n $menuDeferSECONDS ]]; then
		menuDeferSECONDS=$(echo "$menuDeferSECONDS" | sed 's/,/, /g')
		jamfHelperARRAY+=(-showDelayOptions "$menuDeferSECONDS")
	fi

	# Start the dialog.
	openJamfHelper

	# The $dialogRESULT contains the user's selection; "0" or "1" for deferral and "2" for restart. If $menuDeferSECONDS was enabled then set $defaultDeferSECONDS.
	case "$dialogRESULT" in
		0 | 1 | *1)
			choiceINSTALL="FALSE"
			if [[ -n $menuDeferSECONDS ]]; then
				defaultDeferSECONDS=$(echo "$dialogRESULT" | sed 's/.$//')
				sendToLog "Status: User or display timeout chose to defer update for $defaultDeferSECONDS seconds."
			else
				sendToLog "Status: User or display timeout chose to defer update, using the default defer of $defaultDeferSECONDS seconds."
			fi
		;;
		*2)
			sendToLog "Status: User chose to restart now."
			choiceINSTALL="TRUE"
		;;
	esac
fi
}

# MARK: *** Main Workflow ***
################################################################################

mainWorkflow(){
# Initial super workflow preparations.
checkRoot
setDefaults
superInstaller
getOptions "$@"
getPreferences
superStarter "$@"
sendToLog "**** S.U.P.E.R.M.A.N. STARTER COMPLETED ****"
sendToStatus "Running: Main workflow..."

# If requested then restart counters.
[[ "$restartDAYS" == "TRUE" ]] && restartZeroDay
[[ "$restartCOUNTS" == "TRUE" ]] && restartDeferralCounters

# Check for available updates and upgrades. This sets $minorUpdatesRECOMMENDED, $minorUpdatesRESTART, $minorUpdatesDownloadREQUIRED, and $majorUpgradeTARGET.
if [[ "$updateVALIDATE" == "TRUE" ]]; then # Checking after previous super system update, if successful, submit inventory to Jamf and check for Jamf Policies.
	sendToLog "Status: System update/upgrade restart validation workflow enabled."
	sendToStatus "Running: System update/upgrade restart validation workflow enabled."
	checkAfterRestart
else # Default super workflow.
	if [[ "$testModeOPTION" == "TRUE" ]]; then # Test mode...
		if [[ "$skipUpdatesOPTION" == "TRUE" ]]; then
			if [[ "$forceRestartOPTION" != "TRUE" ]] && [[ -z $policyTRIGGERS ]]; then
				sendToLog "Test Mode and Skip Update Mode: You need to also use \"--force-restart\" or \"--policy-triggers\" to simulate notification and dialog workflows."
			fi
		else
			sendToLog "Test Mode: Simulating that restart required system updates are available."
			minorUpdatesRESTART="TRUE"
		fi
	elif [[ "$skipUpdatesOPTION" == "TRUE" ]]; then # Skip updates mode...
		sendToLog "Skip Update Mode: Not checking for Apple software updates."
		minorUpdatesRECOMMENDED="FALSE"
		minorUpdatesRESTART="FALSE"
		minorUpdatesDownloadREQUIRED="FALSE"
		majorUpgradeVERSION="FALSE"
		majorUpgradeNAME="FALSE"
		majorUpgradeTARGET="FALSE"
		majorUpgradeDownloadREQUIRED="FALSE"
	else # Not $testModeOPTION, $skipUpdatesOPTION, or $updateVALIDATE, so it's time for the regular softwareupdate check.
		checkAllAvailableSoftware
	fi
fi

# Start upgrade or update workflow.
if [[ "$majorUpgradeTARGET" != "FALSE" ]]; then
	[[ "$majorUpgradeWORKFLOW" == "JAMF" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MAJOR UPGRADE MACOS $majorUpgradeTARGET MDM PUSH ****"
	[[ "$majorUpgradeWORKFLOW" == "APP" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MAJOR UPGRADE MACOS $majorUpgradeTARGET INSTALLER ****"
	[[ "$majorUpgradeWORKFLOW" == "USER" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MAJOR UPGRADE MACOS $majorUpgradeTARGET USER REQUEST ****"
elif [[ "$minorUpdatesRESTART" == "TRUE" ]]; then
	[[ "$minorUpdateWORKFLOW" == "JAMF" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MINOR UPDATE MACOS MDM PUSH ****"
	[[ "$minorUpdateWORKFLOW" == "ASU" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MINOR UPDATE MACOS ASU ****"
	[[ "$minorUpdateWORKFLOW" == "APP" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MINOR UPDATE MACOS INSTALLER ****"
	[[ "$minorUpdateWORKFLOW" == "USER" ]] && sendToLog "**** S.U.P.E.R.M.A.N. MINOR UPDATE MACOS USER REQUEST ****"
elif [[ "$minorUpdatesRECOMMENDED" == "TRUE" ]]; then
	sendToLog "**** S.U.P.E.R.M.A.N. MINOR UPDATES ONLY ASU ****"
else
	sendToLog "Status: No Apple software updates/upgrades available. Some may be deferred via MDM."
	# Clean up any leftover deferral counters.
	defaults delete "$superPLIST" ZeroDayAuto 2> /dev/null
	defaults delete "$superPLIST" FocusCounter 2> /dev/null
	defaults delete "$superPLIST" SoftCounter 2> /dev/null
	defaults delete "$superPLIST" HardCounter 2> /dev/null
fi

# If non-restart required "recommended" Apple software updates are available, then install all available recommended (non-system) updates.
if [[ "$minorUpdatesRECOMMENDED" == "TRUE" ]]; then
	installRecommendedUpdatesASU
	if [[ "$updateERROR" != "TRUE" ]]; then # If all recommended (non-system) updates are successful, check Apple softwareupdate again and continue workflow.
		sendToLog "Status: Completed install of all recommended (non-system) updates."
		checkAfterRecommended
	else
		sendToLog "Error: Apple softwareupdate failed to install all recommended (non-system) updates, trying again in $defaultDeferSECONDS seconds."
		sendToStatus "Pending: Apple softwareupdate failed to install all recommended (non-system) updates, trying again in $defaultDeferSECONDS seconds."
		makeLaunchDaemonCalendar
	fi
fi

# This is the main logic for determining what to do in the case of available restart required system updates, $policyTRIGGERS, or the $forceRestartOPTION.
if [[ "$majorUpgradeTARGET" != "FALSE" ]] || [[ "$minorUpdatesRESTART" == "TRUE" ]] || [[ -n $policyTRIGGERS ]] || [[ "$forceRestartOPTION" == "TRUE" ]]; then
	checkCurrentUser # Checking the user again because it may have been quite a while since the workflow started (due to earlier installations).
	if [[ "$currentUSER" == "FALSE" ]]; then # A normal user is not logged in, start installation immediately.
		installRestartNoUser
	else # A normal user is currently logged in.
		if [[ "$testModeOPTION" != "TRUE" ]]; then # Not in test mode.
			if [[ "$minorUpdatesDownloadREQUIRED" == "TRUE" ]] || [[ "$majorUpgradeDownloadREQUIRED" == "TRUE" ]]; then # Updates/upgrade has not been downloaded yet.
				if [[ "$minorUpdateWORKFLOW" == "ASU" ]]; then
					downloadMinorSystemUpdateASU
				elif [[ "$majorUpgradeWORKFLOW" == "JAMF" ]] || [[ "$minorUpdateWORKFLOW" == "JAMF" ]]; then
					downloadSystemMDM
				else
					sendToLog "Status: Self-update workflow, unable to automatically download system updates."
				fi
			else # Updates were previously downloaded.
				sendToLog "Status: Previously downloaded ${#downloadedTITLES[@]} software update(s)."
				for i in "${!downloadedTITLES[@]}"; do
					sendToLog "Previous Download $((i + 1)): ${downloadedTITLES[i]}"
				done
			fi
		else
			sendToLog "Test Mode: Skipping download of restart required system update."
		fi
		checkZeroDay # This may need to start the automatic day zero date, so it always runs first.
		checkDateDeadlines
		checkDaysDeadlines
		# User Focus only needs to be checked if there are no date or day deadlines.
		if [[ "$deadlineDateSTATUS" == "FALSE" ]] && [[ "$deadlineDaysSTATUS" == "FALSE" ]]; then
			checkUserFocus
		else # At this point any date or days deadline would rule out any $focusDEFER option.
			focusDEFER="FALSE"
		fi
		checkCountDeadlines
		setDisplayLanguage
		if [[ "$deadlineDateSTATUS" == "HARD" ]] || [[ "$deadlineDaysSTATUS" == "HARD" ]] || [[ "$deadlineCountSTATUS" == "HARD" ]]; then # A hard deadline has passed, similar to no logged in user but with a notification.
			installRestartMain
		elif [[ "$deadlineDateSTATUS" == "SOFT" ]] || [[ "$deadlineDaysSTATUS" == "SOFT" ]] || [[ "$deadlineCountSTATUS" == "SOFT" ]]; then # A soft deadline has passed.
			dialogSoftDeadline
			installRestartMain
		elif [[ "$focusDEFER" == "TRUE" ]]; then # No deadlines have passed but a process has told the display to not sleep or the user has enabled Focus or Do Not Disturb.
			defaultDeferSECONDS="$focusDeferSECONDS"
			sendToStatus "Pending: Automatic user focus deferral, trying again in $defaultDeferSECONDS seconds."
			makeLaunchDaemonCalendar
		else # Logically, this is the only time the choice dialog is shown.
			dialogAskForUpdate
			if [[ "$choiceINSTALL" == "TRUE" ]]; then
				installRestartMain
			else
				sendToStatus "Pending: User chose to defer, trying again in $defaultDeferSECONDS seconds."
				makeLaunchDaemonCalendar
			fi
		fi
	fi
fi

# Logically, at this point there are no minor system updates and no enabled major system upgrades, so check for $recheckDeferSECONDS.
if [[ $(defaults read "$superPLIST" UpdateValidate 2> /dev/null) ]]; then
	sendToLog "Exit: System update/upgrade restart is imminent, super is scheduled to run at next startup."
	sendToStatus "Pending: System update/upgrade restart is imminent, super is scheduled to run at next startup."
elif [[ -n "$recheckDeferSECONDS" ]]; then
	if [[ "$majorUpgradeVERSION" != "FALSE" ]]; then
		sendToLog "Status: A major system upgrade is available but not enabled. Recheck deferral should restart super in $recheckDeferSECONDS seconds."
		sendToStatus "Inactive: A major system upgrade is available but not enabled. Recheck deferral should restart super in $recheckDeferSECONDS seconds."
	else
		sendToLog "Status: No available system updates/upgrades. Recheck deferral should restart super in $recheckDeferSECONDS seconds."
		sendToStatus "Pending: No available system updates/upgrades. Recheck deferral should restart super in $recheckDeferSECONDS seconds."
	fi
	defaultDeferSECONDS="$recheckDeferSECONDS"
	makeLaunchDaemonCalendar
else
	if [[ "$majorUpgradeVERSION" != "FALSE" ]]; then
		sendToLog "Status: A major system upgrade is available but not enabled, and no available minor system updates, and --recheck-defer is inactive."
		sendToStatus "Inactive: A major system upgrade is available but not enabled, and no available minor system updates, and --recheck-defer is inactive."
	else
		sendToLog "Status: Recheck deferral is inactive."
		sendToStatus "Inactive: Recheck deferral is inactive."
	fi
	sendToPending "Inactive."
	removeLaunchDaemon
fi
}

mainWorkflow "$@"
rm -f "$superPIDFILE"
[[ -n "$jamfProTOKEN" ]] && deleteJamfProServerToken
sendToLog "**** S.U.P.E.R.M.A.N. EXIT ****"
exit 0