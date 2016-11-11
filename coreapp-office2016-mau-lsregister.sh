#!/bin/bash
###################################################################
#
# Work round an issue where the Microsoft AutoUpdate application
# is not registered with LaunchServices on installation, resulting
# in an ugly 'You are about to launch MAU for the first time' dialog
# box for each user.
#
# This script is run as a login script.
#
# See: http://tinyurl.com/jzdw9u2
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

# Find Current User
loggedInUser=`/usr/bin/who | awk '/console/{ print $1 }'`
echo "Making sure $loggedInUser won't see the microsoft autoupdate box" 

# Set Command Variable for trusted application
register_trusted_cmd="/usr/bin/sudo -u $loggedInUser /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R -f -trusted"

daemon="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/Microsoft AU Daemon.app"

# Do it!
$register_trusted_cmd "$daemon"
