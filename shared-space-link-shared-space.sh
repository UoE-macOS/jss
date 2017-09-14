#!/bin/bash

###################################################################
#
# Enable users to add shared server spaces for multiple
# Schools via Self Service.
#
# Date: Thu 07 Sep 2017 11:30:33 BST
# Version: 0.1.2
# Creator: dsavage
#
##################################################################

# College or support unit (chss, cmvm, csce, sg)
unit=$4
#unit="chss"

# Subject area or group
subject=$5
#subject="div"

# sfltool is an Apple utility that can work with the sidebar and server list
# Usage: sfltool restore|add-item|save-lists|test|archive|enable-modern|dump-server-state|clear|disable-modern|dump-storage|list-info [options] 
sfl="/usr/bin/sfltool"

user_name=`ls -l /dev/console | awk '{print $3}'`

smb_mount="smb://${user_name}@$unit.datastore.ed.ac.uk/$unit/$subject"

smb_path="smb://$unit.datastore.ed.ac.uk/$unit/$subject"

share="file:///Volumes/${subject}"

favorite_servers="/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteServers.sfl"

favorite_items="/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl"

mount_volume() {
script_args="mount volume \"${smb_mount}\""
# If the home volume is unavailable take 2 attempts at (re)mounting it
tries=0
while ! [ -d /Volumes/${subject} ] && [ ${tries} -lt 2 ];
do
	tries=$((${tries}+1))
	sudo -u ${user_name} | osascript -e "${script_args}"
	sleep 5
done
}

# Adds the entry to the Go > Connect to Server menu...
add_FavoriteServers() {
server_exists=`$sfl dump-storage /Users/"${user_name}""${favorite_servers}" | grep "${smb_path}" | awk '{print $1}'`
if ! [ "${smb_path}" == "${server_exists}" ]; then
  $sfl add-item -n "${smb_path}" com.apple.LSSharedFileList.FavoriteServers "${smb_mount}"
fi
}

# Adds the entry to the sidebar
add_FavoriteItems() {
share_exists=`$sfl dump-storage /Users/"${user_name}""${favorite_items}" | grep "URL:${share}" | awk '{print $4}'`
if ! [ "URL:${share}" == "${share_exists}" ]; then
  if [ -d /Volumes/${subject} ]; then
    $sfl add-item com.apple.LSSharedFileList.FavoriteItems "${share}"
    else
    mount_volume
    $sfl add-item com.apple.LSSharedFileList.FavoriteItems "${share}"
  fi
fi
}

add_FavoriteServers
add_FavoriteItems

exit 0;
