#!/bin/bash
#
# Author: Johan McGwire - Yohan @ Macadmins Slack - Johan@McGwire.tech
#
# Description: This script completely removes all aspects of a NoMAD Login AD Installation

# Checking if running as root or not
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Resetting the authorization database to stock
authchanger -reset 2> /dev/null
if [[ $? ]]; then
    echo "Authorization Database reset"
else
    echo "Error resetting the Authorization Database"
    exit 1
fi

# Removing authchanger
rm -f /usr/local/bin/authchanger
if [[ $? ]]; then
    echo "Authchanger removed"
else
    echo "Error removing authchanger"
    exit 1
fi

# Cleaing out the NoMAD Login files
rm -rf /Library/Security/SecurityAgentPlugins/NoMADLoginAD.bundle
if [[ $? ]]; then
    echo "NoMAD Login AD Removed"
else
    echo "Error removing NoMAD Login AD"
    exit 1
fi

# Cleaning out computer level settings if they exist
if [ -f "/Library/Preferences/menu.nomad.login.ad.plist" ]; then
    rm -f /Library/Preferences/menu.nomad.login.ad.plist
    if [[ $? ]]; then
        echo "NoMAD Login AD Preferences Removed"
    else
        echo "Error removing NoMAD Login AD Preferences"
        exit 1
    fi
fi

# Checking if there is a configuration profile containing a NoMADLoginAD preference
if [ -f "/Library/Managed Preferences/menu.nomad.login.ad.plist" ]; then
    echo "WARNING: There is a configuration profile containing a NoMAD Login AD Preference. This must be removed seperately."
fi

# Exiting and returning the policy call code
exit $?