#!/bin/bash

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
# Date: "Tue  5 Jun 2018 10:47:32 BST"
# Version: 0.1.7
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
      echo $name Laptop
    ;;
    desktop)
      name=$(get_edlan_dnsname)
      # If we don't get a name for some reason
      # then just use the same scheme as for
      # laptops.
      
      [ -z ${name} ] && name=${school}-$(get_serial)
      
      echo $name Desktop
    ;;
    *)
      echo $mobility
      name=$(get_support)-$(get_serial)
      
      echo $name Wildcard
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
# Needs to go to STDERR to avoid passing back bad values.
echo "$0: Mobility: ${mobility}">&2

echo ${mobility}
}

get_serial() {
  # Full serial is a bit long, use the last 8 chars instead.
  serial_no=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}' | tail -c 9)
  # Needs to go to STDERR to avoid passing back bad values.
  echo "$0: Serial No: ${serial_no}" >&2

  echo ${serial_no}
}

get_school() {
  uun=${1}
  school_code=$(ldapsearch -x -H "${LDAP_SERVER}" -b "${LDAP_BASE}"\
        -s sub "(uid=${uun})" "${LDAP_SCHOOL}" | awk -F ': ' '/^'"${LDAP_SCHOOL}"'/ {print $2}')

  # Just return raw eduniSchoolCode for now - ideally we'd like the human-readable abbreviation
  [ -z "${school_code}" ] && school_code="Unknown"

  # Needs to go to STDERR to avoid passing back bad values.
  echo "$0: School Code: ${school_code}" >&2
  
  echo "${school_code}"
}

get_macaddr() {
  active_adapter=`route get ed.ac.uk | grep interface | awk '{print $2}'`
  macaddr=$(ifconfig $active_adapter ether | awk '/ether/ {print $NF}')
  # Needs to go to STDERR to avoid passing back bad values.
  echo "$0: MAC Address: ${macaddr}" >&2
  
  echo ${macaddr}
}

get_edlan_dnsname() {
  mac=$(get_macaddr)
  if ! [ -z ${mac} ]; then
     #dnsfull=$(curl --insecure "${EDLAN_DB}?MAC=${mac}&return=DNS" 2>/dev/null) *** Comment out to work with 10.13, pending edlan changes.
     dnsfull=`python -c "import urllib2, ssl;print urllib2.urlopen('${EDLAN_DB}?MAC=${mac}&return=DNS', context=ssl._create_unverified_context()).read()"`
     # Remove anything potentially dodgy 
     dnsname=`echo ${dnsfull} | awk -F "." '{print $1}'`
     # Needs to go to STDERR to avoid passing back bad values.
     echo "$0: DNS Name: ${dnsname}" >&2
  fi
  
  echo ${dnsname}
}

get_support() {
# Try using the local support account to define the name if we can't define it in other ways, like non-uun accounts or ldap/network issue.
ITSupport=`ls /Users | grep -v "uoesupport" | grep "support"`
if [ -z "$ITSupport" ]; then 
    # Check for the named accounts
    GeoSupport=`ls /Users  | grep "geosadm"`
    if ! [ -z "$GeoSupport" ]; then 
        SupportAccount="$GeoSupport" 
    fi
    SSPSupport=`ls /Users  | grep "sspsitadmin"`
    if ! [ -z "$SSPSupport" ]; then 
        SupportAccount="$SSPSupport" 
    fi
    BioSupport=`ls /Users | grep "sbsadmin"`
    if ! [ -z "$BioSupport" ]; then 
        SupportAccount="$BioSupport" 
    fi
else
    SupportAccount="$ITSupport" 
fi

case $SupportAccount in
camsupport)
  Code="P7A"
  ;;
csesupport)
  Code="P73"
  ;;
divsupport)
  Code="S27"
  ;;
ecasupport)
  Code="S2A"
  ;;
econsupport)
  Code="S23"
  ;;
educsupport)
  Code="S29"
  ;;
eusasupport )
  Code="P99"
  ;;
geosadm)
  Code="S4B"
  ;;
geossupport)
  Code="S4B"
  ;;
hcasupport)
  Code="S2B"
  ;;
healthsupport)
  Code="S2F"
  ;;
isgsupport)
  Code="P5L"
  ;;
lawsupport)
  Code="S26"
  ;;
mathsupport)
  Code="S46"
  ;;
mvmsupport)
  Code="S37"
  ;;
pplssupport)
  Code="S2C"
  ;;
ppssupport)
  Code="P7F"
  ;;
  sbsadmin)
  Code="S42"
  ;;
scecollsupport)
  Code="S4A"
  ;;
sopasupport )
  Code="S44"
  ;;
sspsitadmin)
  Code="S22"
  ;;
srssupport)
  Code="P7K"
  ;;
*)
  Code="Unknown"
  ;;
esac
# Needs to go to STDERR to avoid passing back bad values.
echo "$0: School Code (based on support account): ${Code}" >&2

echo "${Code}"
}

# Do something!
main "${4}"

exit 0;
