#!/bin/bash

###################################################################
#
# This script triggers a custom event ('filevault-init')
# if filevault is currently disabled.
#
# Date: Thu 29 Mar 2018 15:58:06 BST
# Version: 0.1.5
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
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

# in-built jamf variable $3, doesn't seem to be returning a valid username, even if a uun account is logged on.
user_name=`ls -l /dev/console | awk '{print $3}'`

if ! filevault_is_enabled
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
  echo "$0: Filevault is active"
fi

exit 0;
