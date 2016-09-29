#!/bin/sh

###################################################################
#
# Script to configure a single printer using lpadmin.
# If the printer already exists it will not be altered unless
# $10 is set to 'YES' as described below.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################


# Name of the print queue on the server
queue="${4}"

# FQDN of the server hosting ${queue}
server="${5}"

# smb, lpd, ipp etc
protocol="${6}"

# Full path to the appropriate PPD on the client
ppd="${7}"

# Specify an operational policy for this printer. 
# Must be a policy defined in cupsd.conf - default or kerberos recommended.
op_policy="${8}"

# A list of CUPS options, of the form -o name=value -o name=value
options="${9}"

# If this is set to YES then the printer will be deleted and recreated if it exists
reconfigure="${10}"

# Stuff happens below here.

# If we have been asked to reconfigure the queue, delete it first if it exists.
if [[ ${reconfigure} == "YES" ]] && lpstat -a | grep -q "${queue}" 2>/dev/null
then
  /usr/sbin/lpadmin -x "${queue}"
  echo "Deleted printer ${protocol}://${server}/${queue}"
fi

if ! lpstat -a | grep -q "${queue}" 2>/dev/null
then
  /usr/sbin/lpadmin -p "${queue}" -E -v "${protocol}://${server}/${queue}" -P "${ppd}" -D "${queue}" -o printer-op-policy="${op_policy}" "${options}"
  if [[ $? == 0 ]]
  then
    echo "Configured printer at ${protocol}://${server}/${queue}"
  else
    echo "Failed to configure printer at ${protocol}://${server}/${queue}"
    # Delete the queue, just in case we managed to create something broken
    /usr/sbin/lpadmin -x "${queue}"
    exit 255
  fi
fi
