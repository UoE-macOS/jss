#!/bin/bash

###################################################################
#
# This script checks whether there are 5 or fewer profiles on the target Mac and runs a jamf manage command to re-manage them. 
# There should always be more than 5 profiles.
#
# Date: Tue 04 Jul 2017 11:30:33 BST
# Version: 0.1.1
# Creator: dsavage
#
##################################################################

numberofprofiles=`profiles -C | wc -l`

echo "The number of profiles is $numberofprofiles"

if [ $numberofprofiles -lt 6 ]; then

# re-manage the mac
echo "There are fewer than 6 profiles installed. Re-managing to correct."
/usr/local/bin/jamf manage

sleep 15
# sometimes it can be a bit slow to trigger...
/usr/local/bin/jamf manage

fi

exit 0;
