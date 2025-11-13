#!/bin/sh
# ------------------------------------------------------------------
# 一键安装network-svc (Traffmonetizer) 和 
# cache-manager (Repocket) 的 Alpine 脚本
# ------------------------------------------------------------------

# 1. 如果任何命令失败，立即停止脚本
set -e

echo "--- 阶段一：全局环境准备 ---"
echo "正在更新软件包列表..."
apk update

echo "正在安装所有依赖 (crane, nano, C++, Node.js)..."
apk add crane nano libstdc++ libgcc nodejs npm
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
cat << EOF > /etc/conf.d/network-svc
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
EOF

echo "创建 /etc/init.d/network-svc (服务脚本)..."
cat << EOF > /etc/init.d/network-svc
#!/sbin/openrc-run

description="Network Core Service"

depend() {
    need net
}

# 这是 C++ 程序的启动方式
command="/opt/network-svc/app/Cli"
command_args="start accept --token 'yrmSJE4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8='"

command_background="yes"
pidfile="/var/run/network-svc.pid"
output_log="/var/log/network-svc.log"
error_log="/var/log/network-svc.err"
EOF

echo "启动服务 1 (network-svc)..."
chmod +x /etc/init.d/network-svc
rc-update add network-svc default
rc-service network-svc start
echo "'network-svc' 已启动。"
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
cat << EOF > /etc/init.d/cache-manager
#!/sbin/openrc-run

description="System Cache Manager Service"

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

echo "启动服务 2 (cache-manager)..."
chmod +x /etc/init.d/cache-manager
rc-update add cache-manager default
rc-service cache-manager start
echo "'cache-manager' 已启动。"
echo ""

# ------------------------------------------------------------------
# 完成
# ------------------------------------------------------------------
echo "--- 🚀 全部完成！ ---"
echo "两个服务都已安装并启动。"
echo "你可以使用以下命令检查状态："
echo "rc-service network-svc status"
echo "rc-service cache-manager status"
echo "cd /"
