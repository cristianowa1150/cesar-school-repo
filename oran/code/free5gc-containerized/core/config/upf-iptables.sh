#!/bin/bash
#
# Configure iptables and network interfaces in UPF
#

# Get the IP address of the UPF container (eth0)
UPF_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

# Assign the UPF IP to the upfgtp interface (created by gtp5g module)
# This is necessary for GTP-U traffic to work properly
if ip link show upfgtp >/dev/null 2>&1; then
    echo "Configuring upfgtp interface with IP: $UPF_IP"
    ip addr add "$UPF_IP/32" dev upfgtp 2>/dev/null || true
    # Bring the interface up if not already
    ip link set upfgtp up 2>/dev/null || true
else
    echo "Warning: upfgtp interface not found. Make sure gtp5g module is loaded."
fi

# Configure iptables for NAT and forwarding
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -I FORWARD 1 -j ACCEPT

