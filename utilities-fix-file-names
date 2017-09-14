#!/bin/bash

###################################################################
#
# Script to check user's Desktop, Documents and OneDrive folders
# for any illegal characters, leading or trailing spaces and
# overlong path names and to correct them to help allow smooth
# synching in OneDrive.
#
# Date: Thu 31 Aug 2017 11:30:33 BST
# Version: 0.1.2
# Creator: ganders1
#
##################################################################

#clear any previos temp files
rm /tmp/*.ffn

#get the user
uun=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

#remove local fstemps so they won't clog the server
find /Users/$uun -name ".fstemp*" -exec rm -dfR '{}' \;
# Find the OneDrive folder location assuming it has OneDrive in the name...
onedrive=`find /Users/$uun -type d -name "OneDrive*" -not -path "*/Library*" -not -path "*/Music*" -not -path "*/Pictures*" -not -path "*/Downloads*" -not -path "*.pkg" -not -path ".Trash"`

Check_Long_Names ()
{

echo File paths longer than 230 characters may not synchronise to the server. The following are the files that are in that category on your system and have now been temporarily moved to a folder called LongFileNames inside your home folder. If you could please shorten the names of these files and move the shortened versions back into either your Desktop or Documents folder, they will then synchronise to the server as normal: > /tmp/clnOut.ffn
echo " " >> /tmp/clnOut.ffn
linecount=`wc -l /tmp/cln.ffn | awk '{print $1}'`
counter=1
while ! [ "$counter" -gt "$linecount" ]; do

line="`sed -n ${counter}p /tmp/cln.ffn`"

test=`echo $line | wc -m | awk '{print $1}'`
if [ $test -gt "230" ]
then
mkdir /Users/$uun/LongFileNames
mv "$line" /Users/$uun/LongFileNames
open /Users/$uun/LongFileNames
echo Number of Chars = $test   Path = $line 
echo Number of Chars = $test   Path = $line >> /tmp/clnOut.ffn
fi
let "counter = $counter +1"
done
}

Check_Trailing_Chars ()
{

cat /tmp/cln.ffn | grep -v ".pkg" | grep -v ".app" > /tmp/fixtrail.ffn
linecount=`wc -l /tmp/fixtrail.ffn | awk '{print $1}'`
counter=1
while ! [ "$counter" -gt "$linecount" ]; do

line="`sed -n ${counter}p /tmp/fixtrail.ffn`"
lastChar="`sed -n ${counter}p /tmp/fixtrail.ffn | grep -Eo '.$'`"

if [ "$lastChar" == " " ] || [ "$lastChar" == "." ]
then

target=$(echo "$line" | tr '.' '-' | awk '{sub(/[ \t]+$/, "")};1')
echo "$target" >> /tmp/allfixed.ffn
mv -f "$line" "$target"

fi

let "counter = $counter +1"
done
}


Fix_Names ()
{
#count the number of lines in the fixdname.ffn or fixfname.ffn file
linecount=`wc -l /tmp/${1}.ffn | awk '{print $1}'`
counter=1
while ! [ "$counter" -gt "$linecount" ]; do

line="`sed -n ${counter}p /tmp/${1}.ffn`"
echo line= $line

target=$(echo "$line" | tr ':' '-' | tr '\\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '%' '-' | tr '|' '-' )
echo "$target"
echo "$target" >> /tmp/allfixed.ffn

mv -f "$line" "$target"

let "counter = $counter +1"
done
}


#do the finds for the Docs/Desk directories only
echo get Documents folders
find /Users/$uun/Documents -type d -name '*[\\/:*?"<>%|]*' -print >> /tmp/fixdname.ffn

echo get Desktop folders
find /Users/$uun/Desktop -type d -name '*[\\/:*?"<>%|]*' -print  >> /tmp/fixdname.ffn

#need to fix directories before we fix files
Fix_Names fixdname

#do the finds for the Docs/Desk files only
echo get Documents files
find /Users/$uun/Documents -type f -name '*[\\/:*?"<>%|]*' -print >> /tmp/fixfname.ffn

echo get Desktop files
find /Users/$uun/Desktop -type f -name '*[\\/:*?"<>%|]*' -print >> /tmp/fixfname.ffn

#fix the files
Fix_Names fixfname


# OneDrive needs to be separate incase it exists in Docs or Desk, find dirs
find "${onedrive}" -type d -name '*[\\/:*?"<>%|]*' -print  >> /tmp/fix1dname.ffn

#need to fix OneDrive directories before we fix files
Fix_Names fix1dname

# OneDrive needs to be separate incase it exists in Docs or Desk, find files
find "${onedrive}" -type f -name '*[\\/:*?"<>%|]*' -print >> /tmp/fix1fname.ffn

#fix the OneDrive files
Fix_Names fix1fname


find /Users/$uun/Documents -name "*" >> /tmp/cln.ffn
find /Users/$uun/Desktop -name "*" >> /tmp/cln.ffn
find "${onedrive}" -name "*" >> /tmp/cln.ffn

Check_Long_Names
Check_Trailing_Chars

testlong=`grep "$uun" /tmp/clnOut.ffn`

#chown -R $uun:staff /Users/$uun/Desktop
#chown -R $uun:staff /Users/$uun/Documents
#chown -R $uun:staff /Users/$uun/LongFileNames

#send message stuff

Send_Message ()
{

cat <<EOF > /tmp/message.txt
It is necessary for folder or file names containing any illegal characters to be renamed. These characters are the following: \ / : * ? " < > % | they also include trailing . and trailing spaces.

This message is to advise you of any such files or folders that have been affected so that you are aware that of these characters in their names will now have been replaced by a hyphen. 

Here are the files and folders that have been renamed in your case:

EOF


#cat /tmp/fixfname.ffn /tmp/fixdname.ffn > /tmp/allfixed.ffn
cat /tmp/message.txt /tmp/allfixed.ffn > /tmp/fullmessage.txt

if ! [ -z "$testlong" ]
then
cat /tmp/fullmessage.txt /tmp/clnOut.ffn > /tmp/tmpmessage.txt
cat /tmp/tmpmessage.txt > /tmp/fullmessage.txt
fi

echo " " >> /tmp/fullmessage.txt
echo "If you have any queries on this matter, please contact the IS Helpline." >> /tmp/fullmessage.txt
echo " " >> /tmp/fullmessage.txt
echo "Regards, Operational Services" >> /tmp/fullmessage.txt

sudo -u $uun osascript <<EOF
set tmpmes to do shell script "echo /tmp/fullmessage.txt" 
set message to POSIX file tmpmes

tell application "TextEdit"
	activate
	open message
end tell
EOF

}


BrokeFiles=`grep $uun /tmp/fixfname.ffn`
BrokeDirs=`grep $uun /tmp/fixdname.ffn`
Broke1Files=`grep $uun /tmp/fix1fname.ffn`
Broke1Dirs=`grep $uun /tmp/fix1dname.ffn`


if ! [ -z "$BrokeFiles" ] || ! [ -z "$Broke1Files" ]
then
var1="true"
else
var1="false"
fi
if ! [ -z "$BrokeDirs" ] || ! [ -z "$Broke1Dirs" ]
then
var2="true"
else
var2="false"
fi
if ! [ -z "$testlong" ]
then
var3="true"
else
var3="false"
fi

if [ "$var1" == "true" ] || [ "$var2" == "true" ] || [ "$var3" == "true" ]
then
#call the mail function
Send_Message
fi

# cleanup
rm /tmp/*.ffn

exit 0;
