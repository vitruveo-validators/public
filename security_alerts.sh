#!/bin/bash
#Manually update VERSION
#major-release.minor-release
VERSION="1.10"

if [[ "$1" == "--version" || "$1" == "-v" || "$1" == "-version" ]]; then
  echo "Script version: $VERSION"
  exit 0
fi

# Auth File (make a temp copy)
sudo [ -f /tmp/auth.log ] && sudo rm -rf /tmp/auth.log
sudo bash -c 'cp /var/log/auth.log /tmp/auth.log && awk -v date="$(date -d "24 hours ago" +%Y-%m-%dT%H:%M:%S)" '\''$1 "T" $2 >= date'\'' /var/log/auth.log > /va>sudo chmod 777 /tmp/auth.log
LOG_FILE="/tmp/auth.log"

# Discord
WEBHOOK_URL="https://discord.com/api/webhooks/1288723187370299432/qJr-1daVUwm47Av2VNc25yAt3BE_okenv1ej8qqKRAxOMNFtzJxkE-NSC1874V8lxILu"
USER_ID="405216996469243904"

# Search for invalid user attempts in the log file
INVALID_USER=$(grep "Invalid user" "$LOG_FILE" | sed 's/; TTY.*//')

# Check if there are any invalid user attempts
if [ ! -z "$INVALID_USER" ]; then
    # Send the incorrect password attempts to Discord with a mention
    curl -s -X POST -d "content=<@$USER_ID>🕵️ **Invalid User attempts**\`\`\`${INVALID_USER}\`\`\`" "${WEBHOOK_URL}"
fi

# Search for "Failed password" in the log file and exclude lines containing "COMMAND"
FAILED_PASSWORD=$(grep "Failed password" "$LOG_FILE" | grep -v "COMMAND")

# Check if there are any failed passwords
if [ ! -z "$FAILED_PASSWORD" ]; then
    # Send the failed logins to Discord with a mention
    curl -s -X POST -d "content=<@$USER_ID>🕵️ **Failed Password Attempt**\`\`\`${FAILED_PASSWORD}\`\`\`" "${WEBHOOK_URL}"
# Delete temp copy of auth log and restart rsyslog
sudo rm -rf /tmp/auth.log

fi