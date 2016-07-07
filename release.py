#!/usr/bin/env python

## release-to-jss.py: push a tagged release from git to the JSS

import jss
import sys
import time
import subprocess
from base64 import b64encode, b64decode
from optparse import OptionParser

## Very simple - push a tag up to the JSS

script_tag = sys.argv[1]
script_name = sys.argv[2]
script_file = sys.argv[3]

# Create a new JSS object
jss_prefs = jss.JSSPrefs()
j = jss.JSS(jss_prefs)

# look up the script in the jss
try:
  jss_script = j.Script(script_name)
except jss.exceptions.JSSGetError:
  print "Failed to load script %s from the JSS" % script_name
  sys.exit(255)
else:
  print "Loaded %s from the JSS" % script_name

# Make sure our working copy is at the desired tag
try:
  subprocess.check_call([ "git", "checkout", "tags/" + script_tag, "-b", "release-" + script_tag ])
except:
  print "Couldn't switch to tag %s: are you sure it exists?"
  sys.exit(255)

# Update the notes field - we just prepend a message stating when
# this push took place.
msg = "Tag %s pushed from git @ %s\n" % (script_tag, time.strftime("%c"))
jss_script.find('notes').text = msg + jss_script.find('notes').text
print jss_script.find('notes')

# Update the script - we need to write a base64 encoded version
# of the contents of script_file into the 'script_contents_encoded'
# element of the script object
f = open(script_file, 'r')
jss_script.find('script_contents_encoded').text = b64encode(f.read())

# Only one of script_contents and script_contents_encoded should be sent
# so delete the one we are not using.
jss_script.remove(jss_script.find('script_contents'))

try:
  jss_script.save()
except:
  print "Failed to save the script to the jss"
else:
  print "Saved %s to the JSS!" % script_file

# cleanup
print "Cleaning up"
subprocess.check_call([ "git", "checkout", "master" ])
subprocess.check_call([ "git", "branch", "-d", "release-"+script_tag ])


