#!/bin/bash

###################################################################
#
# Script to add applications  to the dock.
# Utilises - https://github.com/kcrawford/dockutil
#
# The script takes 3 arguments; the path to the application
# to be added and two related to the dock item position.
#
# Last Changed: "Tue 19 Mar 2019 16:12:35 GMT"
# Version: 0.1.4
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################


ACTIVE_USER=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

echo "Active user is $ACTIVE_USER"


if [ -z "${ACTIVE_USER}" ] || [ "${ACTIVE_USER}" == "root" ] || [ "${ACTIVE_USER}" == "_mbsetupuser" ] || [ "${ACTIVE_USER}" == "" ]; then
	exit 0;
fi

# we need to wait for the dock to actually start if a user is present
#until [[ $(pgrep Dock) ]]; do
#    wait
#done

if [ -f /Users/$ACTIVE_USER/.NoDock ]; then
exit 0;
fi

sleep 3
echo "Pref file is: ${DOCK_PREF}"
if [ -f "${DOCK_PREF}" ]; then
	echo "Dock preference exists."
else
	su $ACTIVE_USER -c /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock
    echo "Force launching the Dock."
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
ITEM_PATH="$4"
echo "The Application Path is $ITEM_PATH"

POSITION="$5"
echo "The Application position is $POSITION"

POSITION_KEY="$6"
echo "The Application position key is $POSITION_KEY"

GENERATE_URL="$7"
echo "The url is $GENERATE_URL"

ICON="$8"
echo "The icon is $ICON"

# Set the name.
ITEM_NAME=`basename "$ITEM_PATH" | awk -F "." '{print $1}'`

echo "The item to be added is: $ITEM_NAME"

# Set the type .app / .url normally
ITEM_TYPE=`basename "$ITEM_PATH" | awk -F "." '{print $2}'`

echo "The item type to be added is: $ITEM_TYPE"

if ! [ -z "${GENERATE_URL}" ] && [ "${ITEM_TYPE}" == "url" ]; then
	echo '[InternetShortcut]' > "${ITEM_PATH}"
	echo -n 'URL=' >> "${ITEM_PATH}"
	echo "${GENERATE_URL}" >> "${ITEM_PATH}"
	PY_ICON=`echo "\"${ICON}\""`
	PY_PATH=`echo "\"${ITEM_PATH}\""`
	python -c "import Cocoa; Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().initWithContentsOfFile_(${PY_ICON}), ${PY_PATH}, 0)"
fi

# Check if item is already in dock.
CHECK_ITEM=$(defaults read $DOCK_PREF | grep "file-label" | awk -F "=" '{print $2}' | sed -e 's/^[[:space:]]*//' | grep "${ITEM_NAME}")
# Fix an issue with how defaults returns labels which contain a space.
if [[ "$CHECK_ITEM" =~ '"' ]]; then
	CHECK_ITEM=$(echo "$CHECK_ITEM" | awk -F '"' '{print $2}')
fi
# Make sure that we only get a single response
CHECK_ITEM=$(echo "$CHECK_ITEM" | grep -E "^${ITEM_NAME}")

echo "Check Item is $CHECK_ITEM"

if [ "$CHECK_ITEM" == "$ITEM_NAME;" ] || [ "$CHECK_ITEM" == "$ITEM_NAME" ]; then
	echo no action taken >> $DOCK_CHANGE
else
	if [ -e "$ITEM_PATH" ]; then
		if [ "${ITEM_TYPE}" == "app" ]; then
	    	if [ -z "$POSITION" ] || [ "$POSITION" == '' ]; then
	        	$DOCK_UTIL --add "$ITEM_PATH" --no-restart $DOCK_PREF
				echo dock item added >> $DOCK_CHANGE 
	    	else
		    	$DOCK_UTIL --add "$ITEM_PATH" "$POSITION" "$POSITION_KEY" --no-restart $DOCK_PREF 
		    	echo dock item added >> $DOCK_CHANGE
			fi
		else
			$DOCK_UTIL --add "$ITEM_PATH" --section others --no-restart $DOCK_PREF
          	echo dock item added >> $DOCK_CHANGE
		fi
	fi
fi

exit 0;

