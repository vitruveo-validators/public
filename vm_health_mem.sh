#!/bin/bash

# Configuration
WEBHOOK_URL=""https://discord.com/api/webhooks/1289006957125959761/ZFdoopQ9bdTygyBmITexEMKGsWxaq5NbDGMjKdKwuC6a5w7yG0ZeTLlBdfirAIAp5Ljv
USER_ID=""371127409598005248

# Get memory information
MEM_INFO=$(free -m)
TOTAL_MEM=$(echo "$MEM_INFO" | awk 'NR==2{print $2}')
USED_MEM=$(echo "$MEM_INFO" | awk 'NR==2{print $3}')
REMAINING_MEM=$(echo "$TOTAL_MEM - $USED_MEM" | bc)
PERCENTAGE=$(echo "scale=2; $REMAINING_MEM / $TOTAL_MEM * 100" | bc)

# Convert used memory to GB
USED_MEM_GB=$(echo "scale=2; $USED_MEM / 1024" | bc)

# Check if remaining memory is less than 10%
if (( $(echo "$PERCENTAGE < 99" | bc -l) )); then
    CRITICAL_MESSAGE="<@${USER_ID}>\n\nCritical❗Only ${PERCENTAGE}% memory remaining on your Node.\nUsed: ${USED_MEM_GB}GB\nTotal: $(echo "scale=2; $TOTAL_MEM / 1024" | bc)GB."

    # Send critical alert to Discord
    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${CRITICAL_MESSAGE}\"}" "$WEBHOOK_URL"

# Check if remaining memory is less than 30%
elif (( $(echo "$PERCENTAGE < 30" | bc -l) )); then
    MESSAGE="\nWarning ⚠️ Only ${PERCENTAGE}% memory remaining on your Node.\nUsed: ${USED_MEM_GB}GB\nTotal: $(echo "scale=2; $TOTAL_MEM / 1024" | bc)GB."

    # Send alert to Discord
    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"${MESSAGE}\"}" "$WEBHOOK_URL"
fi