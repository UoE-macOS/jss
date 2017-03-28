#!/bin/sh

###################################################################
#
# Script which could be published via self-service to allow
# users to add their own Active Directory homeDirectory to their
# 'favourites' sidebar, simplifying access.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################


LDAP_HOST='ldap://oban.ed.ac.uk'
LDAP_BASE='dc=ed,dc=ac,dc=uk'
LDAP_HOMEDIR='homeDirectory'

main() {
	# Get username and password
	user=$(get_console_user)
	password=$(get_password ${user})

	# Get a kerberos TGT, to allow us to query AD LDAP
  get_tgt $password

	# get the user's AD homePath from LDAP
	homepath=$(get_homepath ${user})

	# Datastore doesn't support kerberos, so
  # add an entry to the user's keychain
	add_keychain_entry "${user}" "${password}" "${homepath}"

	# Mount the network home and work out
	# where it'e been mounted locally
	localpath=$(mount_home "${homepath}")

	# Add it to the Finder sidebar
	add_to_faves "${localpath}"
}


get_console_user() {
        echo `/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser;\
              import sys;\
              username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0];\
              username = [username,""][username in [u"loginwindow", None, u""]];\
              sys.stdout.write(username + "\n")'`
}

get_password() {
	user=${1}
	password=$(sudo -u ${user} osascript - <<EOF
  tell application "Finder"
      activate
      with timeout of 36000 seconds
        set thePwd to text returned of (display dialog "Enter the Active Directory password for ${user}"¬
        default answer "" buttons {"OK"} default button 1 ¬
        with hidden answer)
      end timeout
  end tell
  return thePwd
EOF
					)
	/bin/echo -n ${password}
}

get_tgt() {
  password=${1}
	printf '%s' "${password}" | kinit --password-file=STDIN
}

get_homepath() {
	user=${1}
	ldapsearch -H "${LDAP_HOST}" -b "${LDAP_BASE}" -s sub "(cn=${user})" "${LDAP_HOMEDIR}" 2>/dev/null | \
		awk ' /^homeDirectory/ {print $2}' |\
		sed -E 's|\\|/|g; s|//||g'
}

add_keychain_entry() {
	user=${1}
	password=${2}
	server="$(echo ${3} | awk -F '/' '{print $1}')"
	sudo -u "${user}" echo "add-internet-password -a "${user}" -d ED -s "${server}" -r 'smb ' -w "$(printf '%q' ${password})" -T '/System/Library/CoreServices/NetAuthAgent.app' -U /Users/${user}/Library/Keychains/login.keychain" \
    | security -i
	}

mount_home() {
	path=${1}
	sudo -u ${user} osascript -e "mount volume \"smb://${path}\"" >/dev/null
	localpath=$(mount | egrep "$path\s" | awk '{print $3}')
	echo $localpath
}

add_to_faves() {
	localpath=${1}
	/usr/bin/sfltool add-item com.apple.LSSharedFileList.FavoriteItems "file://${localpath}"
}
  

main
