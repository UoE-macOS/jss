#!/bin/bash

# Preference key reference
# https://gitlab.com/orchardandgrove-oss/NoMADLogin-AD/wikis/Configuration/preferences

# Set domain
domain="ed.ac.uk"

# Set background image transparancy
background_image_alpha=9

# Set logo location
logo="/usr/local/jamf/UoELogo.png"

# Place holder for username text field
placeholder="University username"

# Depedning on OS Version, set the background image
os_version=$( sw_vers -productVersion | awk -F '.' '{print $2}' )
case $os_version in
	12)
	background_image="/Library/Desktop Pictures/Sierra.jpg"
	;;
	13)
	background_image="/Library/Desktop Pictures/High Sierra.jpg"
	;;
	14)
	background_image="/Library/Desktop Pictures/Mojave Night.jpg"
	;;
	*)
	background_image="/usr/local/jamf/Black.png"
	;;
esac

# Set default AD domain
defaults write /Library/Preferences/menu.nomad.login.ad.plist ADDomain "$domain"

# Set background image
defaults write /Library/Preferences/menu.nomad.login.ad.plist BackgroundImage "$background_image"

# Set background image transparency
defaults write /Library/Preferences/menu.nomad.login.ad.plist BackgroundImageAlpha -int "$background_image_alpha"

# Set login window logo
defaults write /Library/Preferences/menu.nomad.login.ad.plist LoginLogo "$logo"

# A String to show as the placeholder in the Username textfield.
defaults write /Library/Preferences/menu.nomad.login.ad.plist UsernameFieldPlaceholder "$placeholder"

# Set security authorization database mechanisms with authchanger
/usr/local/bin/authchanger -reset -AD

# Kill loginwindow process to force NoMAD Login to launch
/usr/bin/killall -HUP loginwindow

exit 0