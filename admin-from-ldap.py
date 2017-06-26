#!/usr/bin/python

###
# Search LDAP for a group with a name which matches our computer name
# If we find one, make the local admin users group on this machine match
# it as closely as possible.
###

from SystemConfiguration import SCDynamicStoreCopyConsoleUser
from pwd import getpwnam
import subprocess
import ldap
import ldap.sasl
import sys
import re
import os

def main(args):
    # These should be provided by the JSS.
    LDAP_SERVER = args[4]
    LDAP_BASE = args[5]

    user = current_user()
    
    # Check whether the current user has a Kerberos Ticket-granting Ticket
    if user_has_tgt(user):
        # if we have been called with '--get-admins' just print the users 
        # who should be admins, then exit. 
        if len(args) > 6 and args[6] == '--get-admins':
            print " ".join(get_group_members(computer_name(), LDAP_SERVER, LDAP_BASE))
            sys.exit(0)
        else:
            # Call this script, as the current console user, to utilise their Kerberos Credentials Cache
            # The three 'dummy' arguments take the place of the arguments the JSS would 
            # add if it were calling us.
            members = subprocess.check_output(['launchctl', 'asuser', str(uid(user)), sys.argv[0],
                                                'dummy', 'dummy', 'dummy', LDAP_SERVER, LDAP_BASE,
						'--get-admins']).strip().split(" ") 
           
            if len(members) > 0: 
                # Make all members of the LDAP group (if found) local admins 
                for mem in members:
                    if user_is_local_user(mem):
                        if not user_is_member_of('admin', mem):
                            print "Adding {} to group {}".format(mem, 'admin')
                            add_user_to_group('admin', mem)
                    else:
                        print "Not a local user:", mem
            
            # Remove any local admins who are not members of the LDAP group (FIXME: this 
            # should probably be more nuanced)  
            current_admins = get_current_admins()
            for adm in current_admins:
                if adm not in members:
                    print "Removing {} from group {}".format(adm, 'admin')
                    remove_user_from_group('admin', adm)  

    else:
        print "No Kerberos TGT for", current_user()

def ldap_bind(server):
    try:
        con=ldap.initialize(server)
        auth = ldap.sasl.gssapi("")
        con.sasl_interactive_bind_s("", auth)
    except Exception, e:
        print "Error: Failed to bind to LDAP server: %s" % e
        sys.exit(1)
    return con

def current_user():
    username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]
    username = [username,""][username in [u"loginwindow", None, u""]]
    return (username)

def uid(user):
    return getpwnam(user)[2]

def user_has_tgt(user):
    # Check whether user has a kerberos TGT
    try:
       subprocess.check_call(['launchctl', 'asuser', str(uid(user)), 'klist', '-s'])
       return True
    except subprocess.CalledProcessError:
       return False
    
def get_group_members(group, server, base):
    # Search LDAP 'server' for a group named 'group' anywhere under
    # search base 'base' and return a list of the CNs of group
    # members.
    con = ldap_bind(server)
    ldap_result_id = con.search(base, ldap.SCOPE_SUBTREE, 'cn=' + group, ['member'])
    result_type, result_data = con.result(ldap_result_id)
    members = []
    for mem in result_data[0][1]['member']:
       members.append(mem.split(',')[0].replace('CN=',""))
    return members 

def get_current_admins():
    raw = subprocess.check_output(['dscl', '.', '-read', '/Groups/admin', 'GroupMembership'])    
    return raw.split()[2:]
      
def user_is_member_of(group, user):
    # Is the user already a local admin?
    try:
        subprocess.check_call(['dseditgroup', '-o', 'checkmember', '-m', user, group])
        return True
    except subprocess.CalledProcessError:
        return False

def user_is_local_user(user):
    try:
        FNULL = open(os.devnull, 'w')
        subprocess.check_call(['dscl', '.', '-read', ('/Users/' + user)], stdout=FNULL, stderr=FNULL)
        return True
    except subprocess.CalledProcessError as e:
        if e.returncode == 56:
            return False
        else:
            raise

def add_user_to_group(group, user):
    subprocess.check_call(['dseditgroup', '-o', 'edit', '-a', user, '-t', 'user', group])

def remove_user_from_group(group, user):
    subprocess.check_call(['dseditgroup', '-o', 'edit', '-d', user, '-t', 'user', group])

def computer_name():
    computer_name = subprocess.check_output(['scutil', '--get', 'ComputerName']).strip()
    return computer_name

if __name__ == "__main__":
    main(sys.argv)        
