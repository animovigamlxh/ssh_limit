#!/bin/bash

# 一键安全防护脚本
# 快速启用所有必要的安全防护措施

echo "🛡️  一键安全防护"
echo "正在为您的节点启用全面安全防护..."
echo ""

# 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用root权限运行此脚本: sudo $0"
    exit 1
fi

# 修复dpkg问题（如果存在）
if command -v dpkg >/dev/null 2>&1; then
    echo "🔧 修复系统包管理状态..."
    dpkg --configure -a 2>/dev/null || true
fi

echo "🚫 启用SSH爆破防护..."
# 清理可能的旧规则
iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW -m limit --limit 2/minute --limit-burst 3 -j ACCEPT 2>/dev/null || true
iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW -j DROP 2>/dev/null || true
# 设置SSH连接限制
iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW -m limit --limit 2/minute --limit-burst 3 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW -j DROP

echo "🚫 启用Telnet爆破防护..."
# 清理可能的旧规则
iptables -D OUTPUT -p tcp --dport 23 -m state --state NEW -m limit --limit 1/minute --limit-burst 2 -j ACCEPT 2>/dev/null || true
iptables -D OUTPUT -p tcp --dport 23 -m state --state NEW -j DROP 2>/dev/null || true
# 设置Telnet连接限制
iptables -A OUTPUT -p tcp --dport 23 -m state --state NEW -m limit --limit 1/minute --limit-burst 2 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 23 -m state --state NEW -j DROP

echo "🚫 禁止常见攻击端口..."
# 常见攻击端口
ATTACK_PORTS="135,139,445,1433,1521,3306,3389,5432,5900,6379,9200,11211,27017"
iptables -D OUTPUT -p tcp -m multiport --dports $ATTACK_PORTS -j DROP 2>/dev/null || true
iptables -A OUTPUT -p tcp -m multiport --dports $ATTACK_PORTS -j DROP

echo "💾 保存防护规则..."
# 保存iptables规则
if command -v apt-get >/dev/null 2>&1; then
    # Ubuntu/Debian
    mkdir -p /etc/iptables 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules 2>/dev/null
    
    # 尝试安装持久化工具
    if ! command -v netfilter-persistent >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1 && apt-get install -y iptables-persistent >/dev/null 2>&1 || true
    fi
    
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1
    fi
    
elif command -v yum >/dev/null 2>&1; then
    # CentOS/RHEL
    service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables
elif command -v apk >/dev/null 2>&1; then
    # Alpine
    mkdir -p /etc/iptables 2>/dev/null
    iptables-save > /etc/iptables/rules-save
fi

echo ""
echo "🎯 安全防护设置完成！"
echo ""
echo "✅ 已启用的防护措施："
echo "   • SSH爆破防护：每分钟最多2个连接"
echo "   • Telnet爆破防护：每分钟最多1个连接"
echo "   • 常见攻击端口防护：已禁止连接到危险端口"
echo "   • 防护规则已保存：重启后自动生效"
echo ""
echo "📊 查看防护状态："
echo "   iptables -L OUTPUT -n | grep -E 'dpt:(22|23)'"
echo ""
echo "🗑️  如需移除防护（不推荐）："
echo "   iptables -F OUTPUT"
echo ""
echo "⚠️  重要提醒："
echo "   • 这些规则限制从您的服务器主动连接到其他服务器"
echo "   • 不影响用户通过代理访问网站"
echo "   • 可以有效防止恶意用户进行爆破攻击"
echo ""
echo "🔒 您的机场节点现在更安全了！" 
