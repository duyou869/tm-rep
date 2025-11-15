#!/bin/bash
# 这是一个完整的脚本，用于安装Podman并运行两个服务

echo "--- 步骤 1/5: 更新软件源并安装 Podman ---"
apt update
apt install -y podman

# 确保安装成功
if ! command -v podman &> /dev/null
then
    echo "Podman 安装失败，请检查错误。"
    exit 1
fi

echo "--- 步骤 2/5: 运行 traffmonetizer (tm) 容器 ---"
# 注意：我为你添加了 --restart=always，这对于 systemd 自动生成重启策略很重要
podman run -d --name tm --restart=always \
  docker.io/traffmonetizer/cli_v2 \
  start accept --token yrmSJE4O8GpjywUb/IzzRgOQl+NVBrYWS9jCee5L8L8=

echo "--- 步骤 3/5: 运行 repocket 容器 ---"
podman run -d --name repocket \
  -e RP_EMAIL=bellesassman4011479@gmail.com \
  -e RP_API_KEY=5cd00e75-a7cc-4bb7-bd73-9e58df30e14b \
  --restart=always \
  docker.io/repocket/repocket

echo "--- 步骤 4/5: 生成 Systemd 服务文件 ---"
# 为 tm 生成服务
podman generate systemd --name tm --new -f > /etc/systemd/system/podman-tm.service

# 为 repocket 生成服务
podman generate systemd --name repocket --new -f > /etc/systemd/system/podman-repocket.service

echo "--- 步骤 5/5: 重新加载 Systemd 并启用开机自启 ---"
systemctl daemon-reload

# 启用 (Enable) 这两个服务
systemctl enable podman-tm.service
systemctl enable podman-repocket.service

echo "---"
echo "✅ 全部完成！"
echo "---"
echo "Podman 已安装，tm 和 repocket 容器已在运行。"
echo "这两个容器均已设置为开机自启。"
echo "---"
echo "你可以使用以下命令检查它们的状态："
echo "systemctl status podman-tm.service"
echo "systemctl status podman-repocket.service"
echo "---"
echo "你也可以使用 podman logs 查看日志："
echo "podman logs tm"
echo "podman logs repocket"
