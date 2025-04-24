#!/bin/bash

# LORNA TUNNEL v2 Supreme Edition - Full NAT IPv6+GRE Secure Tunnel with Monitoring
# Compatible: Ubuntu 22 Only

if ! grep -q "Ubuntu 22" /etc/os-release; then
  echo "ERROR: Only Ubuntu 22 is supported!"
  exit 1
fi

clear
echo -e "\e[1;36m
  ╔════════════════════════════════════════════╗
  ║        LORNA TUNNEL v2 SUPREME EDITION     ║
  ║   Full IPv6+GRE Tunnel + Monitoring Stack  ║
  ╚════════════════════════════════════════════╝
\e[0m"
echo "1) Install Tunnel (Iran Server)"
echo "2) Install Tunnel (Foreign Server)"
echo "3) Install Monitoring + Security"
echo "4) Uninstall Tunnel Only"
echo -e "\e[1;31m6) Nuclear Uninstall - Remove Everything\e[0m"
read -p "Choose an option (1-6): " choice

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
iptables -A INPUT -p tcp --dport 19999 -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
systemctl restart netdata || true
EOF
  echo -e "\e[1;32mIran Tunnel setup completed.\e[0m"
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
iptables -A INPUT -p tcp --dport 19999 -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
systemctl restart netdata || true
EOF
  echo -e "\e[1;32mForeign Tunnel setup completed.\e[0m"
}

install_monitoring() {
  apt update
  apt install -y netdata fail2ban
  sed -i 's/^  bind to = 127.0.0.1/  bind to = 0.0.0.0/' /etc/netdata/netdata.conf
  systemctl enable netdata
  systemctl restart netdata
  systemctl enable fail2ban
  systemctl restart fail2ban
  iptables -A INPUT -p tcp --dport 19999 -j ACCEPT

  # مانیتور تونل
  cat <<EOF > /usr/local/bin/tunnel-monitor.sh
#!/bin/bash
logfile="/var/log/tunnel-monitor.log"
iran_ip="172.16.1.2"
foreign_ip="172.16.1.1"

echo "----------------------------------------" >> \$logfile
echo "Tunnel Monitor: \$(date)" >> \$logfile

for iface in 6to4tun_IR GRE6Tun_IR 6to4tun_KH GRE6Tun_KH; do
  if ip link show "\$iface" &> /dev/null; then
    state=\$(cat /sys/class/net/\$iface/operstate)
    echo "Interface \$iface is \$state" >> \$logfile
  else
    echo "Interface \$iface not found" >> \$logfile
  fi
done

ping -c 2 \$iran_ip &>/dev/null && echo "Ping to Iran (\$iran_ip): OK" >> \$logfile || echo "Ping to Iran (\$iran_ip): FAIL" >> \$logfile
ping -c 2 \$foreign_ip &>/dev/null && echo "Ping to Foreign (\$foreign_ip): OK" >> \$logfile || echo "Ping to Foreign (\$foreign_ip): FAIL" >> \$logfile

echo "Server Uptime: \$(uptime -p)" >> \$logfile
echo "" >> \$logfile
EOF

  chmod +x /usr/local/bin/tunnel-monitor.sh
  (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/tunnel-monitor.sh") | crontab -

  echo -e "\e[1;32mMonitoring & Security setup done. Access at: http://$(hostname -I | awk '{print $1}'):19999\e[0m"
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
  echo -e "\e[1;33mTunnel uninstalled and firewall reset.\e[0m"
}

nuclear_uninstall() {
  echo -e "\e[1;31mWARNING: This will remove everything (tunnel, monitoring, firewall rules, logs). Proceed? (yes/no)\e[0m"
  read -p "> " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi

  uninstall_tunnel
  apt purge -y netdata fail2ban
  apt autoremove -y
  rm -f /usr/local/bin/tunnel-monitor.sh
  crontab -l | grep -v 'tunnel-monitor.sh' | crontab -
  rm -f /var/log/tunnel-monitor.log
  echo -e "\e[1;31mAll components removed. Clean system.\e[0m"
}

case $choice in
  1) install_iran ;;
  2) install_foreign ;;
  3) install_monitoring ;;
  4) uninstall_tunnel ;;
  5) exit 0 ;;
  6) nuclear_uninstall ;;
  *) echo "Invalid option." ;;
esac
