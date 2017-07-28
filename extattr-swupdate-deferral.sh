#!/bin/sh

#######################################################################
# A small extension attribute to report on deferred software updates.
#
# The value will either be:
# 
# None: in which case this machine doesn't have any pending updates 
#       that require a restart
# or
# A Date: in which case there are pending updates that require a reboot 
#         and that date is the last date on which the user will be 
#         allowed to defer installation
#
#######################################################################
defer_date=$(/usr/libexec/PlistBuddy -c "Print DeferOkUntil" \
             /var/db/UoESoftwareUpdateDeferral 2>/dev/null)
if [ $? == 0 ]
then
    echo "<result>${defer_date}</result>"
else
    echo "<result>None</result>"
fi
