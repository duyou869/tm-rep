#!/bin/sh
#
# v3 - 自动检测 Debian, Ubuntu, Alpine 并执行
#

# 如果任何命令失败，脚本将立即退出
set -e

echo "--- 步骤 1/6: 检测操作系统 ---"

# 检查 /etc/os-release 来确定系统
if [ -f /etc/os-release ]; then
    # . /etc/os-release 会加载该文件中的变量 (例如 ID, ID_LIKE)
    . /etc/os-release
else
    echo "错误：无法找到 /etc/os-release。无法确定操作系统。"
    exit 1
fi

# 检查是 Debian/Ubuntu 还是 Alpine
# 明确添加 $ID = "ubuntu"
if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ] || [ "$ID_LIKE" = "debian" ]; then
    echo "检测到 Debian / Ubuntu 类系统 (ID: $ID)。"
    SYSTEM_TYPE="debian" # 内部类型统一用 "debian" 处理，因为它们都用 apt 和 systemd
    
elif [ "$ID" = "alpine" ]; then
    echo "检测到 Alpine Linux (ID: $ID)。"
    SYSTEM_TYPE="alpine"
    
else
    echo "错误：不支持的操作系统 ($ID)。"
    echo "此脚本仅支持 Debian, Ubuntu, 或 Alpine。"
    exit 1
fi

echo "--- 步骤 2/6: 安装 Podman ---"

if [ "$SYSTEM_TYPE" = "debian" ]; then
    echo "正在使用 apt (适用于 Debian/Ubuntu)..."
    # 非交互式安装，避免卡住
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt install -y podman
    
elif [ "$SYSTEM_TYPE" = "alpine" ]; then
    echo "正在使用 apk (适用于 Alpine)..."
    apk update
    apk add podman
fi

# 确保安装成功
if ! command -v podman >/dev/null 2>&1; then
    echo "Podman 安装失败，请检查错误。"
    exit 1
fi
echo "Podman 安装成功。"

echo "--- 步骤 3/6: 运行 traffmonetizer (tm) 容器 ---"
# --restart=always 对两个系统都很重要
podman run -d --name tm --restart=always \
  docker.io/traffmonetizer/cli_v2 \
  start accept --token yrmSJE4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8=

echo "--- 步骤 4/6: 运行 repocket 容器 ---"
podman run -d --name repocket \
  -e RP_EMAIL=bellesassman4011479@gmail.com \
  -e RP_API_KEY=5cd00e75-a7cc-4bb7-bd73-9e58df30e14b \
  --restart=always \
  docker.io/repocket/repocket

echo "--- 步骤 5/6: 设置开机自启 ---"

if [ "$SYSTEM_TYPE" = "debian" ]; then
    echo "正在为 Debian/Ubuntu (systemd) 设置开机自启..."
    
    # 生成 systemd 服务文件
    podman generate systemd --name tm --new -f > /etc/systemd/system/podman-tm.service
    podman generate systemd --name repocket --new -f > /etc/systemd/system/podman-repocket.service
    
    # 重新加载并启用服务
    systemctl daemon-reload
    systemctl enable podman-tm.service
    systemctl enable podman-repocket.service
    
    echo "Systemd 服务已启用。"

elif [ "$SYSTEM_TYPE" = "alpine" ]; then
    echo "正在为 Alpine (OpenRC) 设置开机自启..."
    
    # 检查 podman-auto-restart 服务是否存在
    if [ -f /etc/init.d/podman-auto-restart ]; then
        # 启用 OpenRC 服务, 它会自动重启所有 --restart=always 的容器
        rc-update add podman-auto-restart default
        rc-service podman-auto-restart start
        echo "OpenRC 'podman-auto-restart' 服务已启用。"
    else
        echo "警告：未找到 /etc/init.d/podman-auto-restart。"
        echo "请检查 'podman' 或 'podman-openrc' 包是否完整安装。"
        echo "容器已运行，但可能无法开机自启。"
    fi
fi

echo "---"
echo "✅ 步骤 6/6: 全部完成！"
echo "---"
echo "Podman 已安装，tm 和 repocket 容器已在运行。"
echo "两者均已配置为开机自启。"
echo "---"
echo "你可以使用 podman logs 查看日志："
echo "podman logs tm"
echo "podman logs repocket"
