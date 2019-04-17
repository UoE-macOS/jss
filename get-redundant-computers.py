#!/usr/bin/python

# Import resources
import urllib2
import base64
import getpass
import subprocess
from collections import OrderedDict
import json
import sys

# Function for displaying computers in console
def display_computers(temp_comp_dict, dict_name):
    # Convert all machine names to upper case
    dict_upper = {k.upper(): v for k, v in temp_comp_dict.iteritems()}
    # Sort dictionary by keys
    comp_dict = sort_dict_by_keys(dict_upper)
    # For each key in the dictionary, print the key and the value
    print "\n%s" % (dict_name)
    print "========================================"
    for key in comp_dict:
        print "%s : %s" % (key, comp_dict[key])

# Function for sorting dictionary by keys
def sort_dict_by_keys(comp_dict):
    sorted_dict = OrderedDict(sorted(comp_dict.items(), key=lambda t: t[0]))
    # Return sorted dictionary
    return sorted_dict

# Function to obtain computers formthe JSS
def get_computers(username, password):
    URL = "https://uoe.jamfcloud.com/JSSResource/computergroups/name/Compliance%20-%20Check%20in%20over%20365%20days"
    print "\n"
    print "Obtaining computer information from the JSS for all machines"
    # Open connection to JSS, passing search string, The request will return JSON.
    request = urllib2.Request(URL)
    request.add_header('Accept','application/json')
    request.add_header('Authorization', 'Basic ' + base64.b64encode(username + ':' + password))
    response = urllib2.urlopen(request)
    # Print message to display if info was obtained
    print "Status code from request: %s\n" % response.code
    # Store the response from the JSS
    response_json = json.loads(response.read())
    # The following code can be used to display all details from the response. For the moment we are only interested in name and serial.
    #print json.dumps(response_json,sort_keys=True, indent=4)
    # Declare empty dictionary to store results'
    comp_group = {}
    # For each computer record returned, get the computer name and the serial number
    for computer in response_json['computer_group']['computers']:
        comp_group[(computer.get('name'))]=computer.get('serial_number')
    #Find amount of computers
    amount = len(comp_group.keys())
    # Return amount of computers and the full list
    return comp_group, amount

# ----------------------------------
# Begin main program

# Clear the screen
subprocess.call('clear')

# Get JSS username
username = raw_input ('Enter JSS username: ')
# Get JSS password
password = getpass.getpass(prompt='Enter your JSS password: ')

comp_dict, total_amount= get_computers(username, password)

sort_dict_by_keys(comp_dict)
display_computers(comp_dict, "Last check-in with JSS over 365 days ago")
print "\nTotal amount not seen in over 365 days : %d\n" % total_amount

