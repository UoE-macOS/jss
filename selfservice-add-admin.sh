#!/bin/bash

##############
# TempAdmin.sh
# This script will give a user 15 minutes of Admin level access.
# It is designed to create its own offline self-destruct mechanism.
##############

USERNAME=`who |grep console| awk '{print $1}'`

# create LaunchDaemon to remove admin rights
#####
echo "<?xml version="1.0" encoding="UTF-8"?> 
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"> 
<plist version="1.0"> 
<dict>
    <key>Disabled</key>
    <true/>
    <key>Label</key> 
    <string>uk.ac.ed.adminremove</string> 
    <key>ProgramArguments</key> 
    <array> 
        <string>/Library/Scripts/removeTempAdmin.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer> 
</dict> 
</plist>" > /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
#####

# create admin rights removal script
#####
echo '#!/bin/bash
USERNAME=`cat /var/admin-logs/userToRemove`
/usr/sbin/dseditgroup -o edit -d $USERNAME -t user admin
rm -f /var/admin-logs/userToRemove
rm -f /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
rm -f /Library/Scripts/removeTempAdmin.sh
exit 0'  > /Library/Scripts/removeTempAdmin.sh
#####

# set the permission on the files just made
chown root:wheel /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
chmod 644 /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
chown root:wheel /Library/Scripts/removeTempAdmin.sh
chmod 755 /Library/Scripts/removeTempAdmin.sh

# enable and load the LaunchDaemon
defaults write /Library/LaunchDaemons/uk.ac.ed.adminremove.plist Disabled -bool false
launchctl load -w /Library/LaunchDaemons/uk.ac.ed.adminremove.plist

# build log files in /var/admin-logs
mkdir /var/admin-logs
TIME=`date "+Date:%m-%d-%Y TIME:%H:%M:%S"`
echo $TIME " by " $USERNAME >> /var/admin-logs/15minAdmin

# note the user
echo $USERNAME >> /var/admin-logs/userToRemove

# give current logged user admin rights
/usr/sbin/dseditgroup -o edit -a $USERNAME -t user admin

# notify
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Applications/Utilities/Keychain\ Access.app/Contents/Resources/Keychain_Unlocked.png -heading 'Temporary Admin Rights Granted' -description "
Please use responsibly. 
All administrative activity is logged. 
Access expires in 15 minutes." -button1 'OK' > /dev/null 2>&1 &

exit 0
