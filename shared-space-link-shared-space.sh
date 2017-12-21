#!/bin/bash

###################################################################
#
# Enable users to add shared server spaces for multiple
# Schools via Self Service.
#
# Date: Thu 21 Dec 2017 15:16:22 GMT
# Version: 0.1.3
# Creator: dsavage
#
##################################################################

# College or support unit (chss, cmvm, csce, sg)
unit=$4
#unit="chss"

# Subject area or group
subject=$5
#subject="div"

user_name=`ls -l /dev/console | awk '{print $3}'`

smb_mount="smb://${user_name}@$unit.datastore.ed.ac.uk/$unit/$subject"

smb_path="smb://$unit.datastore.ed.ac.uk/$unit/$subject"

share="/Volumes/${subject}"


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


# Adds the entry to the sidebar
add_FavoriteItems() {
  if [ -d /Volumes/${subject} ]; then
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
