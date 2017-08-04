#############################################################
#
# If OneDrive hasn't been configured for Business Use, put a link to the
# OneDrive applicatoin into the user's Finder favorites. Conversely
# if OneDrive is configured for business, remove the link (as the OneDrive
# Folder itself will be in the sidebar
#
# Code liberally cribbed from here: 
# http://programtalk.com/vs2/?source=python/10467/pyLoginItems/pyLoginItems.py
#
# Author: g.lee@ed.ac.uk
#############################################################

from Foundation import NSURL
from LaunchServices import kLSSharedFileListFavoriteItems, kLSSharedFileListNoUserInteraction
from Foundation import NSBundle
import subprocess
import objc

# The ObjC bridge for LSSharedFileList is broken/missing on 10.11 and above, 
# this black magic loads the necessary bits manually
 
SFL_bundle = NSBundle.bundleWithIdentifier_('com.apple.coreservices.SharedFileList')
functions  = [('LSSharedFileListCreate',              '^{OpaqueLSSharedFileListRef=}^{__CFAllocator=}^{__CFString=}@'),
              ('LSSharedFileListCopySnapshot',        '^{__CFArray=}^{OpaqueLSSharedFileListRef=}o^I'),
              ('LSSharedFileListItemCopyDisplayName', '^{__CFString=}^{OpaqueLSSharedFileListItemRef=}'),
              ('LSSharedFileListItemResolve',         'i^{OpaqueLSSharedFileListItemRef=}Io^^{__CFURL=}o^{FSRef=[80C]}'),
              ('LSSharedFileListItemMove',            'i^{OpaqueLSSharedFileListRef=}^{OpaqueLSSharedFileListItemRef=}^{OpaqueLSSharedFileListItemRef=}'),
              ('LSSharedFileListItemRemove',          'i^{OpaqueLSSharedFileListRef=}^{OpaqueLSSharedFileListItemRef=}'),
              ('LSSharedFileListInsertItemURL',       '^{OpaqueLSSharedFileListItemRef=}^{OpaqueLSSharedFileListRef=}^{OpaqueLSSharedFileListItemRef=}^{__CFString=}^{OpaqueIconRef=}^{__CFURL=}^{__CFDictionary=}^{__CFArray=}'),
              ('kLSSharedFileListItemBeforeFirst',    '^{OpaqueLSSharedFileListItemRef=}'),
              ('kLSSharedFileListItemLast',           '^{OpaqueLSSharedFileListItemRef=}'),]
objc.loadBundleFunctions(SFL_bundle, globals(), functions)

def main():
    if onedrive_is_configured():
        remove_fav('/Applications/OneDrive.app')
        print 'Removed OneDrive from favorites'
    else:
        add_fav('/Applications/OneDrive.app')
        print 'Added OneDrive to favorites'

def _get_favs():
    list_ref = LSSharedFileListCreate(None, kLSSharedFileListFavoriteItems, None)
    favs,_ = LSSharedFileListCopySnapshot(list_ref, None)
    return [list_ref, favs]

def _get_item_cfurl(an_item, flags=None):
    if flags is None:
        # Attempt to resolve the items without interacting or mounting
        flags = kLSSharedFileListNoUserInteraction + kLSSharedFileListNoUserInteraction
    err, a_CFURL, a_FSRef = LSSharedFileListItemResolve(an_item, flags, None, None)
    return a_CFURL

def list_favs():
    # Attempt to find the URLs for the items without mounting drives
    URLs = []
    for an_item in _get_favs()[1]:
        URLs.append(_get_item_cfurl(an_item).path())
    return URLs

def remove_fav(path_to_item):
    current_paths = list_favs()
    if path_to_item in current_paths:
        list_ref, current_items = _get_favs()
        i = current_paths.index(path_to_item)
        target_item = current_items[i]
        result = LSSharedFileListItemRemove(list_ref, target_item)

def add_fav(path_to_item):
    current_paths = list_favs()
    if path_to_item not in current_paths:
        list_ref, current_items = _get_favs()
        added_item = NSURL.fileURLWithPath_(path_to_item)
        result = LSSharedFileListInsertItemURL(list_ref, kLSSharedFileListItemLast, None, None, added_item, {}, [])

def onedrive_is_configured():
    # How do we tell if OneDrive is configured?
    # Looking for the existence of the IsBusinessProvisioned pref key
    # is one option
    result = 0
    try:
        result = subprocess.check_output(['defaults', 'read', 'com.microsoft.OneDrive', 'IsBusinessProvisioned'])
    except subprocess.CalledProcessError: # Key didn't exist
        return False
    if result.strip() == '1':
        return True
    else:
        return False

if __name__ == "__main__":
    main()
