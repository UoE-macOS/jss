#!/bin/bash

###################################################################
#
# This script triggers a custom event ('filevault-init')
# if filevault is currently disabled and the user logging
# in is a valid user in our directory service.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

LDAP_SERVER="ldaps://authorise.is.ed.ac.uk"
LDAP_BASE="dc=authorise,dc=ed,dc=ac,dc=uk"
LDAP_SCHOOL="eduniSchoolCode"
LDAP_FULLNAME="cn"
LDAP_UIDNUM="uidNumber"

filevault_is_enabled() {
  fdesetup status | grep 'FileVault is On'
  [ $? == 0 ]
}

user_is_valid() {
  echo "$0: Looking for user id number"
  uid_num=$(ldapsearch -x -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
        -s sub "(uid=${1})" "${LDAP_UIDNUM}" | awk -F ': ' '/^'"${LDAP_UIDNUM}"'/ {print $2}')

  [ ! -z ${uid_num} ]
}

# in-built jamf variable $3, doesn't seem to be returning a valid username, even if a uun account is logged on.
user_name=`ls -l /dev/console | awk '{print $3}'`

if ! filevault_is_enabled
then
  if user_is_valid ${user_name}
  then
    # This causes the 'UoE - FileVault - Initialise' policy to
    # set things up such that FileVault will be enabled for the
    # current user on next logout
    /usr/local/bin/jamf policy -event 'filevault-init'
    
    # Now force the user to log out to complete the enablement process
    result="$(sudo -u ${user_name} osascript <<EOT
      repeat while application "Finder" is not running
        delay 1
      end repeat
      tell application "System Events"
        activate
        with timeout of 36000 seconds
          display dialog "You need to log out and enter your password in order to complete the disk encryption process" buttons {"Log Out Now"} default button 1
        end timeout
      end tell
      -- Log out without giving any further warnings
      tell application "loginwindow" to «event aevtrlgo»
EOT
)"

  else
    echo "$0: Filevault inactive but non-valid user"
  fi
else
  echo "$0: Filevault is active"
fi
