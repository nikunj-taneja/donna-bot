#!/usr/bin/env -S uv run
"""
One-shot script to run the Google OAuth flow and save a token file.
Run locally (needs a browser). The resulting token is then copied to the VPS.

Usage:
    python3 scripts/google_auth.py
"""

import json
import os
import warnings
warnings.filterwarnings("ignore")

from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = [
    # Gmail — read, compose drafts, send
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/gmail.send",
    # Drive — see, edit, create (note: Google has no scope that excludes delete;
    # use drive scope and avoid delete calls at the app level)
    "https://www.googleapis.com/auth/drive",
    # Contacts — read only
    "https://www.googleapis.com/auth/contacts.readonly",
    # Calendar — see, edit, share
    "https://www.googleapis.com/auth/calendar",
]

CLIENT_SECRET = os.path.join(os.path.dirname(__file__), "..", "google_oauth_client_secret.json")
TOKEN_OUT = os.path.join(os.path.dirname(__file__), "..", "google_oauth_token.json")

def main():
    flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET, SCOPES)
    print("\nStarting local auth server on http://localhost:8085 ...")
    print("Open the URL below in your browser — the token will be captured automatically.\n")
    creds = flow.run_local_server(port=8085, open_browser=False)

    token_data = {
        "token": creds.token,
        "refresh_token": creds.refresh_token,
        "token_uri": creds.token_uri,
        "client_id": creds.client_id,
        "client_secret": creds.client_secret,
        "scopes": list(creds.scopes) if creds.scopes else SCOPES,
    }

    with open(TOKEN_OUT, "w") as f:
        json.dump(token_data, f, indent=2)

    print(f"\nToken saved to: {os.path.abspath(TOKEN_OUT)}")
    print("Next: run  scp google_oauth_token.json root@82.29.166.220:/opt/donna/google_oauth_token.json")

if __name__ == "__main__":
    main()
