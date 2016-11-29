#!/bin/bash

###################################################################
#
# Script to control the Application Firewall.  
# On 10.12 and later most of these options can be controlled
# using a profile, but for 10.11 we need to use a script.
#
# Last Changed: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

# Set the path for the app firewall command line tool.
SOCKET_FILTER="/usr/libexec/ApplicationFirewall/socketfilterfw"

# Firewall options
GLOBAL_STATE="$4"
BLOCK_ALL="$5"
ALLOW_SIGNED="$6"
STEALTH_MODE="$7"
LOGGING_MODE="$8"
LOGGING_OPTION="$9"

############## Firewall Configuration ##############

# Turn the firewall on or off
echo "Turning firewall ${GLOBAL_STATE}"
"${SOCKET_FILTER}" --setglobalstate "${GLOBAL_STATE}"

# Enable or disable block all option.
echo "Setting 'block all' to ${BLOCK_ALL}"
"${SOCKET_FILTER}" --setblockall "${BLOCK_ALL}"

# Set whether signed applications are to automatically receive incoming connections or not.
echo "Setting 'allow signed' to ${ALLOW_SIGNED}"
"${SOCKET_FILTER}" --setallowsigned "${ALLOW_SIGNED}"

# Set stealth mode on or off, note that machine won't respond to ping.
echo "Setting stealth mode to ${STEALTH_MODE}"
"${SOCKET_FILTER}" --setstealthmode "${STEALTH_MODE}"

# Set logging to on or off. 
echo "Turning logging ${LOGGING_MODE}"
"${SOCKET_FILTER}" --setloggingmode "${LOGGING_MODE}"

# Set logging option to throttled, brief or detail. Log default is throttled.
echo "Setting log mode to ${LOGGING_OPTION}"
"${SOCKET_FILTER}" --setloggingopt "${LOGGING_OPTION}"

exit 0;

