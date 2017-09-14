#!/bin/bash

# Workaround as shown in https://www.jamf.com/jamf-nation/discussions/19050/add-wifi-networks-without-admin-privileges
# Allows non-admin users to add printers and manage their WiFi configuration.

#For WiFi

/usr/bin/security authorizationdb write system.preferences.network allow
/usr/bin/security authorizationdb write system.services.systemconfiguration.network allow

#For printing

/usr/bin/security authorizationdb write system.preferences.printing allow
/usr/bin/security authorizationdb write system.print.operator allow
/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group lpadmin
/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group _lpadmin

exit 0;
