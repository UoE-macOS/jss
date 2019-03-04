#!/bin/bash

###################################################################
#
# Script to mount multiple shares on login.
# Run it as a login script.
#
# $1 $2 and $3 are ignored.
#
# $4 should be an integer timeout in seconds to wait for a server to be mounted.
#
# Pass as many arguments as desired from $5 onwards, as a share URL and 
# we will attempt to mount each of them.
#
# We will not attempt to mount hosts that don't respond to a ping
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

run_with_timeout () {
    # This hack allows us to run a process and kill it if it hasn't 
    # returned within `timeout` seconds. The process needs to have 
    # the string MyProcessIdentifier-`id` somewhere in its commandline
    # so that we can find it to kill it.

    # This is necessary because if osascript fails to mount a server
    # it pops a dialog on the screen and will wait indefinitely until
    # the user dismisses it - when this script is run as a login script
    # this results in an indefinite hang of the login process if a server
    # is unavailable.

    timeout_seconds="$1"
    shift

    my_id="$1"
    shift

    # Start timeout - this will kill any process belonging to $username and
    # with 'MyProcessIdentifier-${my_id}' in its command line after $timeout_seconds
    (
        sleep "$timeout_seconds"
        write_log "Timed out after $timeout_seconds seconds"
        kill $(ps aux | grep ^${username}.*[M]yProcessIdentifier-${my_id} | awk '{print $2}') &>/dev/null
    ) & 2>/dev/null
    timeout_pid=$!

    # Run the rest of the argument list
    "$@" 

    # Stop timeout
    kill $timeout_pid &>/dev/null
}

username=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (
        SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][
            username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

shift; shift; shift # Discard args 1, 2 and 3

timeout=${1}
shift

urls="${@}"

for url in ${urls}
do 
    # Don't bother trying to mount the host if it's unavailable
    if echo ${url} | egrep -q '(afp|smb|nfs)://'
    then 
        write_log "Attempting to mount ${url}"
        # `MyProcessIdentifier-${my_id}` is a dummy argument which is used by the run_with_timeout() function
        # to find the process and kill it if it times out. 
        my_id=$RANDOM
        run_with_timeout ${timeout} ${my_id} sudo -u ${username} /usr/bin/osascript - MyProcessIdentifier-${my_id}  << EOT
        with timeout of 10 seconds -- This timeout is ineffective.
            tell application "Finder" 
                try
                    mount volume "${url}"
                on error
                    return
                end try
            end tell
        end timeout
EOT
    fi
done
