#!/bin/sh

#######################################################################
#
# This script sets the computer name.
# If the computer is a desktop, then it is looked up by MAC address
# in the EdLAN database, and the HOSTNAME from the resulting entry
# is used.
#
# If the computer is a laptop, and $4 is set to LOGIN
# then the name will be based on the school code of the user
# who is currently logged in, combined with the computer serial number.
#
# Date: "Fri 23 Jun 16:26:38 2016 +0100"
# Version: 0.1.5
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
#######################################################################

LDAP_SERVER="ldaps://authorise.is.ed.ac.uk"
LDAP_BASE="dc=authorise,dc=ed,dc=ac,dc=uk"
LDAP_SCHOOL="eduniSchoolCode"
LDAP_FULLNAME="cn"
LDAP_UIDNUM="uidNumber"

EDLAN_DB="https://www.edlan-db.ucs.ed.ac.uk/webservice/pie.cfm"

main() {
  if [[ ${1} == 'LOGIN' ]]
  then
    # Use the logged-in user's name, probably because we are
    # being run immediately after setup of a DEP machine.
    uun="$(ls -l /dev/console | awk '{print $3}')"
  else
    # Need to ask the user. NOT IMPLEMENTED YET
    echo "This script will only run if $4 is set to LOGIN"
    exit 255
  fi
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

  # Check name is right
  livename=`/usr/sbin/scutil --get ComputerName`
  until [ $livename == $name ]; do
    /usr/sbin/scutil --set LocalHostName "${name}"
    /usr/sbin/scutil --set ComputerName "${name}"
    /usr/sbin/scutil --set HostName "${name}"
    # Set the NetBIOS name
    defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "${name}"
    sleep 2
    livename=`/usr/sbin/scutil --get ComputerName`
  done

  dscacheutil -flushcache

  #defaults write /System/Library/LaunchDaemons/com.apple.discoveryd "ProgramArguments" -array-add '<string>--no-namechange</string>'

  killall sysinfo
  open -a /Applications/sysinfo.app > /dev/null 2>&1

  echo "$0: Set machine name to ${name}"
  echo "$0: Updating JSS"

  /usr/local/bin/jamf recon -endUsername ${uun}
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
  school_code=$(ldapsearch -x -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
        -s sub "(uid=${uun})" "${LDAP_SCHOOL}" | awk -F ': ' '/^'"${LDAP_SCHOOL}"'/ {print $2}')

  # Just return raw eduniSchoolCode for now - ideally we'd like the human-readable abbreviation
  [ -z "${school_code}" ] && school_code="Unknown"

  logger "$0: School Code: ${school_code}"
  
  echo "${school_code}"
}

get_macaddr() {
  macaddr=$(ifconfig en0 ether | awk '/ether/ {print $NF}')
  logger "$0: MAC Address: ${macaddr}"
  echo ${macaddr}
}

get_edlan_dnsname() {
  mac=$(get_macaddr)
  netbios=$(curl --insecure "${EDLAN_DB}?MAC=${mac}&return=NetBIOS" 2>/dev/null) 
  # Remove anything potentially dodgy 
  #dnsname=`echo ${dnsfull} | awk -F "." '{print $1}'`
  echo ${netbios}
  logger "$0: NetBIOS Name: ${netbios}"
}

# Do something!
main "${4}"

exit 0;
