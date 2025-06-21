#!/bin/bash

# 机场一键安全防护脚本
# 快速启用/关闭所有必要的安全防护措施

# 显示使用说明
show_usage() {
    echo "🛡️  机场一键安全防护脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  on      启用安全防护（默认）"
    echo "  off     关闭安全防护"
    echo "  status  查看防护状态"
    echo "  help    显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 on       # 启用防护"
    echo "  $0 off      # 关闭防护"
    echo "  $0 status   # 查看状态"
    echo ""
}

# 检查权限
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ 请使用root权限运行此脚本: sudo $0"
        exit 1
    fi
}

# 修复dpkg问题
fix_dpkg() {
    if command -v dpkg >/dev/null 2>&1; then
        echo "🔧 修复系统包管理状态..."
        dpkg --configure -a 2>/dev/null || true
    fi
}

# 启用安全防护
enable_protection() {
    echo "🛡️  启用机场安全防护"
    echo "正在为您的节点启用全面安全防护..."
    echo ""
    
    fix_dpkg
    
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
    
    save_rules
    
    echo ""
    echo "🎯 安全防护启用完成！"
    echo ""
    echo "✅ 已启用的防护措施："
    echo "   • SSH爆破防护：每分钟最多2个连接"
    echo "   • Telnet爆破防护：每分钟最多1个连接"
    echo "   • 常见攻击端口防护：已禁止连接到危险端口"
    echo "   • 防护规则已保存：重启后自动生效"
    echo ""
    echo "🔒 您的节点现在更安全了！"
}

# 关闭安全防护
disable_protection() {
    echo "🔓 关闭安全防护"
    echo "正在移除所有安全防护规则..."
    echo ""
    
    echo "🗑️  移除SSH爆破防护..."
    iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW -m limit --limit 2/minute --limit-burst 3 -j ACCEPT 2>/dev/null || true
    iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW -j DROP 2>/dev/null || true
    
    echo "🗑️  移除Telnet爆破防护..."
    iptables -D OUTPUT -p tcp --dport 23 -m state --state NEW -m limit --limit 1/minute --limit-burst 2 -j ACCEPT 2>/dev/null || true
    iptables -D OUTPUT -p tcp --dport 23 -m state --state NEW -j DROP 2>/dev/null || true
    
    echo "🗑️  移除攻击端口防护..."
    ATTACK_PORTS="135,139,445,1433,1521,3306,3389,5432,5900,6379,9200,11211,27017"
    iptables -D OUTPUT -p tcp -m multiport --dports $ATTACK_PORTS -j DROP 2>/dev/null || true
    
    save_rules
    
    echo ""
    echo "⚠️  安全防护已关闭！"
    echo ""
    echo "❌ 已移除的防护措施："
    echo "   • SSH爆破防护"
    echo "   • Telnet爆破防护"
    echo "   • 常见攻击端口防护"
    echo ""
    echo "🚨 警告：您的服务器现在更容易被恶意用户滥用！"
    echo "💡 建议运行 '$0 on' 重新启用防护"
}

# 查看防护状态
show_status() {
    echo "📊 机场安全防护状态"
    echo ""
    
    echo "SSH防护规则："
    if iptables -L OUTPUT -n | grep -q "dpt:22"; then
        iptables -L OUTPUT -n --line-numbers | grep "dpt:22"
        echo "✅ SSH防护已启用"
    else
        echo "❌ SSH防护未启用"
    fi
    echo ""
    
    echo "Telnet防护规则："
    if iptables -L OUTPUT -n | grep -q "dpt:23"; then
        iptables -L OUTPUT -n --line-numbers | grep "dpt:23"
        echo "✅ Telnet防护已启用"
    else
        echo "❌ Telnet防护未启用"
    fi
    echo ""
    
    echo "攻击端口防护："
    if iptables -L OUTPUT -n | grep -q "multiport"; then
        iptables -L OUTPUT -n | grep "multiport"
        echo "✅ 攻击端口防护已启用"
    else
        echo "❌ 攻击端口防护未启用"
    fi
    echo ""
    
    # 统计防护状态
    ssh_enabled=$(iptables -L OUTPUT -n | grep -c "dpt:22" || echo "0")
    telnet_enabled=$(iptables -L OUTPUT -n | grep -c "dpt:23" || echo "0")
    ports_enabled=$(iptables -L OUTPUT -n | grep -c "multiport" || echo "0")
    
    total_protections=$((ssh_enabled + telnet_enabled + ports_enabled))
    
    if [ $total_protections -gt 0 ]; then
        echo "🛡️  防护状态：已启用 ($total_protections/3)"
    else
        echo "🚨 防护状态：完全关闭 (0/3)"
    fi
}

# 保存规则函数
save_rules() {
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
}

# 主程序
ACTION=${1:-"on"}  # 默认为启用

case "$ACTION" in
    "on"|"enable"|"start")
        check_permissions
        enable_protection
        echo ""
        echo "📋 管理命令："
        echo "   查看状态: $0 status"
        echo "   关闭防护: $0 off"
        ;;
    "off"|"disable"|"stop")
        check_permissions
        disable_protection
        echo ""
        echo "📋 管理命令："
        echo "   查看状态: $0 status"
        echo "   启用防护: $0 on"
        ;;
    "status"|"show")
        show_status
        echo ""
        echo "📋 管理命令："
        echo "   启用防护: $0 on"
        echo "   关闭防护: $0 off"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "❌ 未知选项: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac 
