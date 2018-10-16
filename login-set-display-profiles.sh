#!/bin/sh
#
# login-set-display-profiles.sh
# Thanks to Tim Sutton
# https://github.com/timsutton/customdisplayprofiles
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
# Very simple helper script to run the customdisplayprofiles tool to
# set profiles stored in a known folder location, with subfolders named
# by display index, like in the sample structure below. The icc file itself
# is given only by a shell wildcard, but the tool will only take the first
# argument.
#
# This would allow someone calibrating a display to configure a profile
# for all users simply by copying the profile to the correct folder
# and ensuring it's the only file in this folder.
#
# This script would typically be run at login using a LaunchAgent.
#
# Sample folder hierarchy:
#
# /Library/Org/CustomDisplayProfiles
# ├── 1
# │   └── Custom Profile 1.icc
# └── 2
#     └── Custom Profile 2.icc


PROFILES_DIR=/Users/Shared/CustomDisplayProfiles
TOOL_PATH=/usr/local/bin/customdisplayprofiles

if [ ! -d $PROFILES_DIR ] || [ ! -x $TOOL_PATH ]
then
    echo "Either $PROFILES_DIR or $TOOL_PATH is missing"
    exit 255
fi

for DISPLAY_INDEX in $(ls "${PROFILES_DIR}"); do
    echo "Setting profile for display $DISPLAY_INDEX..."
    sudo -u $3 $TOOL_PATH set --display $DISPLAY_INDEX "$PROFILES_DIR/$DISPLAY_INDEX"/*
done