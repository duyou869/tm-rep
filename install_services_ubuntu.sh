#!/bin/bash
# ------------------------------------------------------------------
# 一键安装和伪装 network-svc 和 cache-manager 的脚本
#
# !! 目标系统: Ubuntu / Debian (使用 apt 和 systemd) !!
# V2 - 自动获取最新的 crane 版本，修复下载失败的问题
# ------------------------------------------------------------------

# 1. 如果任何命令失败，立即停止脚本
set -e

echo "--- 阶段一：全局环境准备 (Ubuntu/Debian) ---"
echo "正在更新软件包列表 (apt update)..."
# -y 自动回答 "yes"
apt-get update -y

echo "正在安装所有依赖 (curl, nano, C++, Node.js)..."
# 注意：这里用 apt-get，并且包名可能不同
apt-get install -y curl nano libstdc++6 libgcc-s1 nodejs npm
echo "所有依赖安装完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段二：(新) 手动安装 crane (自动获取最新版)
# ------------------------------------------------------------------
echo "--- 阶段二：手动安装 crane ---"
echo "Ubuntu/Debian 仓库中没有 crane，正在从 GitHub 自动查找最新版..."

# 1. 自动从 GitHub API 查询最新的版本号 (例如: v0.20.1)
# 我们使用 curl 的 -f 选项，如果API失败（如404或403），脚本会因为 set -e 而停止
CRANE_VERSION=$(curl -s -f "https://api.github.com/repos/google/go-containerregistry/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$CRANE_VERSION" ]; then
    echo "错误：无法自动从 GitHub API 获取最新版本号。"
    echo "请检查你的 VPS 是否能访问 api.github.com"
    exit 1
fi

echo "找到最新版本: $CRANE_VERSION，正在下载..."

# 2. 使用这个最新版本号下载
curl -f -L "https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/crane_Linux_x86_64.tar.gz" -o crane.tar.gz
tar -zxvf crane.tar.gz crane
mv crane /usr/local/bin/crane
rm crane.tar.gz
echo "crane 已安装到 /usr/local/bin/crane"
echo ""

# ------------------------------------------------------------------
# 阶段三：安装服务 1 (network-svc / Traffmonetizer)
# ------------------------------------------------------------------
echo "--- 阶段三：安装 'network-svc' ---"
echo "创建目录 /opt/network-svc 并进入..."
mkdir -p /opt/network-svc
cd /opt/network-svc

echo "正在使用 crane 拉取和解压 traffmonetizer 镜像..."
crane pull traffmonetizer/cli_v2 image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;

echo "清理安装文件..."
rm image.tar *.tar.gz manifest.json
echo "'network-svc' 已安装到 /opt/network-svc/app"
echo ""

# ------------------------------------------------------------------
# 阶段四：配置服务 1 (systemd 版本)
# ------------------------------------------------------------------
echo "--- 阶段四：配置 'network-svc' (systemd) ---"
echo "创建 /etc/systemd/system/network-svc.service (服务脚本)..."
cat << EOF > /etc/systemd/system/network-svc.service
[Unit]
Description=Network Core Service (Traffmonetizer)
After=network.target

[Service]
Type=simple
# 设置 .NET ICU 修复
Environment=DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# C++ 程序的启动方式
ExecStart=/opt/network-svc/app/Cli start accept --token 'yrmSJE4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8='

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "启动服务 1 (network-svc)..."
systemctl daemon-reload           # 1. 重载 systemd，识别新文件
systemctl enable network-svc.service  # 2. 设置开机自启
systemctl start network-svc.service   # 3. 立即启动
echo "'network-svc' 已启动。"
echo ""

# ------------------------------------------------------------------
# 阶段五：安装服务 2 (cache-manager / Repocket)
# ------------------------------------------------------------------
echo "--- 阶段五：安装 'cache-manager' ---"
echo "创建目录 /opt-cache-manager 并进入..."
mkdir -p /opt-cache-manager
cd /opt-cache-manager

echo "正在使用 crane 拉取和解压 repocket 镜像..."
crane pull repocket/repocket image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;

echo "清理安装文件..."
rm image.tar *.tar.gz manifest.json
echo "'cache-manager' 已安装到 /opt-cache-manager/app"
echo ""

# ------------------------------------------------------------------
# 阶段六：配置服务 2 (systemd 版本)
# ------------------------------------------------------------------
echo "--- 阶段六：配置 'cache-manager' (systemd) ---"
echo "创建 /etc/systemd/system/cache-manager.service (服务脚本)..."
cat << EOF > /etc/systemd/system/cache-manager.service
[Unit]
Description=System Cache Manager Service (Repocket)
After=network.target

[Service]
Type=simple

# Node.js 程序的执行目录
WorkingDirectory=/opt-cache-manager/app

# Node.js 程序的启动命令
ExecStart=/usr/bin/node dist/index.js -e 'bellesassman4011479@gmail.com' -p '5cd00e75-a7cc-4bb7-bd73-9e58df30e14b'

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "启动服务 2 (cache-manager)..."
systemctl daemon-reload             # 1. 重载 systemd
systemctl enable cache-manager.service  # 2. 设置开机自启
systemctl start cache-manager.service   # 3. 立即启动
echo "'cache-manager' 已启动。"
echo ""

# ------------------------------------------------------------------
# 完成
# ------------------------------------------------------------------
echo "--- 🚀 全部完成！ (Ubuntu/Debian) ---"
echo "两个服务都已安装并启动。"
echo "你可以使用以下命令检查状态："
echo "systemctl status network-svc"
echo "systemctl status cache-manager"
echo "cd /"
