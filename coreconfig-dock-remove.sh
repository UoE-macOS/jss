#!/bin/bash

###################################################################
#
# Script to remove applications from the dock.
# Utilises - https://github.com/kcrawford/dockutil
#
# The script removes the Remote Support and Support icons from the dock
# and sets a hidden file so that the state is retained. Script is executed
# from Self Service.
#
# Last Changed: Fri 26 Apr 2019 10:05:33 BST
# Version: 0.1.2
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################


ACTIVE_USER=`ls -l /dev/console | awk '{print $3}'`

echo "Active user is $ACTIVE_USER"

DOCK_PREF="/Users/$ACTIVE_USER/Library/Preferences/com.apple.dock.plist"

echo "The Dock Pref plist is $DOCK_PREF"

# File to show opt out of dock icons.
touch /Users/$ACTIVE_USER/.NoDock

# Set the path for the dock command line tool.
DOCK_UTIL="/usr/local/bin/dockutil"

echo "The Dock Utility is at $DOCK_UTIL"

$DOCK_UTIL --remove 'RemoteSupport.url' --no-restart $DOCK_PREF
$DOCK_UTIL --remove 'Support.url' $DOCK_PREF

exit 0;
