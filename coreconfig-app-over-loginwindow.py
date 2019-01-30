#!/usr/bin/python
import sys
import plistlib
import os
import subprocess

# This script will set up (or remove) a launchagent to ensure that `app` runs over
# the loginwindow.
# 
# ARGS:
# $4: ENABLE | DISABLE | DELETE
# $5: Path to application
# $6: LaunchAgent identifier
# $7: Timeout (in seconds)
# $8: (optional) path to the script which will launch `app`
#
# This script will create (or remove) a LaunchAgent and a launcher script. The Agent specifies
# a SessionType of 'LoginWindow' which ensures that it is only loaded when the machine
# is sitting at the loginwindow. The Agent loads a launcher script, which handles
# checking the idle time and launches `app` if the threshold exceeded in $7 has been 
# exceeded.
#
# NB only certain apps can run over loginwindow - it is your responsibility to check
# that the app you are launching works corrrectly 
#
# NBB apps launched over the loginwindw run as root, so there are security implications to 
# doing this with an app you don't fully control.
#
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER




def parse_args():
    """ Parse arguments and return a dict containing them """
    args = {}
    args['me'] = sys.argv[0]
    args['action'] = sys.argv[4]
    args['app'] = sys.argv[5]
    args['id'] = sys.argv[6]
    args['timeout'] = sys.argv[7]
    args['script_path'] = sys.argv[8]

    if args['action'] not in ['ENABLE', 'DISABLE', 'DELETE']:
        print('$4 must be ENABLE, DISABLE or DELETE')
        sys.exit(255)
    if not (os.path.isfile(args['app']) and 
            os.access(args['app'], os.X_OK)):
        print('$5 must be a path to an executable')
        sys.exit(255)
    if args['id'] in [None,  ""]:
        print('Must provide an identifier as $6')
        sys.exit(255)
    if args['script_path'] in [None,  ""]:
        args['script_path'] = os.path.join('/Library/MacSD/Scripts/',
                                args['id']) + '_launcher.py'          

    
    return args


def create_launchagent(agent_id, executable):
    # Create a LaunchAgent to lock out the loginwindow
    # We create it 'Disabled' and leave it that way, loading it
    # with launchctl '-F' to ensure it's never loaded accidentally.
    contents = { "Label": agent_id,
                 "Disabled": True,
                 "LimitLoadToSessionType": ['LoginWindow'],
                 "ProgramArguments": [executable],
                 "RunAtLoad": True,
                 "keepAlive": False
                 }

    # Just overwrite it if it's already there
    print('Writing agent file to ' + os.path.join('/Library/LaunchAgents/', agent_id))
    plistlib.writePlist(contents, os.path.join('/Library/LaunchAgents/', agent_id))

def delete_launchagent(agent_id):
    if os.path.isfile(os.path.join('/Library/LaunchAgents/', agent_id)):
        print("deleting agent from " + os.path.join('/Library/LaunchAgents/', agent_id))
        os.unlink(os.path.join('/Library/LaunchAgents/', agent_id))


def load_launchagent(agent_id):
    print("Loading agent")
    try:
        subprocess.check_call(['launchctl', 'load', '-F', 
                            '-w', '-S', 'LoginWindow', os.path.join('/Library/LaunchAgents/', 
                                                                        agent_id)])
    except subprocess.CalledProcessError:
        print("Couldn't load agent - perhaps we are not currently at loginwindow")

def unload_launchagent(agent_id):
    print("Unoading agent")
    try:
        subprocess.check_call(['launchctl', 'unload', '-F', 
                           '-w', '-S', 'LoginWindow', os.path.join('/Library/LaunchAgents/', 
                                                                    agent_id)])
    except subprocess.CalledProcessError:
        print("Couldn't unload agent - perhaps it wasn't loaded")

def delete_script(path):
    try:
        print("Deleting script at " + path)
        os.unlink(path)
    except OSError:
        print("Failed - perhaps it doesnt exist")

def create_script(path, app, timeout):
    script = """#!/usr/bin/env python
>>>import os
>>>import time
>>>def get_idle_time():
    >>>\"\"\"Get number of seconds since last user input\"\"\"
    >>>cmd = "ioreg -c IOHIDSystem | perl -ane 'if (/Idle/) {{$idle=(pop @F)/1000000000; print $idle}}'"
    >>>result = os.popen(cmd)
    >>>str = result.read()
    >>>idle = int(str.split(".")[0])
    >>>return idle

>>>while True:
    >>>idletime = get_idle_time()
    >>>print('Idle Time is ' + str(idletime))
    >>>if idletime > {}:
        >>>subprocess.check_call(['{}'])
    >>>time.sleep(30) """.format(timeout, app)

    print("Creating script at " + path)
    outfile = open(path, 'w')
    outfile.write(script.replace('>>>', ''))
    subprocess.check_call(['chmod', '+x', path])


if __name__ == "__main__":
    ARGS = parse_args()
    print(ARGS)
    if ARGS['action'] == 'ENABLE':
        create_launchagent(ARGS['id'], ARGS['script_path'])
        create_script(ARGS['script_path'], ARGS['app'], ARGS['timeout'])
        load_launchagent(ARGS['id'])
    elif ARGS['action'] == 'DISABLE':
        unload_launchagent(ARGS['id'])
    elif ARGS['action'] == 'DELETE':
        unload_launchagent(ARGS['id'])
        delete_launchagent(ARGS['id'])
        delete_script(ARGS['script_path'])
    else:
        print("Unknown error!")
        sys.exit(255)