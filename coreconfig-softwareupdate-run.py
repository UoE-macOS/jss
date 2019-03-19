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
import platform
import sys
import subprocess
import plistlib
import datetime
import thread
import time
import logging
import signal
from threading import Timer
from SystemConfiguration import SCDynamicStoreCopyConsoleUser
from xml.etree import ElementTree
from Foundation import CFPreferencesCopyAppValue

# Set location of log file
log_file = "/Library/Logs/software-update.log"
if os.path.exists(log_file):
    os.remove(log_file)

# Create logger object and set default logging level
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Create console handler and set level to debug
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)

# Create file handler and set level to debug
file_handler = logging.FileHandler(r'/Library/Logs/software-update.log')
file_handler.setLevel(logging.DEBUG)

# Create formatter
formatter = logging.Formatter('[%(asctime)s][%(levelname)s] %(message)s', datefmt='%a, %d-%b-%y %H:%M:%S')

# Set formatters for handlers
console_handler.setFormatter(formatter)
file_handler.setFormatter(formatter)

# Add handlers to logger
logger.addHandler(console_handler)
logger.addHandler(file_handler)

# Declare variables
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
#SWUPDATE_ICON = '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns'
UNI_LOGO = '/usr/local/jamf/UoELogo.png'
CAUTION_ICON = '/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns'

def get_args():
    logger.info("Grabbing arguments from JSS.")
    try:
        args = { 'DEFER_LIMIT': int(sys.argv[4]),
                 'QUIET_HOURS_START': int(sys.argv[5]),
                 'QUIET_HOURS_END': int(sys.argv[6]),
                 'MIN_BATTERY_LEVEL': int(sys.argv[7])
        }
    except ValueError:
        logger.error("You need to specify DEFER_LIMIT, QUIET_HOURS_START, QUIET_HOURS_AND and MIN_BATTERY_LEVEL as integers")
        raise
    return args

# Function to close and remove logging handlers
def close_logger():
    console_handler.close()
    file_handler.close()
    logger.removeHandler(console_handler)
    logger.removeHandler(file_handler)

def check_for_icon(path_to_icon):
    if os.path.exists(path_to_icon):
        logger.info("SW Update icon found at %s" % path_to_icon)
    else:
        logger.warn("Unable to find icon at %s" % path_to_icon)

def kill_jh():
    # Get all jamfhelper PIDs. By default check_output returns "\n" at the end of it's line, so we want to strip the new line so it's not included in the output.
    # By default, check_output also returns an exception if there is a problem, so using a try
    try:
        jh_process = subprocess.check_output(['pgrep','jamfHelper']).strip()
    # If Jamf Helper is not running then break from the function
    except:
        logger.info("No Jamf Helper process is running")
        return
    # For each jamf helper process
    for proc in jh_process.splitlines():
        # As it's a string, convert it to integer
        jh_pid = int(proc)
        logger.info("Killing jamfHelper process ID : %d" % jh_pid)
        # Kill the process
        os.kill(jh_pid, signal.SIGTERM)

def process_updates(args,sw_update_icon):
    # Don't run if the quickadd package is still doing its stuff
    if os.path.exists(QUICKADD_LOCK):
        logger.error("QuickAdd package appears to be running - will exit")
        close_logger()
        sys.exit(0)

    need_restart = []
    try:
        logger.info("Checking to see what updates are available.")
        sync_update_list()
        if (recommended_updates() is None) or len(recommended_updates()) == 0:
            logger.info("There are no recommended updates to be installed.")
            remove_deferral_tracking_file()
            return True

        for update in recommended_updates():
            logger.info("Processing {}".format(update.get("Display Name")))
            # Download only if required
            if not is_downloaded(update):
                logger.info("Downloading %s" % update)
                download_update(update)

            # If already downloaded
            if is_downloaded(update):
                if not requires_restart(update):
                    logger.info("%s is already downloaded and doesn't require a restart. Installing..." % update)
                    install_update(update)
                else:
                    # Restart is required. Add
                    # to the list
                    logger.info("%s is downloaded but requires a restart. Adding to the list of updates that require a restart." % update)
                    need_restart.append(update)

            if len(need_restart) == 0:
                # No updates require a restart, and we are done.
                logger.info("No updates require a restart.")
                return True

        # Now we can deal with updates that require a restart
        if console_user():
            logger.info("Currently logged in user is %s" % console_user())
            # Are we allowed to defer logout?
            max_defer_date = deferral_ok_until(args['DEFER_LIMIT'])
            if max_defer_date != False:
                # Yes, we were allowed to defer
                # Does the user want to defer?
                if not user_wants_to_defer(max_defer_date,
                                           "\n".join([u.get("Display Name") for u in need_restart]),sw_update_icon):
                    logger.info("%s doesn't want to defer" % console_user)
                    # User doesn't want to defer, so set
                    # things up to install update, and force
                    # logout.
                    if is_a_laptop():
                        apply_updates_laptop()
                    else:
                        logger.info('Preforming "friendly" logout.')
                        friendly_logout()
                else:
                    logger.info("%s has chosen to defer" % console_user())
                    # User wants to defer, and is allowed to defer.
                    # OK, just bail
                    return True
            else:
                # User is not allowed to defer any longer
                # so require a logout
                if is_a_laptop():
                    apply_updates_laptop()
                else:
                    logger.warn("%s is not allowed to defer any longer." % console_user())
                    force_logout("\n".join([u.get("Display Name") for u in need_restart]))

        elif ( nobody_logged_in() and
               is_quiet_hours(args['QUIET_HOURS_START'],
                              args['QUIET_HOURS_END'])):
            logger.info("Nobody is logged in and we are in quiet hours - starting unattended install...")
            unattended_install(min_battery=args['MIN_BATTERY_LEVEL'])

        else:
            logger.warn("Updates require a restart but someone is logged in remotely or we are not in quiet hours - aborting")
            return False

    except KeyboardInterrupt:
        # If any of the softwareupdate commands times out
        # we receive a KeyboardInterrupt
        logger.error("Command timed out: giving up!")
        close_logger()
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
    if (using_ac_power() or min_battery_level(min_battery)):
        if not is_a_laptop():
            # We won't have any network access at the loginwindow so not much point attempting this on a laptop
            lock_out_loginwindow()
            install_recommended_updates()
            # We should make this authenticated...
            unauthenticated_reboot()
        else:
            logger.info("Model type MacBook, unattended install won't complete.")
    else:
        logger.warn("Power conditions were unacceptable for unattended installation.")

def unauthenticated_reboot():
    # Will bring us back to firmware login screen
    # if filevault is enabled.
    subprocess.check_call(['/sbin/reboot'])



def create_lgwindow_launchagent():
    # Create a LaunchAgent to lock out the loginwindow
    # We create it 'Disabled' and leave it that way, loading it
    # with launchctl '-F' to ensure it's never loaded accidentally.
    logger.info("Creating loginwindow launchagent.")
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
    logger.info("Attempting to lockout the loginwindow")
    # Make sure our agent exists
    create_lgwindow_launchagent()
    time.sleep(1)
    # Then load it
    helper_tries = 1
    while helper_tries < 6:
        if os.path.exists(HELPER_AGENT):
            logger.info("Attempting to load: uk.ac.ed.mdp.jamfhelper-swupdate")
            subprocess.check_call(['launchctl', 'load',
                                   '-F', '-S', 'LoginWindow',
                                   HELPER_AGENT ])
            break
        else:
            logger.info("Failed to create helper agent, waiting...")
            time.sleep(1)
            helper_tries += 1
            logger.info("waiting for agent, attempts : %d" % helper_tries)


def sync_update_list():
    logger.info("Checking for updates")
    # Get all recommended updates
    cmd_with_timeout([ SWUPDATE, '-l', '-r' ], 180)


def install_update(update):
    """ Install a single update """
    update_name = "{}-{}".format(update.get("Identifier"),
                                 update.get("Display Version"))

    logger.info("Installing: {}".format(update_name))
    result = cmd_with_timeout([ SWUPDATE, '-i', update_name ], 3600)

def deferral_ok_until(limit):
    now = datetime.datetime.now()
    if os.path.exists(DEFER_FILE):
        # Read deferral date
        df = plistlib.readPlist(DEFER_FILE)
        ok_until = df['DeferOkUntil']
        if now < ok_until:
            logger.info("OK to defer until {}".format(ok_until))
            return ok_until
        else:
            logger.warn("Not OK to defer ({}) is in the past".format(ok_until))
            return False
    else:
        # Create the file, and write into it
        limit = datetime.timedelta(days = int(limit) )
        defer_date = now + limit
        plist = { 'DeferOkUntil': defer_date }
        plistlib.writePlist(plist, DEFER_FILE)
        logger.info("Created deferral file - Ok to defer until {}".format(defer_date))
        return defer_date

def user_wants_to_defer(defer_until, updates, sw_update_icon):
    answer = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Software Update Available',
                              '-icon', sw_update_icon,
                              '-timeout', '99999',
                              '-description', "One or more software updates require a restart:\n\n%s\n\nUpdates must be applied regularly.\n\nYou will be required to restart after:\n%s.\n" % (updates, defer_until.strftime( "%a, %d %b %H:%M:%S")),
                              '-button1', 'Restart now',
                               '-button2', 'Restart later' ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if answer == 2: # 0 = now, 2 = defer
        logger.info("User elected to defer update")
        return True
    else:
        logger.info("User permitted immediate update")
        return False

def force_logout(updates):
    answer = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Mandatory Restart Required',
                              '-icon', SWUPDATE_ICON,
                              '-timeout', '99999',
                              '-description', "One or more updates which require a restart have been deferred for the maximum allowable time:\n\n%s\n\nA restart is now mandatory.\n\nPlease save your work and restart now to install the update." % updates,
                              '-button1', 'Restart now' ])
    friendly_logout()

def apply_updates_laptop():
    answer = subprocess.Popen([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Required Updates Applying',
                              '-icon', SWUPDATE_ICON,
                              '-timeout', '99999',
                              '-description', "One or more updates which require a restart are being applied.\n\nThis Mac will restart momentarily to complete the install.", '&'])
    install_recommended_updates()
    # Kill all instances of jamf helper
    kill_jh()
    friendly_reboot()

def retry_logout():
    answer = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Failed to logout!',
                              '-icon', SWUPDATE_ICON,
                              '-timeout', '99999',
                              '-description', "Logout does not appear to have been successful.\n\nPlease save your work and restart now to install the update.",
                              '-button1', 'Restart now' ])
    friendly_logout()

def remove_deferral_tracking_file():
    if os.path.exists(DEFER_FILE):
        os.remove(DEFER_FILE)
        logger.info("Removed deferral tracking file")

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
    logger.info("Attempting logout.")
    subprocess.call([ 'sudo', '-u', user, 'osascript', '-e', u'tell application "loginwindow" to  «event aevtrlgo»' ])
    logout_tries = 1
    while logout_tries < 15:
        logger.info("logout attempts : %d" % logout_tries)
        time.sleep(2)
        if nobody_logged_in():
            logger.info("It appears no one is logged in. Attempting unattended install.")
            unattended_install(min_battery=args['MIN_BATTERY_LEVEL'])
            logger.info("Break from loop")
            break
        else:
            logout_tries += 1
    # If after 15 attempts it's still unsuccessful, retry the logout
    logger.warn("Still not logged out. Attempting again.")
    retry_logout()

def friendly_reboot():

    logger.info("Attempting friendly restart.")
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
        logger.info("Reboot attempts : %d" % reboot_tries)
        # Display 2nd message, warning user to save their data.
        jh_window2 = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Update Notification',
                              '-icon', CAUTION_ICON,
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
                logger.info("No applications appear to be opened. Restarting.")
                subprocess.call(['osascript', '-e', 'tell app "System Events" to restart'])
                # Close logger
                close_logger()
                # Exit script
                sys.exit(0)
            # Else, it looks like there are apps open. Display message listing open apps.
            else:
                jh_window3 = subprocess.call([ JAMFHELPER,
                              '-windowType', 'utility',
                              '-title', 'UoE Mac Supported Desktop',
                              '-heading', 'Applications open',
                              '-icon', CAUTION_ICON,
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
            # All apps should now be closed. Restarting
            logger.info("Restarting!")
            subprocess.call(['osascript', '-e', 'tell app "System Events" to restart'])
            # Close logger
            close_logger()
            # Exit script
            sys.exit(0)
        reboot_tries += 1

def install_recommended_updates():
    # An hour should be sufficient to install
    # updates, hopefully!
    cmd_with_timeout([ SWUPDATE, '-i', '-r' ], 3600)

def min_battery_level(min):
    if is_a_laptop():
        try:
            level = subprocess.check_output(['pmset', '-g', 'batt']).split("\t")[1].split(';')[0][:-1]
            logger.info("Battery level: {}".format(level))
            return int(level) >= min
        except (IndexError, ValueError):
            # Couldn't get battery level - play it safe
            logger.info("Failed to get battery level")
            return False
    else:
        logger.info("Not a laptop.")

def using_ac_power():
    source = subprocess.check_output(['pmset', '-g', 'batt']).split("\t")[0].split(" ")[3][1:]
    logger.info("Power source is: {}".format(source))
    return source == 'AC'

def is_a_laptop():
    return subprocess.check_output(['sysctl', 'hw.model']).find('MacBook') > 0

def recommended_updates():
    """ Return a dict of pending recommended updates """
    updates = CFPreferencesCopyAppValue('RecommendedUpdates',
                                        '/Library/Preferences/com.apple.SoftwareUpdate')
    if len(updates) > 0:
        return updates

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
        # We don't know the localisation ahead of time, so just look for
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
    # set in its package distribution file.
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
    logger.info(("Downloading {}".format(identifier)))
    cmd_with_timeout([SWUPDATE, '-d', identifier], 3600)

if __name__ == "__main__":
    # Get OS Version
    macOS_vers, _, _ = platform.mac_ver()
    macOS_vers = float('.'.join(macOS_vers.split('.')[:2]))

    if (macOS_vers == 10.12) or (macOS_vers == 10.11) :
        logger.info("Running 10.12 or 10.11.")
        SWUPDATE_ICON = '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns'
        # Check to make sure software update logo exists
        check_for_icon(SWUPDATE_ICON)

    if (macOS_vers == 10.13):
        logger.info("Running 10.13.")
        SWUPDATE_ICON = '/System/Library/CoreServices/Install Command Line Developer Tools.app/Contents/Resources/SoftwareUpdate.icns'
        # Check to make sure software update logo exists
        check_for_icon(SWUPDATE_ICON)

    if (macOS_vers == 10.14):
        logger.info("Running 10.14")
        SWUPDATE_ICON = '/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns'
        # Check to make sure software update logo exists
        check_for_icon(SWUPDATE_ICON)

    args = get_args()
    process_updates(args, SWUPDATE_ICON)

    # Close the loggers
    logger.info("Done!")
    close_logger()
