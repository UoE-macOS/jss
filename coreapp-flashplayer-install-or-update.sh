#!/bin/sh

###################################################################
#
# This script will check whether the currently installed version
# of Flash Player matches that available from Adobe's servers. If
# the versions differ, it will download the latest version and
# install it.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

install_flash() {
  # Create a temporary directory in which to mount the .dmg
  tmp_mount=`/usr/bin/mktemp -d /tmp/flashplayer.XXXX`
  
  # Attach the install DMG directly from Adobe's servers (ensuring HTTPS)
  hdiutil attach "$( eval echo "${DOWNLOAD_URL}" )" -nobrowse -quiet -mountpoint "${tmp_mount}"
  
  # The package has used some slightly different naming schemes
  pkg_path="$(/usr/bin/find ${tmp_mount} \( -iname \*Flash*\.pkg -o -iname \*Flash*\.mpkg \))"

  # Install the package, logging as much as we can
  /usr/sbin/installer -dumplog -verbose -pkg "${pkg_path}" -target "/"
  
  # Let things settle down
  sleep 1
  
  # Detach the dmg and remove the temporary mountpoint
  hdiutil detach "${tmp_mount}" && /bin/rm -rf "${tmp_mount}"
}

configure_flash() {
# Create mms.cfg file that sets the Flash Player preferences never to check for updates, since we use this script to.
# The /Library/Application\ Support/Macromedia folder it gets created in should already exist as this step is after the Flash install.

echo "****** Setting Flash Player to never check for updates ******"

cat <<EOF > /Library/Application\ Support/Macromedia/mms.cfg
AutoUpdateDisable=1
SilentAutoUpdateEnable=0
EOF

# Set file permissions
chown -R root:admin /Library/Application\ Support/Macromedia/mms.cfg  
}


## URL pointing to a direct download of the Flash Player disk image
DOWNLOAD_URL=`curl http://get.adobe.com/flashplayer/webservices/json/ | python -m json.tool | grep osx.dmg | awk -F '"' '{sub(/^http:/, "https:", $4); print $4}'`

ME=$(basename "${0}")

installed_version="$(defaults read /Library/Internet\ Plug-Ins/Flash\ Player.plugin/Contents/version CFBundleShortVersionString)"

available_version="$(/usr/bin/curl --silent http://fpdownload2.macromedia.com/get/flashplayer/update/current/xml/version_en_mac_pl.xml |\
                 grep 'update version' | sed -E 's/.*update version="([0-9,]+)".*/\1/;s/,/./g')"

# If the version installed differs at all from the available version then we want to update
case "${installed_version}" in
  "${available_version}")
    echo "$ME: Flash version checked OK (${available_version})"
    ;;
  *) 
    echo "$ME: Flash version differs - installed: ${installed_version} available ${available_version}"
    install_flash
    ;;
esac

# Apply the Flash preferences config.

if [ -d /Library/Application\ Support/Macromedia ]; then
	configure_flash
else
	mkdir /Library/Application\ Support/Macromedia
    configure_flash
fi

exit 0;
