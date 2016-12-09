#!/usr/bin/python

################################################################################
#
# Generic script to wait for some processes to exit before kicking
# off another policy.
#
# Arguments:
#
#  $4 (app_name): The human-friendly name of the application we want to install.
#  $5 (app_path): Path to the application we are installing (unused at present).
#  $6 (banned_procs): A regular expression which will be matched against the
#                     output of 'ps' to determine whether any unwanted processes
#                     are running, eg: (Microsoft Word$|Endnote\.app.*)
#  $7 (post_trigger): A trigger event which will be launched by this policy
#                     when there are no banned_processes running.
#
# Last Changed: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
#################################################################################

import re
import sys
from subprocess import (Popen, check_call, check_output, PIPE, STDOUT)
from time import sleep

def prompt_for_banned_procs(app_name, banned_procs, post_trigger):
    """ While any processes matching the regex banned_procs
        are running, display a message requesting that the
        user kill them.
        
        Once there are none, execute post_policy
    """
    showed_msg = False
    helper = None
    
    print "Waiting for processes matching %s to exit...." % banned_procs
    
    while search_procs(banned_procs) is not None:
        showed_msg = True
        # Ask the user to quit the offending processes. We are in a
        # while loop because the user can quit the jamfHelper process
        if helper is None or helper.poll() is not None:
            helper = display_message(search_procs(banned_procs, names=True), app_name)
            sleep(0.5)
                                     
    # If we made it to here, the 'banned' processes have been quit
    # so kill off the jamfHelper process if it still exists.
    if showed_msg == True and helper.poll() is None:
        helper.terminate()

    # If we are here, there are no banned processes running
    # so launch the post policy.
    print "Firing trigger %s" % post_trigger
    check_call(['/usr/local/bin/jamf', 'policy', '-event', post_trigger])
  


def display_message(processes, app_name):
    """ Use jamfHelper to display a message to the user
        asking them to quit the offending processes
    """
    JAMFHELPER = '/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
    
    msg = (("An update is available for %s.\n\n" +
          "Please close these applications to allow the update to install:\n\n%s") %   
          (app_name, '\n'.join([ p.split('/')[-1] for p in processes ])))

    helper = Popen([ JAMFHELPER,
                              '-windowType', 'hud',
                              '-title', 'Updating %s' % app_name,
                              '-icon', '/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns',
                              '-iconSize', '64',
                              '-timeout', '99999',
                              '-description', msg ], stdout=PIPE, stderr=STDOUT)          
    return helper


def search_procs(p_pattern, names=False):
    """ Return list of pids for processes
        whose name matches regex
    """
    # Get a list of all running processes
    procs = check_output(['ps', '-Ao', 'pid,comm'], stderr=STDOUT).split('\n')
    # Format it into a list of [ [pid, path], [pid, path] ]
    proc_list = [ x.strip().split(' ', 1) for x in procs if x is not '']
    p_regex=re.compile(p_pattern)
    try: 
        if names == False: # Just return PIDs
            result = [ ps[0] for ps in proc_list if re.search(p_regex, ps[1]) ]
        else: # Just return names
            result = [ ps[1] for ps in proc_list if re.search(p_regex, ps[1]) ]
    except IndexError:
        result = None
    if len(result) == 0:
        result = None
    return result


if __name__ == '__main__':
    prompt_for_banned_procs(sys.argv[4], sys.argv[6], sys.argv[7])



  
