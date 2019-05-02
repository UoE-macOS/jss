#!/bin/bash
###################################################################
#
# Script to restart the dock if required.
#
# Last Changed: "Thu 13 Jul 2017 10:48:12"
# Version: 0.1.1
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################

ACTIVE_USER=`ls -l /dev/console | awk '{print $3}'`

if [ -z "${ACTIVE_USER}" ] || [ "${ACTIVE_USER}" == "root" ] || [ "${ACTIVE_USER}" == "_mbsetupuser" ] || [ "${ACTIVE_USER}" == "" ]; then
	exit 0;
fi

# File to store if dock was changed.
DOCK_CHANGE="/tmp/dock-change.txt"

Escape=0
# we need to wait for the the file to exist before starting. 
until [ -e $DOCK_CHANGE ]; do
    sleep 3
    Escape=$(($Escape+1))
	if [ "$Escape" -gt 4 ]; then
    	echo "Breaking loop and failing out as the ${DOCK_CHANGE} isn't generated."
        killall Dock
		exit 0;
    	#break
	fi
done


sleep 5

CHECK_ITEM=`grep 'dock item added' $DOCK_CHANGE | tr -d '\n'`

if ! [ -z "$CHECK_ITEM" ] || ! [ "$CHECK_ITEM" == '' ]; then
sleep 5
killall Dock
fi

rm -f $DOCK_CHANGE

exit 0;
