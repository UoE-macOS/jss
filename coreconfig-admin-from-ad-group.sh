#!/bin/bash

###################################################################
#
# Script to assign admin rights based on the membership of an AD group
# with the Computers name. NoMAD caches user AD group membership, so 
# admin rights will remain, even when the machine is offsite.
#
# Date: Mon Jan 15 16:17:19 GMT 2018
# Version: 0.1.9
# Creator: dsavage
#
##################################################################


Random_Domain_Controller ()
{
Random_DC="aviemore brora ceres crieff cromarty kelso leven oban vesta"
Num_Random=`echo $Random_DC | wc -w`
Random_Number=`jot -r 1 1 $Num_Random`
Select_DC=`eval echo \"$Random_DC\" | awk '{print $'${Random_Number}'}' `

echo "$Select_DC"
}

# may switch - `python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`
User_Name=`ls -l /dev/console | awk '{print $3}'`

echo $User_Name

Computer_Name=`/usr/sbin/scutil --get ComputerName | tr '[:upper:]' '[:lower:]'`

echo $Computer_Name

# Incase of a mismatch between the local folder and the username
Home_Path=`dscl . -read /Users/$User_Name | grep "NFSHomeDirectory" | grep '/Users/' | awk '{print $2}'`

# Path to the preference
NoMAD_Path="${Home_Path}/Library/Preferences/com.trusourcelabs.NoMAD.plist"

if ! [ -e "$NoMAD_Path" ];
then
	exit 254; # NoMAD hasn't launched
fi

user_uid=`id -u $User_Name`

# Change Auth_User to use python to call the klist command as the shell just wasn't working.
Auth_User=$(python - <<EOF
import subprocess
import os

try:
    subprocess.check_call(['launchctl', 'asuser', str($user_uid), 'klist', '-s'])
    print "$User_Name@ED.AC.UK\n"
except subprocess.CalledProcessError:
    print "False\n"
EOF
)

if [ "$Auth_User" == "False" ];
then
	exit 255; # No Kerberos ticket.
fi

Admin_Group=`defaults read $NoMAD_Path "Groups" | grep -i "$Computer_Name" | awk -F '"' '{print $2}' | tr '[:upper:]' '[:lower:]'`

UUN=`echo $Auth_User | tr @ " " | awk '{print $1}'`

Who_is_Admin=`dscl . -read /Groups/admin | grep GroupMembership`

Admin_Exists=`echo $Who_is_Admin | tr " " "\n" | grep $User_Name` 

Domain_Controller="$(Random_Domain_Controller)"


# Until we can ping a domain controller
until ping -c 1 ${Domain_Controller}.ed.ac.uk | grep -q '1 packets received'
do
echo no response to ping, server $Domain_Controller down

Domain_Controller="$(Random_Domain_Controller)"
done

echo "$Domain_Controller responded to ping, using for AD rights..."

Admin_Users=( `launchctl asuser $user_uid ldapsearch -b"ou=Authorisation,ou=UoESD,dc=ed,dc=ac,dc=uk" -H "ldap://${Domain_Controller}.ed.ac.uk" "(cn=${Computer_Name})" member | grep "member:" | awk -F "CN=" '{print $2}' | awk -F "," '{print $1}' `)

echo ${Admin_Users[@]}

# Apply admin rights
for AD_User in ${Admin_Users[@]}
do
	# Is there a local account with the uun name
	UUN_Present=`dscl . -list /Users | grep $AD_User`
	# check the local username matches the UUN or that the UUN is present in the local node.
	if  [ "${User_Name}@ED.AC.UK" == "$Auth_User" ] || [ "$AD_User" == "$UUN_Present" ];
	then
		if ! [ "$Admin_Exists" == "$AD_User" ];
		then
			/usr/sbin/dseditgroup -o edit -a $AD_User -t user admin
		fi
	fi
done

UUN_Present=`dscl . -list /Users | grep $UUN`

# Revoke admin rights

if ! [ "$Admin_Group" == "$Computer_Name" ] && [ "$UUN" == "$UUN_Present" ];
then
	if [ "$Admin_Exists" == "$UUN" ];
	then
		/usr/sbin/dseditgroup -o edit -d $UUN -t user admin
	fi
	if [ "$Admin_Exists" == "$User_Name" ];
	then
		/usr/sbin/dseditgroup -o edit -d $User_Name -t user admin
	fi
fi

exit 0;
