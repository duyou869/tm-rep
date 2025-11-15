#!/bin/sh
#
# =============================================================
# “四合一”最终脚本 (v2 - 带自动重启)
#
# 安装服务:
# 1. network-svc  (Traffmonetizer)
# 2. cache-manager (Repocket)
# 3. earnfm-svc    (EarnFM)
# 4. psclient-svc  (PacketStream)
#
# 解决了所有依赖、兼容性问题，并添加了崩溃后自动重启。
# =============================================================

# 1. 如果任何命令失败，立即停止脚本
set -e

echo "--- 阶段一：全局环境准备 ---"
echo "正在更新软件包列表..."
apk update

echo "正在安装所有依赖 (crane, nano, C++, Node.js, gcompat)..."
# - network-svc/earnfm-svc/psclient-svc 需要: crane, libstdc++, libgcc
# - cache-manager 需要: crane, nodejs, npm
# - earnfm-svc/psclient-svc (glibc程序) 额外需要: gcompat
apk add crane nano libstdc++ libgcc nodejs npm gcompat

echo "所有依赖安装完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段二：安装服务 1 (network-svc / Traffmonetizer)
# ------------------------------------------------------------------
echo "--- 阶段二：安装 'network-svc' ---"
mkdir -p /opt/network-svc
cd /opt/network-svc
echo "正在拉取和解压 traffmonetizer..."
crane pull traffmonetizer/cli_v2 image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;
rm image.tar *.tar.gz manifest.json
echo "'network-svc' 已安装。"
echo ""

# ------------------------------------------------------------------
# 阶段三：配置服务 1 (network-svc)
# ------------------------------------------------------------------
echo "--- 阶段三：配置 'network-svc' ---"
cat << 'EOF' > /etc/conf.d/network-svc
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
EOF

cat << 'EOF' > /etc/init.d/network-svc
#!/sbin/openrc-run
description="Network Core Service (Traffmonetizer)"

# 添加 supervisor 实现崩溃后自动重启
supervisor="supervise-daemon"

depend() { 
    need net 
}
command="/opt/network-svc/app/Cli"
command_args="start accept --token 'yrmSJO4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8='"

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
mkdir -p /opt-cache-manager
cd /opt-cache-manager
echo "正在拉取和解压 repocket..."
crane pull repocket/repocket image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;
rm image.tar *.tar.gz manifest.json
echo "'cache-manager' 已安装。"
echo ""

# ------------------------------------------------------------------
# 阶段五：配置服务 2 (cache-manager)
# ------------------------------------------------------------------
echo "--- 阶段五：配置 'cache-manager' ---"
cat << 'EOF' > /etc/init.d/cache-manager
#!/sbin/openrc-run
description="System Cache Manager Service (Repocket)"

# 添加 supervisor 实现崩溃后自动重启
supervisor="supervise-daemon"

depend() { 
    need net 
}
directory="/opt-cache-manager/app"
command="/usr/bin/node"
command_args="dist/index.js -e 'bellesassman4011479@gmail.com' -p '5cd00e75-a7cc-4bb7-bd73-9e58df30e14b'"

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
mkdir -p /opt/earnfm-svc
cd /opt/earnfm-svc
echo "正在拉取和解压 earnfm-client..."
crane pull earnfm/earnfm-client:latest image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;
rm image.tar *.tar.gz manifest.json
echo "'earnfm-svc' 已安装。"
echo ""

# ------------------------------------------------------------------
# 阶段七：配置服务 3 (earnfm-svc)
# ------------------------------------------------------------------
echo "--- 阶段七：配置 'earnfm-svc' ---"
cat << 'EOF' > /etc/conf.d/earnfm-svc
export EARNFM_TOKEN="6ead30b9-3fff-4fe2-b358-b0cc8703e10d"
EOF

cat << 'EOF' > /etc/init.d/earnfm-svc
#!/sbin/openrc-run
description="EarnFM Client Service"

# 添加 supervisor 实现崩溃后自动重启
supervisor="supervise-daemon"

depend() { 
    need net 
}
command="/opt/earnfm-svc/app/earnfm_example"

pidfile="/var/run/earnfm-svc.pid"
output_log="/var/log/earnfm-svc.log"
error_log="/var/log/earnfm-svc.err"
EOF
echo "'earnfm-svc' 配置完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段八：安装服务 4 (psclient-svc / PacketStream)
# ------------------------------------------------------------------
echo "--- 阶段八：安装 'psclient-svc' ---"
mkdir -p /opt/psclient-svc
cd /opt/psclient-svc
echo "正在拉取和解压 psclient..."
crane pull packetstream/psclient:latest image.tar
tar -xvf image.tar
find . -name "*.tar.gz" -exec tar -xvf {} \;
rm image.tar *.tar.gz manifest.json
echo "'psclient-svc' 已安装。"
echo ""

# ------------------------------------------------------------------
# 阶段九：配置服务 4 (psclient-svc)
# ------------------------------------------------------------------
echo "--- 阶段九：配置 'psclient-svc' ---"
cat << 'EOF' > /etc/conf.d/psclient-svc
export CID="7d2K"
export PS_IS_DOCKER="true"
EOF

cat << 'EOF' > /etc/init.d/psclient-svc
#!/sbin/openrc-run
description="PacketStream Client Service"

# 添加 supervisor 实现崩溃后自动重启
supervisor="supervise-daemon"

depend() { 
    need net 
}
# 我们绕过了 pslauncher, 直接运行 amd64 程序
command="/opt/psclient-svc/usr/local/bin/linux_amd64/psclient"

pidfile="/var/run/psclient-svc.pid"
output_log="/var/log/psclient-svc.log"
error_log="/var/log/psclient-svc.err"
EOF
echo "'psclient-svc' 配置完毕。"
echo ""

# ------------------------------------------------------------------
# 阶段十：启动所有服务
# ------------------------------------------------------------------
echo "--- 阶段十：启动所有四个服务 ---"

echo "设置所有服务脚本为可执行..."
chmod +x /etc/init.d/network-svc
chmod +x /etc/init.d/cache-manager
chmod +x /etc/init.d/earnfm-svc
chmod +x /etc/init.d/psclient-svc

echo "添加所有四个服务到开机自启..."
rc-update add network-svc default
rc-update add cache-manager default
rc-update add earnfm-svc default
rc-update add psclient-svc default

echo "立即启动所有四个服务 (将由 supervisor 接管)..."
rc-service network-svc start
rc-service cache-manager start
rc-service earnfm-svc start
rc-service psclient-svc start

echo ""
echo "--- 🚀 全部完成！ ---"
echo "所有四个服务都已安装并启动 (带自动重启)。"
echo ""
echo "--- 状态检查 ---"
echo "你可以使用 'rc-status' 检查所有服务状态。"
echo ""
echo "--- 实时日志检查 (按 Ctrl+C 退出) ---"
echo "1. network-svc:  tail -f /var/log/network-svc.log"
echo "2. cache-manager: tail -f /var/log/cache-manager.log"
echo "3. earnfm-svc:    tail -f /var/log/earnfm-svc.log"
echo "4. psclient-svc:  tail -f /var/log/psclient-svc.log"
echo ""
echo "--- 错误日志检查 (如果崩溃) ---"
echo "1. network-svc:  cat /var/log/network-svc.err"
echo "2. cache-manager: cat /var/log/cache-manager.err"
echo "3. earnfm-svc:    cat /var/log/earnfm-svc.err"
echo "4. psclient-svc:  cat /var/log/psclient-svc.err"
