################################
# Complete all-in-1 monitoring #
################################
# Version: 1.0
# Last Modified: May 2024
# Author: Nathan B 
# Contributors: CdNode Team


#!/bin/bash

# Querying the status of GETH
PROCESS_NAME="geth"
PID=$(pgrep $PROCESS_NAME)

if [ -z "$PID" ]; then

        echo "***************************************************************************"
        echo
        echo  "Critical: YOUR VITRUVEO VALIDATOR 'name' GETH IS NOT RUNNING"
        echo
        echo "***************************************************************************"

 exit 0
fi

# Monitors peer list for a value of  0
output=$(/home/validatoradmin/vitruveo-protocol/build/bin/geth --exec "admin.peers.length" attach http://localhost:8545)
peers=$(echo "$output" | grep -o -E '[0-9]+')

if [ "$peers" -eq 0 ]; then

        echo "*************************************************"
        echo
        echo "Critical: YOUR VALIDATOR 'name' HAS NO PEERS"
        echo
        echo "*************************************************"

 exit 0
fi

# Monitoring CPU and Memory for GETH and alerts at 51%+ and/or 81%+
CPU_USAGE=$(ps -p $PID -o %cpu | grep -v CPU | awk '{print $1}')

if (( $(echo "$CPU_USAGE > 51" | bc -l) )); then
  echo "Warning: CPU usage of $PROCESS_NAME is over 50%!"
fi

MEM_USAGE=$(ps -p $PID -o %mem | grep -v MEM | awk '{print $1}')

if (( $(echo "$MEM_USAGE > 51" | bc -l) )); then
  echo "Warning: Memory usage of $PROCESS_NAME is over 50%!"
fi

CPU_USAGE=$(ps -p $PID -o %cpu | grep -v CPU | awk '{print $1}')

if (( $(echo "$CPU_USAGE > 81" | bc -l) )); then
  echo "Critical: CPU usage of $PROCESS_NAME is now over 80%!"
fi

MEM_USAGE=$(ps -p $PID -o %mem | grep -v MEM | awk '{print $1}')

if (( $(echo "$MEM_USAGE > 81" | bc -l) )); then
  echo "Critical: Memory usage of $PROCESS_NAME is now over 80%!"
fi

# Get the total MB consumed on the Ubuntu Server and report if it drops below 40% and/or 10%
total_memory=$(free -m | awk 'NR==2{print $2}')
used_memory=$(free -m | awk 'NR==2{print $3}')
free_memory_percent=$((100 - $used_memory*100/$total_memory))

if ((free_memory_percent < 40)); then
    echo "Warning: Free memory on Ubuntu has dropped below 40%."
fi

total_memory=$(free -m | awk 'NR==2{print $2}')
used_memory=$(free -m | awk 'NR==2{print $3}')
free_memory_percent=$((100 - $used_memory*100/$total_memory))

if ((free_memory_percent < 10)); then
    echo "Critical: Free memory on Ubuntu has dropped below 10%."
fi

# Monitor Disk Free Space and report if free space goes below 50% and/or 15%
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
free_space=$((100 - disk_usage))

if ((free_space <= 50)); then
    echo "Warning: Free disk space is less than or equal to 50%."

fi

disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
free_space=$((100 - disk_usage))

if ((free_space <= 15)); then
    echo "Critical: Free disk space is now less than or equal to 15%."

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
    echo "Warning: Network consumption today has exceeded 5 GiB/s ; an average range is between 2GiB/s >> 3 GiB/s per day"

fi
fi

