#!/bin/sh

###################################################################
#
# Simple proof of concept. The file 'UoE-Production-Status.txt' is
# used by an extension attribute to place machines in a 'DEV', 'TEST'
# or 'LIVE' smart group. Could be used by users to opt-in to certain
# pre-release software or configuration.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################


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

