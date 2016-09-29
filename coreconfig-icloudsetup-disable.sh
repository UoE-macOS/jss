#!/bin/bash

###################################################################
#
# Copied and modified from Rich Trouton's script at ...
# https://gist.github.com/rtrouton/a01073797a6d7e1fff9a#file-gistfile1-sh
#
# NB in >=10.12 it appears to be possible to do this with a profile
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

# Determine OS version
osvers=$(sw_vers -productVersion | awk -F. '{print $2}')
sw_vers=$(sw_vers -productVersion)

# Determine OS build number

sw_build=$(sw_vers -buildVersion)

# Checks first to see if the Mac is running 10.7.0 or higher.
# If so, the script checks the system default user template
# for the presence of the Library/Preferences directory. Once
# found, the iCloud and Diagnostic pop-up settings are set
# to be disabled.
if [[ ${osvers} -ge 7 ]]
then
  for USER_TEMPLATE in "/System/Library/User Template"/*
  do
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${sw_vers}"
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenBuddyBuildVersion "${sw_build}"     
  done
fi
