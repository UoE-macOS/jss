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
# This script expects to be run at login as a jamf login script. 
# 
# Arguments should be provided as: 
# $3 Username of logging-in user
# $4 Path to directory containing the profiles to be applied
# $5 Path to the 'customdisplayprofiles' tool
#
# Sample folder hierarchy:
#
# /Library/Org/CustomDisplayProfiles
# ├── 1
# │   └── Custom Profile 1.icc
# └── 2
#     └── Custom Profile 2.icc


PROFILES_DIR=$4
TOOL_PATH=$5

if [ ! -d $PROFILES_DIR ] || [ ! -x $TOOL_PATH ]
then
    echo "Either $PROFILES_DIR or $TOOL_PATH is missing"
    exit 255
fi

for DISPLAY_INDEX in $(ls "${PROFILES_DIR}"); do
    echo "Setting profile for display $DISPLAY_INDEX..."
    sudo -u $3 $TOOL_PATH set --display $DISPLAY_INDEX "$PROFILES_DIR/$DISPLAY_INDEX"/*
done