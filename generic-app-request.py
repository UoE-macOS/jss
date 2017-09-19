#!/usr/bin/python
# -*- coding: utf-8 -*-

##########################################################################
#
# A generic mechanism for creating application authorisation requests.
#
# NB, on its own this script merely creates .apprequest files in a folder.
# It must be combined with the approprioate extension attribute and
# moddleware request processing software to be of any use.
#
# IN DEVELOPMENT - USE WITH CAUTION.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##########################################################################


import json
import sys
import os
import datetime
from uuid import uuid4
from subprocess import check_call, check_output, Popen, PIPE

REQUESTS_DIR = '/Library/MacAtED/AppRequests'

def main(args):
    APP_NAME = args[4]

    msg = get_msg(current_user(), APP_NAME)
    if msg == None:
      # The user cancelled - just exit.
      sys.exit(0)

    # Build our request
    request = {}
    request['date'] = get_now()
    request['UUN'] = get_user()
    request['UUID'] = gen_uuid()
    request['policy'] = APP_NAME
    request['message'] = msg  

    try:
        write_request(request)
        run_recon()
        display_confirmation()
    except Exception as ex:
        raise
        sys.exit(1)

def display_confirmation():
    script = """tell application "Finder"
                activate
                display dialog "Your request has been submitted successfully.
 
You'll receive an email when it has been processed." buttons {"OK"} default button {"OK"} with title "Mac@ED Application Requests"
               end tell
             """
    proc = Popen(['sudo', '-u', current_user(), 'osascript', '-'],
                        stdin=PIPE,
                        stdout=PIPE)  
    out = proc.communicate(script)[0]
    
    
def run_recon():
    check_call(['/usr/local/bin/jamf', 'recon'])
    

def write_request(request, dir=REQUESTS_DIR):
    try:
        os.makedirs(dir)
    except OSError as ex:
        if ex.args[1] == 'Permission denied':
            print "Couldn't create requests directory at {:s}".format(dir)
            raise
        elif ex.args[1] == 'File exists':
            pass

    # The directory should now exist for us to write into
    # If the file already exists, we have a big problem
    out_filename = dir + '/' + request['UUID'] + '.apprequest'

    if os.path.exists(out_filename):
        print "Our request already exists - this should not happen! UUID: {:s}".format(request['UUID'])
        raise

    # Now try to write the request file
    try:
        with open(out_filename, 'w') as out_file:
            out_file.write(json.dumps(request))
    except Exception as ex:
        print "Failed to write request file: {:s}".format(ex)
        raise
        
    
def get_now():
    return datetime.datetime.now().isoformat()

def get_user():
    return current_user()

def gen_uuid():
    return str(uuid4())

def current_user():
    return check_output(['ls', '-l', '/dev/console']).split()[2]

def get_msg(user, app):
    """ Ask the user for a message. Returns None if they clicked 
        Cancel 
    """
    msg = None
    script = """tell application "System Events"
	activate
	set message to ""
	set clicked to ""
	repeat until message is not ""
		set message to text returned of (display dialog "You are about to request permission to install {:s}.
		
Your request will be forwarded to the approver for your area.

Please leave a message (required):" with title "Mac@ED Application Approval" default answer "" buttons {{"Request", "Cancel"}} with icon file "System:Library:CoreServices:Installer.app:Contents:Resources:package.icns")
	end repeat
	return message
end tell""".format(app)
    
    with open(os.devnull, 'w') as FNULL:
  
        proc = Popen(['sudo', '-u', current_user(), 'osascript', '-'],
                        stdin=PIPE,
                        stdout=PIPE,
                        stderr=FNULL)  
        out = proc.communicate(script)[0]
        return out.strip() or None

if __name__ == "__main__":
  main(sys.argv)
