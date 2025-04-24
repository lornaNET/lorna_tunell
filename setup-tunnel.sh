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
echo "2) Install Tunnel (Kharej Server)"
echo "3) Install Monitoring + Security"
echo "4) Uninstall Tunnel Only"
echo -e "\e[1;31m6) Nuclear Uninstall - Remove Everything\e[0m"
read -p "Choose an option (1-6): " choice

setup_rc_local() {
  echo '#!/bin/bash' > /etc/rc.local
  chmod +x /etc/rc.local
}

create_tunnels() {
  local type=$1
  shift
  local ips=("$@")
  
  for i in "${!ips[@]}"; do
    ip_name="tun_${type}_$((i+1))"
    local_ip="172.16.1.$((i+1))/30"
    remote_ip="${ips[$i]}"
    
    cat <<EOF >> /etc/rc.local
# Tunnel $ip_name
ip tunnel add $ip_name mode sit remote $remote_ip local $ip_iran || true
ip -6 addr add 2001:470:1f10:e1f::$(($i+1))/64 dev $ip_name || true
ip link set $ip_name mtu 1480
ip link set $ip_name up
ip -6 tunnel add GRE6Tun_${type}_${i+1} mode ip6gre remote 2001:470:1f10:e1f::$(($i+1)) local 2001:470:1f10:e1f::1 || true
ip addr add $local_ip dev GRE6Tun_${type}_${i+1} || true
ip link set GRE6Tun_${type}_${i+1} mtu 1436
ip link set GRE6Tun_${type}_${i+1} up
iptables -t nat -A POSTROUTING -o GRE6Tun_${type}_${i+1} -j MASQUERADE
EOF
  done
}

check_tunnel_status() {
  local type=$1
  for i in $(seq 1 $2); do
    ip_name="tun_${type}_$i"
    if ip link show "$ip_name" &> /dev/null; then
      state=$(cat /sys/class/net/$ip_name/operstate)
      if [[ "$state" == "up" ]]; then
        echo -e "$ip_name: ✅ Tunnel is UP"
      else
        echo -e "$ip_name: ❌ Tunnel is DOWN"
      fi
    else
      echo -e "$ip_name: ❌ Tunnel is not found"
    fi
  done
}

install_iran() {
  read -p "How many Iran IPs do you want to tunnel? " num_iran_ips
  iran_ips=()
  for ((i=1; i<=num_iran_ips; i++)); do
    read -p "Enter Iran server IP #$i: " ip_iran
    iran_ips+=("$ip_iran")
  done
  read -p "Enter Kharej server IP: " ip_kharej

  setup_rc_local
  create_tunnels "iran" "${iran_ips[@]}"
  
  echo -e "\e[1;32mIran Tunnel setup completed.\e[0m"
  check_tunnel_status "iran" "$num_iran_ips"
}

install_kharej() {
  read -p "How many Kharej IPs do you want to tunnel? " num_kharej_ips
  kharej_ips=()
  for ((i=1; i<=num_kharej_ips; i++)); do
    read -p "Enter Kharej server IP #$i: " ip_kharej
    kharej_ips+=("$ip_kharej")
  done
  read -p "Enter Iran server IP: " ip_iran
  
  setup_rc_local
  create_tunnels "kharej" "${kharej_ips[@]}"
  
  echo -e "\e[1;32mKharej Tunnel setup completed.\e[0m"
  check_tunnel_status "kharej" "$num_kharej_ips"
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
kharej_ip="172.16.1.1"

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
ping -c 2 \$kharej_ip &>/dev/null && echo "Ping to Kharej (\$kharej_ip): OK" >> \$logfile || echo "Ping to Kharej (\$kharej_ip): FAIL" >> \$logfile

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
  2) install_kharej ;;
  3) install_monitoring ;;
  4) uninstall_tunnel ;;
  5) exit 0 ;;
  6) nuclear_uninstall ;;
  *) echo "Invalid option." ;;
esac
