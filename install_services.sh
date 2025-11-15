#!/bin/sh
#
# =============================================================
# “三合一”最终脚本 (Alpine / OpenRC)
#
# 安装服务:
# 1. network-svc  (Traffmonetizer)
# 2. cache-manager (Repocket)
# 3. earnfm-svc    (EarnFM)
#
# 解决了所有依赖和兼容性问题。
# =============================================================

# 1. 如果任何命令失败，立即停止脚本
set -e

echo "--- 阶段一：全局环境准备 ---"
echo "正在更新软件包列表..."
apk update

echo "正在安装所有依赖 (crane, nano, C++, Node.js, gcompat)..."
# - network-svc/earnfm-svc 需要: crane, libstdc++, libgcc
# - cache-manager 需要: crane, nodejs, npm
# - earnfm-svc (glibc程序) 额外需要: gcompat
apk add crane nano libstdc++ libgcc nodejs npm gcompat

echo "所有依赖安装完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段二：安装服务 1 (network-svc / Traffmonetizer)
# ------------------------------------------------------------------
echo "--- 阶段二：安装 'network-svc' ---"
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
# 阶段三：配置服务 1 (network-svc)
# ------------------------------------------------------------------
echo "--- 阶段三：配置 'network-svc' ---"
echo "创建 /etc/conf.d/network-svc (用于 .NET ICU 修复)..."
cat << 'EOF' > /etc/conf.d/network-svc
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
EOF

echo "创建 /etc/init.d/network-svc (服务脚本)..."
cat << 'EOF' > /etc/init.d/network-svc
#!/sbin/openrc-run

description="Network Core Service (Traffmonetizer)"

depend() {
    need net
}

command="/opt/network-svc/app/Cli"
command_args="start accept --token 'yrmSJO4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8='"

command_background="yes"
pidfile="/var/run/network-svc.pid"
output_log="/var/log/network-svc.log"
error_log="/var/log/network-svc.err"
EOF

echo "'network-svc' 配置完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段四：安装服务 2 (cache-manager / Repocket)
# ------------------------------------------------------------------
echo "--- 阶段四：安装 'cache-manager' ---"
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
# 阶段五：配置服务 2 (cache-manager)
# ------------------------------------------------------------------
echo "--- 阶段五：配置 'cache-manager' ---"
echo "创建 /etc/init.d/cache-manager (服务脚本)..."
cat << 'EOF' > /etc/init.d/cache-manager
#!/sbin/openrc-run

description="System Cache Manager Service (Repocket)"

depend() {
    need net
}

# 这是 Node.js 程序的执行目录
directory="/opt-cache-manager/app"

# 这是 Node.js 程序的启动命令
command="/usr/bin/node"
command_args="dist/index.js -e 'bellesassman4011479@gmail.com' -p '5cd00e75-a7cc-4bb7-bd73-9e58df30e14b'"

command_background="yes"
pidfile="/var/run/cache-manager.pid"
output_log="/var/log/cache-manager.log"
error_log="/var/log/cache-manager.err"
EOF

echo "'cache-manager' 配置完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段六：安装服务 3 (earnfm-svc / EarnFM)
# ------------------------------------------------------------------
echo "--- 阶段六：安装 'earnfm-svc' ---"
echo "创建目录 /opt/earnfm-svc 并进入..."
mkdir -p /opt/earnfm-svc
cd /opt/earnfm-svc

echo "正在使用 crane 拉取和解压 earnfm-client 镜像..."
crane pull earnfm/earnfm-client:latest image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;

echo "清理安装文件..."
rm image.tar *.tar.gz manifest.json
echo "'earnfm-svc' 已安装到 /opt/earnfm-svc/app"
echo ""

# ------------------------------------------------------------------
# 阶段七：配置服务 3 (earnfm-svc)
# ------------------------------------------------------------------
echo "--- 阶段七：配置 'earnfm-svc' ---"
echo "创建 /etc/conf.d/earnfm-svc (用于存放 Token)..."
cat << 'EOF' > /etc/conf.d/earnfm-svc
# 你的 EarnFM Token
export EARNFM_TOKEN="6ead30b9-3fff-4fe2-b358-b0cc8703e10d"
EOF

echo "创建 /etc/init.d/earnfm-svc (服务脚本)..."
cat << 'EOF' > /etc/init.d/earnfm-svc
#!/sbin/openrc-run

description="EarnFM Client Service"

depend() {
    need net
}

# 1. 环境变量从 /etc/conf.d/earnfm-svc 自动加载
# 2. 启动命令 (gcompat 兼容层会自动处理)
command="/opt/earnfm-svc/app/earnfm_example"

command_background="yes"
pidfile="/var/run/earnfm-svc.pid"
output_log="/var/log/earnfm-svc.log"
error_log="/var/log/earnfm-svc.err"
EOF

echo "'earnfm-svc' 配置完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段八：启动所有服务
# ------------------------------------------------------------------
echo "--- 阶段八：启动所有三个服务 ---"

echo "设置所有服务脚本为可执行..."
chmod +x /etc/init.d/network-svc
chmod +x /etc/init.d/cache-manager
chmod +x /etc/init.d/earnfm-svc

echo "添加所有三个服务到开机自启..."
rc-update add network-svc default
rc-update add cache-manager default
rc-update add earnfm-svc default

echo "立即启动所有三个服务..."
rc-service network-svc start
rc-service cache-manager start
rc-service earnfm-svc start

echo ""
echo "--- 🚀 全部完成！ ---"
echo "所有三个服务都已安装并启动。"
echo "你可以使用 'rc-status' 检查状态。"
