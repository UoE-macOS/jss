#!/bin/bash

###################################################################
#
# Script to add applications  to the dock.
# Utilises - https://github.com/kcrawford/dockutil
#
# The script takes 3 arguments; the path to the application
# to be added and two related to the dock item position.
#
# Last Changed: "Wed 02 Aug 2017 15:30:04"
# Version: 0.1.3
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################

# we need to wait for the dock to actually start 
until [[ $(pgrep Dock) ]]; do
    wait
done

ACTIVE_USER=`ls -l /dev/console | awk '{print $3}'`

echo "Active user is $ACTIVE_USER"

if [ -f /Users/$ACTIVE_USER/.NoDock ]; then
exit 0;
fi

DOCK_PREF="/Users/$ACTIVE_USER/Library/Preferences/com.apple.dock.plist"

echo "The Dock Pref plist is $DOCK_PREF"

# File to store if dock was changed.
DOCK_CHANGE="/tmp/dock-change.txt"

echo "The Dock Change text file is at $DOCK_CHANGE"

# Set the path for the dock command line tool.
DOCK_UTIL="/usr/local/bin/dockutil"

echo "The Dock Utility is at $DOCK_UTIL"

# Path to the application, normally /Applications/****.app
APPLICATION_PATH="$4"

echo "The Application Path is $APPLICATION_PATH"

POSITION="$5"

echo "The Application position is $POSITION"

POSITION_KEY="$6"

echo "The Application position key is $POSITION_KEY"

# Set the application name.
APP_NAME=`basename "$APPLICATION_PATH" | awk -F "." '{print $1}'`

echo "The App Name is $APP_NAME"

# Check if item is already in dock.
CHECK_ITEM=$(defaults read $DOCK_PREF | grep "file-label" | awk -F "=" '{print $2}' | sed -e 's/^[[:space:]]*//' | grep "${APP_NAME}")
# Fix an issue with how defaults returns labels which contain a space.
if [[ "$CHECK_ITEM" =~ '"' ]]; then
	CHECK_ITEM=$(echo "$CHECK_ITEM" | awk -F '"' '{print $2}')
fi
# Make sure that we only get a single response
CHECK_ITEM=$(echo "$CHECK_ITEM" | grep -E "^${APP_NAME}")

echo "Check Item is $CHECK_ITEM"

if [ "$CHECK_ITEM" == "$APP_NAME;" ] || [ "$CHECK_ITEM" == "$APP_NAME" ]; then
	echo no action taken >> $DOCK_CHANGE
else
	if [ -e "$APPLICATION_PATH" ]; then
	    if [ -z "$POSITION" ] || [ "$POSITION" == '' ]; then
	        $DOCK_UTIL --add "$APPLICATION_PATH" --no-restart $DOCK_PREF
			echo dock item added >> $DOCK_CHANGE 
	    else
		    $DOCK_UTIL --add "$APPLICATION_PATH" "$POSITION" "$POSITION_KEY" --no-restart $DOCK_PREF 
		    echo dock item added >> $DOCK_CHANGE
		fi
	fi
fi

exit 0;
