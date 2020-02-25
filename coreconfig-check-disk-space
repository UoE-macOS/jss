#!/bin/bash

#############################################################################
#
# Script to perform a check on the Mac's available disk space and trigger a 
# Yo notification to alert the user if the disk's capacity exceeds 95% or 
# there are fewer than 15GB available, whichever comes first.
#
# The latter is the threshold below which operating system upgrades may
# not be successful, so it is best to keep the user informed.
# 
#
# Date: Tues 25 Feb 2020 15:23:23 GMT
# Version: 0.1.1
# Creator: ganders1
#
#############################################################################


# Find boot disk name
bootDisk=`diskutil info / | grep "Device Node:" | awk '{print $3}'`

# Find free space percentage
freeSpacePercentage=`df -g | grep "${bootDisk}" | awk '{print $5}' | awk -F "%" '{print $1}'`
echo "The Mac's hard disk is at ${freeSpacePercentage}% capacity."

# Find free space in GB
freeSpaceGB=`df -g | grep "${bootDisk}" | awk '{print $4}'`
echo "There are ${freeSpaceGB}GB free on the Mac."


# Check if disk capacity is greater than 95% or the available free space is below 15GB

spaceStatus=Pass

if [[ ${freeSpacePercentage} -ge 95 ]]; then
	spaceStatus=Fail
fi

if [[ ${freeSpaceGB%.*} -le 15 ]]; then
    spaceStatus=Fail
fi
  	
if [[ $spaceStatus == Pass ]]; then 	
  	/bin/echo "Disk Check: OK - There are either greater than 15GB free on the Mac or the current disk capacity used is below 95%."
    
else

    /bin/echo "Disk Check: ERROR - There are only ${freeSpaceGB}GB free on the Mac or the current disk capacity used is above 95%. Triggering Yo notification on freeing up space."

    # Trigger Yo notification on low disk space pointing users to https://edin.ac/mac-low-disk-space
    /usr/local/bin/jamf policy -event low-disk-space
fi

exit 0;
