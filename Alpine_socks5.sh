#!/bin/sh

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
echo "--- SOCKS5 代理 (Dante) 交互式安装程序 (V7) ---"

prompt_read "请输入 SOCKS5 代理端口 (默认 25426): " PROXY_PORT
[ -z "$PROXY_PORT" ] && PROXY_PORT=25426

prompt_read "请输入 SOCKS5 认证用户名 (回车 = 不设置密码/公开代理): " SOCKS_USER

# V6 修正: 使用正确的包名和配置文件名
AUTH_METHOD="none"
PACKAGES="dante-server"
CONFIG_FILE="/etc/sockd.conf" # 正确的配置文件路径
SERVICE_NAME="sockd" # 正确的服务名
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
    
    # --- V7 修改点 ---
    prompt_read "我理解风险并确认要创建公开代理 (回车 = 确认, 输入 'no' 取消): " CONFIRM_OPEN
    
    # 检查用户是否明确输入了 'no' (或 'n')
    # 任何其他输入（包括直接回车）都视为同意
    case "$CONFIRM_OPEN" in
        [nN] | [nN][oO])
            echo "已取消安装。"
            exit 0
            ;;
        *)
            # 默认继续
            echo "已确认创建公开代理。"
            ;;
    esac
    # --- V7 修改结束 ---
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

# 5. 配置 sockd.conf (V6 修正)
echo "正在配置 $CONFIG_FILE..."

EXT_IF=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
if [ -z "$EXT_IF" ]; then
    echo "警告：无法自动检测外部网络接口。尝试备选方案..."
    EXT_IF=$(ip -4 route ls | grep default | awk '{ for(i=1;i<=NF;i++) { if($i=="dev") { print $(i+1); exit; } } }')
    if [ -z "$EXT_IF" ]; then
        echo "错误：无法检测网络接口。请手动配置 $CONFIG_FILE"
        exit 1
    fi
fi

echo "检测到外部接口: $EXT_IF"

# V6 修正: 写入正确的配置文件
cat > $CONFIG_FILE <<EOF
# $CONFIG_FILE - 由智汇的脚本生成 (V7)
logoutput: /var/log/sockd.log
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
touch /var/log/sockd.log
chown nobody:nobody /var/log/sockd.log

# 7. 启动并设置开机自启 (V6 修正)
echo "正在启动 $SERVICE_NAME 服务并设置开机自启..."
rc-service $SERVICE_NAME stop >/dev/null 2>&1
rc-service $SERVICE_NAME start
rc-update add $SERVICE_NAME default

# 8. 完成
SERVER_IP=$(ip -4 addr show $EXT_IF | grep 'inet' | awk '{print $2}' | cut -d'/' -f1)

echo "-----------------------------------------"
echo "SOCKS5 代理服务器安装完成！ (V7)"
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
echo "   rc-service $SERVICE_NAME stop; rc-update del $SERVICE_NAME;"
echo "   $UNINSTALL_CMD"
echo "-----------------------------------------"
