#!/usr/bin/python
# -*- coding: utf-8 -*-

###################################################################
#
# This script provides a deferral and enforcement mechanism for 
# software updates. If updates are available which don't require
# a restart, they are installed silently in the background. If critical 
# updates are found which do require a restart, the user is nagged to 
# install them and given the option to defer for up to DEFER_LIMIT
# days. DEFER_LIMIT can be set as ${4} in the JSS.
# After DEFER_LIMIT days the warning can't be dismissed until the user agrees to
# install the updates.
#
# We use Apple's supported-ish mechanism for setting updates to install
# at logout so that we don't get into a situation of installing updates
# which require a reboot under the user, leaving the machine in a potentially
# unstable state
#
# If no user is logged in at all (including via SSH), then we lock the
# login screen and install any pending updates. No deferral is offered
# or honoured if we install at the login window. Care should be taken
# as to when this policy runs!
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################

import os
import sys
import subprocess
import plistlib
import datetime
import thread
from time import sleep
from threading import Timer
from SystemConfiguration import SCDynamicStoreCopyConsoleUser

SWUPDATE = '/usr/sbin/softwareupdate'
PLISTBUDDY = '/usr/libexec/PlistBuddy'
JAMFHELPER = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
INDEX = '/Library/Updates/index.plist'
TRIGGERFILE = '/var/db/.AppleLaunchSoftwareUpdate'
OPTIONSFILE = '/var/db/.SoftwareUpdateOptions'
DEFER_FILE = '/var/db/UoESoftwareUpdateDeferral'
QUICKADD_LOCK = '/var/run/UoEQuickAddRunning'
NO_NETWORK_MSG = "Can't connect to the Apple Software Update server, because you are not connected to the Internet."
SWUPDATE_PROCESSES = ['softwareupdated', 'swhelperd', 'softwareupdate_notify_agent', 'softwareupdate_download_service']
HELPER_AGENT = '/Library/LaunchAgents/uk.ac.ed.mdp.jamfhelper-swupdate.plist'
QUIET_HOURS_START = 23
QUIET_HOURS_END = 5

if len(sys.argv) > 3:
    DEFER_LIMIT = sys.argv[4]
else:
    DEFER_LIMIT = 3 # 7 Days by default

    
def process_updates():
    # Don't run if the quickadd package is still doing its stuff
    if os.path.exists(QUICKADD_LOCK):
        print "QuickAdd package appears to be running - will exit"
        sys.exit(0)
    
    # Check for updates - we stash the result so that
    # we minimise the number of times we have to run the
    # softwareupdate command - it's slow.
    try: 
        list = get_update_list()
     
        if updates_available(list):
            download_updates()
            if restart_required(list):
                if console_user(): 
                    # User is logged in - ask if they want to defer
                    defer_until = deferral_ok_until()
                    if defer_until != False:
                        if not should_defer(defer_until):
                            prep_index_for_logout_install()
                            force_update_on_logout()
                            friendly_logout()
                        else:
                            sys.exit(0)
                    else:
                        # User is not allowed to defer any longer
                        # so require a logout
                        prep_index_for_logout_install()
                        force_update_on_logout()
                        force_logout()
                elif nobody_logged_in(): # Nobody is logged in...
                    print "Nobody is logged in - starting unattended install..."
                    unattended_install()
                else:
                    print "Updates require a restart but someone is logged in remotely - aborting"
                    sys.exit(0)
            else:
                # Updates are available, but they don't
                # require a restart - just install them
                print "Installing updates which don't require a restart"
                install_recommended_updates()
                # and remove the deferral tracking file
                remove_deferral_tracking_file()
                sys.exit(0)
        else:
            print "No Updates"
            remove_deferral_tracking_file()
            sys.exit(0)
    except KeyboardInterrupt:
        # If any of the softwareupdate commands times out
        # we receive a KeyboardInterrupt
        print "Command timed out: giving up!"
        sys.exit(255)


def cmd_with_timeout(cmd, timeout):
    # Run a command, kill it and throw an Exception
    # in the main thread if it doesn't complete
    # within <timeout> seconds.
    # stdout and stderr will be returned together.
    
    def kill_proc(p):
        p.kill()
        # The timer is running in a separate thread, so
        # use interrupt_main() to throw a KeyboardInterrupt
        # back in the main thread.
        thread.interrupt_main() 
  
    _proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    my_timer = Timer(timeout, kill_proc, [_proc])

    try:
        my_timer.start()
        stdout = _proc.communicate()
        return stdout
    finally:
        my_timer.cancel()


def is_quiet_hours(start, end):
    now_hour = datetime.datetime.now().hour
    if (start < end):
        return start <= now_hour < end
    else:
        # Quiet hours run over midnight
        return (start <= now_hour) or (now_hour < end)
        
      
def unattended_install():
    # Do a bunch of safety checks and if all is OK,
    # try to install updates unattended
    # Safety checks here?
    if nobody_logged_in():
        lock_out_loginwindow()
        install_recommended_updates()
        # We should make this authenticated...
        unauthenticated_reboot()
    else:
        print "Found somebody logged in, aborting unattended install"

def unauthenticated_reboot():
    # Will bring us back to firmware login screen
    # if filevault is enabled.
    subprocess.check_call(['/sbin/reboot'])

def create_lgwindow_launchagent():
    # Create a LaunchAgent to lock out the loginwindow
    # We create it 'Disabled' and leave it that way, loading it
    # with launchctl '-F' to ensure it's never loaded accidentally.
    contents = { "Label": "uk.ac.ed.mdp.jamfhelper-swupdate.plist",
                 "Disabled": True,
                 "LimitLoadToSessionType": [ 'LoginWindow' ],
                 "ProgramArguments": [ JAMFHELPER,
                                       '-windowType', 'fs',
                                       '-heading', 'Installing macOS updates...',
                                       '-icon', '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns',
                                       '-description', 'Please do not turn off this computer.' ],
                 "RunAtLoad": True,
                 "keepAlive": True
                 }   

    # Just overwrite it if it's already there
    plistlib.writePlist(contents, HELPER_AGENT)
                                       
def lock_out_loginwindow():
    # Make sure our agent exists
    create_lgwindow_launchagent()
    # Then load it
    subprocess.check_call(['launchctl', 'load',
                           '-F', '-S', 'LoginWindow',
                           HELPER_AGENT ])
    
def get_update_list():
    print "Checking for updates"
    
    # Get all recommended updates
    list = cmd_with_timeout([ SWUPDATE, '-l', '-r' ], 120)
    return list[0].split("\n")


def download_updates():
    print "Downloading updates"
    # Download applicable updates
    cmd_with_timeout([ SWUPDATE, '-d', '-r' ], 600)
    
def prep_index_for_logout_install():
    # The ProductPaths key of the index file
    # will contain the names of all the downloaded
    # updates - set them all up to install on logout.
    swindex = plistlib.readPlist(INDEX)

    # Clean up our index
    print "Setting up the updates index file"
    swindex['InstallAtLogout'] = []

    for product in swindex['ProductPaths'].keys():
        print "Setting up {} to install at logout".format(product)
        swindex['InstallAtLogout'].append(product)

    plistlib.writePlist(swindex, INDEX)

    
def force_update_on_logout():
    print "Setting updates to run on logout"

    # Write options into a hidden plist
    options = {'-RootInstallMode': 'YES', '-SkipConfirm': 'YES'}
    plistlib.writePlist(options, OPTIONSFILE)
    
    # Touch the magic trigger file
    with open(TRIGGERFILE, 'w'):
        pass
    
    # Kick the various daemons belonging to the softwareupdate 
    # mechanism. This seems to be necesaary to get Software Update
    # to realise that the needed updates have been downloaded 
    for process in SWUPDATE_PROCESSES:
        err = subprocess.call([ 'killall', '-HUP', process ], stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    sleep(5) 
     

def deferral_ok_until():
    now = datetime.datetime.now()

    if os.path.exists(DEFER_FILE):
        # Read deferral date
        df = plistlib.readPlist(DEFER_FILE)
        ok_until = df['DeferOkUntil']
        if now < ok_until:
            print "OK to defer until {}".format(ok_until)
            return ok_until
        else:
            print "Not OK to defer ({}) is in the past".format(ok_until)
            return False
    else:
        # Create the file, and write into it
        limit = datetime.timedelta(days = int(DEFER_LIMIT) )
        defer_date = now + limit
        plist = { 'DeferOkUntil': defer_date }
        plistlib.writePlist(plist, DEFER_FILE)
        print "Created deferral file - Ok to defer until {}".format(defer_date)
        return defer_date

def should_defer(defer_until):
    answer = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Software Update Available',
                              '-icon', '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns',
                              '-timeout', '99999',
                              '-description', "One or more software updates require a restart.\nIt is essential that software updates are applied in a timely fashion.\n\nYou can either restart now or defer.\n\nAfter %s you will be required to restart." % defer_until.strftime( "%a, %d %b %H:%M:%S"),
                              '-button1', 'Restart now',
                               '-button2', 'Restart later' ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if answer == 2: # 0 = now, 2 = defer
        print "User elected to defer update"
        return True
    else:
        print "User permitted immediate update"
        return False
        
def force_logout():
    answer = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Mandatory Restart Required',
                              '-icon', '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns',
                              '-timeout', '99999',
                              '-description', "A software update which requires a restart has been deferred for the maximum allowable time and a restart is now mandatory.\n\nPlease save your work and restart now to install the update.",
                              '-button1', 'Restart now' ])
    friendly_logout()

def remove_deferral_tracking_file():
    if os.path.exists(DEFER_FILE):
        os.remove(DEFER_FILE)
        print "Removed deferral tracking file"
    

def console_user():
    username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]
    username = [username, None][username in [u"loginwindow", None, u""]]
    return username


def nobody_logged_in():
    # If the 'w' command only returns 2 lines of output
    # the nobody is on the console or a tty
    # also check console user for belt and braces
    return ( len(subprocess.check_output(['w']).strip().split("\n")) < 3 and
             console_user() == None )
        
    
def friendly_logout():
    user = console_user()
    subprocess.call([ 'sudo', '-u', user, 'osascript', '-e', u'tell application "loginwindow" to  «event aevtrlgo»' ])

def restart_required(updates):
    return any('[restart]' in a for a in updates)

def updates_available(updates):
    # Returns True if there are not no updates :)
    return not ( 'No new software available.' in updates or
                 NO_NETWORK_MSG in updates)
                 
def install_recommended_updates():
    # An hour should be sufficient to install
    # updates, hopefully! 
    cmd_with_timeout([ SWUPDATE, '-i', '-r' ], 3600)

    
if __name__ == "__main__":
    process_updates()
