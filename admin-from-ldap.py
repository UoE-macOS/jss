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

SERVER = sys.argv[4] 
SEARCH_BASE = sys.argv[5] 
SCOPE = sys.argv[6]

def main(args):
    user = current_user()
    if user_has_tgt(user):
        if len(args) > 1 and args[1] == '--get-admins':
            print " ".join(get_group_members(computer_name()))
        else:
            # Call ourselves, as the current user, to utilise our TGT
            members = subprocess.check_output(['launchctl', 'asuser', 
                                                str(uid(user)), sys.argv[0], 
                                                '--get-admins']).strip().split(" ") 
            for mem in members:
                if not user_is_member_of('admin', mem):
                    print "Adding {} to group {}".format(mem, 'admin')
                    add_user_to_group('admin', mem)
           
            current_admins = get_current_admins()
            for adm in current_admins:
                if adm not in members:
                    print "Removing {} from group {}".format(adm, 'admin')
                    remove_user_from_group('admin', adm)  

    else:
        print "No Kerberos TGT for", current_user()

def ldap_bind():
    try:
        con=ldap.initialize(SERVER)
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
    except subprocess.calledProcessError:
       return False
    
def get_group_members(group):
    con = ldap_bind()
    ldap_result_id = con.search(SEARCH_BASE, SCOPE, 'cn=' + group, ['member'])
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

def add_user_to_group(group, user):
    subprocess.check_call(['dseditgroup', '-o', 'edit', '-a', user, '-t', 'user', group])

def remove_user_from_group(group, user):
    subprocess.check_call(['dseditgroup', '-o', 'edit', '-d', user, '-t', 'user', group])

def computer_name():
    computer_name = subprocess.check_output(['scutil', '--get', 'ComputerName']).strip()
    return computer_name

if __name__ == "__main__":
    main(sys.argv)        
