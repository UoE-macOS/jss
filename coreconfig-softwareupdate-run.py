#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import plistlib
import datetime

SWUPDATE = '/usr/sbin/softwareupdate'
PLISTBUDDY = '/usr/libexec/PlistBuddy'
JAMFHELPER = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
INDEX = '/Library/Updates/index.plist'
TRIGGERFILE = '/var/db/.AppleLaunchSoftwareUpdate'
OPTIONSFILE = '/var/db/.SoftwareUpdateOptions'
DEFER_FILE = '/var/db/UoESoftwareUpdateDeferral'
SW_LAUNCHDAEMON = '/System/Library/LaunchDaemons/com.apple.softwareupdated.plist'
QUICKADD_LOCK = '/var/run/UoEQuickAddRunning'

if len(sys.argv) > 3:
    DEFER_LIMIT = sys.argv[3]
else:
    DEFER_LIMIT = 7 # 7 Days by default


def main():
    # Don't run if the quickadd package is still doing its stuff
    if os.path.exists(QUICKADD_LOCK):
        print "QuickAdd package appears to be running - will exit"
        sys.exit(0)
    
    # Check for updates - we stash the result so that
    # we minimise the about of times we have to run the
    # softwareupdate command - it's slow.
    list = get_updates()
    
    if updates_available(list):
        # Download them now, if possible
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
            install_updates()
    else:
        print "No Updates"
    

def get_updates():
    print "Checking for updates"
    
    # Get all recommended updates
    list = subprocess.check_output([ SWUPDATE, '-l', '-r' ], stderr=subprocess.STDOUT)
    return list


def download_updates():
    print "Downloading updates"
    # Download applicable updates
    subprocess.check_call([ SWUPDATE, '-d', '-r' ])
    
def prep_index_for_logout_install():
    # The ProductPaths key of the index file
    # will contain the names of all the downloaded
    # updates - set them all up to install on logout.
    swindex = plistlib.readPlist(INDEX)

    # Clean up our index
    print "Setting up the updates index file"
    swindex['InstallAtLogout'] = []

    for product in swindex['ProductPaths'].keys():
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
    
    # Kick the softwareupdate daemon
    subprocess.call([ 'launchctl', 'unload', SW_LAUNCHDAEMON ])
    subprocess.call([ 'launchctl', 'load', SW_LAUNCHDAEMON ])
    
def deferral_ok_until():
    now = datetime.datetime.now()

    if os.path.exists(DEFER_FILE):
        # Read deferral date
        df = plistlib.readPlist(DEFER_FILE)
        ok_until = df['DeferOkUntil']
        if now < ok_until:
            print "OK to defer!"
            return ok_until
        else:
            print "Not OK to defer."
            return False
    else:
        # Create the file, and write into it
        limit = datetime.timedelta(days = DEFER_LIMIT)
        defer_date = now + limit
        plist = { 'DeferOkUntil': defer_date }
        plistlib.writePlist(plist, DEFER_FILE)
        print "Created deferral file - OK to defer"
        return defer_date

def should_defer(defer_until):
    answer = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Software Update Available',
                              '-icon', '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns',
                              '-timeout', '99999',
                              '-description', "One or more software updates require a restart.\nIt is essential that software updates are applied in a timely fashion.\n\nYou can either restart now or defer.\n\nAfter %s you will be required to restart." % defer_until,
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
                              '-description', 'A software update which requires a restart has been deferred for %s days and a restart is now mandatory.\n\nPlease save your work and restart now.',
                              '-button1', 'Restart now' ])
    friendly_logout()
    
    
def console_user():
    return subprocess.check_output([ 'ls', '-l', '/dev/console' ]).split()[2]
    
def friendly_logout():
    user = console_user()
    subprocess.call([ 'sudo', '-u', user, 'osascript', '-e', u'tell application "loginwindow" to  «event aevtrlgo»' ])

def restart_required(updates):
    return 'restart' in updates

def updates_available(updates):
    # Returns True if there are not no updates :)
    return not 'No new software available.' in updates

def install_updates():
    subprocess.check_call([ SWUPDATE, '-i', '-r' ])


    
main()
