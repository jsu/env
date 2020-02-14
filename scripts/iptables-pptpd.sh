#!/bin/sh
iptables -P INPUT ACCEPT
iptables -F 
iptables -X
iptables -Z

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o eth1 -jMASQUERADE
iptables -A INPUT -p tcp --dport 1723 -j ACCEPT
iptables -P INPUT DROP
