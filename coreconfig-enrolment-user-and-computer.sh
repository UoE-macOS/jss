#!/bin/bash

###################################################################
#
# This script is run at enrollmentcomplete on non-DEP machines.
# We assume that the quickadd package is being run by a user who
# may or may not be the intended primary user of the machine.
#
# The script will ask for the username of the primary user (if run when a user 
# is logged on) and, if a password is provided which matches our dircetory service
# and there is no existing account for that user on this machine, will
# then create a local account for that user. If the machine is a
# laptop it is named with a compbination of that user's school code
# and the serial number. If it is a desktop the name is looked up
# in our network database.
#
# Finally the policy to install our core-applications is called.
#
# Date: "Tue  7 May 2019 15:07:29 BST"
# Version: 0.2.0
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: ganders1
#
##################################################################


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
  exit
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
    printf '%s' "${pwd}"
    exit # Make sure we don't print the password multiple times!
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

get_cmd() {
    # These are the two background install locations.
    cmd1="installer -pkg /Library/MacMDP/Downloads/QuickAdd-0.2-1.pkg"
    cmd2="installer -pkg /Library/Application Support/JAMF/Downloads/QuickAdd-0.2-1.pkg"
    # Determine installation process
    checkprocess1=`ps -A | grep "$cmd1" | grep -v "grep"`
    checkprocess2=`ps -A | grep "$cmd2" | grep -v "grep"`

    if [ -z $checkprocess1 ] && [ -z $checkprocess2 ]; then
	    background="False"
    else
	    background="True"
    fi
    echo ${background}
}

health_check() {
if [ $dialogue == "YES" ]; then
	# Display a message in the background...
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
 -windowType utility\
 -title 'UoE Mac Supported Desktop'\
 -heading 'System Health Check'\
 -icon '/Applications/Utilities/Disk Utility.app/Contents/Resources/AppIcon.icns'\
 -timeout 99999\
 -description "$(echo -e We are verifying your disk and clearing caches.\\n\\nThis will take several minutes.\\nPlease do not restart your computer)" &
	/usr/local/bin/jamf policy -event Health-Check
	killall jamfHelper
else
	/usr/local/bin/jamf policy -event Health-Check
fi
}

bind_ad() {
/usr/local/bin/jamf policy -event Bind-AD
}

trigger_core_apps() {
if [ $dialogue == "YES" ]; then
	# Display this message but send the jamfhelper process into the background
	# so that execution continues
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
 -windowType utility\
 -title 'UoE Mac Supported Desktop'\
 -heading 'Checking Core Applications'\
 -icon '/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns'\
 -timeout 99999\
 -description "$(echo -e We are ensuring that your core applications are installed and up-to-date.\\n\\nThis will take several minutes.\\n\\nPlease do not restart your computer.)" &
	/usr/local/bin/jamf policy -event Core-Apps
	killall jamfHelper
else
	/usr/local/bin/jamf policy -event Core-Apps
fi
}

trigger_software_update() {
if [ $dialogue == "YES" ]; then
	# Display this message but send the jamfhelper process into the background
	# so that execution continues
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
 -windowType utility\
 -title 'UoE Mac Supported Desktop'\
 -heading 'Checking Software Update'\
 -icon '/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns'\
 -timeout 99999\
 -description "$(echo -e We are ensuring that your Operating System is up-to-date.\\n\\nThis will take several minutes.\\n\\nPlease do not restart your computer.)" &
	/usr/local/bin/jamf policy -event runsoftwareupdate
	killall jamfHelper
else
	/usr/local/bin/jamf policy -event runsoftwareupdate
fi
}

trigger_os_installer() {
if [ $dialogue == "YES" ]; then
	# Display this message but send the jamfhelper process into the background
	# so that execution continues
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
 -windowType utility\
 -title 'UoE Mac Supported Desktop'\
 -heading 'Checking Core Applications'\
 -icon '/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns'\
 -timeout 99999\
 -description "$(echo -e We are now putting the new macOS installer in-place.\\n\\nThis should take 20 to 30 minutes.\\n\\nYou will be able to launch the upgrade from Self Service once this installation is complete.\\n\\nPlease do not restart your computer.)" &
	/usr/local/bin/jamf policy -event OS-Installer
	killall jamfHelper
else
	/usr/local/bin/jamf policy -event OS-Installer
fi
}

do_restart () {
username=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

if [ -z $username ] || [ "$username" == '' ]; then
	dialogue="NO"
else
	dialogue="YES"
fi
    
if [ $dialogue == "YES" ]; then
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
else
rm "${LOCK_FILE}"
reboot
fi
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
  # Full serial is a bit long, use the last 8 chars instead.
  serial_no=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}' | tail -c 9)
  echo ${serial_no}
  logger "$0: Serial No: ${serial_no}"
}

get_school() {
  uun=${1}
  school_code=$(ldapsearch -x -H "${LDAP_SERVER}" -b"${LDAP_BASE}" -s sub "(uid=${uun})" "${LDAP_SCHOOL}" | awk -F ': ' '/^'"${LDAP_SCHOOL}"'/ {print $2}')
        
  # Just return raw eduniSchoolCode for now - ideally we'd like the human-readable abbreviation
  [ -z "${school_code}" ] && school_code="Unknown"
  echo ${school_code}
  logger "$0: School Code: ${school_code}"
}

get_macaddr() {
  active_adapter=`route get ed.ac.uk | grep interface | awk '{print $2}'`
  macaddr=$(ifconfig $active_adapter ether | awk '/ether/ {print $NF}')
  logger "$0: MAC Address: ${macaddr}"
  echo ${macaddr}
}


get_edlan_dnsname() {
  mac=$(get_macaddr)
  if ! [ -z ${mac} ]; then
     #dnsfull=$(curl --insecure "${EDLAN_DB}?MAC=${mac}&return=DNS" 2>/dev/null) *** Comment out to work with 10.13, pending edlan changes.
     dnsfull=`python -c "import urllib2, ssl;print urllib2.urlopen('${EDLAN_DB}?MAC=${mac}&return=DNS', context=ssl._create_unverified_context()).read()"`
     # Remove anything potentially dodgy 
     dnsname=`echo ${dnsfull} | awk -F "." '{print $1}'`
     echo ${dnsname}
  fi
  logger "$0: DNS Name: ${dnsname}"
}

set_computer_name() {
uun=${1}
if [ $dialogue == "YES" ]; then
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
else
	/usr/local/bin/jamf policy -event Set-Desktop-Name
fi
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

create_mobile_account() {
	logger "$0: Creating mobile account for ${uun}"
	uun="${1}"
	if [ -z "${uun}" ] || [ "${uun}" == '' ]; then
	    logger "$0: Something went wrong, no username passed xx ${uun} xx"
        return 255
	else
	    mkdir /Users/$uun
	    chown -R $uun /Users/$uun
	    /System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -v -n $uun
	fi

    create_check=`dscl . -read /Users/${uun} RecordName`
    if [ "${create_check}" == "RecordName: ${uun}" ]; then
        return 0
    else
        logger "$0: Something went wrong, could not create mobile account xx ${uun} xx. Machine may not be bound to AD."
        return 255
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
  # Create the home folder
  createhomedir -c -u $uun
  
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

# Drop a lock file so that other processes know
# we are running

touch "${LOCK_FILE}"

# Is there a user logged in
username=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`
dialogue=""

# What OS is running?
osversion=`sw_vers -productVersion | awk -F . '{print $2}'`


if [ -z $username ] || [ "$username" == '' ]; then
	dialogue="NO"
else
	cmdinstall=$(get_cmd)
	case $cmdinstall in
		True)
		dialogue="NO"
		;;
		False)
		dialogue="YES"
		;;
		*)
		dialogue="NO"
		;;
	esac
fi

usertype=""
  mobility=$(get_mobility)
  case $mobility in
    mobile)
      usertype=Local
    ;;
    desktop)
	usertype=Mobile
    ;;
  esac 

if [ $dialogue == "YES" ]; then
uun=$(get_username)
else
uun=""
# No user logged in, so try the last 5 users
lastusers=$(last -9 | awk '{print $1}')
for user in $lastusers
do
	if ! [ "$(get_school ${user})" == "Unknown" ] ||
	 ! [ -z "$(get_school ${user})" ]
	then
	uun=$user
	fi
done
fi

# Set the computers name
set_computer_name ${uun}

if ! $(has_local_account ${uun})
then
  if [ $usertype == "Mobile" ]
  then
  bind_ad
  create_mobile_account ${uun}
  fi
  if [ $usertype == "Local" ] || [ -z $usertype ]
  then
  create_local_account ${uun}
  fi
  if [ ${?} != 0 ]
  then
  	if [ $dialogue == "YES" ]; then
    warn_no_user_account ${uun}
    fi
  else
  	if [ $dialogue == "YES" ]; then
    success_message ${uun}
    fi
  fi  
else
  if [ $dialogue == "YES" ]; then
  success_message_existing_account ${uun}
  fi
fi

# Run recon to let the JSS know who the primary user of this machine will be
update_jss ${uun} 

# Run any policies that are triggered by the 'Core-Apps' event  
trigger_core_apps

# Run any policies that are triggered by the 'OS-Installer' event  

free_space=`diskutil info / | grep "Free Space" | awk '{print $4}' | awk -F "." '{print $1}'`

if [ $osversion == "12" ] || [ $osversion == "13" ]; then
	logger "$0: OS installer already in-place or OS on version 12 or 13."
else
    if [ "${usertype}" == "desktop" ]; then
        if [ $free_space -ge 25 ]; then
	        trigger_os_installer
	    else
	        logger "$0: Not enough free disk space to continue"
	    fi
	fi
fi

health_check

# Cache offline policies for login items
#/usr/local/bin/jamf policy -event Login
/usr/local/bin/jamf policy -event Dock
/usr/local/bin/jamf policy -event LoginItem

# Check whether School/dept's local admin account exists and, if not, created it
/usr/local/bin/jamf policy -event Check-Local-Admin

# Check if the Mac is already encrypted and prompt so the key can be escrowed.
fv_status=`fdesetup status | awk '{print $3}'`

if [ "${fv_status}" == "On." ]; then
	/usr/local/bin/jamf policy -event FileVault-Ctrl
fi

# Last thing before a restart check for OS updates
trigger_software_update

# Time to do a restart
do_restart

exit 0;
