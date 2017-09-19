#!/bin/bash

###################################################################
#
# Trigger Mac contacting and updating its entry in the OCS Inventory
#
# Date: Wed 02 Aug 2017 11:30:33 BST
# Version: 0.1.2
# Creator: dsavage
#
##################################################################

server="$4" # http://inventory.is.ed.ac.uk/ocsinventory
tag="$5" # COL-SCH
logfile="$6" # /var/log/ocsng.log
debug="$7" # 0 or 1

OCS_CFG="/etc/ocsinventory-agent/ocsinventory-agent.cfg"

if ! [ -d /etc/ocsinventory-agent ]; then
    mkdir /etc/ocsinventory-agent
fi

cat <<EOF > "$OCS_CFG"
server="$server"
tag="$tag"
logfile="$logfile"
debug="$debug"

EOF

touch /Applications/OCSNG.app/Contents/Resources/lib/XML/SAX/ParserDetails.ini

touch "${logfile}"

/Applications/OCSNG.app/Contents/Resources/ocsinventory-agent

exit 0;
