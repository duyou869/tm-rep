#!/bin/sh
# ------------------------------------------------------------------
# 一键安装network-svc (Traffmonetizer) 的 Alpine 脚本
# ------------------------------------------------------------------

# 1. 如果任何命令失败，立即停止脚本
set -e

echo "--- 阶段一：全局环境准备 ---"
echo "正在更新软件包列表..."
apk update

echo "正在安装所有依赖 (crane, nano, C++, Node.js)..."
apk add crane nano libstdc++ libgcc 
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
# 完成
# ------------------------------------------------------------------
echo "--- 🚀 全部完成！ ---"
echo "服务已安装并启动。"
echo "你可以使用以下命令检查状态："
echo "rc-service network-svc status"
echo "cd /"
