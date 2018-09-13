#!/bin/bash

###################################################################
#
# Script to set the AD groups which have admin rights on a machine
# $4 should be a comma-separated list of groups, or an empty string
# to remove all admin groups.
#
# Last Changed: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################
set -eu

TOOL='/usr/sbin/dsconfigad'

# $4 should be a comma-separated list of groups
if [[ ! -z ${4-} ]]
then
    GROUPLIST="${4}"
else
    echo "USAGE: ${0} arg1 arg2 arg3 GROUPLIST"
    echo ""
    echo "GROUPLIST should be a comma-separated list of AD groups that will"
    echo "be allowed admin rights on this machine, or the string NONE"
    exit 255
fi

function current_value {
    # Fragile but seems to work.
    current_value="$(${TOOL} -show | grep "Allowed admin groups" | awk 'BEGIN {FS = "="};{print $2}' | sed 's/ //')"
    echo "${current_value}"
}


if [[ "${4}" == "NONE" ]]
# We've been asked to disable admin groups
then
    GROUPLIST="not set"
    command="${TOOL} -nogroups"
else
    command='${TOOL} -groups "${GROUPLIST}"'
fi


echo "Checking AD Admin Groups..."
if [[ "$(current_value)" == "${GROUPLIST}" ]]
then
    echo "No change needed"
    exit 0
else
    echo "Setting admin groups to '${GROUPLIST}'..."
    # Do it.
    eval ${command}
    if [ $? -eq 0 ] && [[ "$(current_value)"  == "${GROUPLIST}" ]]
    then
        echo "Succeeded"
        exit 0
    else
        echo "Failed"
        exit 1
    fi
fi