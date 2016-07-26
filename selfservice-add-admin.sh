#!/bin/bash

##############
# TempAdmin.sh
# This script will give a user 15 minutes of Admin level access.
# It is designed to create its own offline self-destruct mechanism.
##############

USERNAME=`who |grep console| awk '{print $1}'`
LOGS='/var/admin-logs'

# create LaunchDaemon to remove admin rights
#####
echo '<?xml version="1.0" encoding="UTF-8"?> 
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
</plist>' > /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
#####

# create admin rights removal script
#####

cat > /Library/Scripts/removeTempAdmin.sh << EOT
#!/bin/bash
USERNAME="\$(cat ${LOGS}/userToRemove)"
TIME="\$(date '+Date:%m-%d-%Y TIME:%H:%M:%S')"

/usr/sbin/dseditgroup -o edit -d $USERNAME -t user admin
echo "\$TIME REVOKED \$USERNAME" >> "${LOGS}/15minAdmin"

rm -f "${LOGS}/userToRemove"

launchctl unload -w  /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
rm -f /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
rm -f /Library/Scripts/removeTempAdmin.sh

## What happens if nobody is logged in?
osascript -e 'display notification "Local administrator privileges have been revoked" with title "Admin Revoked"'
exit 0
EOT

# set the permission on the files just made
chown root:wheel /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
chmod 644 /Library/LaunchDaemons/uk.ac.ed.adminremove.plist
chown root:wheel /Library/Scripts/removeTempAdmin.sh
chmod 755 /Library/Scripts/removeTempAdmin.sh

# enable and load the LaunchDaemon
launchctl load -w /Library/LaunchDaemons/uk.ac.ed.adminremove.plist

# build log files in /var/admin-logs
[ ! -d "${LOGS}" ] && mkdir "${LOGS}"
TIME=`date "+Date:%m-%d-%Y TIME:%H:%M:%S"`
echo $TIME " by " $USERNAME >> "${LOGS}"/15minAdmin

# note the user
echo $USERNAME >> "${LOGS}"/userToRemove

# give current logged user admin rights
/usr/sbin/dseditgroup -o edit -a $USERNAME -t user admin

# notify
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Applications/Utilities/Keychain\ Access.app/Contents/Resources/Keychain_Unlocked.png -heading 'Admin Rights Granted' -description "
Please use responsibly. 
All administrative activity is logged. 
Access expires in 15 minutes." -button1 'OK' > /dev/null 2>&1 &

exit 0
