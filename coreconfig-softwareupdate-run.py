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
# We use Apple's supported-ish mechanism for setting updates to install
# at logout so that we don't get into a situation of installing updates
# which require a reboot under the user, leaving the machine in a potentially
# unstable state
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

SWUPDATE = '/usr/sbin/softwareupdate'
PLISTBUDDY = '/usr/libexec/PlistBuddy'
JAMFHELPER = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
INDEX = '/Library/Updates/index.plist'
TRIGGERFILE = '/var/db/.AppleLaunchSoftwareUpdate'
OPTIONSFILE = '/var/db/.SoftwareUpdateOptions'
DEFER_FILE = '/var/db/UoESoftwareUpdateDeferral'
QUICKADD_LOCK = '/var/run/UoEQuickAddRunning'
SWUPDATE_PROCESSES = ['softwareupdated', 'swhelperd', 'softwareupdate_notify_agent', 'softwareupdate_download_service']

if len(sys.argv) > 3:
    DEFER_LIMIT = sys.argv[4]
else:
    DEFER_LIMIT = 7 # 7 Days by default


def main():
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
            if restart_required(list):
                # Updates are available and a restart is
                # required.
                # Download available updates
                download_updates()
                # Offer the user the chance to defer
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
            else:
                # Updates are available, but they don't
                # require a restart - just install them
                print "Installing updates which don't require a restart"
                install_updates()
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
        print "Giving up!"
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
                              '-button2', 'Restart later' ])
    if answer == 2: # 0 = now, 2 = defer
        return True
    else:
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
    return subprocess.check_output([ 'ls', '-l', '/dev/console' ]).split()[2]
    
def friendly_logout():
    user = console_user()
    subprocess.call([ 'sudo', '-u', user, 'osascript', '-e', u'tell application "loginwindow" to  «event aevtrlgo»' ])

def restart_required(updates):
    return any('[restart]' in a for a in updates)

def updates_available(updates):
    # Returns True if there are not no updates :)
    return not 'No new software available.' in updates

def install_updates():
    # Half an hour should be sufficient to install
    # updates, hopefully!
    cmd_with_timeout([ SWUPDATE, '-i', '-r' ], 1800)

    
main()
