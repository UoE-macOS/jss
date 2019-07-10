#!/usr/bin/python

# Import resources
import urllib2
import base64
import getpass
import subprocess
from collections import OrderedDict
import json
import sys
import logging
import datetime
import os

# Get current day and time, convert to short version so we can append to log.
current_date = datetime.datetime.now()
current_day = current_date.strftime("%d")
current_month = current_date.strftime("%b")
current_year = current_date.strftime("%y")
# Concatenate strings
current_short_date = current_day + "-" + current_month + "-" + current_year

# Create folder for logs
log_path = "/Library/Logs/JSSRecordsRemoved/"

# Create folder to store logs (just so we have a record of what's been removed.)
if not os.path.exists(log_path):
    try:
        # Create directory
        os.mkdir(log_path)
    except FileExistsError:
        print "Unable to create " + log_path
else:
    print("Directory " , log_path ,  " already exists")

log_file = "/Library/Logs/JSSRecordsRemoved/%s.log" % current_short_date

# Create logger object and set default logging level
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Create console handler and set level to debug
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)

# Create file handler and set level to debug
file_handler = logging.FileHandler(r'/Library/Logs/JSSRecordsRemoved/%s.log' % current_short_date)
file_handler.setLevel(logging.DEBUG)

# Create formatter
formatter = logging.Formatter('[%(asctime)s][%(levelname)s] %(message)s', datefmt='%a, %d-%b-%y %H:%M:%S')

# Set formatters for handlers
console_handler.setFormatter(formatter)
file_handler.setFormatter(formatter)

# Add handlers to logger
logger.addHandler(console_handler)
logger.addHandler(file_handler)

# Function to close and remove logging handlers
def close_logger():
    console_handler.close()
    file_handler.close()
    logger.removeHandler(console_handler)
    logger.removeHandler(file_handler)

# Function for sorting dictionary by keys
def sort_dict_by_keys(temp_comp_dict):
    dict_upper = {k.upper(): v for k, v in temp_comp_dict.iteritems()}
    sorted_dict = OrderedDict(sorted(dict_upper.items(), key=lambda t: t[0]))
    # Return sorted dictionary
    return sorted_dict

# Function to obtain computers from the JSS
def get_computers(username, password):
    URL = "https://uoe.jamfcloud.com/JSSResource/computergroups/name/Compliance%20-%20No%20check-in%20for%20over%20300%20days"
    logger.info("\n")
    logger.info('Obtaining information from JSS smart group "Compliance - No check-in for over 300 days":')
    # Open connection to JSS, passing search string, The request will return JSON.
    request = urllib2.Request(URL)
    request.add_header('Accept','application/json')
    request.add_header('Authorization', 'Basic ' + base64.b64encode(username + ':' + password))
    response = urllib2.urlopen(request)
    # Print message to display if info was obtained
    logger.info("Status code from request: %s\n" % response.code)
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

def remove_computers(username, password, computers):
    for comp in computers:
        logger.info("Removing %s record from the JSS...." % comp)
        URL = "https://uoe.jamfcloud.com/JSSResource/computers/name/%s" % comp
        request = urllib2.Request(URL)
        request.add_header('Accept','application/json')
        request.add_header('Authorization', 'Basic ' + base64.b64encode(username + ':' + password))
        request.get_method = lambda: 'DELETE'
        response = urllib2.urlopen(request)

def DecryptString(inputString, salt, passphrase):
    '''Usage: >>> DecryptString("Encrypted String", "Salt", "Passphrase")'''
    p = subprocess.Popen(['/usr/bin/openssl', 'enc', '-aes256', '-d', '-a', '-A', '-S', salt, '-k', passphrase], stdin = subprocess.PIPE, stdout = subprocess.PIPE)
    return p.communicate(inputString)[0].strip()

# Get encrypted strings
apiuser = str(sys.argv[4])
apipword = str(sys.argv[5])
salt = str(sys.argv[6])
passphrase = str(sys.argv[7])

# De-crypt strings
JSSusername = DecryptString(apiuser ,salt, passphrase)
JSSpword = DecryptString(apipword ,salt, passphrase)

# Get list of machines that have not contacted JSS in over 300 days
comp_dict, total_amount= get_computers(JSSusername, JSSpword)

# Sort the machines by name
sorted_comp = sort_dict_by_keys(comp_dict)

# Print out list of machines
logger.info("Total amount not seen in over 300 days : %d" % total_amount)
logger.info("Complete list of machines not checked in in over 300 days")
logger.info("===========================================================")
logger.info((json.dumps(sorted_comp, indent=35, sort_keys=True)))
logger.info("Preparing to remove JSS Records...")

# Remove the records
remove_computers(JSSusername, JSSpword, sorted_comp)

logger.info("JSS Records removed!")

close_logger()