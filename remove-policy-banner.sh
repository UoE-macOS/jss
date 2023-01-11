#!/bin/bash

# Created by rcoleman

# Get build version
OS_VERSION_MAJOR=$(sw_vers -buildVersion | cut -c 1-2)

# Policy banner location
POLICY_BANNER="/Library/Security/PolicyBanner.rtfd"

# Check if we are running at least Big Sur already. If so then remove the policy banner
if [[ "$OS_VERSION_MAJOR" -ge 20 ]]; then
    echo "Device running Big Sur at least."
    # Check policy banner exists
    if [ -e "$POLICY_BANNER" ]; then
        echo "Found policy banner file. Removing.."
        rm -Rv "$POLICY_BANNER"
    fi
fi

exit 0;