#!/bin/bash

### Define current Gateway, DNS, and Domain ###
current_gateway=$(ip route show | grep default | awk '{print $3}')
current_dns=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\n' ',' | sed 's/,$/\n/')
current_domain=$(hostname -d)
current_nic=$(ip -o -f inet route show | awk '$1=="default" {print $5}')
deleted_nic="" # initialize for adding NIC as a member of new bridge

### Gather desired IP ###
echo "Enter your desired IP address and CIDR notation (e.g., 192.168.0.1/24):"
read bridge_cidr

### Gather desired gateway ###
echo "Enter your desired Gateway IP address (or press Enter to use current gateway ($current_gateway)):"
read bridge_gateway

### Gather desired DNS ###
echo "Enter your desired DNS Server IP address (or press Enter to use current DNS ($current_dns)):"
read bridge_dns

### Gather desired domain ###
echo "Enter your desired Domain Name (or press Enter to use the current domain name ($current_domain)):"
read bridge_domain

### Gather desired NIC ###
echo "Enter the network interface to remove and add to the bridge interface (or press Enter to use the current domain name ($current_nic)):"
read bridge_nic

### Install cockpit, enable, and open firewall for port 9090 (cockpit) ###
dnf -y install cockpit cockpit-machines cockpit-composer
systemctl enable --now cockpit
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload

### Install pre-req binaries & enable libvirt ###
dnf -y install qemu-kvm libvirt virt-install virt-viewer
systemctl enable --now libvirtd
systemctl enable --now osbuild-composer.socket

### add bridge [br0] ###
nmcli connection add type bridge autoconnect yes con-name br0 ifname br0
echo "Created bridge br0"

### set IP address for [br0] ###
nmcli connection modify br0 ipv4.addresses $bridge_cidr ipv4.method manual
echo "Set IPv4 address to $bridge_cidr"

### set Gateway for [br0] ###
if [ -n "$bridge_gateway" ]; then
    nmcli connection modify br0 ipv4.gateway $bridge_gateway
    echo "Set $bridge_gateway as gateway"
else
    nmcli connection modify br0 ipv4.gateway $current_gateway
    echo "Set $current_gateway as gateway"
fi

### set DNS for [br0] ###
if [ -n "$bridge_dns" ]; then
    nmcli connection modify br0 ipv4.dns $bridge_dns
    echo "Set $bridge_dns as DNS"
else
    nmcli connection modify br0 ipv4.dns $current_dns
    echo "Set $current_dns as DNS"
fi

### set DNS search base for [br0] ###
if [ -n "$bridge_domain" ]; then
    nmcli connection modify br0 ipv4.dns-search $bridge_domain
    echo "Set $bridge_domain as ipv4.dns-search"
else
    nmcli connection modify br0 ipv4.dns-search $current_domain
    echo "Set $current_domain as ipv4.dns-search"
fi

### remove the current interface ###
if [ -n "$bridge_nic" ]; then
    #nmcli connection del $bridge_nic
    deleted_nic=$bridge_nic
    echo "Removed $deleted_nic"
else
    #nmcli connection del $current_nic
    deleted_nic=$current_nic
    echo "Removed $deleted_nic"
fi

### add the removed interface again as a member of [br0] ###
#nmcli connection add type bridge-slave autoconnect yes con-name $deleted_nic ifname $deleted_nic master br0
echo "Added $deleted_nic to bridge br0"

### disable ipv6
nmcli connection modify br0 ipv6.method disabled

### reboot ###
read -p "You need to reboot. Reboot now? (y/n): " answer
if [ "$answer" == "yes" or "$answer" == "y" ]; then
    reboot
fi