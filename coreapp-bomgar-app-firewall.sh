#!/bin/sh

#######################################################################
#
# This script is intended to be run at login and adds the Bomgar
# application to the os x application firewall. The application name
# contains a random or date-related string so we need to use globbing
# to locate it.
#
# In theory it isn't necessary to run this more than once for each
# version of Bomgar, but running it every login has no perceptible
# performance hit and ensures that the user is not presented with the
# 'would you like to allow Bomgar Jump Client to access the network'
# dialogue, which has been seen to cause confusion.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
#######################################################################

# Check bomgar agent and app exist, use arrays since it is just easier.
BOMGAR_APP=(/Users/Shared/bomgar-scc*)
BOMGAR_AGENT=(/Library/LaunchAgents/com.bomgar.bomgar-scc*)

# Check bomgar exists and is in use.
if [ -e ${BOMGAR_APP[0]} ] && [ -e ${BOMGAR_AGENT[0]} ]
then
count=0
	# Wait until bomgar is loaded before setting the firewall rule or it won't stick.
	until ps ax | grep 'bomgar-scc*' | grep "drone" | grep -v "grep"
	do
		sleep 2
		# Safety counter to kill the loop just incase.
		if [ $count -gt 60 ];
		then
			break
		fi
		count=$((count+1))
	done
else
	# If bomgar isn't in use then quit.
	exit 0;
fi

# Set the pathfor the app firewall command line tool.
SOCKET_FILTER="/usr/libexec/ApplicationFirewall/socketfilterfw"

# Find our installed bomgar.
BOMGAR_PATH=$(find /Users/Shared -maxdepth 1 -name 'bomgar-scc*.app')

# Check if the firewall is enabled.
FIREWALL_STATE=$(${SOCKET_FILTER} --getglobalstate | awk '{print $3}')

if [ "${FIREWALL_STATE}" == "enabled." ]
then
	for BOMGAR_INSTANCE in ${BOMGAR_PATH[@]}
	do
		# Use Gatekeeper command line to approve Bomgar.
		spctl --add --label "Remote Support" "${BOMGAR_INSTANCE}"

		#Firewall exceptions
		$SOCKET_FILTER --unblockapp "${BOMGAR_INSTANCE}"
		$SOCKET_FILTER --add "${BOMGAR_INSTANCE}"
	done
    # Restart the firewall
    ${SOCKET_FILTER} --setglobalstate off
    sleep 1
    ${SOCKET_FILTER} --setglobalstate on
fi

exit 0;

