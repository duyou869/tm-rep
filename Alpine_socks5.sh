#!/bin/sh

# Alpine Linux SOCKS5 (dante-server) 交互式安装脚本 (V5 - 最终路径修复版)
# 智汇 (Gemini) - 修复了 danted 的可执行文件路径
#
# !! 安全警告 !!
# 代理服务器是双重用途技术。请确保您的使用遵守当地法律法规
# 和服务提供商的政策。严禁将此服务用于非法或恶意活动。
# 您有责任保护此代理的安全，防止被滥用。
#

# --- 兼容性函数 ---
prompt_read() {
    printf "%s" "$1"
    read "$2"
}
prompt_read_silent() {
    printf "%s" "$1"
    stty -echo
    read "$2"
    stty echo
    printf "\n"
}
# --- 结束 ---

# 1. 检查是否为 Root 用户
if [ "$(id -u)" -ne 0 ]; then
   echo "错误：此脚本需要以 root 权限运行。"
   exit 1
fi

# 2. 获取用户输入
echo "--- SOCKS5 代理 (Dante) 交互式安装程序 (V5) ---"

prompt_read "请输入 SOCKS5 代理端口 (默认 25426): " PROXY_PORT
[ -z "$PROXY_PORT" ] && PROXY_PORT=25426

prompt_read "请输入 SOCKS5 认证用户名 (回车 = 不设置密码/公开代理): " SOCKS_USER

AUTH_METHOD="none"
PACKAGES="dante-server"
UNINSTALL_CMD="apk del dante-server; rm -f /etc/init.d/danted"

# 检查是否需要认证
if [ -n "$SOCKS_USER" ]; then
    # 需要认证
    prompt_read_silent "请输入 SOCKS5 认证密码: " SOCKS_PASS

    if [ -z "$SOCKS_PASS" ]; then
        echo "错误：设置了用户名，但密码不能为空！"
        exit 1
    fi
    
    AUTH_METHOD="username"
    PACKAGES="dante-server shadow"
    UNINSTALL_CMD="apk del dante-server shadow; userdel $SOCKS_USER; rm -f /etc/init.d/danted"
    
else
    # 无认证（公开代理）
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!! 严重警告 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "您选择不设置用户名和密码。这将创建一个 *公开代理*。"
    echo "互联网上的任何人都可以连接到您的服务器并使用您的网络。"
    echo "这非常危险，极易导致您的服务器被滥用并被服务商封禁。"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo
    prompt_read "我理解风险并确认要创建公开代理 (请输入 'yes' 继续): " CONFIRM_OPEN
    
    if [ "$CONFIRM_OPEN" != "yes" ]; then
        echo "已取消安装。"
        exit 0
    fi
    echo "已确认创建公开代理。"
fi

# 3. 安装软件包
echo "正在更新软件包列表并安装: $PACKAGES..."
apk update
apk add $PACKAGES

if [ $? -ne 0 ]; then
    echo "错误：软件包安装失败。"
    exit 1
fi

# 4. 创建 SOCKS5 认证用户 (如果需要)
if [ "$AUTH_METHOD" = "username" ]; then
    echo "正在为 '$SOCKS_USER' 创建系统用户 (用于认证)..."
    adduser -D -H -s /bin/false "$SOCKS_USER"
    echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd

    if [ $? -ne 0 ]; then
        echo "错误：创建或设置用户密码失败。"
        exit 1
    fi
fi

# 5. 配置 dante-server
echo "正在配置 dante-server (/etc/danted.conf)..."

EXT_IF=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
if [ -z "$EXT_IF" ]; then
    echo "警告：无法自动检测外部网络接口。尝试备选方案..."
    EXT_IF=$(ip -4 route ls | grep default | awk '{ for(i=1;i<=NF;i++) { if($i=="dev") { print $(i+1); exit; } } }')
    if [ -z "$EXT_IF" ]; then
        echo "错误：无法检测网络接口。请手动配置 /etc/danted.conf"
        exit 1
    fi
fi

echo "检测到外部接口: $EXT_IF"
CONFIG_FILE="/etc/danted.conf"

cat > $CONFIG_FILE <<EOF
# danted.conf - 由智汇的脚本生成 (V5-POSIX)
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $PROXY_PORT
external: $EXT_IF
socksmethod: $AUTH_METHOD
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0
    to: 0.0.0.0/0
    log: connect error
}

socks pass {
    from: 0.0.0.0/0
    to: 0.0.0.0/0
    log: connect error
}
EOF

# 6. 创建日志文件并设置权限
touch /var/log/danted.log
chown nobody:nobody /var/log/danted.log

# 7. [V5 修复] 为 Alpine OpenRC 创建服务文件
#    Alpine 将 danted 安装在 /usr/bin/danted, 而不是 /usr/sbin/danted
echo "正在创建 /etc/init.d/danted 服务脚本..."
cat > /etc/init.d/danted <<'EOF'
#!/sbin/openrc-run

command="/usr/bin/danted"
command_args="-D"
pidfile="/var/run/danted.pid"

depend() {
    need net
    use dns
}
EOF

chmod +x /etc/init.d/danted

# 8. 启动并设置开机自启
echo "正在启动 danted 服务并设置开机自启..."
killall danted >/dev/null 2>&1
rc-service danted stop >/dev/null 2>&1
rc-service danted start
rc-update add danted default

# 9. 完成
SERVER_IP=$(ip -4 addr show $EXT_IF | grep 'inet' | awk '{print $2}' | cut -d'/' -f1)

echo "-----------------------------------------"
echo "SOCKS5 代理服务器安装完成！ (V5)"
echo ""
echo "  服务器地址 (IP): $SERVER_IP"
echo "  服务器端口 (Port): $PROXY_PORT"

if [ "$AUTH_METHOD" = "username" ]; then
    echo "  用户名 (Username): $SOCKS_USER"
    echo "  密码 (Password): [已隐藏]"
else
    echo "  认证 (Auth): 无 (公开代理)"
    echo "  !! 警告：您的代理是公开的，请务必注意安全风险 !!"
fi

echo "-----------------------------------------"
echo "重要提示："
echo "1. 请妥善保管您的认证信息（如果设置了）。"
echo "2. 如果您的 Alpine 机器配置了防火墙，请确保放行 TCP 端口: $PROXY_PORT"
echo "3. 如需卸载，请运行: "
echo "   rc-service danted stop; rc-update del danted;"
echo "   $UNINSTALL_CMD"
echo "-----------------------------------------"
