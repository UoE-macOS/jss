#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import time
import sys
from SystemConfiguration import SCDynamicStoreCopyConsoleUser


JAMFHELPER = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
SWUPDATE_ICON = '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns'
UNI_LOGO ="/usr/local/jamf/UoELogo.png"
ALERT_ICON = '/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns'

username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]
username = [username, None][username in [u"loginwindow", None, u""]]

def friendly_reboot():
    
    print "Attempting friendly restart."
    # Display initial message with university logo. This will not only reassure the user that this is an intended process, but will also help the logged in user prepare to save their data.
    jh_window1 = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Update Notification',
                              '-icon', UNI_LOGO,
                              '-timeout', '99999',
                              '-description', "In order to install the latest security updates, it is essential that your macOS device is restarted.\n\nPlease make sure you have saved your data before proceeding.\n\nTHIS PROCESS CANNOT BE DEFERRED!",
                              '-button1', 'Continue' ])
    
    # Set reboot attempts. At the moment this will loop at least 100 times if the user attempts to quit jamf helper
    reboot_tries = 1
    while reboot_tries < 100:
        print "Reboot attempts : %d" % reboot_tries
        # Display 2nd message, warning user to save their data.
        jh_window2 = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Update Notification',
                              '-icon', ALERT_ICON,
                              '-timeout', '99999',
                              '-description', "This mac will now attempt to close all applications and restart.\n\nBefore selecting \"Restart now\", please make sure that you have saved all of your data!",
                              '-button1', 'Restart now' ])
        # If restart now is selected
        if (jh_window2 == 0):
            # Get list of open applications
            apps = subprocess.check_output(['osascript', '-e', 'tell app "System Events" to get name of (processes where background only is false)']).strip()
            # If there are no apps open
            if (not apps):
                # Restart
                print "Restarting."
                subprocess.call(['osascript', '-e', 'tell app "System Events" to restart'])
                # Exit script
                sys.exit(0)
            # Else, it looks like there are apps open. Display message listing open apps.
            else:                        
                jh_window3 = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Applications open',
                              '-icon', ALERT_ICON,
                              '-timeout', '99999',
                              '-description', "Before the mac can be restarted, the following applications need to be closed:\n\n%s\nDo you wish to force quit these applications?\n\nANY UNSAVED DATA WILL BE LOST!" % apps,
                              '-button1', 'Close all' ])
                # If user wishes to close all open apps then attempt to close
                if (jh_window3 == 0):
                    apple_script_cmd = '''
                        tell application "System Events"
                            set listOfProcesses to (name of every process where background only is false)
                        end tell
                        repeat with processName in listOfProcesses
                            do shell script "Killall " & quoted form of processName
                        end repeat'''
                    # Run the apple script command
                    proc = subprocess.Popen(['osascript', '-'],
                                        stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE)
                    stdout_output = proc.communicate(apple_script_cmd)[0]
                    print stdout_output
                else:
                    # User has most likely attempted to quit jamf helper. Go to next iteration of loop and start again
                    continue
            #Restart   
            print "Restarting!"    
            subprocess.call(['osascript', '-e', 'tell app "System Events" to restart'])
            # Exit script
            sys.exit(0)
        reboot_tries += 1
    
if __name__ == "__main__":
    friendly_reboot()


