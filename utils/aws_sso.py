#!/usr/init/env python3

import hashlib
import json
import os
import re
import subprocess
import sys
from configparser import ConfigParser
from datetime import datetime, timedelta, timezone
from pathlib import Path

import boto3
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
AWS_DEFAULT_REGION  = 'cn-northwest-1'

VERBOSE_MODE = True

def main():
    profile_list = get_aws_profiles()

    for profile in profile_list:
        _print_msg(f'\n####################################################################################\n Getting credentials for profile {profile}\n####################################################################################')
        profile_opts = read_aws_profile(f'profile {profile}')
        
        # Resolve sso_session inheritance so sso_start_url and sso_region are available
        config = _read_config(AWS_CONFIG_PATH)
        if 'sso_session' in profile_opts:
            session_section = f'sso-session {profile_opts["sso_session"]}'
            if config.has_section(session_section):
                for key, val in config.items(session_section):
                    if key not in profile_opts:
                        profile_opts[key] = val

        cache_login  = None
        while cache_login is None:
            cache_login  = get_sso_cached_login(profile_opts)
            if cache_login is None:
                aws_cli_login(profile)
        
        update_credentials_file(f'profile {profile}', profile_opts, cache_login)

def aws_cli_login(profile):
    subprocess.run(["aws", "sso", "login", "--profile", profile, "--use-device-code"],
                   stderr=sys.stderr,
                   stdout=sys.stdout,
                   check=True)

def get_aws_profiles():
    config = _read_config(AWS_CONFIG_PATH)
    profiles = []
    for section in config.sections():
        if section.startswith("profile "):
            profiles.append(re.sub(r"^profile ", "", str(section)))
    profiles.sort()
    return profiles

def update_credentials_file(profile_name, profile_opts, cache_login):
    credentials  = get_sso_temporary_credentials(profile_name, profile_opts, cache_login)
    update_credentials(profile_name, profile_opts, credentials)

def read_aws_profile(profile_name):
    config = _read_config(AWS_CONFIG_PATH)
    if config.has_section(profile_name):
        return dict(config.items(profile_name))
    return {}

def get_sso_cached_login(profile):
    if "sso_start_url" not in profile:
        _print_warn('Profile missing sso_start_url. Skipping cache check.')
        return None

    cache = hashlib.sha1(profile["sso_start_url"].encode("utf-8")).hexdigest()
    sso_cache_file = f'{AWS_SSO_CACHE_PATH}/{cache}.json'

    if not Path(sso_cache_file).is_file():
        _print_warn('Current cached SSO login is invalid/missing. Starting Login')
        return None

    else:
        data = _load_json(sso_cache_file)
        if not data or 'expiresAt' not in data:
            return None

        now = datetime.now().astimezone(UTC)
        expires_at = parse(data['expiresAt']).astimezone(UTC)

        if now > expires_at:
            _print_warn('SSO credentials have expired. Starting Login')
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

    expires = datetime.fromtimestamp(response['roleCredentials']['expiration'] / 1000.0, tz=timezone.utc).astimezone(UTC)
    _print_success(f'Got session token. Valid until {expires.astimezone(tzlocal())} for {profile_name}')

    return response["roleCredentials"]

def update_credentials(profile_name, profile_opts, credentials):
    profile_clean_name = profile_name.replace('profile ', '')
    _print_msg(f'\nAdding to credential files under [{profile_clean_name}]')

    region = profile_opts.get("region", AWS_DEFAULT_REGION)
    config = _read_config(AWS_CREDENTIAL_PATH)

    if config.has_section(profile_clean_name):
        config.remove_section(profile_clean_name)

    config.add_section(profile_clean_name)
    config.set(profile_clean_name, "region", region)
    config.set(profile_clean_name, "aws_access_key_id", credentials["accessKeyId"])
    config.set(profile_clean_name, "aws_secret_access_key", credentials["secretAccessKey"])
    config.set(profile_clean_name, "aws_session_token", credentials["sessionToken"])

    _write_config(AWS_CREDENTIAL_PATH, config)

def _read_config(path):
    config = ConfigParser()
    if Path(path).is_file():
        config.read(path)
    return config

def _write_config(path, config):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as destination:
        config.write(destination)

def _load_json(path):
    try:
        with open(path) as context:
            return json.load(context)
    except (ValueError, json.JSONDecodeError):
        return None

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

if __name__ == "__main__":
    main()
