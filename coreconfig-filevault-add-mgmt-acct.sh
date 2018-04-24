#!/bin/bash

###
#
#            Name:  FileVaultEnableAdminAccount.sh
#     Description:  This script is intended to run on Macs which need a
#                   local admin account added as a FileVault enabled user.
#         Credits:  https://github.com/homebysix
#                   https://github.com/ToplessBanana
#                   https://github.com/brysontyrrell
#                   https://www.jamf.com/jamf-nation/articles/146
#       Tested On:  macOS 10.13, 10.12, 10.11
#         Created:  2018-03-21
#   Last Modified:  2018-04-20
#         Version:  1.7.3
#
###


################################## VARIABLES ##################################

# Company logo. (Tested with PNG, JPG, GIF, PDF, and AI formats.)
LOGO="/usr/local/jamf/UoELogo.png"

# The title of the message that will be displayed to the user.
# Not too long, or it'll get clipped.
PROMPT_TITLE="FileVault Update Required"

# The body of the message that will be displayed before prompting the user for
# their password. All message strings below can be multiple lines.
PROMPT_MESSAGE="The Mac Supported Desktop requires access to the FileVault encryption on this computer to back up its encryption key. 

Select \"Next\" and enter the password of an account which can unlock FileVault (this may be your own logon password).

Our use of this password is secure, and used only to safely gather the FileVault key. The password you type is not stored in any way. 

If you are unsure how to proceed, or want more information, contact the IS Helpline on 0131 6515151 or via https://www.ed.ac.uk/is/helpline, advising that you are receiving this message.

David Savage
IS ITI Desktop Services
Information Services
University of Edinburgh"

# The body of the message that will be displayed after 5 incorrect passwords.
FORGOT_PW_MESSAGE="Please contact the IS Helpline for assistance."

# The detail of the message that will be displayed after successful completion.
PROMPT_SUCCESS="FileVault Update Succesful"
SUCCESS_MESSAGE="Thank you! Your Mac's FileVault settings have successfully been updated."

# The body of the message that will be displayed if a failure occurs.
FAIL_MESSAGE="Error"

# Specify the admin or management account that you want FileVault-enabled.
ADMIN_USER_ENCRYPTED="$4"
ADMIN_PASS_ENCRYPTED="$5"
SALT="$6"
PASSPHRASE="$7"

################################## FUNCTIONS ##################################

# Decrypts admin username and password
function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "$SALT" -k "$PASSPHRASE"
}

# Enables SecureToken for the admin account.
enableSecureToken() {
    sysadminctl -adminUser $CURRENT_USER -adminPassword $USER_PASS -secureTokenOn $ADMIN_USER -password $ADMIN_PASS
}

# Creates a PLIST containing the necessary administrator and user credentials.
createPlist() {
    echo '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>Username</key>
    <string>'$CURRENT_USER'</string>
    <key>Password</key>
    <string>'$USER_PASS'</string>
    <key>AdditionalUsers</key>
    <array>
        <dict>
            <key>Username</key>
            <string>'$ADMIN_USER'</string>
            <key>Password</key>
            <string>'$ADMIN_PASS'</string>
        </dict>
    </array>
    </dict>
    </plist>' > /private/tmp/userToAdd.plist
}

# Adds the admin account user to the list of FileVault enabled users.
addUser() {
    sudo fdesetup add -i < /private/tmp/userToAdd.plist
}

# Update the preboot role volume's subject directory.
updatePreboot() {
    diskutil apfs updatePreboot /
}

# Deletes the PLIST containing the administrator and user credentials.
cleanUp() {
    rm /private/tmp/userToAdd.plist
    unset USER_PASS
}

######################## VALIDATION AND ERROR CHECKING ########################

# Suppress errors for the duration of this script. (This prevents JAMF Pro from
# marking a policy as "failed" if the words "fail" or "error" inadvertently
# appear in the script output.)
exec 2>/dev/null

BAILOUT=false

# Make sure we have root privileges (for fdesetup).
if [[ $EUID -ne 0 ]]; then
    REASON="This script must run as root."
    BAILOUT=true
fi

# Check for remote users.
REMOTE_USERS=$(/usr/bin/who | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | wc -l)
if [[ $REMOTE_USERS -gt 0 ]]; then
    REASON="Remote users are logged in."
    BAILOUT=true
fi

# Make sure the custom logo file is present.
if [[ ! -f "$LOGO" ]]; then
    REASON="Custom logo not present: $LOGO"
    BAILOUT=true
fi

# Convert POSIX path of logo icon to Mac path for AppleScript
LOGO_POSIX="$(/usr/bin/osascript -e 'tell application "System Events" to return POSIX file "'"$LOGO"'" as text')"

# Bail out if jamfHelper doesn't exist.
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
if [[ ! -x "$jamfHelper" ]]; then
    REASON="jamfHelper not found."
    BAILOUT=true
fi

# Check the OS version.
OS_MAJOR=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
OS_MINOR=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')
if [[ "$OS_MAJOR" -ne 10 || "$OS_MINOR" -lt 9 ]]; then
    REASON="this script requires macOS 10.9 or higher. This Mac has $(sw_vers -productVersion)."
    BAILOUT=true
fi

# Check to see if the encryption process is complete
FV_STATUS="$(/usr/bin/fdesetup status)"
if grep -q "Encryption in progress" <<< "$FV_STATUS"; then
    REASON="FileVault encryption is in progress. Please run the script again when it finishes."
    BAILOUT=true
elif grep -q "FileVault is Off" <<< "$FV_STATUS"; then
    REASON="FileVault is not active."
    BAILOUT=true
elif ! grep -q "FileVault is On" <<< "$FV_STATUS"; then
    REASON="unable to determine encryption status."
    BAILOUT=true
fi

# Get the logged in user's name
CURRENT_USER=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Make sure there's an actual user logged in
if [[ -z $CURRENT_USER || "$CURRENT_USER" == "root" ]]; then
    REASON="no user is currently logged in."
    BAILOUT=true
else
    # Make sure logged in account is already authorized with FileVault 2
    FV_USERS="$(/usr/bin/fdesetup list | awk -F "," '{print $1}')"
    if ! egrep -q "^${CURRENT_USER}" <<< "$FV_USERS"; then

REASON="$CURRENT_USER is not on the list of FileVault-enabled users. Please log in as:
        
$FV_USERS"
        BAILOUT=true
    fi
fi

# Check if volume is using HFS+ or APFS
FILESYSTEM_TYPE=$(/usr/sbin/diskutil info / | awk '/Type \(Bundle\)/ {print $3}')

################################ MAIN PROCESS #################################

# Decrypt Admin Account Credentials
ADMIN_USER=$(DecryptString ${ADMIN_USER_ENCRYPTED})
ADMIN_PASS=$(DecryptString ${ADMIN_PASS_ENCRYPTED})

# Get information necessary to display messages in the current user's context.
USER_ID=$(/usr/bin/id -u "$CURRENT_USER")
if [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -le 9 ]]; then
    L_ID=$(/usr/bin/pgrep -x -u "$USER_ID" loginwindow)
    L_METHOD="bsexec"
elif [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -gt 9 ]]; then
    L_ID=$USER_ID
    L_METHOD="asuser"
fi

# If any error occurred in the validation section, bail out.
if [[ "$BAILOUT" == "true" ]]; then
    echo "[ERROR]: $REASON"
    launchctl "$L_METHOD" "$L_ID" "$jamfHelper" -windowType "utility" -icon "$LOGO" -title "$PROMPT_TITLE" -description "$FAIL_MESSAGE: $REASON." -button1 'OK' -defaultButton 1 -startlaunchd &>/dev/null &
    exit 1
fi

# Display a branded prompt explaining the password prompt.
echo "Alerting user $CURRENT_USER about incoming password prompt..."
/bin/launchctl "$L_METHOD" "$L_ID" "$jamfHelper" -windowType "utility" -icon "$LOGO" -title "$PROMPT_TITLE" -description "$PROMPT_MESSAGE" -button1 "Next" -defaultButton 1 -startlaunchd &>/dev/null

# Get the logged in user's password via a prompt.
echo "Prompting $CURRENT_USER for their Mac password..."
USER_PASS="$(/bin/launchctl "$L_METHOD" "$L_ID" /usr/bin/osascript -e 'display dialog "Please enter the password of a FileVault-enabled user on your Mac:" default answer "" with title "'"${PROMPT_TITLE//\"/\\\"}"'" giving up after 86400 with text buttons {"OK"} default button 1 with hidden answer with icon file "'"${LOGO_POSIX//\"/\\\"}"'"' -e 'return text returned of result')"

# Thanks to James Barclay (@futureimperfect) for this password validation loop.
TRY=1
until /usr/bin/dscl /Search -authonly "$CURRENT_USER" "$USER_PASS" &>/dev/null; do
    (( TRY++ ))
    echo "Prompting $CURRENT_USER for their Mac password (attempt $TRY)..."
    USER_PASS="$(/bin/launchctl "$L_METHOD" "$L_ID" /usr/bin/osascript -e 'display dialog "Sorry, that password was incorrect. Please try again:" default answer "" with title "'"${PROMPT_TITLE//\"/\\\"}"'" giving up after 86400 with text buttons {"OK"} default button 1 with hidden answer with icon file "'"${LOGO_POSIX//\"/\\\"}"'"' -e 'return text returned of result')"
    if (( TRY >= 5 )); then
        echo "[ERROR] Password prompt unsuccessful after 5 attempts. Displaying \"forgot password\" message..."
        /bin/launchctl "$L_METHOD" "$L_ID" "$jamfHelper" -windowType "utility" -icon "$LOGO" -title "$PROMPT_TITLE" -description "$FORGOT_PW_MESSAGE" -button1 'OK' -defaultButton 1 -startlaunchd &>/dev/null &
        exit 1
    fi
done
echo "Successfully prompted for Mac password."

echo "Checking to make sure $ADMIN_USER is present..."
if [[ $(dscl . list /Users) =~ "$ADMIN_USER" ]]; then
    echo "$ADMIN_USER is present."
else
    echo "$ADMIN_USER not found. Creating user..."
    jamf createAccount -username "$ADMIN_USER" -realname "$ADMIN_USER" -password "$ADMIN_PASS" -admin
    if [[ $(dscl . list /Users) =~ "$ADMIN_USER" ]]; then
        echo "      User Created."
    else
        echo "      ERROR Creating User."
        exit 1
    fi
fi

# if macOS 10.13 or later enable SecureToken first
if [[ "$OS_MINOR" -ge 13 ]]; then
    echo "System is running macOS $OS_MAJOR.$OS_MINOR."
    # Enables SecureToken for the admin account.
    if [[ "$FILESYSTEM_TYPE" == "apfs" ]]; then
        echo "Enabling SecureToken..."
        enableSecureToken
        # Check and see if account is now FileVault enabled
        ADMIN_FV_STATUS=$(sysadminctl -adminUser $CURRENT_USER -adminPassword $USER_PASS -secureTokenStatus $ADMIN_USER 2>&1)
        SECURE_TOKEN_STATUS=$(echo $ADMIN_FV_STATUS | sed -e 's/.*is\(.*\).for.*/\1/')
        if [[ "$SECURE_TOKEN_STATUS" == *"ENABLED"* ]]; then
            echo "$ADMIN_USER has been granted a SecureToken..."
        fi
    fi
        echo "Making $ADMIN_USER FileVault Enabled..."
        # Translate XML reserved characters to XML friendly representations.
        USER_PASS=${USER_PASS//&/&amp;}
        USER_PASS=${USER_PASS//</&lt;}
        USER_PASS=${USER_PASS//>/&gt;}
        USER_PASS=${USER_PASS//\"/&quot;}
        USER_PASS=${USER_PASS//\'/&apos;}
        # FileVault enable admin account
        createPlist
        addUser
        # Check if admin account is not FileVault ENABLED
        FV2_CHECK=$(fdesetup list | awk -v usrN="$ADMIN_USER" -F, 'match($0, usrN) {print $1}')
        if [[ "$FV2_CHECK" == "${ADMIN_USER}" ]]; then
        	echo "$ADMIN_USER is now FileVault Enabled."
            if [[ "$FILESYSTEM_TYPE" == "apfs" ]]; then
                echo "Updating APFS Preboot..."
                updatePreboot
            fi
        else
            echo "Error making $ADMIN_USER FileVault Enabled."
        fi
elif [[ "$OS_MINOR" -le 12 ]]; then
    echo "System is running macOS $OS_MAJOR.$OS_MINOR."
    echo "Making $ADMIN_USER FileVault Enabled..."
    # Translate XML reserved characters to XML friendly representations.
    USER_PASS=${USER_PASS//&/&amp;}
    USER_PASS=${USER_PASS//</&lt;}
    USER_PASS=${USER_PASS//>/&gt;}
    USER_PASS=${USER_PASS//\"/&quot;}
    USER_PASS=${USER_PASS//\'/&apos;}
    # FileVault enable admin account
    createPlist
    addUser
    # Check if admin account is not FileVault ENABLED
    FV2_CHECK=$(fdesetup list | awk -v usrN="$ADMIN_USER" -F, 'match($0, usrN) {print $1}')
    if [[ "$FV2_CHECK" == "${ADMIN_USER}" ]]; then
        echo "$ADMIN_USER is now FileVault Enabled."
        /bin/launchctl "$L_METHOD" "$L_ID" "$jamfHelper" -windowType "utility" -icon "$LOGO" -title "$PROMPT_SUCCESS" -description "$SUCCESS_MESSAGE" -button1 'OK' -defaultButton 1 -startlaunchd &>/dev/null &
    else
        echo "Error making $ADMIN_USER FileVault Enabled."
    fi
fi

cleanUp

# Attempt to re-escrow the key
/usr/local/jamf/bin/jamf policy -event FileVault-Key

exit 0;
