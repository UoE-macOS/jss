#!/bin/bash

# Get timestamp
TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`

# Sleep for 60s to make sure update  has completed
sleep 60s

# Check to make sure the replacement plugin exists
if [ ! -d /usr/local/jamf/XeroxFeatures/XeroxFeatures.plugin ]; then
	echo "$TIMESTAMP XeroxFeatures.plugin version 3.52.0 not found in /usr/local/jamf/XeroxFeatures" 
	# Run custom trigger to re-install Xerox plugin fix
	echo "$TIMESTAMP Running custom trigger for policy.."
	/usr/local/jamf/bin/jamf policy -event xeroxPlugin
	exit 0;
fi

# Get current version of plugin
CURRENT_VERSION=`defaults read /Library/Printers/Xerox/PDEs/XeroxFeatures.plugin/Contents/Info CFBundleShortVersionString`

# If current version is the version we want then quit script
if [ $CURRENT_VERSION = "3.52.0" ]; then
	echo "$TIMESTAMP Current version is fine, no need to change. Quitting script…"
	exit 0;
# Else, remove current plugin and replace with 3.52.0
else
	# Remove current plugin
	echo "$TIMESTAMP Current version is $CURRENT_VERSION. Removing…."
	rm -dfr /Library/Printers/Xerox/PDEs/XeroxFeatures.plugin
	# Replace plugin with the version we want
	echo "$TIMESTAMP Replacing version $CURRENT_VERSION with 3.52.0…"
	ditto -v "/usr/local/jamf/XeroxFeatures/XeroxFeatures.plugin" "/Library/Printers/Xerox/PDEs/XeroxFeatures.plugin"
	# Echo completion
	echo "$TIMESTAMP Done!"
fi
exit 0;