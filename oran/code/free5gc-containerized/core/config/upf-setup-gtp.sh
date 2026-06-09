#!/bin/bash
#
# Configure the upfgtp interface with IPv4 address
# This script should be executed after the UPF has started and created the upfgtp interface
#

# Wait for upfgtp interface to be created (max 30 seconds)
MAX_WAIT=30
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if ip link show upfgtp >/dev/null 2>&1; then
        break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if ! ip link show upfgtp >/dev/null 2>&1; then
    echo "Error: upfgtp interface not found after ${MAX_WAIT}s"
    exit 1
fi

# Get the IP address of the UPF container (eth0)
UPF_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

if [ -z "$UPF_IP" ]; then
    echo "Error: Could not determine UPF IP address"
    exit 1
fi

# Check if IP is already assigned
if ip addr show upfgtp | grep -q "inet $UPF_IP"; then
    echo "upfgtp interface already has IP: $UPF_IP"
    exit 0
fi

# Assign the UPF IP to the upfgtp interface
echo "Configuring upfgtp interface with IP: $UPF_IP"
ip addr add "$UPF_IP/32" dev upfgtp 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Successfully assigned IP $UPF_IP to upfgtp interface"
    # Bring the interface up if not already
    ip link set upfgtp up 2>/dev/null || true
else
    echo "Warning: Failed to assign IP to upfgtp interface (may already be assigned)"
fi

