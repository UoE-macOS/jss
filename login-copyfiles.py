#!/usr/bin/python

###################################################################
#
# Sync files and directories from <source>, to matching locations in
# the home folder of the logging-in user.
#
# Args:
# 3: Username of logging-in user
# 4: Source root - all source directories are relative to this one
# 5: Items - comma-separated list of items to be copied from source
#    root to dest root. Paths relative to the home folder of the 
#    logging-in user.
# 6 - 11: Continuation of $5. Args from $6 to $11 will be added to the
#         list of items to be copied.
#
# This script expects to be run as a login script with $3 containing
# the username of the logging-in user.
# 
# Date: @@DATE
# Version: @@VERSION
# Origin: @@ORIGIN
# Released by JSS User: @@USER
#
##################################################################
from __future__ import print_function
import os
import sys
import pwd
import time
import subprocess
from datetime import datetime
from distutils.file_util import copy_file
from distutils.dir_util import mkpath
from distutils.errors import DistutilsFileError



def main(args):
    # Only run for non-local users.
    if user_is_local(args['user']):
        log("{} is a local user. Exiting".format(args['user']))
        sys.exit(0)
    
    # Just bail if the target doesn't appear. We don't
    # want to create it ourselves, as we don't want to 
    # interfere with the OS user-templating process.
    if not wait_for_target(args['target']):
        sys.exit(1)

    for item in args['items']:
        target = '/'.join([args['target'], item])
        source = '/'.join([args['source'], item])
        log("Copying {} to {}".format(source, target))
        try:

            copy_item(source, target, args)
        except Exception as exc:
            print(exc)
            raise

    log("Done.") 
        
      
def process_args(argv=None):
    argv = argv or sys.argv
    args = {}

    args['source'] = argv[4]
    
    args['items'] = []

    for arg in range(5, 11):
        try:
            if argv[arg] != "":
                log('Adding to list: ' + argv[arg])
                args['items'] += argv[arg].split(',')
        except IndexError:
            break


    args['target'] = os.path.expanduser('~' + argv[3])
    args['uid'] = pwd.getpwnam(argv[3]).pw_uid
    args['gid'] = 20 # 'staff' - default group
    args['user'] = argv[3]
    
    log('source: ' + args['source'])
    log('target: ' + args['target'])
    log('items: ' + '\n'.join(args['items']))

    return args

  
  
def user_is_local(user):
    return ('user is a member of the group' in
        subprocess.check_output(['dsmemberutil', 'checkmembership',
                                '-U', user, '-G', 'localaccounts']).split('\n'))
  
  
def copy_item(source, target, args):
    
    create_parents(source, target, args)

    if os.path.isfile(source):
        copy_file(source, target)
        os.chown(target, args['uid'], args['gid'])
        
    elif os.path.isdir(source):
        copy_tree(source, target, uid=args['uid'], gid=args['gid'])

    else:
        raise TypeError('copy_item() passed something other'
                        'than a path to a file or directory.')


def create_parents(source, target, args):
    def _recurse(path):
        components = []
        if os.path.isfile(path):
            components = os.path.dirname(target).split('/')
        elif os.path.isdir(path):
            components = target.split('/')
        for i in range(1, len(components) + 1):
            thisdir = '/' + '/'.join(components[:i])
            log(thisdir)
            yield thisdir
    
    for item in _recurse(source):
        if not os.path.isdir(item):
            os.mkdir(item)
            os.chown(item, args['uid'], args['gid'])


def wait_for_target(target):
    maxwait = 10
    waited = 0
    while not os.path.isdir(target):
        if waited == maxwait:
            log('Target {} doesn\'t exist after {} '
                'seconds. Exiting'.format(target, maxwait))
            return False
        else:
            log('Waiting for {} to exist ({})'.format(target, waited))
            waited += 1
            time.sleep(1)
    return True

def log(msg):
    print('{}: {}'.format(datetime.now(), msg))


# This is copied from distutils and modified to add chown functionality
def copy_tree(src, dst, uid=None, gid=None, preserve_mode=1, preserve_times=1,
              preserve_symlinks=0, update=0, verbose=1, dry_run=0):
    """Copy an entire directory tree 'src' to a new location 'dst'.

    Both 'src' and 'dst' must be directory names.  If 'src' is not a
    directory, raise DistutilsFileError.  If 'dst' does not exist, it is
    created with 'mkpath()'.  The end result of the copy is that every
    file in 'src' is copied to 'dst', and directories under 'src' are
    recursively copied to 'dst'.  Return the list of files that were
    copied or might have been copied, using their output name.  The
    return value is unaffected by 'update' or 'dry_run': it is simply
    the list of all files under 'src', with the names changed to be
    under 'dst'.

    If 'uid' and 'gid' are provided, newly created directories and 
    files will have ownership changed to match them. Requires that 
    you are running as root.
    
    'preserve_mode' and 'preserve_times' are the same as for
    'copy_file'; note that they only apply to regular files, not to
    directories.  If 'preserve_symlinks' is true, symlinks will be
    copied as symlinks (on platforms that support them!); otherwise
    (the default), the destination of the symlink will be copied.
    'update' and 'verbose' are the same as for 'copy_file'.
    """

    if not dry_run and not os.path.isdir(src):
        raise DistutilsFileError, \
              "cannot copy tree '%s': not a directory" % src
    try:
        names = os.listdir(src)
    except os.error, (errno, errstr):
        if dry_run:
            names = []
        else:
            raise DistutilsFileError, \
                  "error listing files in '%s': %s" % (src, errstr)

    if not dry_run:
        mkpath(dst, verbose=verbose)
        if uid and gid:
            log('chown: ' + dst)
            os.chown(dst, uid, gid)

    outputs = []

    for n in names:
        src_name = os.path.join(src, n)
        dst_name = os.path.join(dst, n)

        if preserve_symlinks and os.path.islink(src_name):
            link_dest = os.readlink(src_name)
            if verbose >= 1:
                log("linking {} -> {}".format(dst_name, link_dest))
            if not dry_run:
                os.symlink(link_dest, dst_name)
            outputs.append(dst_name)

        elif os.path.isdir(src_name):
            outputs.extend(
                copy_tree(src_name, dst_name, uid, gid, preserve_mode,
                          preserve_times, preserve_symlinks, update,
                          verbose=verbose, dry_run=dry_run))
        else:
            copy_file(src_name, dst_name, preserve_mode,
                      preserve_times, update, verbose=verbose,
                      dry_run=dry_run)
            if uid and gid:
                log('chown: ' + dst_name)
                os.chown(dst_name, uid, gid)
            outputs.append(dst_name)
           

    return outputs


if __name__ == '__main__':
    main(process_args())