#!/bin/sh

newstatus="${4}"
jamfdir='/Library/Application Support/JAMF/'
checkfile='UoE-Production-Status.txt'

if [ ! -d "${jamfdir}" ]
then
  echo "Couldn't find ${jamfdir} !"
  exit 255
fi

# Just overwrite the file with our new status
echo "${newstatus}"  > "${jamfdir}/${checkfile}"

# And report back to the jss
/usr/local/bin/jamf recon

