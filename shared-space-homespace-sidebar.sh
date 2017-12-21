#!/bin/bash

###################################################################
#
# Script for desktop Macs to add a shortcut to the user's network homespace into their 
# Favourites list in the Finder once the user is signed into NoMAD, which should happen by default on desktop Macs.
#
# Date: Thu 21 Dec 2017 15:16:22 GMT
# Version: 0.1.3
# Creator: dsavage
#
##################################################################

#Get username of logged in user
User_Name=`ls -l /dev/console | awk '{print $3}'`

# Get local homepath
Home_Path=`dscl . -read /Users/$User_Name | grep "NFSHomeDirectory" | grep '/Users/' | awk '{print $2}'`

# Path to the NoMAD preference
NoMAD_Path="${Home_Path}/Library/Preferences/com.trusourcelabs.NoMAD.plist"

if ! [ -e "$NoMAD_Path" ];
then
	echo "****** NoMAD has not launched. Cannot add homespace shortcut to Finder favourites. ******"
	exit 254; # NoMAD hasn't launched
fi

# Derive the homespace path from NoMAD
homespace=`defaults read $NoMAD_Path "UserHome"`

# Break down and reformat the home path
homeServer=`echo $homespace | awk -F "/" '{print $3}'` 

homeSharePoint=`echo $homespace | awk -F "/" '{print $4}'` 
echo $homeSharePoint >> $LogFile

homePath=`echo $homespace | awk -F "/" '{for(i=5;i<=NF;i++) print $i}'` 
homeSharePath=`echo $homePath | tr ' ' '/'`
echo $homeSharePath >> $LogFile


# Define the completed path from which to create the sidebar shortcut
share="/Volumes/${homeSharePoint}/${homeSharePath}/"
#trimmedshare=$(echo $share | sed 's:/*$::')
#echo "The trimmed share path is: $trimmedshare"

mount_volume() {
script_args="mount volume \"smb://${homeServer}/${homeSharePoint}\""
# If the home volume is unavailable take 2 attempts at (re)mounting it
tries=0
while ! [ -d /Volumes/${homeSharePoint} ] && [ ${tries} -lt 2 ];
do
	tries=$((${tries}+1))
	sudo -u ${User_Name} | osascript -e "${script_args}"
	sleep 5
done
}

# Add the entry to the sidebar
add_FavoriteItems() {
if [ -d /Volumes/${homeSharePoint} ]; then
    python - <<EOF
import sys
sys.path.append('/usr/local/python')
from FinderSidebarEditor import FinderSidebar                  # Import the module
sidebar = FinderSidebar()                                      # Create a Finder sidebar instance to act on.
sidebar.add("$share")                                        # Add 'Utilities' favorite to sidebar
EOF
  else
    mount_volume
	python - <<EOF
import sys
sys.path.append('/usr/local/python')
from FinderSidebarEditor import FinderSidebar                  # Import the module
sidebar = FinderSidebar()                                      # Create a Finder sidebar instance to act on.
sidebar.add("$share")                                        # Add 'Utilities' favorite to sidebar
EOF
fi
}

add_FavoriteItems

exit 0;
