################################
# Complete all-in-1 monitoring #
################################
# Version: 1.5
# Last Modified: Sep 2024
# Author: Nathan B 
# Contributors: CdNode team


#!/bin/bash

# Querying the status of GETH
PROCESS_NAME="geth"
PID=$(pgrep $PROCESS_NAME)

if [ -z "$PID" ]; then

        echo "-----------------------------------------------------------------------------"
        echo
        echo  "Critical: YOUR VITRUVEO VALIDATOR <NODE_NAME> GETH IS NOT RUNNING"
        echo  "Discord User: <@DISCORD_ID>"
        echo
        echo "-----------------------------------------------------------------------------"

 exit 0
fi

# Monitors peer list for a value of  0
output=$(/home/validatoradmin/vitruveo-protocol/build/bin/geth --exec "admin.peers.length" attach http://localhost:8545)
peers=$(echo "$output" | grep -o -E '[0-9]+')

if [ "$peers" -eq 0 ]; then

        echo "-----------------------------------------------------------------------------"
        echo
        echo  "Critical: YOUR VALIDATOR <NODE_NAME> HAS NO PEERS"
        echo  "Discord User: <@DISCORD_ID>"
        echo
        echo "-----------------------------------------------------------------------------"

 exit 0
fi

# Monitoring CPU and Memory for GETH and alerts at 51%+ and/or 81%+
CPU_USAGE=$(ps -p $PID -o %cpu | grep -v CPU | awk '{print $1}')

if (( $(echo "$CPU_USAGE > 51" | bc -l) )); then
  echo "----------------------------------------------------------"
  echo "Warning: CPU usage of $PROCESS_NAME is over 50%!"
  echo "Discord User: <@DISCORD_ID>"
  echo "----------------------------------------------------------"
fi

MEM_USAGE=$(ps -p $PID -o %mem | grep -v MEM | awk '{print $1}')

if (( $(echo "$MEM_USAGE > 51" | bc -l) )); then
  echo "----------------------------------------------------------"
  echo "Warning: Memory usage of $PROCESS_NAME is over 50%!"
  echo "Discord User: <@DISCORD_ID>"
  echo "----------------------------------------------------------"  
fi

CPU_USAGE=$(ps -p $PID -o %cpu | grep -v CPU | awk '{print $1}')

if (( $(echo "$CPU_USAGE > 81" | bc -l) )); then
  echo "----------------------------------------------------------"
  echo "Critical: CPU usage of $PROCESS_NAME is now over 80%!"
  echo "Discord User: <@DISCORD_ID>"
  echo "----------------------------------------------------------"
fi

MEM_USAGE=$(ps -p $PID -o %mem | grep -v MEM | awk '{print $1}')

if (( $(echo "$MEM_USAGE > 81" | bc -l) )); then
  echo "----------------------------------------------------------"
  echo "Critical: Memory usage of $PROCESS_NAME is now over 80%!"
  echo "Discord User: <@DISCORD_ID>"
  echo "----------------------------------------------------------"
fi

# Get the total MB consumed on the Ubuntu Server and report if it drops below 40% and/or 10%
total_memory=$(free -m | awk 'NR==2{print $2}')
used_memory=$(free -m | awk 'NR==2{print $3}')
free_memory_percent=$((100 - $used_memory*100/$total_memory))

if ((free_memory_percent < 40)); then
  echo "----------------------------------------------------------"
  echo "Warning: Free memory on Ubuntu has dropped below 40%."
  echo "Discord User: <@DISCORD_ID>"
  echo "----------------------------------------------------------"
fi

total_memory=$(free -m | awk 'NR==2{print $2}')
used_memory=$(free -m | awk 'NR==2{print $3}')
free_memory_percent=$((100 - $used_memory*100/$total_memory))

if ((free_memory_percent < 10)); then
  echo "----------------------------------------------------------"
  echo "Critical: Free memory on Ubuntu has dropped below 10%."
  echo "Discord User: <@DISCORD_ID>" 
  echo "----------------------------------------------------------"
fi

# Monitor Disk Free Space and report if free space goes below 50% and/or 15%
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
free_space=$((100 - disk_usage))

if ((free_space <= 50)); then
  echo "----------------------------------------------------------"
  echo "Warning: Free disk space is less than or equal to 50%."
  echo "Discord User: <@DISCORD_ID>"
  echo "----------------------------------------------------------"

fi

disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
free_space=$((100 - disk_usage))

if ((free_space <= 15)); then
  echo "-------------------------------------------------------------"
  echo "Critical: Free disk space is now less than or equal to 15%."
  echo "Discord User: <@DISCORD_ID>"
  echo "-------------------------------------------------------------"

fi

# Run vnstat to collect the network MiB traffic for the current day and alert if it exceeds 500MiBs
if ! command -v vnstat &> /dev/null; then
  echo "vnstat could not be found, attempting to install..."
  sudo apt-get install vnstat -y
fi

network_consumption_today=$(vnstat --oneline | awk -F\; '{print $6}')
if [[ $network_consumption_today == *"MiB"* ]]; then
   :
elif [[ $network_consumption_today == *"GiB"* ]]; then

value=$(echo $network_consumption_today | sed 's/ GiB//')
if (( $(echo "$value > 5" | bc -l) )); then
  echo "--------------------------------------------------------------------------------------------------------------------"
  echo "Warning: Network consumption today has exceeded 5 GiB/s ; an average range is between 2GiB/s >> 3 GiB/s per day"
  echo "Discord User: <@DISCORD_ID>"
  echo "--------------------------------------------------------------------------------------------------------------------"

# Check internet connectivity to www.google.com
check_google() {
  if ! curl -s --head --request GET https://www.google.com | grep "HTTP/2 200" > /dev/null; then
    echo "----------------------------------------------------------"
    echo "Critical: Check your Internet Connection"
    echo "Validator cannot connect to google.com"
    echo "Discord User: <@DISCORD_ID>"
    echo "----------------------------------------------------------"
  fi
}

# Check internet connectivity to explorer.vitruveo.xyz
check_vitruveo() {
  if ! curl -s --head --request GET https://explorer.vitruveo.xyz | grep "HTTP/1.1 200 OK" > /dev/null; then
    echo "----------------------------------------------------------"
    echo "Critical: Check your Internet Connection"
    echo "Validator cannot connect to explorer.vitruveo.xyz"
    echo "Discord User: <@DISCORD_ID>"
    echo "----------------------------------------------------------"
  fi
}

check_google
check_vitruveo


fi
fi
