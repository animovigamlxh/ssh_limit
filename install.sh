#!/bin/bash

# 限制对外SSH连接
iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW -m limit --limit 3/minute --limit-burst 5 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW -j DROP

# 保存iptables规则
if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y iptables-persistent
    netfilter-persistent save
elif command -v yum >/dev/null 2>&1; then
    service iptables save
fi

# 修改SSH客户端配置以限制连接尝试
cat > /etc/ssh/ssh_config.d/limits.conf << EOF
# 限制每个目标的连接尝试次数
Host *
    ConnectTimeout 10
    ConnectionAttempts 2
    MaxSessions 2
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

echo "已设置以下限制："
echo "1. 每分钟最多允许3个新的SSH连接尝试"
echo "2. 突发限制为5个连接"
echo "3. 每个目标主机最多尝试2次连接"
echo "4. SSH连接超时设置为10秒"

echo "如果需要临时解除限制，请运行："
echo "iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW -m limit --limit 3/minute --limit-burst 5 -j ACCEPT"
echo "iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW -j DROP" 
