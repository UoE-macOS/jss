#!/bin/sh

KRB5FILE='/etc/krb5.conf'
PAMFILE='/etc/pam.d/authorization'

# Make sure that we have a krb5.conf file that looks as we expect
temp_krb5=`mktemp`

cat > $temp_krb5 <<EOF
# This file is maintained by the Mac Supported Desktop.
# Do not edit it! If you feel you need to alter your Kerberos
# configuration, please contact IS.Helpline@ed.ac.uk
[libdefaults]
dns_lookup_realm = true
default_realm = ED.AC.UK

[domain_realm]
jabber.is.ed.ac.uk = EASE.ED.AC.UK
.jabber.is.ed.ac.uk = EASE.ED.AC.UK
authorise.is.ed.ac.uk = EASE.ED.AC.UK
.authorise.is.ed.ac.uk = EASE.ED.AC.UK
ecdf.ed.ac.uk = ED.AC.UK
.ecdf.ed.ac.uk = ED.AC.UK

EOF

if [ ! -f "${KRB5FILE}" ]
then
	cp "${temp_krb5}" "${KRB5FILE}"
	chmod 644 "${KRB5FILE}"
else
	# If the files are not the same
	if ! cmp "${KRB5FILE}" ${temp_krb5} &> /dev/null
	then
		echo "Refreshing ${KRB5FILE}"
	  mv "${KRB5FILE}" "${KRB5FILE}".$(date "+%Y-%m-%d-%H:%M:%S")
		cp "${temp_krb5}" "${KRB5FILE}"
		echo "Backed up old file"
	else
		echo "${KRB5FILE} loooks fine. Leaving alone"
	fi
fi


if [ -f ${PAMFILE} ]
then
	echo 'Ensuring ${PAMFILE} is up to date...'
	if egrep '^auth       optional       pam_krb5.so use_first_pass use_kcminit$' ${PAMFILE}
	then
		sed -i.$(date "+%Y-%m-%d-%H:%M:%S") \
				's/^auth       optional       pam_krb5.so use_first_pass use_kcminit$/auth       optional       pam_krb5.so use_first_pass use_kcminit default_principal/'\
				${PAMFILE}
	fi
else
	echo "Couldn't find ${PAMFILE}. Something is very wrong!"
fi
