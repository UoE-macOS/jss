#!/bin/bash

###################################################################
#
# Script to add or remove LoginItems on login.
#
#
# The script takes arguments for task (add/del) App_Path to Application
# and if it is hidden.
#
# Last Changed: "Tue 16 Jun 2017 10:48:12"
# Version: 0.1
# Origin: https://github.com/UoE-macOS/jss.git
# Released by JSS User: dsavage
#
##################################################################
# launchctl asuser $User_Name -- Might be needed in future...

#Task="add"
#App_Path="/Applications/NoMAD.app"
#Hidden="true"
Task="$4"
App_Path="$5"
Hidden="$6"
Item=`basename $App_Path`
Label=`basename $App_Path | awk -F "." '{print $1}'`
User_Name=`ls -l /dev/console | awk '{print $3}'`
App_Running=`ps -A | grep "$App_Path/Contents" | grep -v "grep"`
Existing_Items=( `/usr/bin/osascript -e 'tell application "System Events" to get the name of every login item' `)
Already_Exists=`echo ${Existing_Items[@]} | grep "$Label"`

if [ -z "$App_Path" ] || [ -z "$Task" ]; then
    echo "Required variable is undefined!"
    exit 0;
fi

if [ "$Task" == "add" ]; then
    if [ -z "$Already_Exists" ] || [ "$Already_Exists" == '' ]; then
        /usr/bin/osascript <<EOF
tell application "System Events" to make login item at end with properties {Path:"$App_Path", name:"$Item", hidden:$Hidden}
EOF
    fi
    if [ -z "${App_Running}" ] || [ "${App_Running}" == '' ]; then
       open -a "${App_Path}" > /dev/null 2>&1
    fi
fi

# The delete function

if [ "$Task" == "del" ]; then
    if ! [ -z "$Already_Exists" ] || ! [ "$Already_Exists" == '' ]; then
        /usr/bin/osascript <<EOF
tell application "System Events" to delete login item "$Item"
tell application "System Events" to delete login item "$Label"
EOF
    fi
fi

exit 0;

