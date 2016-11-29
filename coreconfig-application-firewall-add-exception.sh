#!/bin/bash

###################################################################
#
# Script to add an exception for an individual application to
# the builtin firewall.
#
# On 10.12 and later most of these options can be controlled
# using a profile, but for 10.11 we need to use a script.
#
# The script takes a single argument" the path to the application
# to be added.
#
# Last Changed: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

# Set the pathfor the app firewall command line tool.
SOCKET_FILTER="/usr/libexec/ApplicationFirewall/socketfilterfw"

# Path to the application, normally /Applications/****.app
APPLICATION_PATH="$4"

echo "Adding app firewall exception for ${APPLICATION_PATH}..."

# Find the state of the firewall.
FIREWALL_STATE="$(${SOCKET_FILTER} --getglobalstate | awk '{print $3}')"

# Add the firewall exceptions.
"${SOCKET_FILTER}" --unblockapp "${APPLICATION_PATH}"
"${SOCKET_FILTER}" --add "${APPLICATION_PATH}"

# May need to restart the firwall to get the setting to stick, but avoid enabling it if it is disabled.
if [ "${FIREWALL_STATE}" == "enabled." ]
then
    echo "Restarting application firewall..."
    # Restart the firewall
    "${SOCKET_FILTER}" --setglobalstate off
    sleep 1
    "${SOCKET_FILTER}" --setglobalstate on
else
    echo "The firewall is not running."
fi
