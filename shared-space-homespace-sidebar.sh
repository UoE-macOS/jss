#!/bin/bash

###################################################################
#
# Script for desktop Macs to add a shortcut to the user's network homespace into their 
# Favourites list in the Finder once the user is signed into NoMAD, which should happen by default on desktop Macs.
#
# Date: Thu 07 Sep 2017 11:30:33 BST
# Version: 0.1.2
# Creator: dsavage
#
##################################################################

# sfltool is an Apple utility that can work with the sidebar and server list
# Usage: sfltool restore|add-item|save-lists|test|archive|enable-modern|dump-server-state|clear|disable-modern|dump-storage|list-info [options] 
sfl="/usr/bin/sfltool"

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
share="file:///Volumes/${homeSharePoint}/${homeSharePath}/"
#trimmedshare=$(echo $share | sed 's:/*$::')
#echo "The trimmed share path is: $trimmedshare"
 
# Define the Finder sidebar favourites path
favorite_items="/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl"

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
share_exists=`$sfl dump-storage /Users/"${User_Name}""${favorite_items}" | grep "URL:${share}" | awk '{print $4}'`
if ! [ "${share_exists}" == "URL:${share}" ]; then
  if [ -d /Volumes/${homeSharePoint} ]; then
    $sfl add-item com.apple.LSSharedFileList.FavoriteItems "${share}"
  else
    mount_volume
    share_exists=`$sfl dump-storage /Users/"${User_Name}""${favorite_items}" | grep "URL:${share}" | awk '{print $4}'`
    if ! [ "${share_exists}" == "URL:${share}" ]; then
        $sfl add-item com.apple.LSSharedFileList.FavoriteItems "${share}"
    fi
  fi
fi
}

add_FavoriteItems

exit 0;
