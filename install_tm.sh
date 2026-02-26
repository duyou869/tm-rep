#!/bin/sh
# ------------------------------------------------------------------
# 一键安装 network-svc (Traffmonetizer) 的 Alpine 脚本
# ------------------------------------------------------------------
set -e

echo "--- 阶段一：全局环境准备 ---"
echo "正在更新软件包列表..."
apk update

echo "正在安装所有依赖..."
apk add crane nano libstdc++ libgcc
echo "所有依赖安装完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段二：安装 network-svc
# ------------------------------------------------------------------
echo "--- 阶段二：安装 'network-svc' ---"
rm -rf /opt/network-svc
mkdir -p /opt/network-svc
cd /opt/network-svc

echo "正在使用 crane 拉取和解压 traffmonetizer 镜像..."
crane pull traffmonetizer/cli_v2 image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;

echo "清理安装文件..."
rm -f image.tar *.tar.gz manifest.json sha256:*
chmod +x /opt/network-svc/usr/local/bin/cli
echo "'network-svc' 已安装到 /opt/network-svc/usr/local/bin/cli"
echo ""

# ------------------------------------------------------------------
# 阶段三：配置 network-svc
# ------------------------------------------------------------------
echo "--- 阶段三：配置 'network-svc' ---"

echo "创建 /etc/conf.d/network-svc..."
cat << 'EOF' > /etc/conf.d/network-svc
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
EOF

echo "创建 /etc/init.d/network-svc..."
cat << 'EOF' > /etc/init.d/network-svc
#!/sbin/openrc-run

description="Network Core Service"

depend() {
    need net
}

command="/opt/network-svc/usr/local/bin/cli"
command_args="start accept --token 'yrmSJE4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8='"

command_background="yes"
pidfile="/var/run/network-svc.pid"
output_log="/var/log/network-svc.log"
error_log="/var/log/network-svc.err"
EOF

chmod +x /etc/init.d/network-svc

echo "添加到开机启动..."
rc-update add network-svc default

echo "启动服务..."
rc-service network-svc start

echo ""
echo "--- 安装完成 ---"
echo "查看状态: rc-service network-svc status"
echo "查看日志: cat /var/log/network-svc.log"
echo "查看错误: cat /var/log/network-svc.err"
