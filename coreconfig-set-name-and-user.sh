#!/bin/bash

LDAP_SERVER="ldaps://authorise.is.ed.ac.uk"
LDAP_BASE="dc=authorise,dc=ed,dc=ac,dc=uk"
LDAP_SCHOOL="eduniSchoolCode"
LDAP_FULLNAME="cn"
LDAP_UIDNUM="uidNumber"

KRB_REALM='ED.AC.UK'

EDLAN_DB="https://www.edlan-db.ucs.ed.ac.uk/webservice/pie.cfm"
LOCK_FILE="/var/run/UoEQuickAddRunning"

JSS_URL="$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)"


check_jss_available() {
  # Can we see the JSS?
  logger "$0: Checking JSS availability for $JSS_URL"
  curl -I ${JSS_URL} &> /dev/null
  jss_status=$?

  if [ ${jss_status} -ne 0 ]
  then
    echo "Can't contact JSS at ${JSS_URL}"
    echo "Error status was: ${jss_status}"
    echo "Please contact support"
    exit 1
  else
    true
  fi
} 


get_fullname() {
   logger "$0: Looking for user fullname"
   full_name=$(ldapsearch -x -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
        -s sub "(uid=${1})" "${LDAP_FULLNAME}" | awk -F ': ' '/^'"${LDAP_FULLNAME}"'/ {print $2}')
   echo "${full_name}"
}

get_uid_num() {
   logger "$0: Looking for user id number"
   uid_num=$(ldapsearch -x -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
        -s sub "(uid=${1})" "${LDAP_UIDNUM}" | awk -F ': ' '/^'"${LDAP_UIDNUM}"'/ {print $2}')
   echo "${uid_num}"
}

## Who is going to be using this machine?
get_username() {
  logger "$0: Asking for username"
  logged_in_user=$( ls -l /dev/console | awk '{print $3}' )
  uun=$(sudo -u ${logged_in_user} osascript << EOF
  tell application "Finder"
      activate
      with timeout of 36000 seconds
        set uun to text returned of (display dialog "Welcome to the Mac Supported Desktop.\n\nPlease enter the University Username of the primary user of this computer.\n\nAn account will be created on this computer if it does not exist:"¬
        with title "University of Edinburgh Mac Supported Desktop" default answer ""¬
        buttons {"OK"} default button {"OK"})
      end timeout
  end tell
  return uun
  EOF
     )
  until $(valid_username ${uun})
  do
    get_username
  done
  echo ${uun}
}

get_password() {
  uun=${1}
  logger "$0: Asking for password"
  logged_in_user=$( ls -l /dev/console | awk '{print $3}' )
  pwd="$(sudo -u ${logged_in_user} osascript << EOF
  tell application "Finder"
      activate
      with timeout of 36000 seconds
        set the_result to (display dialog "Please enter the password for that username"¬
          with title "University of Edinburgh Mac Supported Desktop" default answer "" with hidden answer)
        set the_answer to text returned of the_result
      end timeout
  end tell
  return the_answer
  EOF
     )"
  until  [ $? != 0 ] || $(got_krb_tgt ${uun} "${pwd}") 
  do
    get_password ${uun} 
  done

  if [ -z "${pwd}" ]
  then
    false
  else
    echo "${pwd}"
  fi
}

valid_username() {
  # Determine validity of a username by checking whether we can find the school code.
  uun=${1}
  logger "$0: Checking validity of username"

  [ ! -z "$(get_school ${1})" ]
}
  
got_krb_tgt() {
  # Get a kerberos TGT
  # Avoid passing a password on the commandline
  # Use printf to avoid the shell interpreting any special chars
  uun="${1}"
  pwd="${2}"

  printf '%s' "${pwd}" | kinit --password-file=STDIN "${uun}@${KRB_REALM}"
}

get_mobility() {
  product_name=$(ioreg -l | awk '/product-name/ { split($0, line, "\""); printf("%s\n", line[4]); }')

  if echo "${product_name}" | grep -qi "macbook" 
  then
    mobility=mobile
  else
    mobility=desktop
  fi

  echo ${mobility}
  logger "$0: Mobility: ${mobility}"
}

get_serial() {
  serial_no=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')
  echo ${serial_no}
  logger "$0: Serial No: ${serial_no}"
}

get_school() {
  uun=${1}
  school_code=$(ldapsearch -x -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
        -s sub "(uid=${uun})" "${LDAP_SCHOOL}" | awk -F ': ' '/^'"${LDAP_SCHOOL}"'/ {print $2}')
  
  # Just return raw eduniSchoolCode for now - ideally we'd like the human-readable abbreviation 
  echo ${school_code}
  logger "$0: School Code: ${school_code}"
}

get_macaddr() {
  macaddr=$(ifconfig en0 ether | awk '/ether/ {print $NF}')
  logger "$0: MAC Address: ${macaddr}"
  echo ${macaddr}
}

get_edlan_dnsname() {
  mac=$(get_macaddr)
  dnsname=$(curl --insecure "${EDLAN_DB}?MAC=${mac}&return=DNS" 2>/dev/null) 
  # Remove anything potentially dodgy 
  dnsname=echo ${dnsname} | tr -cd "[[:alnum:]]-_."
  echo ${dnsname}
  logger "$0: DNS Name: ${dnsname}"
}

set_machine_name() {
  mobility=$(get_mobility)
  school="$(get_school ${uun})"
  case $mobility in
    mobile)
      name=${school}-$(get_serial)
    ;;
    desktop)
      name=$(get_edlan_dnsname)
      # If we don't get a name for some reason
      # then just use the same scheme as for
      # laptops.
      [ -z ${name} ] && name=${school}-$(get_serial)
    ;;
    *)
      name=${school}-"Unknown"
    ;;
  esac 
  /usr/sbin/scutil --set LocalHostName $( echo "${name}" | awk -F '.' '{print $1}' )
  /usr/sbin/scutil --set ComputerName "${name}"
  /usr/sbin/scutil --set HostName "${name}"
  logger "$0: Set machine name to ${name}"
}

has_local_account() {
  # Does a local account exist with ${uun}
  uun=${1}
  if acct=$(dscl . -list /Users | grep "^${uun}$")
  then
    logger "$0: Local Account for ${uun} exists"
    true 
  else
    logger "$0: Local Account for ${uun} does not exist"
    false
  fi
}


create_local_account() {
  logger "$0: Creating local account for ${uun}"
  uun="${1}"
  pwd="$(get_password ${uun})"
  if [ -z "${pwd}" ]
  then
       return 255
  fi
  dscl . -create /Users/${uun}
  dscl . -create /Users/${uun} UserShell /bin/bash
  dscl . -create /Users/${uun} RealName "$(get_fullname ${uun})"
  dscl . -create /Users/${uun} UniqueID "$(get_uid_num ${uun})"
  dscl . -create /Users/${uun} PrimaryGroupID 20
  dscl . -create /Users/${uun} NFSHomeDirectory /Users/${uun}
  
  logger "$0: Setting password for ${uun}"
  # Avoid passing the password on the commandline
	# We use printf '%q' to make sure that special
	# chars are escaped from being interpreted by
	# expect.
  result=$(/usr/bin/expect -f - << EOT
  log_user 0
  spawn -noecho dscl . -passwd /Users/${uun}
  expect "New Password:*"
  send -- $(printf '%q' "${pwd}") 
  send -- "\r"
  expect {
    "*DS Error:*" {
      send_user "Fail"
      exit
     }
    
     eof {
      send_user "Success"
      exit
     }
  }   
EOT
	)
  # Return a failure if we failed to set the password
  if [ "${result}" == "Success" ]
  then
    return 0
  else
    return 255
  fi
  
}

update_jss() {
  /usr/local/bin/jamf recon -endUsername ${1}
}

trigger_core_apps() {
  # trigger the 'core-apps' event which will kick off the
  # installation of our core applications
  /usr/local/bin/jamf policy -event core-apps
}

warn_no_user_account() {
  uun=${1}
  logged_in_user=$( ls -l /dev/console | awk '{print $3}' )
  sudo -u ${logged_in_user} osascript << EOT
   tell application "Finder"
    activate
    display dialog "Warning - local account creation failed for ${uun}\n\nYou will need to create one manually."¬      
    buttons {"OK"} default button {"OK"}      
    end tell
EOT
  
}

success_message() {
  uun=${1}
  logged_in_user=$( ls -l /dev/console | awk '{print $3}' )
  sudo -u ${logged_in_user} osascript << EOT
    tell application "Finder"
    activate
    display dialog "A local user account has been created for ${uun}."¬
    buttons {"OK"} default button {"OK"}           
    end tell
EOT
  
}

success_message_existing_account() {
  uun=${1}
  logged_in_user=$( ls -l /dev/console | awk '{print $3}' )
  sudo -u ${logged_in_user} osascript << EOT
    tell application "Finder"
    activate
    display dialog "We found a local account for ${uun}.\n\nIt has not been altered in any way."¬
    buttons {"OK"} default button {"OK"}           
    end tell
EOT
  
}

delete_lcfg() {
	# Display a message in the background...
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
 -windowType utility\
 -title 'UoE Mac Supported Desktop'\
 -heading 'Removing LCFG'\
 -icon '/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns'\
 -timeout 99999\
 -description "$(echo -e We are removing the previous management framework.\\n\\nThis will take several minutes.\\nPlease do not restart your computer)" &

	/usr/local/bin/jamf policy -event delete-lcfg

	killall jamfHelper
}

	
### Execution starts here ###
check_jss_available

# Drop a lock file so that other processes know
# we are running

touch "${LOCK_FILE}"

uun=$(get_username)

set_machine_name ${uun}

if ! $(has_local_account ${uun})
then
  create_local_account ${uun}
  if [ ${?} != 0 ]
  then
    warn_no_user_account ${uun}
  else
    success_message ${uun}
  fi  
else
  success_message_existing_account ${uun}
fi

# If an old LCFG installation exists, delete it.
delete_lcfg

# Run recon to let the JSS know who the primary user of this machine will be
update_jss ${uun} 

# Display this message but send the jamfhelper process into the background
# so that execution continues
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
 -windowType utility\
 -title 'UoE Mac Supported Desktop'\
 -heading 'Checking Core Applications'\
 -icon '/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns'\
 -timeout 99999\
 -description "$(echo -e We are ensuring that your core applications and system software are up to date.\\n\\nThis will take several minutes.\\nPlease do not restart your computer)" &

# Run any policies that are triggered by the 'core-apps' event  
trigger_core_apps

# Run softwareupdate to install any recommended updates
softwareupdate -i -r

# CoreApps are done now, kill the info window.
killall jamfHelper

/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
  -windowType utility\
  -title 'UoE Mac Supported Desktop'\
  -heading 'Please restart'\
  -icon '/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns'\
  -description "$(echo -e Core installation complete.\\n\\nPlease restart and log in as ${uun} to complete the setup.)"\
  -timeout 99999\
  -button1 'Restart now'

# We are done - delete our lock file
rm "${LOCK_FILE}"

# We didn't give the user a choice, so...
reboot
