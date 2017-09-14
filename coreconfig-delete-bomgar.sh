#!/bin/bash

###################################################################
#
# Remove Bomgar remote support client from target Mac
#
# Date: Wed 28 Jun 2017 11:30:33 BST
# Version: 0.1.1
# Creator: dsavage
#
##################################################################

# Search default location (/Users/Shared) for existing Bomgar installs.
# For each file in /Users/Shared
for entry in "/Users/Shared"/*; do 
	# Get filename
	fname=`basename $entry`	
	 # If beginning of file starts with "bomgar-scc"
	if [[ $fname = "bomgar-scc"* ]] ; then
		# Kill the bomgar process
		for KILLPID in `ps ax | grep 'bomgar' | awk ' { print $1;}'`; do 
  			kill -9 $KILLPID;
		done				
  	else
  		# File found is not the Bomgar jump client. Move onto the next file.
  		echo
  		echo "This file / directory is not the Bomgar Jump Client. Moving onto the next file / directory."
  	fi
 # Remove LaunchAgents and daemons related to the process along with the application
rm -rf /Library/LaunchDaemons/com.bomgar.bomgar-ps-*
rm -rf /Library/LaunchAgents/com.bomgar.bomgar-scc*
rm -rf /Users/Shared/bomgar-scc-*			  		

done
