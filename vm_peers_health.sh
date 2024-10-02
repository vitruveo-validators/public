#!/bin/bash
# Manually update VERSION
# major-release.minor-release
VERSION="1.5"

if [[ "$1" == "--version" || "$1" == "-v" || "$1" == "-version" ]]; then
  echo "Script version: $VERSION"
  exit 0
fi

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1289665505065439303/FdsxMzjKT0aFJmKv0Bz4tTVyfTeoyq-iDDmxTuCqVwgTqhDm_mzA1_UOsAAj_cxuKBeJ"
DISCORD_USER_ID="405216996469243904"

# CPU Health
get_cpu_usage() {
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    printf "%.2f" "$CPU_USAGE"
}

PERCENTAGE_1=$(get_cpu_usage)
sleep 5
PERCENTAGE_2=$(get_cpu_usage)

if (( $(echo "$PERCENTAGE_1 > 80" | bc -l) && $(echo "$PERCENTAGE_2 > 80" | bc -l) )); then
    CRITICAL_MESSAGE="<@${DISCORD_USER_ID}>\n\nCritical❗CPU usage on your Node is above 80%\nCurrent CPU usage: ${PERCENTAGE_1}% (1st check), ${PERCENTAGE_2}% (2nd check)"
    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${CRITICAL_MESSAGE}\"}" "$DISCORD_WEBHOOK_URL"

elif (( $(echo "$PERCENTAGE_1 > 50" | bc -l) && $(echo "$PERCENTAGE_2 > 50" | bc -l) )); then
    MESSAGE="\nWarning⚠️ CPU usage on your Node is above 50%\nCurrent CPU usage: ${PERCENTAGE_1}% (1st check), ${PERCENTAGE_2}% (2nd check)"
    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${MESSAGE}\"}" "$DISCORD_WEBHOOK_URL"
fi

# MEM Health
MEM_INFO=$(free -m)
TOTAL_MEM=$(echo "$MEM_INFO" | awk 'NR==2{print $2}')
USED_MEM=$(echo "$MEM_INFO" | awk 'NR==2{print $3}')
REMAINING_MEM=$(echo "$TOTAL_MEM - $USED_MEM" | bc)
PERCENTAGE=$(echo "scale=2; $REMAINING_MEM / $TOTAL_MEM * 100" | bc)

USED_MEM_GB=$(echo "scale=2; $USED_MEM / 1024" | bc)

if (( $(echo "$PERCENTAGE < 10" | bc -l) )); then
    CRITICAL_MESSAGE="<@${DISCORD_USER_ID}>\n\nCritical❗Only ${PERCENTAGE}% memory remaining on your Node.\nUsed: ${USED_MEM_GB}GB\nTotal: $(echo "scale=2; $TOTAL_MEM / 1024" | bc)GB."

    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${CRITICAL_MESSAGE}\"}" "$DISCORD_WEBHOOK_URL"

elif (( $(echo "$PERCENTAGE < 30" | bc -l) )); then
    MESSAGE="\nWarning ⚠️ Only ${PERCENTAGE}% memory remaining on your Node.\nUsed: ${USED_MEM_GB}GB\nTotal: $(echo "scale=2; $TOTAL_MEM / 1024" | bc)GB."

    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${MESSAGE}\"}" "$DISCORD_WEBHOOK_URL"
fi

# Disk Health
DISK_INFO=$(df -h / | awk 'NR==2 {print $2, $3, $4, $5}')
TOTAL_SIZE=$(echo $DISK_INFO | awk '{print $1}')
USED_SIZE=$(echo $DISK_INFO | awk '{print $2}')
AVAIL_SIZE=$(echo $DISK_INFO | awk '{print $3}')
USAGE_PERCENT=$(echo $DISK_INFO | awk '{print $4}' | sed 's/%//')

send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"$message\"}" $DISCORD_WEBHOOK_URL
}

if [ "$USAGE_PERCENT" -gt 90 ]; then
    send_discord_message "<@$DISCORD_USER_ID> Critical❗Node disk at ${USAGE_PERCENT}% - **Action immediately**❗\nTotal Size:${TOTAL_SIZE}B\nUsed: ${USED_SIZE}\n**Available: ${AVAIL_SIZE}**"

elif [ "$USAGE_PERCENT" -gt 70 ]; then
    send_discord_message "⚠️Warning: Node disk at ${USAGE_PERCENT}%  - Consider freeing up space\nTotal Size: ${TOTAL_SIZE}\nUsed: ${USED_SIZE}\n**Available: ${AVAIL_SIZE}**"
fi


# Network Health
send_alert() {
    local message="$1"
    curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"${message}\"}" "$DISCORD_WEBHOOK_URL"
}

if ! command -v vnstat &> /dev/null; then
    echo "vnstat could not be found, attempting to install..."
    sudo apt-get update && sudo apt-get install vnstat -y
fi

network_consumption_today=$(vnstat --oneline | awk -F\; '{print $6}')

if [[ $network_consumption_today == *"GiB"* ]]; then
    value=$(echo "$network_consumption_today" | sed 's/ GiB//')
    if (( $(echo "$value > 6" | bc -l) )); then
        alert_message="Warning: ⚠️ Your Node so far today has consumed **$network_consumption_today**\nAn average range is between **2 GiB** & **4 GiB** per day."
        send_alert "$alert_message"
fi
fi

# PEER Health
GETH_PATH="$HOME/vitruveo-protocol/build/bin/geth"
RPC_URL="http://localhost:8545"

send_alert() {
    local content="$1"
    curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"${content}\"}" "$DISCORD_WEBHOOK_URL"
}

PEER_COUNT=$($GETH_PATH --exec 'admin.peers.length' attach "$RPC_URL")

if [ $? -ne 0 ]; then
    exit 1
fi

if [ "$PEER_COUNT" -eq 0 ]; then
    send_alert "<@${DISCORD_USER_ID}> ❗ Critical: NO peers connected to your Validator!"
elif [ "$PEER_COUNT" -le 5 ]; then
    send_alert "Warning: ⚠️ Only $PEER_COUNT peers connected to your Validator."
elif [ "$PEER_COUNT" -eq 10 ]; then
    send_alert "Good Peer Count: ✅ Exactly 10 peers connected your Validator."

fi