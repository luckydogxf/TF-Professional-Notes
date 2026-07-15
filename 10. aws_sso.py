# 自动读取~/.aws/config
```
[profile ew1.staging.pay]
sso_start_url = https://d-xxx.awsapps.com/start
sso_region = eu-central-1
sso_account_id = 3260xxx
sso_role_name = AWS-rw-All
region = eu-west-1
output = json
```

来产生SSO session。
```#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from configparser import ConfigParser
from datetime import datetime, timedelta
from pathlib import Path

import boto3
import inquirer
from dateutil.parser import parse
from dateutil.tz import tzlocal
from pytz import UTC

class Colour:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


AWS_CONFIG_PATH     = f'{Path.home()}/.aws/config'
AWS_CREDENTIAL_PATH = f'{Path.home()}/.aws/credentials'
AWS_SSO_CACHE_PATH  = f'{Path.home()}/.aws/sso/cache'
AWS_DEFAULT_REGION  = 'eu-west-1'
AWS_DEFAULT_PROFILE = 'ew1.staging.jpay'


VERBOSE_MODE = True


REPEATED_PROFILES = {
    "ew1.staging.jpay"        : [ 'devstg-jpay', 'ew1.sandbox.jpay', 'devstg.jpay', 'jumiapay-devstg' ],
    "ew1.monitoring.jpay"     : ['mng.jpay', 'jumiapay-mng', "ew1.monitoring.jservices"],
    "ew1.production.jaccount" : ['ew1.dev.jaccount', 'ew1.staging.jpay' ],
    "ew1.production.jpay"     : ['prod.jpay', 'jumiapay-production'],
    "ew1.staging.services"     : ['ew1.dev.jservices', 'ew1.staging.jservices']
}

def main():

    profile_list = get_aws_profiles()

    for profile in profile_list:
        _print_msg('\n####################################################################################\n Getting credentials for profile {}\n####################################################################################'.format(profile))
        profile_opts = read_aws_profile(f'profile {profile}')
        cache_login  = None
        while cache_login is None:
            cache_login  = get_sso_cached_login(profile_opts)
            if cache_login is None:
                aws_cli_login(profile)
        
        update_credentials_file(f'profile {profile}', cache_login)


def aws_cli_login(profile):
    subprocess.run("aws sso login --profile {}".format(profile).split(),
                   stderr=sys.stderr,
                   stdout=sys.stdout,
                   check=True)

def get_aws_profiles():
    config = _read_config(AWS_CONFIG_PATH)

    profiles = []
    for section in config.sections():
        profiles.append(re.sub(r"^profile ", "", str(section)))
    profiles.sort()

    return profiles


def update_credentials_file(profile_name, cache_login):
    profile_opts = read_aws_profile(profile_name)
    credentials  = get_sso_temporary_credentials(profile_name, profile_opts, cache_login)

    update_credentials(profile_name, profile_opts, credentials)


def read_aws_profile(profile_name):
    config = _read_config(AWS_CONFIG_PATH)
    profile_opts = config.items(profile_name)
    profile = dict(profile_opts)
    return profile

def get_sso_cached_login(profile):

    cache = hashlib.sha1(profile["sso_start_url"].encode("utf-8")).hexdigest()
    sso_cache_file = f'{AWS_SSO_CACHE_PATH}/{cache}.json'

    if not Path(sso_cache_file).is_file():
        _print_warn(
            'Current cached SSO login is invalid/missing. Starting Login')
        return None

    else:
        data = _load_json(sso_cache_file)
        now = datetime.now().astimezone(UTC)
        expires_at = parse(data['expiresAt']).astimezone(UTC)

        if data.get('region') != profile['sso_region']:
            _print_warn(
                'SSO authentication region in cache does not match region defined in profile')

        if now > expires_at:
            _print_warn(
                'SSO credentials have expired. Starting Login')
            return None

        if (now + timedelta(minutes=30)) >= expires_at:
            _print_warn('Your current SSO credentials will expire in less than 30 minutes!')

        _print_success(f'Found credentials. Valid until {expires_at.astimezone(tzlocal())}')
        return data



def get_sso_temporary_credentials(profile_name, profile, login):

    client = boto3.client('sso', region_name=profile['sso_region'])
    response = client.get_role_credentials(
        roleName=profile['sso_role_name'],
        accountId=profile['sso_account_id'],
        accessToken=login['accessToken'],
    )

    expires = datetime.fromtimestamp(response['roleCredentials']['expiration'] / 1000.0, UTC)
    _print_success(f'Got session token. Valid until {expires.astimezone(tzlocal())} for {profile_name}')

    return response["roleCredentials"]



def update_credentials(profile_name, profile_opts, credentials):
    profile_name  = profile_name.replace('profile ', '')

    profiles_name = []
    profiles_name.append(profile_name)

    if profile_name in REPEATED_PROFILES.keys():
        profiles_name = profiles_name + REPEATED_PROFILES[profile_name]
    
    _print_msg(f'\nAdding to credential files under [{profiles_name}]')

    region = profile_opts.get("region", AWS_DEFAULT_REGION)
    config = _read_config(AWS_CREDENTIAL_PATH)

    for profile in profiles_name:

        if config.has_section(profile):
            config.remove_section(profile)

        config.add_section(profile)

        if profile in get_aws_profiles():
            profile_opts = read_aws_profile("profile {}".format(profile))
            if profile_opts['region'] != None:
                config.set(profile, "region", profile_opts['region'])
            else:
                config.set(profile, "region", region)
        else:
            config.set(profile, "region", region)
        config.set(profile, "aws_access_key_id", credentials["accessKeyId"])
        config.set(profile, "aws_secret_access_key ", credentials["secretAccessKey"])
        config.set(profile, "aws_session_token", credentials["sessionToken"])

    _write_config(AWS_CREDENTIAL_PATH, config)








#################################################
############   Auxiliary Functions ##############
#################################################

def _read_config(path):
    config = ConfigParser()
    config.read(path)
    return config

def _write_config(path, config):
    with open(path, "w") as destination:
        config.write(destination)

def _load_json(path):
    try:
        with open(path) as context:
            return json.load(context)
    except ValueError:
        pass  # skip invalid json



def _print_colour(colour, message, always=False):
    if always or VERBOSE_MODE:
        if os.environ.get('CLI_NO_COLOR', False):
            print(message)
        else:
            print(''.join([colour, message, Colour.ENDC]))

def _print_error(message):
    _print_colour(Colour.FAIL, message, always=True)
    sys.exit(1)


def _print_warn(message):
    _print_colour(Colour.WARNING, message, always=True)


def _print_msg(message):
    _print_colour(Colour.OKBLUE, message)


def _print_success(message):
    _print_colour(Colour.OKGREEN, message)


#################################################
############         Main          ##############
#################################################


if __name__ == "__main__":
    main()
```
