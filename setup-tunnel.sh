#!/bin/bash

# LORNA TUNELL v2 Supreme Edition
# Author: You
# Description: Full-tunnel NAT IPv6+GRE secure tunneling system
# Supports Hetzner, Ocean, etc. with fail-safe setup and monitoring.

# Only run on Ubuntu 22
if ! grep -q "Ubuntu 22" /etc/os-release; then
  echo "This script only runs on Ubuntu 22."
  exit 1
fi

clear
echo "--------------------------------------------------"
echo "LORNA TUNELL v2 Supreme Edition"
echo "--------------------------------------------------"
echo "1) Install Tunnel (Iran Server)"
echo "2) Install Tunnel (Foreign Server)"
echo "3) Install Monitoring + Security"
echo "4) Uninstall Tunnel"
echo "5) Exit"
read -p "Choose an option (1-5): " choice

setup_rc_local() {
  echo '#!/bin/bash' > /etc/rc.local
  chmod +x /etc/rc.local
}

install_iran() {
  read -p "Enter Iran server IP: " ip_iran
  read -p "Enter Foreign server IP: " ip_foreign
  setup_rc_local
  cat <<EOF >> /etc/rc.local
ip tunnel add 6to4tun_IR mode sit remote $ip_foreign local $ip_iran || true
ip -6 addr add 2001:470:1f10:e1f::1/64 dev 6to4tun_IR || true
ip link set 6to4tun_IR mtu 1480
ip link set 6to4tun_IR up
ip -6 tunnel add GRE6Tun_IR mode ip6gre remote 2001:470:1f10:e1f::2 local 2001:470:1f10:e1f::1 || true
ip addr add 172.16.1.1/30 dev GRE6Tun_IR || true
ip link set GRE6Tun_IR mtu 1436
ip link set GRE6Tun_IR up
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -t nat -A PREROUTING -j DNAT --to-destination 172.16.1.2
iptables -t nat -A POSTROUTING -o GRE6Tun_IR -j MASQUERADE
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
EOF
  echo "Tunnel setup for Iran server completed."
}

install_foreign() {
  read -p "Enter Iran server IP: " ip_iran
  read -p "Enter Foreign server IP: " ip_foreign
  setup_rc_local
  cat <<EOF >> /etc/rc.local
ip tunnel add 6to4tun_KH mode sit remote $ip_iran local $ip_foreign || true
ip -6 addr add 2001:470:1f10:e1f::2/64 dev 6to4tun_KH || true
ip link set 6to4tun_KH mtu 1480
ip link set 6to4tun_KH up
ip -6 tunnel add GRE6Tun_KH mode ip6gre remote 2001:470:1f10:e1f::1 local 2001:470:1f10:e1f::2 || true
ip addr add 172.16.1.2/30 dev GRE6Tun_KH || true
ip link set GRE6Tun_KH mtu 1436
ip link set GRE6Tun_KH up
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
EOF
  echo "Tunnel setup for Foreign server completed."
}

install_monitoring() {
  apt update
  apt install -y netdata fail2ban
  systemctl enable netdata
  systemctl start netdata
  systemctl enable fail2ban
  systemctl start fail2ban
  echo "Monitoring (Netdata) and security (Fail2Ban) installed and running."
}

uninstall_tunnel() {
  ip tunnel del 6to4tun_IR 2>/dev/null || true
  ip tunnel del 6to4tun_KH 2>/dev/null || true
  ip tunnel del GRE6Tun_IR 2>/dev/null || true
  ip tunnel del GRE6Tun_KH 2>/dev/null || true
  rm -f /etc/rc.local
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  echo "Tunnel uninstalled and iptables reset."
}

case $choice in
  1) install_iran ;;
  2) install_foreign ;;
  3) install_monitoring ;;
  4) uninstall_tunnel ;;
  5) exit 0 ;;
  *) echo "Invalid option." ;;
esac
