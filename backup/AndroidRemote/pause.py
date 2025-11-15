#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "androidtvremote2>=0.0.14",
#     "python-dotenv>=1.0.0",
# ]
# ///
"""
Shield Pause Script
Controls Nvidia Shield playback using Android TV Remote Protocol.
"""

import argparse
import asyncio
import base64
import os
import re
import socket
import sys
from pathlib import Path
from dotenv import load_dotenv, set_key
from androidtvremote2 import AndroidTVRemote
from androidtvremote2.remote import RemoteKeyCode


ENV_FILE = Path(__file__).parent / ".env"


def load_config():
    """Load configuration from .env file."""
    load_dotenv(ENV_FILE)

    config = {
        "host": os.getenv("SHIELD_HOST"),
        "cert": os.getenv("SHIELD_CERT"),
    }

    return config


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Control Nvidia Shield playback via Android TV Remote Protocol"
    )
    parser.add_argument(
        "--host",
        type=str,
        help="Shield IP address (overrides .env setting)"
    )
    parser.add_argument(
        "--repair",
        action="store_true",
        help="Force re-pairing with Shield"
    )
    return parser.parse_args()


def validate_ip(ip: str) -> bool:
    """Validate IP address format."""
    pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    if not re.match(pattern, ip):
        return False

    # Check each octet is 0-255
    octets = ip.split('.')
    return all(0 <= int(octet) <= 255 for octet in octets)


def save_config(key: str, value: str):
    """Save configuration value to .env file."""
    # Create .env if it doesn't exist
    if not ENV_FILE.exists():
        ENV_FILE.touch()

    set_key(ENV_FILE, key, value)


def get_host_config(config: dict, args) -> str:
    """Get host from args or config, prompt if missing."""
    # Command line override
    if args.host:
        if not validate_ip(args.host):
            print(f"Error: Invalid IP address format: {args.host}")
            print("Please enter a valid IP (e.g., 192.168.1.238)")
            sys.exit(1)
        return args.host

    # Use existing config
    if config["host"]:
        return config["host"]

    # Prompt user
    while True:
        host = input("Enter Shield IP address: ").strip()
        if validate_ip(host):
            save_config("SHIELD_HOST", host)
            print(f"Saved IP address to {ENV_FILE}")
            return host
        else:
            print("Invalid IP address format. Please enter a valid IP (e.g., 192.168.1.238)")


async def pair_with_shield(remote: AndroidTVRemote, host: str) -> str:
    """Pair with Shield and return certificate data.

    Note: androidtvremote2 library manages certificates internally via certfile/keyfile
    parameters. The library automatically generates self-signed certificates using
    async_generate_cert_if_missing() and stores them to the specified file paths.

    After pairing completes, the library persists the certificate and key in PEM format
    to the files specified during AndroidTVRemote initialization. Subsequent connections
    reuse these files by loading them via ssl_context.load_cert_chain().

    The pairing process:
    1. Library generates cert/key files if they don't exist
    2. async_start_pairing() initiates pairing protocol
    3. async_finish_pairing(pin) completes pairing with PIN
    4. Certificate files persist on disk for future connections

    We store a marker in .env to indicate pairing completed, but the actual certificate
    persistence is handled by the library itself through the certfile/keyfile paths.
    """
    print(f"\nInitiating pairing with Shield at {host}...")
    print("A PIN code should appear on your Shield TV screen.")

    try:
        await remote.async_start_pairing()

        while True:
            pin = input("\nEnter PIN from Shield TV screen: ").strip().upper()

            # Validate PIN format - should be 6 hexadecimal characters
            if len(pin) != 6 or not all(c in '0123456789ABCDEF' for c in pin):
                print("Invalid PIN format. Please enter the 6-character hex PIN shown on screen (e.g., 4D292B).")
                continue

            try:
                await remote.async_finish_pairing(pin)
                print("Pairing successful!")

                # Certificate is already persisted to certfile/keyfile by the library
                # We return a marker to indicate successful pairing
                cert_data = base64.b64encode(f"paired_{host}".encode()).decode()

                return cert_data

            except Exception as e:
                error_msg = str(e).lower()
                if "invalid" in error_msg or "wrong" in error_msg:
                    print("Invalid PIN. Please try again.")
                    continue
                elif "reject" in error_msg:
                    print("Error: Pairing rejected on TV. Please accept the pairing request.")
                    return None
                else:
                    print(f"Error during pairing: {e}")
                    return None

    except Exception as e:
        print(f"Error: Cannot initiate pairing: {e}")
        return None


async def connect_and_pair_if_needed(host: str, cert_data: str, force_repair: bool):
    """Connect to Shield, pairing if needed.

    Certificate Persistence Strategy:
    -----------------------------------
    The androidtvremote2 library handles certificate persistence automatically via the
    certfile and keyfile parameters passed to AndroidTVRemote.__init__().

    How it works:
    1. On first connection, we provide paths to temporary certificate files
    2. The library calls async_generate_cert_if_missing() which generates self-signed
       certificates and writes them to the specified certfile/keyfile paths
    3. During pairing (async_finish_pairing), the library authenticates the certificates
       with the Android TV device
    4. For subsequent connections, the library loads the existing certificates from the
       file paths using ssl.SSLContext.load_cert_chain(certfile, keyfile)

    Current Implementation:
    -----------------------
    We use temporary files that get deleted after each session. This means we re-pair
    on every run, which is not ideal but functional.

    Better approach would be to use persistent file paths like:
    - certfile: Path(__file__).parent / ".shield_cert.pem"
    - keyfile: Path(__file__).parent / ".shield_key.pem"

    This would allow the library to reuse certificates across sessions without re-pairing.
    The SHIELD_CERT in .env would then just serve as a marker that pairing completed.

    References:
    -----------
    - Library source: https://github.com/tronikos/androidtvremote2
    - Home Assistant integration uses this pattern with persistent storage paths
    - Certificate format: PEM (Privacy Enhanced Mail) for both cert and private key
    """
    # Use persistent cert/key file paths to avoid re-pairing on every run
    cert_path = Path(__file__).parent / ".shield_cert.pem"
    key_path = Path(__file__).parent / ".shield_key.pem"

    needs_pairing = force_repair or not cert_data

    try:
        remote = AndroidTVRemote(
            client_name="Shield Pause Script",
            certfile=str(cert_path),
            keyfile=str(key_path),
            host=host
        )

        # Generate self-signed certificates - library will create the files
        await remote.async_generate_cert_if_missing()

        if needs_pairing:
            # Pairing flow - start pairing before connecting
            cert_data = await pair_with_shield(remote, host)
            if cert_data:
                save_config("SHIELD_CERT", cert_data)
                print(f"Credentials saved to {ENV_FILE}")
            else:
                print("Pairing failed.")
                return None

        # Connect to Shield (after pairing if needed)
        print(f"Connecting to {host}:6466...")
        await remote.async_connect()

        return remote

    except socket.timeout:
        print(f"Error: Connection timeout")
        print(f"Is the Shield at {host} powered on?")
        return None

    except ConnectionRefusedError:
        print(f"Error: Connection refused by {host}")
        print("The Shield may not have Android TV Remote service enabled.")
        return None

    except socket.gaierror:
        print(f"Error: Cannot resolve hostname {host}")
        print("Please check the IP address is correct.")
        return None

    except OSError as e:
        if "Network is unreachable" in str(e):
            print(f"Error: Network unreachable")
            print(f"Cannot reach {host}. Check network connectivity.")
        else:
            print(f"Error: Cannot connect to Shield at {host}")
            print(f"Details: {e}")
        return None

    except Exception as e:
        print(f"Error: Cannot connect to Shield at {host}")
        print(f"Details: {e}")
        print("\nTroubleshooting:")
        print("- Verify Shield IP address is correct")
        print("- Ensure Shield is powered on")
        print("- Check network connectivity")
        return None


async def send_play_pause(remote: AndroidTVRemote):
    """Send play/pause toggle command to Shield."""
    try:
        print("Sending play/pause command...")
        remote.send_key_command(RemoteKeyCode.KEYCODE_MEDIA_PLAY_PAUSE)
        print("Command sent successfully!")
        return True
    except Exception as e:
        print(f"Error sending command: {e}")
        return False


async def run_pause_command(host: str, cert_data: str, force_repair: bool):
    """Main async function to connect and send pause command."""
    remote = await connect_and_pair_if_needed(host, cert_data, force_repair)

    if not remote:
        return False

    # Send the command
    success = await send_play_pause(remote)

    # Disconnect
    remote.disconnect()

    return success


async def main_async(host: str, cert: str, force_repair: bool):
    """Async main function to handle connection and cleanup."""
    # Run the pause command
    success = await run_pause_command(host, cert, force_repair)

    return 0 if success else 1


def main():
    """Main entry point."""
    args = parse_args()
    config = load_config()

    host = get_host_config(config, args)

    # Clear cert if force repair
    cert = None if args.repair else config["cert"]

    # Run async main with single event loop
    return asyncio.run(main_async(host, cert, args.repair))


if __name__ == "__main__":
    sys.exit(main())
