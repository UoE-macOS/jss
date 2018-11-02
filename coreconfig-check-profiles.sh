#!/bin/bash

###################################################################
#
# This script checks whether there are 5 or fewer profiles on the target Mac and runs a jamf manage command to re-manage them. 
# There should always be more than 5 profiles.
#
# Date: Fri  2 Mar 2018 10:57:22 GMT
# Version: 0.1.2
# Creator: dsavage
#
##################################################################


# Define the profiles
# Office2016 - AutoUpdate
p_o2016_au="986C0511-6273-4A75-91DF-BA337F0CD7A3"
# Office2016 - Disable Insider
p_o2016_di="B8B966FA-FDB5-4DB4-AF80-A3FF9C813EE6"
# Office2016 - Register Apps
p_o2016_ra="B9E39560-65D4-4F6C-ABB3-E7D3D7ECD264"
# NoMAD
p_nomad="C12F73E7-EB18-4D3F-9347-A01CF8BD6005"
# Login Window
p_lw="5D5679E0-4D8C-4BB6-93E3-4BB488B19E05"
# Login Window - User-Configurable
p_lw_uc="3F890695-CF78-45B7-8E26-B3E340091A16"

check_profile ()
{
	profile_id=$1
	profile_installed=`profiles -C | grep "${profile_id}" | awk '{print $4}'`
	if [ "${profile_id}" == "${profile_installed}" ]; then
		echo ${profile_installed}
	else
		echo Fail
	fi
}

# Check for Office 2016 Profiles.
O2016_AU=$(check_profile ${p_o2016_au})
O2016_DI=$(check_profile ${p_o2016_di})
O2016_RA=$(check_profile ${p_o2016_ra})

# Check for NoMAD Profile
NOMAD=$(check_profile ${p_nomad})

# Check for LoginWindow Profile (a or b)
LW=$(check_profile ${p_lw})
LW_UC=$(check_profile ${p_lw_uc})
# Only one of the loginwindow configs is ever in use so set another variable.
if [ ${LW} == "Fail" ] && [ ${LW_UC} == ${p_lw_uc} ]; then
	LGN=${LW_UC} 
else
	LGN=${LW}
fi

# Array with our installed profile ids or a failure
PROFILES=( $O2016_AU $O2016_DI $O2016_RA $NOMAD $LGN )
PRF_MISSING="False"
for prfid in "${PROFILES[@]}"
do
	if [ ${prfid} == "Fail" ]; then
		PRF_MISSING="True"
	fi
done

if [ ${PRF_MISSING} == "True" ]; then
	# Jamf MDM remove
	/usr/local/jamf/bin/jamf removeMdmProfile
	# Remove each profile, incase they are corrupt or have stuck around
	for prfid in "${PROFILES[@]}"
	do
		/usr/bin/profiles -R -p ${prfid}
	done
	sleep 5
	# Jamf MDM Add
	/usr/local/jamf/bin/jamf mdm
fi

# ---------------------- Old Function -----------------------
# numberofprofiles=`profiles -C | wc -l`

# echo "The number of profiles is $numberofprofiles"

# if [ $numberofprofiles -lt 6 ]; then
# re-manage the mac
# echo "There are fewer than 6 profiles installed. Re-managing to correct."
# /usr/local/bin/jamf manage
#sleep 15
# sometimes it can be a bit slow to trigger...
#/usr/local/bin/jamf manage
#fi
# ---------------------- Old Function -----------------------

exit 0;

