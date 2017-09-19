#!/bin/sh

###################################################################
#
# Script to fully remove Cisco AnyConnect SSL client from a machine. May be required before the app tries to reinstall.
#
# Date: Mon 03 Jul 2017 11:30:33 BST
# Version: 0.1.1
# Creator: dsavage
#
##################################################################

# Delete installed files

rm -dfR /Applications/Cisco > /dev/null
rm -f /Library/LaunchAgents/com.cisco.anyconnect.gui.plist > /dev/null
rm -f /Library/LaunchDaemons/com.cisco.anyconnect.aciseagentd.plist > /dev/null
rm -f /Library/LaunchDaemons/com.cisco.anyconnect.ciscod.plist > /dev/null
rm -f /Library/LaunchDaemons/com.cisco.anyconnect.vpnagentd.plist > /dev/null
rm -dfR /opt/cisco > /dev/null

# Forget existing package receipts

pkgutil --forget com.cisco.pkg.anyconnect.dart > /dev/null
pkgutil --forget com.cisco.pkg.anyconnect.fireamp > /dev/null
pkgutil --forget com.cisco.pkg.anyconnect.iseposture > /dev/null
pkgutil --forget com.cisco.pkg.anyconnect.nvm_v2 > /dev/null
pkgutil --forget com.cisco.pkg.anyconnect.posture > /dev/null
pkgutil --forget com.cisco.pkg.anyconnect.vpn > /dev/null
pkgutil --forget com.cisco.pkg.anyconnect.websecurity_v2 > /dev/null

exit 0;
