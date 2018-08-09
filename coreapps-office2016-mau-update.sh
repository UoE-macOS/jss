#!/bin/bash

#######################################
#
# Check the network connection before running MS Update. See I180613-0229
# We gather info on the active network link then have conditions we will perform updates over.
#
# Date: Mon 25 Jun 2018 11:36:07 BST
# Version: 0.1.1
# Creator: dsavage
#
#######################################

MS_Update="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"
Do_MS_Up=""

# Check network adapter
Active_Adapter=`route get ed.ac.uk | grep interface | awk '{print $2}'`
Adapter_Name=$(networksetup -listallhardwareports | grep -B1 "$Active_Adapter" | awk -F': ' '/Hardware Port/{print $NF}')

# Find out out link status if we are on Ethernet or Wireless, then work out if updates should happen.
if [[ "$Adapter_Name" =~ "Ethernet" ]]; then
    Link_Speed=$(ifconfig $Active_Adapter | awk -F': ' '/media:/{print $NF}' | awk -F '[()]' '{print $2}' | awk '{print $1}')
	# Make sure we have a decent connection.
	if [[ "$Link_Speed" =~ "100baseT" ]] || [[ "$Link_Speed" == "1000baseT" ]]; then
		Do_MS_Up="Yes"
	else
		Do_MS_Up="No"
	fi
elif [[ "$Adapter_Name" =~ "Wi-Fi" ]]; then
    Max_Link_Speed=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/maxRate/{print $NF}')
    #Link_Speed=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/lastTxRate/{print $NF}')
	Link_Auth=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/link auth/{print $NF}')
	if [ "$Link_Auth" == "none" ] || [ $Max_Link_Speed -le 250 ]; then
		Do_MS_Up="No"
		Link_Speed=$Max_Link_Speed
	else
		echo "Network available."
		Do_MS_Up="Yes"
	fi
else
	Link_Speed=0
fi

if [ "$Do_MS_Up" == "Yes" ]; then
	echo "Checking for the latest Microsoft updates."
	"$MS_Update" --install
else
# Poor network link
echo "No Microsoft Update performed, Internet connection was: $Link_Speed"
fi

exit 0;
