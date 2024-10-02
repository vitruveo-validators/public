#!/bin/bash
#Manually update VERSION
#major-release.minor-release
VERSION="1.5"

if [[ "$1" == "--version" || "$1" == "-v" || "$1" == "-version" ]]; then
  echo "Script version: $VERSION"
  exit 0
fi

GETH_PATH="$HOME/vitruveo-protocol/build/bin/geth"
RPC_URL="http://localhost:8545"
DISCORD_WEBHOOK_URL=""

send_alert() {
    local content="$1"
    curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"${content}\"}" "$DISCORD_WEBHOOK_URL"
}

PEER_COUNT=$($GETH_PATH --exec 'admin.peers.length' attach "$RPC_URL")

if [ $? -ne 0 ]; then
    exit 1
fi

if [ "$PEER_COUNT" -le 5 ]; then
    message="Current peer count is **$PEER_COUNT** and that's 🪫"
elif [ "$PEER_COUNT" -ge 6 ] && [ "$PEER_COUNT" -le 9 ]; then
    message="Current peer count is **$PEER_COUNT** and that's 🆗"
else
    message="Current peer count is **$PEER_COUNT** and that's ✅"
fi

send_alert "$message"