#!/bin/sh

# Simple script to set up preferences for softwareupdate.
# The actual values can be passed in via variables for flexibility.

ME="$( echo $0 | awk -F '/' '{print $NF}' )"

echo "${ME}: Setting Software Update preferences..."

app_store_prefs='/Library/Preferences/com.apple.commerce'
software_update_prefs='/Library/Preferences/com.apple.SoftwareUpdate'

# Do we perform (App Store) application updates automatically?
app_updates=${4:-'TRUE'}

# Do we perform OS X updates (which may require a restart) automatically?
os_updates=${5:-'TRUE'}

# Do we perform 'critical updates' automatically?
critical_updates=${6:-'TRUE'}

# Do we update config files (XProtect etc) automatically?
config_updates=${7:-'TRUE'}

# Should SoftwareUpdate automatically download OS updates?
auto_download=${8:-'TRUE'}

# Should SoftwareUpdate automatically check for OS updates?
auto_check=${9:-'TRUE'}


# Set our preferences

defaults write ${app_store_prefs} AutoUpdate -bool ${app_updates}
defaults write ${app_store_prefs} AutoUpdateRestartRequired -bool ${os_updates}

defaults write ${software_update_prefs} AutomaticCheckEnabled -bool ${auto_check}
defaults write ${software_update_prefs} AutomaticDownload -bool ${auto_download}
defaults write ${software_update_prefs} ConfigDataInstall -bool ${config_updates}
defaults write ${software_update_prefs} CriticalUpdateInstall -bool ${critical_updates}

echo "${ME}: Finished setting Software Update preferences..."
