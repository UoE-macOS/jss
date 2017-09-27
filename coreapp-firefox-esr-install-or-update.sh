#!/bin/sh

###################################################################
#
# This script will check whether the currently installed version
# of Firefox ESR matches that available from Mozilla's servers. If
# the versions differ, it will download the latest version and
# install it.
#
#
# Date: "Tue 26 Sep 2017 13:59:43 BST"
# Version: 0.1.1
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################

# We may want to version lock Firefox ESR or can let it upgrade from vendor derived info.
if [ -z "$4"] || [ "$4" == '' ]; then
  available_version="$(curl https://www.mozilla.org/en-US/firefox/organizations/all/ | grep "data-esr-versions=" | awk -F '"' '{print $10}')"
else
  available_version="$4"
fi

DOWNLOAD_URL="http://download-origin.cdn.mozilla.net/pub/firefox/releases/${available_version}esr/mac/en-GB/Firefox ${available_version}esr.dmg"

installed_version="$(defaults read /Applications/Firefox.app/Contents/info CFBundleShortVersionString)"

install_Firefox() {
  # Create a temporary directory in which to mount the .dmg
  tmp_mount=`/usr/bin/mktemp -d /tmp/firefox.XXXX`
  
  # Attach the install DMG directly from Mozilla's servers (ensuring HTTPS)
  hdiutil attach "$( eval echo "${DOWNLOAD_URL}" )" -nobrowse -quiet -mountpoint "${tmp_mount}"
  
  rm -dfR "/Applications/Firefox.app"

  ditto "${tmp_mount}/Firefox.app" "/Applications/Firefox.app"
  
  # Let things settle down
  sleep 1
  
  # Detach the dmg and remove the temporary mountpoint
  hdiutil detach "${tmp_mount}" && /bin/rm -rf "${tmp_mount}"

  if [ -e "/Applications/Firefox.app" ]; then
    echo "******Latest version of Firefox ESR is installed on target Mac.******"
  fi
}

check_Running ()
{
# To find if the app is running, use:
ps -A | grep "Firefox.app" | grep -v "grep" > /tmp/RunningApps.txt

if grep -q "Firefox.app" /tmp/RunningApps.txt;
then
	echo "******Application is currently running on target Mac. Installation of Firefox ESR cannot proceed.******"
	exit 1;
else
    echo "******Application is not running on target Mac. Proceeding...******"
    install_Firefox
    exit 0
fi
}

# If the version installed differs at all from the available version
# then we want to update

case "${installed_version}" in
  "${available_version}")
    echo "****** Firefox version checked OK (${available_version}) ******"
    ;;
  *) 
    echo "****** Firefox version differs - installed: ${installed_version}, available: ${available_version} ******"
    check_Running
    ;;
esac

exit 0;
