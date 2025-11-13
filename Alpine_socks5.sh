#!/bin/sh

# Alpine Linux SOCKS5 (dante-server) 交互式安装脚本 (V3 - POSIX 兼容版)

# --- 兼容性函数 ---
# 封装 read -p 的功能
prompt_read() {
    # $1 = 提示符, $2 = 变量名
    printf "%s" "$1"
    read "$2"
}

# 封装 read -sp (静默输入) 的功能
prompt_read_silent() {
    # $1 = 提示符, $2 = 变量名
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
echo "--- SOCKS5 代理 (Dante) 交互式安装程序 (V3) ---"

prompt_read "请输入 SOCKS5 代理端口 (默认 25426): " PROXY_PORT
[ -z "$PROXY_PORT" ] && PROXY_PORT=25426

prompt_read "请输入 SOCKS5 认证用户名 (回车 = 不设置密码/公开代理): " SOCKS_USER

AUTH_METHOD="none"
PACKAGES="dante-server"
UNINSTALL_CMD="apk del dante-server"

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
    UNINSTALL_CMD="apk del dante-server shadow; userdel $SOCKS_USER"
    
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

# 自动检测主要的外部网络接口 (POSIX 兼容)
EXT_IF=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
if [ -z "$EXT_IF" ]; then
    echo "警告：无法自动检测外部网络接口。尝试备选方案..."
    # 使用 awk 替代 grep -Po
    EXT_IF=$(ip -4 route ls | grep default | awk '{ for(i=1;i<=NF;i++) { if($i=="dev") { print $(i+1); exit; } } }')
    if [ -z "$EXT_IF" ]; then
        echo "错误：无法检测网络接口。请手动配置 /etc/danted.conf"
        exit 1
    fi
fi

echo "检测到外部接口: $EXT_IF"
CONFIG_FILE="/etc/danted.conf"

cat > $CONFIG_FILE <<EOF
# danted.conf - 由智汇的脚本生成 (V3-POSIX)
logoutput: /var/log/danted.log

# 内部接口：监听所有IP地址的指定端口
internal: 0.0.0.0 port = $PROXY_PORT

# 外部接口：流量将通过此接口出去
external: $EXT_IF

# 认证方式：
# username = 使用系统用户 (/etc/passwd) 进行用户名/密码验证
# none = 无认证 (公开代理)
socksmethod: $AUTH_METHOD

# 运行服务的用户
user.privileged: root
user.unprivileged: nobody

# --- 客户端规则 (谁可以连接到代理) ---
client pass {
    from: 0.0.0.0/0
    to: 0.0.0.0/0
    log: connect error
}

# --- SOCKS 规则 (认证后/或无需认证 可以访问哪里) ---
socks pass {
    from: 0.0.0.0/0
    to: 0.0.0.0/0
    log: connect error
}
EOF

# 6. 创建日志文件并设置权限
touch /var/log/danted.log
chown nobody:nobody /var/log/danted.log

# 7. 启动并设置开机自启
echo "正在启动 danted 服务并设置开机自启..."
rc-service danted stop >/dev/null 2>&1
rc-service danted start
rc-update add danted default

# 8. 完成
SERVER_IP=$(ip -4 addr show $EXT_IF | grep 'inet' | awk '{print $2}' | cut -d'/' -f1)

echo "-----------------------------------------"
echo "SOCKS5 代理服务器安装完成！"
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
