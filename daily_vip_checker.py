#!/usr/bin/env python3

import subprocess
import requests
import pandas as pd
from datetime import datetime, timedelta
import argparse
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging
from tqdm import tqdm
import sys
import pkg_resources
import json
import random  # Import the random module for choosing a congratulatory phrase

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Discord configuration
DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1259928007586349127/apGEaWwtMhztHFvrIGaY75WT2nsuevR5J5ltnWoMZiB7o5aQi8WjUmrS0wKfF0mTCtyA"
DISCORD_USER_ID = "296922649345523723"
# Define a list of congratulatory phrases
CONGRATULATORY_PHRASES = [
    "Well done! 🎉",
    "Amazing job! 👏",
    "Fantastic achievement! 🚀",
    "Congrats on the great performance! 🌟",
    "Way to go! 👍",
    "Excellent work! 🏆",
    "Kudos to you! 🎊",
    "You’re on fire! 🔥",
    "Bravo on the achievement! 🎖️",
    "Keep up the great work! 🎈",
]

# Function to check and install required packages
def check_and_install_packages():
    required_packages = [
        'requests',
        'pandas',
        'tqdm'
    ]
    
    installed_packages = {pkg.key for pkg in pkg_resources.working_set}
    missing_packages = [pkg for pkg in required_packages if pkg not in installed_packages]
    
    if missing_packages:
        logging.info(f"Missing packages: {', '.join(missing_packages)}")
        logging.info("Installing missing packages...")
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install'] + missing_packages)
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to install packages: {e}")
            sys.exit(1)
    else:
        logging.info("All required packages are already installed.")

# Check and install required Python packages
check_and_install_packages()

# Function to execute a command and return the output
def execute_command(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        result.check_returncode()  # Raise an exception if the command failed
        return result.stdout.strip()  # Remove any surrounding whitespace or new lines
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed with error: {e.stderr}")
        raise

# Function to fetch mined blocks data with retries and exponential backoff
def fetch_mined_blocks(address, api_url_template, retries=3, timeout=10):
    api_url = api_url_template.format(address=address)
    for attempt in range(retries):
        try:
            response = requests.get(api_url, timeout=timeout)
            response.raise_for_status()  # Check for HTTP errors
            return response.json().get('result', [])
        except requests.RequestException as e:
            logging.error(f"Attempt {attempt + 1} for {address} failed: {e}")
            if attempt < retries - 1:
                logging.info(f"Retrying... ({attempt + 1}/{retries})")
                time.sleep(2 ** attempt)  # Exponential backoff
            else:
                logging.error(f"Failed to fetch data for {address} after {retries} attempts.")
                return []
    return []

# Function to process blocks data
def process_blocks_data(mined_blocks_list, start_date, end_date):
    df = pd.DataFrame(mined_blocks_list)
    if 'timeStamp' in df.columns:
        df.rename(columns={'timeStamp': 'timestamp'}, inplace=True)
        df['timestamp'] = pd.to_datetime(df['timestamp'], utc=True)  # Ensure timestamp is in UTC
        
        # Convert start_date and end_date to timezone-aware
        start_date = pd.to_datetime(start_date, utc=True)
        end_date = pd.to_datetime(end_date, utc=True)
        
        # Filter the data for the specified date range
        mask = (df['timestamp'] >= start_date) & (df['timestamp'] <= end_date)
        filtered_data = df[mask]
        
        # Count the number of blocks validated by the node wallet in the given date range
        num_validated_blocks = filtered_data.shape[0]
        return num_validated_blocks
    else:
        return 0

# Function to send a notification to Discord
def send_notification(message):
    tagged_message = f"<@{DISCORD_USER_ID}> {message}"
    json_payload = json.dumps({"content": tagged_message})
    response = requests.post(DISCORD_WEBHOOK_URL, data=json_payload, headers={"Content-Type": "application/json"})
    if response.status_code == 204:
        logging.info("Notification sent to Discord successfully.")
    else:
        logging.error(f"Failed to send notification to Discord: {response.status_code} {response.text}")

# Main function to execute the script
def main():
    # Define the API URL template for fetching mined blocks data
    api_url_template = "https://explorer.vitruveo.xyz/api?module=account&action=getminedblocks&address={address}"
    
    # Commands to get the main account wallet and list node wallets
    geth_command_signers = './vitruveo-protocol/build/bin/geth --exec "var signers = clique.getSigners(); for (var i = 0; i < signers.length; i++) { console.log((i + 1) + \'. \' + signers[i]); }" attach http://localhost:8545'
    geth_command_account = './vitruveo-protocol/build/bin/geth --exec "eth.accounts[0]" attach http://localhost:8545'

    # Define command-line arguments
    parser = argparse.ArgumentParser(description='Fetch and count Ethereum node wallet block validation data.')
    args = parser.parse_args()
    
    # Constants
    SECONDS_PER_BLOCK = 5.5
    SECONDS_PER_DAY = 24 * 60 * 60
    AVERAGE_DAYS_PER_MONTH = 30.44

    # Calculate total blocks per day and per month
    total_blocks_day = SECONDS_PER_DAY // SECONDS_PER_BLOCK  # 17,280
    total_blocks_month = int(total_blocks_day * AVERAGE_DAYS_PER_MONTH)  # 526,387

    # Get the main account wallet address
    try:
        main_wallet_address = execute_command(geth_command_account)
        main_wallet_address = main_wallet_address.strip('"')  # Remove any surrounding quotation marks
        logging.info(f"Main wallet address: {main_wallet_address}")
    except RuntimeError as e:
        logging.error(f"Error fetching main wallet address: {e}")
        sys.exit(1)

    # Get the list of wallet addresses
    try:
        wallet_list_output = execute_command(geth_command_signers)
    except RuntimeError as e:
        logging.error(f"Error fetching wallet list: {e}")
        sys.exit(1)
    
    # Extract wallet addresses from the output
    node_wallet_addresses = []
    for line in wallet_list_output.strip().split('\n'):
        if '. ' in line:
            # Extract wallet address after '. '
            address = line.split('. ')[1].strip()
            node_wallet_addresses.append(address)

    # Check if the main wallet address is among the node wallets
    if main_wallet_address not in node_wallet_addresses:
        logging.error("Main wallet address not found in node signers.")
        sys.exit(1)

    # Number of nodes
    num_nodes = len(node_wallet_addresses)
    logging.info(f"Number of nodes: {num_nodes}")

    # Create a ThreadPoolExecutor for concurrent API requests with progress bar
    with ThreadPoolExecutor(max_workers=2) as executor:
        # Only submit a future for the main wallet address
        future_to_address = {executor.submit(fetch_mined_blocks, main_wallet_address, api_url_template): main_wallet_address}
        for future in tqdm(as_completed(future_to_address), total=len(future_to_address), desc="Fetching mined blocks"):
            address = future_to_address[future]
            try:
                mined_blocks_data = future.result()

                # Get today's date and the first day of the current month
                today = datetime.now()
                first_of_month = today.replace(day=1)

                # Check blocks validated in the last 24 hours
                last_24_hours = today - timedelta(days=1)
                num_validated_blocks_24h = process_blocks_data(mined_blocks_data, last_24_hours, today)
                
                # Divide the total number of blocks by the number of nodes
                average_blocks_24h_per_node = total_blocks_day / num_nodes
                percentage_24h = (num_validated_blocks_24h / average_blocks_24h_per_node) * 100

                # Check blocks validated this month
                num_validated_blocks_month = process_blocks_data(mined_blocks_data, first_of_month, today)
                
                # Divide the total number of blocks by the number of nodes
                average_blocks_month_per_node = total_blocks_month / num_nodes
                percentage_month = (num_validated_blocks_month / average_blocks_month_per_node) * 100

                # Print the results
                print(f"{address}:")
                print(f"  Last 24 hours: {num_validated_blocks_24h} blocks ({percentage_24h:.2f}%)")
                print(f"  This month: {num_validated_blocks_month} blocks ({percentage_month:.2f}%)")

                # Log the results
                logging.info(f"{address}: Last 24 hours: {num_validated_blocks_24h} blocks ({percentage_24h:.2f}%)")
                logging.info(f"{address}: This month: {num_validated_blocks_month} blocks ({percentage_month:.2f}%)")

                # Send a Discord alert if the 24-hour block percentage hits 98% or more
                if percentage_24h >= 98:
                    content = (
                        f"**Alert!** 🚨\n\n"
                        f"The wallet **{main_wallet_address}** has achieved **{percentage_24h:.2f}%** of the total blocks in the last 24 hours.\n\n"
                        f"Keep monitoring the performance of the node to ensure it remains effective.\n\n"
                        f"---\n"
                        f"{random.choice(CONGRATULATORY_PHRASES)}"
                    )
                    send_notification(content)  # Fixed function call

            except Exception as e:
                logging.error(f"Error processing data for {address}: {e}")

if __name__ == "__main__":
    main()
