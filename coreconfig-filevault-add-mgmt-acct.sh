#!/bin/bash

###################################################################
#
# If this script is running, filevault is
# enabled but we neither have a valid recovery
# key nor is our management account able to 
# unlock the disk - we don't want to be in this 
# situation so we try to persuade the user to give
# us credentials that will allow us to add the 
# management user to filevault.
#
# Date: "Mon Sep 04 16:26:38 2016 +0100"
# Version: 0.1.4
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################

current_user="${3}"
mgmt_user="${4}"
mgmt_pass="${5}"

get_password() {
  logger "$0: Asking for password"
  pwd="$(sudo -u ${current_user} osascript << EOF
  repeat while application "Finder" is not running
    delay 1
  end repeat
  tell application "Finder"
      activate
      with timeout of 36000 seconds
        set the_result to (display dialog "The Mac Supported Desktop requires access to the FileVault encryption on this computer to back up its encryption key.\n\nEnter the password of an account which can unlock FileVault on this computer (this may be your own logon password).\n\nOur use of this password is secure, and used only to safely gather the Filevault key. The password you type is not stored in any way. If you are unsure how to proceed, or want more information, contact the IS Helpline on 0131 6515151 advising that you are receiving this message."¬
          buttons {"Accept"} default button 1 with title "University of Edinburgh Mac Supported Desktop" default answer "" with hidden answer)
        set the_answer to text returned of the_result
      end timeout
  end tell
  return the_answer
  EOF
     )"

  if [ -z "${pwd}" ]
  then
    false
  else
    echo "${pwd}"
  fi
}

user_pwd="$(get_password)"

# Try enabling filevault
/usr/bin/expect -f- << EOT
  spawn /usr/bin/fdesetup add -usertoadd "${mgmt_user}"; 
  expect "Enter a password for '/', or the recovery key:*"
  send -- $(printf '%q' "${user_pwd}")  
  send -- "\r"
  expect "Enter the password for the added user '${mgmt_user}':*" 
  send -- $(printf '%q' "${mgmt_pass}") 
  send -- "\r"
  expect eof;
EOT

# Did we succeed?
if fdesetup list | grep -q ${mgmt_user}
then
  echo "Successs!"
  # Report our new-found success to the JSS
  /usr/local/bin/jamf recon
  exit 0
else
  echo "Failed :("
  exit 255
fi
