#!/bin/bash

# Preference key reference
# https://gitlab.com/orchardandgrove-oss/NoMADLogin-AD/wikis/Configuration/preferences

# Function for obtaining timestamp
timestamp() {
    while read -r line
    do
        TIMESTAMP=`date`
        echo "[$TIMESTAMP] $line"
    done
}

# Log file location
LOGFILE="/Library/Logs/NoLoAD.log"

# Set domain
DOMAIN="ed.ac.uk"

# Set background image transparancy
BACKGROUND_IMAGE_ALPHA=1

# Set logo location
LOGO="/usr/local/jamf/UoELogo.png"

# Place holder for username text field
PLACEHOLDER="Your University Login"

# Set plist location
PLIST="/Library/Preferences/menu.nomad.login.ad.plist"

ADMIN="YES"

echo "*** Installing NoMAD Login AD and setting preferences ****" | timestamp 2>&1 | tee -a $LOGFILE

# Depending on OS Version, set the background image
OS_VERSION=$( sw_vers -productVersion | awk -F '.' '{print $2}' )
echo "OS Version is $OS_VERSION" | timestamp 2>&1 | tee -a $LOGFILE
case $OS_VERSION in
	12)
	BACKGROUND_IMAGE="/Library/Desktop Pictures/Sierra.jpg"
	;;
	13)
	BACKGROUND_IMAGE="/Library/Desktop Pictures/High Sierra.jpg"
	;;
	14)
	BACKGROUND_IMAGE="/Library/Desktop Pictures/Mojave Night.jpg"
	;;
	15)
	# Apple have changed their default location for system wallpapers to /System in 10.15, so probably protected by SIP.
	# They've also converted wallpapers to .heic format which NoLoAD seems to have a problem with, so pointing to a Catalina converted .jpg file not in /System.
	# Converted .jpg file should be in place as packaged as part of NoLoAD
	BACKGROUND_IMAGE="/usr/local/jamf/Catalina Night.jpg"
	;;
	*)
	BACKGROUND_IMAGE="/usr/local/jamf/Black.png"
	;;
esac

# Make every account that logs in an admin
echo "Setting admin user creation..." | timestamp 2>&1 | tee -a $LOGFILE
defaults write $PLIST CreateAdminUser -bool "$ADMIN"

# Set default AD domain
echo "Setting domain to ed.ac.uk..." | timestamp 2>&1 | tee -a $LOGFILE
defaults write $PLIST ADDomain "$DOMAIN"

# Set background image
echo "Setting background image depending on OS version..." | timestamp 2>&1 | tee -a $LOGFILE
defaults write $PLIST BackgroundImage "$BACKGROUND_IMAGE"

# Set background image transparency
echo "Setting background image transparency..." | timestamp 2>&1 | tee -a $LOGFILE
defaults write $PLIST BackgroundImageAlpha -int "$BACKGROUND_IMAGE_ALPHA"

# Set login window logo
echo "Setting university logo location..." | timestamp 2>&1 | tee -a $LOGFILE
defaults write $PLIST LoginLogo "$LOGO"

# A String to show as the placeholder in the Username textfield.
echo "Setting placeholder text..." | timestamp 2>&1 | tee -a $LOGFILE
defaults write $PLIST UsernameFieldPlaceholder "$PLACEHOLDER"

# Wait for setup to complete before loading the NoMAD login window
CURRENT_USER=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
until [ "$CURRENT_USER" != "_mbsetupuser" ]
do
    CURRENT_USER=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
    echo "Current user is $CURRENT_USER" | timestamp 2>&1 | tee -a $LOGFILE
    echo "Waiting for setup to complete..." | timestamp 2>&1 | tee -a $LOGFILE
    sleep 5    
done

# Set security authorization database mechanisms with authchanger
echo "Setting security authorization database mechanisms..." | timestamp 2>&1 | tee -a $LOGFILE
/usr/local/bin/authchanger -reset -AD

# Kill loginwindow process to force NoMAD Login to launch
echo "Killing the login window..." | timestamp 2>&1 | tee -a $LOGFILE
/usr/bin/killall -HUP loginwindow

echo "NoMAD Login AD successfully installed!" | timestamp 2>&1 | tee -a $LOGFILE

exit 0
