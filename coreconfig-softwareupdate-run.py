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
# or honoured if we install at the login window, but the install will only
# proceed if the hour is between QUIET_HOURS_START and QUIET_HOURS_END   
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
import platform
from time import sleep
from threading import Timer
from SystemConfiguration import SCDynamicStoreCopyConsoleUser
from xml.etree import ElementTree
from Foundation import CFPreferencesCopyAppValue


SWUPDATE = '/usr/sbin/softwareupdate'
PLISTBUDDY = '/usr/libexec/PlistBuddy'
JAMFHELPER = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
INDEX = '/Library/Updates/index.plist'
TRIGGERFILE = '/var/db/.AppleLaunchSoftwareUpdate'
OPTIONSFILE = '/var/db/.SoftwareUpdateOptions'
DEFER_FILE = '/var/db/UoESoftwareUpdateDeferral'
QUICKADD_LOCK = '/var/run/UoEQuickAddRunning'
UPDATES_CACHE = '/Library/Updates'
NO_NETWORK_MSG = ("Can't connect to the Apple Software Update server, "
                  "because you are not connected to the Internet.")
SWUPDATE_PROCESSES = ['softwareupdated', 'swhelperd',
                      'softwareupdate_notify_agent',
                      'softwareupdate_download_service']
HELPER_AGENT = '/Library/LaunchAgents/uk.ac.ed.mdp.jamfhelper-swupdate.plist'

# Looks as if the oldskool SoftwareUpdate icon is on its way out...
if platform.mac_ver()[0].split('.')[1] == '12':
    SWUPDATE_ICON = "/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns"
else:
    SWUPDATE_ICON = "/System/Library/CoreServices/Install in Progress.app/Contents/Resources/Installer.icns"
    

def get_args():
    try:
        args = { 'DEFER_LIMIT': int(sys.argv[4]),
                 'QUIET_HOURS_START': int(sys.argv[5]),
                 'QUIET_HOURS_END': int(sys.argv[6]),
                 'MIN_BATTERY_LEVEL': int(sys.argv[7])
        }
    except ValueError:
        print "You need to specify DEFER_LIMIT, QUIET_HOURS_START, QUIET_HOURS_AND and MIN_BATTERY_LEVEL as integers"
        raise
    return args
    
def process_updates(args):
    # Don't run if the quickadd package is still doing its stuff
    if os.path.exists(QUICKADD_LOCK):
        print "QuickAdd package appears to be running - will exit"
        sys.exit(0)
    
    need_restart = []
    try:
        sync_update_list()
        
        if not recommended_updates():
            print "No Updates"
            remove_deferral_tracking_file()
            return True

        for update in recommended_updates():
            print("Processing {}".format(update.get("Display Name")))
            
            # Download only if required
            if not is_downloaded(update):
                download_update(update)
            
            if is_downloaded(update):
                if not requires_restart(update):
                    install_update(update)
                else:
                    # Restart is required. Add
                    # to the list
		    need_restart.append(update)

        if len(need_restart) == 0:
            # No updates require a restart, and we are done.
            return True

        # Now we can deal with updates that require a restart
        if console_user():
            # Someone is logged in. Set updates to install on
            # Next logout:
            force_update_on_next_logout()

            # Are we allowed to defer logout?
            max_defer_date = deferral_ok_until(args['DEFER_LIMIT'])
            if max_defer_date != False:
                # Yes, we were allowed to defer
                # Does the user want to defer?
                if not user_wants_to_defer(max_defer_date,
                                           "\n".join([u.get("Display Name") for u in need_restart])):
                    # User doesn't want to defer, so set
                    # things up to install update, and force
                    # logout.
                    friendly_logout()
                else:
                    # User wants to defer, and is allowed to defer.
                    # OK, just bail
                    return True
            else:
                # User is not allowed to defer any longer
                # so require a logout
                force_logout("\n".join([u.get("Display Name") for u in need_restart]))

        elif ( nobody_logged_in() and
               is_quiet_hours(args['QUIET_HOURS_START'],
                              args['QUIET_HOURS_END'])):
            print "Nobody is logged in and we are in quiet hours - starting unattended install..."
            unattended_install(min_battery=args['MIN_BATTERY_LEVEL'])

        else:
            print ( "Updates require a restart but someone is logged in remotely "
                    "or we are not in quiet hours - aborting" )
            return False
    
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
        
      
def unattended_install(min_battery):
    # Do a bunch of safety checks and if all is OK,
    # try to install updates unattended
    # Safety checks here?
    if (using_ac_power() and min_battery_level(min_battery)):  
        lock_out_loginwindow()
        install_recommended_updates()
        # We should make this authenticated...
        unauthenticated_reboot()
    else:
        print "Power conditions were unacceptable for unattended installation."

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
                                       '-icon', SWUPDATE_ICON,
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
    
def sync_update_list():
    print "Checking for updates"
    # Get all recommended updates
    cmd_with_timeout([ SWUPDATE, '-l', '-r' ], 180)


def install_update(update):
    """ Install a single update """
    update_name = "{}-{}".format(update.get("Identifier"),
                                 update.get("Display Version"))

    print "Installing: {}".format(update_name)
    result = cmd_with_timeout([ SWUPDATE, '-i', update_name ], 3600)
    
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

    
def force_update_on_next_logout():
    prep_index_for_logout_install()

    print "Setting updates to run on logout"

    # Write options into a hidden plist
    options = {'-RootInstallMode': 'YES', '-SkipConfirm': 'YES'}
    plistlib.writePlist(options, OPTIONSFILE)
    
    # Touch the magic trigger file
    with open(TRIGGERFILE, 'w'):
        pass

    # 10.13 seems to require this file. I have no real idea
    # what the contents mean.
    staged = { 'DarkModeEnabled': False,
               'ShouldLaunchFirstLoginBuddy': True,
               'StashMechanism': 'StashSplit',
               'UpgradeType': 'Update',
               'User': console_user(),
               'UserID': pwd.getpwnam(console_user()).pw_uid,
               'UserName': console_user() 
            }
    
    plistlib.writePlist(staged, '/var/db/.StagedAppleUpgrade')
    
    # Kick the various daemons belonging to the softwareupdate 
    # mechanism. This seems to be necesaary to get Software Update
    # to realise that the needed updates have been downloaded

    # This doesn't work on 10.13. It appears even root isn't allowed
    # to kill certain system processes - we just get 'Operation not permitted.'
    for process in SWUPDATE_PROCESSES:
        err = subprocess.call([ 'killall', '-HUP', process ], stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    sleep(5) 

 

def deferral_ok_until(limit):
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
        limit = datetime.timedelta(days = int(limit) )
        defer_date = now + limit
        plist = { 'DeferOkUntil': defer_date }
        plistlib.writePlist(plist, DEFER_FILE)
        print "Created deferral file - Ok to defer until {}".format(defer_date)
        return defer_date

def user_wants_to_defer(defer_until, updates):
   """ Pop a dialog asking the user if they would
   like to defer a restart. Returns True for 'Defer'
   and False for 'Restart Now'
   """
   
   message = ("One or more software updates require a restart:\n\n{}\n\n"
              "Updates must be applied regularly.\n\n"
              "You will be required to restart after:\n\n  {}.").format(updates,
                                                                        defer_until.strftime( "%a, %d %b %H:%M:%S")) 

   script = """Tell application "System Events"
                  activate
                  with timeout of (60 * 60 * 24 * 365) seconds -- 1 Year!
                      display dialog "{}" buttons {{"Restart Now", "Restart Later"}} ¬
                      with title "MacOS Supported Desktop" ¬
                      with icon file (posix file "{}")
                  end timeout
                  End tell""".format(message, SWUPDATE_ICON)
   
   proc = subprocess.Popen(['sudo', '-u', console_user(), 'osascript', '-'],
                           stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
   
   answer, err = proc.communicate(script)
   
   if answer == "button returned:Restart Now\n":
       print "User permitted immediate update"
       return False
   else:
       print "User elected to defer update"
       return True

def force_logout(updates):
   """ Pop a dialog telling the user that they
       must restart immediately.
   """
   
   message = ("One or more updates which require a restart have been deferred "
              "for the maximum allowable time:\n\n{}\n\n"
              "A restart is now mandatory.\n\n"
              "Please save your work and restart now to install the update").format(updates)
                                                                        
   script = """Tell application "System Events"
                  activate
                  with timeout of (60 * 60 * 24 * 365) seconds -- 1 Year!
                      display dialog "{}" buttons {{"Restart Now"}} ¬
                      default button 1 ¬
                      with title "MacOS Supported Desktop" ¬
                      with icon file posix file ("{}")
                  end timeout
                  End tell""".format(message, SWUPDATE_ICON)
   
   proc = subprocess.Popen(['sudo', '-u', console_user(), 'osascript', '-'],
                           stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)

   proc.communicate(script)
   
   # Doesn't matter what the user says! 
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
    
                 
def install_recommended_updates():
    # An hour should be sufficient to install
    # updates, hopefully! 
    cmd_with_timeout([ SWUPDATE, '-i', '-r' ], 3600)
    

def min_battery_level(min):
    if is_a_laptop():
        try:
            level = subprocess.check_output(['pmset', '-g', 'batt']).split("\t")[1].split(';')[0][:-1]
            print "Battery level: {}".format(level)
            return int(level) >= min
        except (IndexError, ValueError):
            # Couldn't get battery level - play it safe
            print "Failed to get battery level"
            return False
    else:
        print "Not a laptop."

def using_ac_power():
    source = subprocess.check_output(['pmset', '-g', 'batt']).split("\t")[0].split(" ")[3][1:]
    print "Power source is: {}".format(source)
    return source == 'AC'

def is_a_laptop():
    return subprocess.check_output(['sysctl', 'hw.model']).find('MacBook') > 0


def recommended_updates():
    """ Return a dict of pending recommended updates """
    updates = CFPreferencesCopyAppValue('RecommendedUpdates',
                                        '/Library/Preferences/com.apple.SoftwareUpdate')
    
    # If there are no updates, explicitly return None
    if updates and len(updates) > 0:
        return updates
    else:
        return None


def is_downloaded(update):
    """ Returns true if the update has been downloaded """
    if update.get("Product Key") in os.listdir(UPDATES_CACHE):
        print("{} is already downloaded".format(update.get("Product Key")))
        return True
    else:
        return False
              

def is_recommended(update):
    """ Returns true if the update is in the list of
    pending recommended updates for this machine """
    return update in recommended_updates()


def requires_restart(update):
    """ Returns True if the update requires a restart 

        Pass in an update dict
    """
    # We look inside the .dist file in the update package to
    # check for a RequireRestart flag.

    # I'm not sure what the cleanest way to do this is.
    # Parsing the output of softwareupdate -l is pretty horrible
    # but I'm not convinced this approach is much better.

    answer = False
    distfile = None

    for afile in os.listdir(os.path.join(UPDATES_CACHE, update.get("Product Key"))):
        # The .dist file is localised (ie update.language.dist)
        # We don't know the localisation adhead of time, so just look for
        # any .dist file in the update - any one will do.
        if afile.endswith(".dist"):
            # Some updates have a 'zzzz' prepended to the productKey, but
            # this isn't present in the name of the dist file.
            canonical_name = afile.replace('zzzz', '')
            distfile = os.path.join(UPDATES_CACHE, update.get("Product Key"), canonical_name)
            break
    try:
        distinfo = ElementTree.parse(distfile)
    except IOError as err:
        raise Exception('{}: Unreadable\n  {}'.format(update.get("Product Key"), err))

    # If the update requires a restart, it will have onConclusion = RequireRestart
    # set in its package ddistribution file.
    for pkg in distinfo.findall('choice/pkg-ref'):
        if pkg.get('onConclusion') == "RequireRestart":
            answer = True
            break
    return answer



def download_update(update):
    """ Download a single update, using the softwareupdate -d command 
    
        Pass in an update dict
    """
    # The name we pass to softwareupdate consists of:
    # [Identifier]-[Display Version] so we need to derive that
    # from the productKey we've been given.
    identifier = "{}-{}".format(update.get("Identifier"),
                                update.get("Display Version"))
                 

    print("Downloading {}".format(identifier))

    cmd_with_timeout([SWUPDATE, '-d', identifier], 3600)
    
if __name__ == "__main__":
    args = get_args()
    process_updates(args)

