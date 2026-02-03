#!/usr/bin/env python3

import http.cookiejar
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Configuration
QUAY_HOST = os.getenv("QUAY_HOST")
USERNAME = os.getenv("QUAY_ADMIN_USER", "username")
EMAIL = os.getenv("QUAY_ADMIN_EMAIL", "user@example.com")
ORGANIZATION = os.getenv("QUAY_ORGANIZATION", "ztvp")
PASSWORD = os.getenv("QUAY_ADMIN_PASSWORD")
REPO = os.getenv("QUAY_REPO", "qtodo")
ROBOT_NAME = os.getenv("ROBOT_NAME", "qtodo-robot")
CA_CERT = os.getenv("CA_CERT", "/run/secrets/kubernetes.io/serviceaccount/ca.crt")

if not all([QUAY_HOST, PASSWORD]):
    print("ERROR: Missing QUAY_HOST or QUAY_ADMIN_PASSWORD env vars")
    sys.exit(1)

BASE_URL = f"https://{QUAY_HOST}"


def log(msg):
    """Log a message to the console"""
    print(f"[{time.strftime('%X')}] {msg}", flush=True)


# Setup SSL
ctx = ssl.create_default_context()
if os.path.exists(CA_CERT):
    ctx.load_verify_locations(CA_CERT)
    log(f"Using CA certificate from {CA_CERT}")
    ctx.check_hostname = True
    ctx.verify_mode = ssl.CERT_REQUIRED
else:
    log(f"WARNING: CA certificate file not found at {CA_CERT}")
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

# Setup Cookies (Required for CSRF)
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(
    urllib.request.HTTPSHandler(context=ctx),
    urllib.request.HTTPCookieProcessor(cj),
)


def api_call(url, method="GET", data=None, headers=None):
    """Make an API call to Quay"""
    url = f"{BASE_URL}/api/v1{url}"

    headers = headers or {}
    headers["Content-Type"] = "application/json"
    headers["X-CSRF-Token"] = get_csrf_token()

    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with opener.open(req) as response:
            return response
    except urllib.error.HTTPError as e:
        log(f"Failed to make API call: {e.code} {e.reason}")
        raise e
    return None


def login():
    """Login to prime the session cookies"""
    log(f"Logging in as '{USERNAME}'...")

    url = f"{BASE_URL}/api/v1/signin"

    headers = {
        "Content-Type": "application/json",
        "X-CSRF-Token": get_csrf_token(),
    }

    payload = json.dumps({"username": USERNAME, "password": PASSWORD}).encode("utf-8")

    req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
    try:
        opener.open(req)
        log("Login successful.")
    except Exception as e:
        log(f"Login failed: {e}")
        sys.exit(1)


def wait_for_quay():
    """Loop until Quay health endpoint returns 200"""
    url = f"{BASE_URL}/health/instance"
    while True:
        try:
            log(f"Checking Quay health at {url}...")
            with opener.open(url, timeout=10) as response:
                if response.status == 200:
                    log("Quay is Online.")
                    return
        except Exception as e:
            log(f"Quay unavailable ({e}). Retrying in 5s...")
            time.sleep(5)


def get_csrf_token():
    """Fetch CSRF token and prime the cookie jar"""
    url = f"{BASE_URL}/csrf_token"
    with opener.open(url) as response:
        data = json.loads(response.read().decode())
        token = data.get("csrf_token")
    return token


def create_org():
    """Create organization"""
    try:
        log(f"Creating Organization '{ORGANIZATION}'...")

        url = "/organization/"
        payload = json.dumps(
            {
                "name": ORGANIZATION,
            }
        ).encode("utf-8")

        response = api_call(url, method="POST", data=payload)

        if response.status in [200, 201, 202]:
            log("SUCCESS: Organization created successfully.")
            return True

    except urllib.error.HTTPError as e:
        if e.code == 400:
            log(f"Organization '{ORGANIZATION}' already exists.")
            return True
        log(f"FAILED to create organization: {e.code} {e.reason}")
    except Exception as e:
        log(f"FAILED to create organization: {e}")
    return False


def create_repo():
    """Create repository"""
    try:
        log(f"Creating Repository '{REPO}'...")

        url = f"/repository/{ORGANIZATION}/{REPO}"
        payload = json.dumps(
            {
                "namespace": ORGANIZATION,
                "name": REPO,
                "description": "Created by quay-user-provisioner",
                "visibility": "private",
            }
        ).encode("utf-8")

        response = api_call(url, method="POST", data=payload)

        if response.status in [200, 201, 202]:
            log("SUCCESS: Repository created successfully.")
            return True

    except urllib.error.HTTPError as e:
        if e.code == 400:
            log(f"Repository '{REPO}' already exists.")
            return True
        log(f"FAILED to create repository: {e.code} {e.reason}")
    except Exception as e:
        log(f"FAILED to create repository: {e}")
    return False


def create_robot():
    """Create robot account"""
    try:
        log(f"Creating Robot '{ROBOT_NAME}'...")

        url = f"/organization/{ORGANIZATION}/robots/{ROBOT_NAME}"
        payload = json.dumps(
            {
                "description": "Created by quay-user-provisioner",
            }
        ).encode("utf-8")

        response = api_call(url, method="PUT", data=payload)

        if response.status in [200, 201, 202]:
            log("SUCCESS: Robot created successfully.")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 400:
            log(f"Robot '{ROBOT_NAME}' already exists.")
            return True
        log(f"FAILED to create robot: {e.code} {e.reason}")
    except Exception as e:
        log(f"FAILED to create robot: {e}")
    return False


def create_user():
    """Perform the user creation flow"""
    try:
        log("Attempting to create user...")
        csrf_token = get_csrf_token()

        url = f"{BASE_URL}/api/v1/user/"
        payload = json.dumps(
            {
                "username": USERNAME,
                "email": EMAIL,
                "password": PASSWORD,
                "_csrf_token": csrf_token,
            }
        ).encode("utf-8")

        headers = {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrf_token,
        }

        req = urllib.request.Request(url, data=payload, headers=headers, method="POST")

        with opener.open(req) as response:
            if response.status in [200, 201, 202]:
                log("SUCCESS: User created successfully.")
                return True
    except urllib.error.HTTPError as e:
        if e.code == 400:
            log(f"User '{USERNAME}' already exists. Exiting.")
            return True
        log(f"Failed to create user: {e.code} {e.reason}")
    except Exception as e:
        log(f"Failed to create user: {e}")
    return False


def set_robot_permissions():
    """Grant Robot Write Access to Repo"""
    robot_full_name = f"{ORGANIZATION}+{ROBOT_NAME}"
    log(f"Setting permissions for '{robot_full_name}' on '{ORGANIZATION}/{REPO}'...")

    url = f"/repository/{ORGANIZATION}/{REPO}/permissions/user/{robot_full_name}"
    payload = {"role": "write"}

    try:
        api_call(url, method="PUT", data=payload)
        log("Permissions set to WRITE.")
    except Exception as e:
        log(f"Failed setting permissions: {e}")
    return False


# Main
if __name__ == "__main__":
    log("Starting Quay User Automator")

    wait_for_quay()

    while not create_user():
        log("Retrying user creation in 10s...")
        time.sleep(10)

    login()

    while not create_org():
        log("Retrying organization creation in 10s...")
        time.sleep(10)

    while not create_repo():
        log("Retrying repository creation in 10s...")
        time.sleep(10)

    while not create_robot():
        log("Retrying robot creation in 10s...")
        time.sleep(10)

    while not set_robot_permissions():
        log("Retrying robot permissions setting in 10s...")
        time.sleep(10)

    sys.exit(0)
