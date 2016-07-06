#!/bin/bash

LDAP_SERVER="ldaps://authorise.is.ed.ac.uk"
LDAP_BASE="dc=authorise,dc=ed,dc=ac,dc=uk"
LDAP_SCHOOL="eduniSchoolCode"
LDAP_FULLNAME="cn"
LDAP_UIDNUM="uidNumber"
EDLAN_DB="https://www.edlan-db.ucs.ed.ac.uk/webservice/pie.cfm"

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
      set uun to text returned of (display dialog "Welcome to the Mac Supported Desktop.\n\nPlease enter the University Username of the primary user of this computer.\n\nAn account will be created on this computer if it does not exist:"¬
      with title "University of Edinburgh Mac Supported Desktop" default answer "")
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
  pwd=$(sudo -u ${logged_in_user} osascript << EOF
  tell application "Finder"
      activate
      set pwd to text returned of (display dialog "Please enter the password for that username"¬
      with title "University of Edinburgh Mac Supported Desktop" default answer "" with hidden answer)
  end tell
  return pwd
  EOF
     )
  until $(valid_password ${uun} ${pwd})
  do
    get_password ${uun} 
  done
  echo ${pwd}
}

valid_username() {
  # Determine validity of a username by checking whether we can find the school code.
  uun=${1}
  logger "$0: Checking validity of username"
  if [ ! -z "$(get_school ${1})" ]
  then
    true
  else
    false
  fi
}
  
valid_password() {
  # Determine the user has typed the correct password
  # Uses expect to avoid passing a password on the commandline
  uun=${1}
  pwd=${2}


  result=$(/usr/bin/expect -f - << EOT
  spawn ldapsearch -W -D "uid=${uun},ou=people,ou=central,${LDAP_BASE}" -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
       -s sub "(uid=${uun})" "${LDAP_SCHOOL}"
  
  expect "Enter LDAP Password:*"
  send -- "${pwd}"
  send -- "\r"
  expect eof
EOT
	   )
  
  # Check we looked up a school code. Returns True or false
  [ ! -z "$(echo "${result}" | awk -F ': ' '/'"${LDAP_SCHOOL}"'/ {print $2}')" ]
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
    ;;
    *)
      name="Unknown"
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
    echo 0 
  else
    echo 1
    logger "$0: Local Account for ${uun} does not exist"
  fi
}


create_local_account() {
  logger "$0: Creating local account for ${uun}"
  uun="${1}"
  pwd="$(get_password ${uun})" 
  dscl . -create /Users/${uun}
  dscl . -create /Users/${uun} UserShell /bin/bash
  dscl . -create /Users/${uun} RealName "$(get_fullname ${uun})"
  dscl . -create /Users/${uun} UniqueID "$(get_uid_num ${uun})"
  dscl . -create /Users/${uun} PrimaryGroupID 20
  dscl . -create /Users/${uun} NFSHomeDirectory /Users/${uun}
  
  logger "$0: Setting password for ${uun}"
  # Avoid passing the password on the commandline 
  /usr/bin/expect -f - << EOT

  spawn dscl . -passwd /Users/${uun}

  expect "New Password:*"

  send -- "${pwd}" 
  send -- "\r"
  expect eof
EOT
}

update_jss() {
  /usr/local/bin/jamf recon -endUsername ${1}
}

### Execution starts here ###
#check_jss_available

uun=$(get_username)

set_machine_name ${uun}

if [ "$(has_local_account ${uun})" != "0" ]
then
  create_local_account ${uun}
fi

update_jss ${uun} 
