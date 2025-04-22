#!/bin/bash

# Only run on Ubuntu 22
if ! grep -q "Ubuntu 22" /etc/os-release; then
  echo "این اسکریپت فقط روی Ubuntu 22 اجرا می‌شود."
  exit 1
fi

clear
echo "--------------------------------------------------"
echo "6to4 Tunnel Setup Script"
echo "--------------------------------------------------"
echo "1) تنظیمات سرور ایران"
echo "2) تنظیمات سرور خارج"
read -p "یکی رو انتخاب کن (1 یا 2): " choice

read -p "IP سرور ایران رو وارد کن: " ip_iran
read -p "IP سرور خارج رو وارد کن: " ip_kharej

# آماده‌سازی فایل rc.local
cat <<EOF > /etc/rc.local
#!/bin/bash
EOF

if [[ "$choice" == "1" ]]; then
cat <<EOF >> /etc/rc.local
ip tunnel add 6to4tun_IR mode sit remote $ip_kharej local $ip_iran
ip -6 addr add 2001:470:1f10:e1f::1/64 dev 6to4tun_IR
ip link set 6to4tun_IR mtu 1480
ip link set 6to4tun_IR up
ip -6 tunnel add GRE6Tun_IR mode ip6gre remote 2001:470:1f10:e1f::2 local 2001:470:1f10:e1f::1
ip addr add 172.16.1.1/30 dev GRE6Tun_IR
ip link set GRE6Tun_IR mtu 1436
ip link set GRE6Tun_IR up
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -A PREROUTING  -j DNAT --to-destination 172.16.1.2
iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $ip_iran
iptables -t nat -A POSTROUTING -o GRE6Tun_IR -j MASQUERADE
iptables -A FORWARD  -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
EOF
elif [[ "$choice" == "2" ]]; then
cat <<EOF >> /etc/rc.local
ip tunnel add 6to4tun_KH mode sit remote $ip_iran local $ip_kharej
ip -6 addr add 2001:470:1f10:e1f::2/64 dev 6to4tun_KH
ip link set 6to4tun_KH mtu 1480
ip link set 6to4tun_KH up
ip -6 tunnel add GRE6Tun_KH mode ip6gre remote 2001:470:1f10:e1f::1 local 2001:470:1f10:e1f::2
ip addr add 172.16.1.2/30 dev GRE6Tun_KH
ip link set GRE6Tun_KH mtu 1436
ip link set GRE6Tun_KH up
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD  -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
EOF
else
  echo "ورودی نامعتبر بود."
  exit 1
fi

chmod +x /etc/rc.local

echo "تنظیمات انجام شد. برای اجرا دستور زیر را بزن:"
echo "sudo /etc/rc.local"
