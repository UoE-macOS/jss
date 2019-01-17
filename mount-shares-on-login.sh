#!/bin/bash

###################################################################
#
# Script to mount multiple shares on login.
# Run it as a login script.
#
# Pass as many arguments as deesired from $4 onwards, as a share URL and 
# we will attempt to mount each of them.
#
# Last Changed: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
###################################################################

write_log () {
    /bin/echo "$(date +"%a %b %d %T"): ${1}" 
}

username=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (
        SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][
            username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

urls="${@}"

for url in ${urls}
do 
    if echo ${url} | egrep -q '(afp|smb|nfs)://'
    then 
        write_log "Attempting to mount ${url}"

        sudo -u ${username} /usr/bin/osascript > /dev/null << EOT
        with timeout of 10 seconds
            tell application "Finder"    
                mount volume "${url}"
            end tell
        end timeout
EOT
    fi
done
