#!/bin/bash

###################################################################
#
# Schedule wake times for Macs to install software updates overnight.
#
# Date: Thu 07 Sep 2017 11:30:33 BST
# Version: 0.1.2
# Creator: dsavage
#
##################################################################
 
Wake_Check=`pmset -g sched | grep wake | awk '{print $1}'`
 
if [ "${Wake_Check}" == "wake" ] || [ "${Wake_Check}" == "wakeorpoweron" ]; then
    echo a schedule has been set on this Mac already.
else
    # jot -- print sequential or random data. In our case randomise the hour.
    Hour=`jot -r 1  1 5`
    # Schedule a repeating wake on Monday, Wednesday and Friday at an hour between 1am and 5am.
    # Only schedule a wake, not a power on to avoid aggravating users.
    pmset repeat wake MWF 0${Hour}:00:00
fi
 
exit 0;
