#!/bin/bash

# File to store if dock was changed.
DOCK_CHANGE="/tmp/dock-change.txt"

# we need to wait for the the file to exist before starting. 
until [ -e $DOCK_CHANGE ]; do
	wait
done

sleep 20

CHECK_ITEM=`grep 'dock item added' $DOCK_CHANGE`

if ! [ -z $CHECK_ITEM ]; then
sleep 5
killall Dock
fi

rm -f $DOCK_CHANGE

exit 0;