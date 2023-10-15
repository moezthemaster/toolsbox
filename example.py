import configparser
import argparse
import requests
import sys
import json
import logging
from helpers import push_data

logging.basicConfig(format='%(asctime)s - %(message)s', level=logging.INFO)


parser = argparse.ArgumentParser("Run of push pajee configuration on target host")
parser.add_argument('-a', '--action', action='store', choices=['push', 'apply'], required=True)
parser.add_argument('-e', '--environment', action='store', required=True)
parser.add_argument('-c', '--configuration', action='store', choices=['wildfly', 'jboss', 'java'], required=True)
parser.add_argument('-p', '--path', action='store')
args = parser.parse_args()

config = configparser.ConfigParser()
config.read('config.cfg')

environment = args.environment
if not environment in config.sections():
    print(f"Error: {args.environment} does not exist in cfg file.")
    sys.exit(1)

#print(config.sections())
# Output: ['Section 1', 'Section 2']
#print(config['DEV1']['hostname'])
# Output: 'value1'
#print(config['INT1']['hostname'])
# Output: 'value3'
#hostname = config[environment]['hostname']
#print(hostname)

pajee_configuration = args.configuration
if not args.path:
    logging.info('Loading pajee configuration from remote file')
    base_file_url = config[environment]['base_file_url']
    pajee_conf_file = f"{pajee_configuration}.yaml"
    conf_url = f"{base_file_url}/{pajee_conf_file}"
    try:
        r = requests.get(conf_url)
        if r.status_code == 404:
            logging.error(f"error: file {pajee_conf_file} does not exist on repo")
            sys.exit(1)
        pajee_conf = r.text
    except Exception:
        raise
else:
    logging.info('Loading pajee configuration from local file')
    pajee_conf_file = f"{args.path}"
    try:
        with open(pajee_conf_file) as f:
            pajee_conf = f.read()
    except FileNotFoundError:
        logging.error(f"File {pajee_conf_file} not found.")
        sys.exit(1)
logging.info('pajee configuration successfully loaded')

push_data = json.loads(push_data)
data_push_key = f"{pajee_configuration}_conf"
push_data['extra_vars'][data_push_key] = pajee_conf
logging.info(f"data: {push_data}")
logging.info(f"Processing {args.action}ing pajee configuration")
