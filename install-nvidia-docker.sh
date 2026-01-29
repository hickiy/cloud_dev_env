#!/bin/bash
# NVIDIA Container Runtime 一键安装脚本 (CentOS 7)

set -e

echo "==============================================="
echo "NVIDIA Container Runtime 安装脚本"
echo "==============================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 此脚本需要 root 权限运行"
    echo "请使用 'sudo bash install-nvidia-docker.sh' 运行"
    exit 1
fi

# 检查 NVIDIA GPU 驱动
echo "检查 NVIDIA GPU 驱动..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  未找到 nvidia-smi（GPU 驱动未安装）"
    echo ""
    echo "请先安装 NVIDIA GPU 驱动："
    echo "1. 访问 https://www.nvidia.com/Download/driverDetails.aspx"
    echo "2. 下载对应 GPU 的驱动"
    echo "3. 运行: sudo bash NVIDIA-Linux-x86_64-*.run"
    echo ""
    exit 1
fi

echo "✓ NVIDIA GPU 驱动已安装"
nvidia-smi --query-gpu=name --format=csv,noheader | sed 's/^/  GPU: /'
echo ""

# 检查 Docker
echo "检查 Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ 未找到 Docker"
    echo "请先安装 Docker："
    echo "  sudo yum install -y docker"
    echo "  sudo systemctl start docker"
    echo "  sudo systemctl enable docker"
    exit 1
fi

echo "✓ Docker 已安装: $(docker --version)"
echo ""

# 添加 NVIDIA 源
echo "==============================================="
echo "添加 NVIDIA 官方源..."
echo "==============================================="

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
echo "检测到系统: $distribution"
echo ""

echo "下载 NVIDIA Docker 仓库配置..."
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | \
  tee /etc/yum.repos.d/nvidia-docker.repo > /dev/null

echo "✓ 仓库配置已添加"
echo ""

# 更新 YUM 缓存
echo "更新 YUM 缓存..."
yum update -y > /dev/null 2>&1
echo "✓ YUM 缓存已更新"
echo ""

# 安装 NVIDIA Container Toolkit
echo "==============================================="
echo "安装 NVIDIA Container Toolkit..."
echo "==============================================="
echo ""

echo "安装 nvidia-docker2..."
yum install -y nvidia-docker2 > /dev/null 2>&1
echo "✓ nvidia-docker2 已安装"
echo ""

echo "安装 nvidia-container-runtime..."
yum install -y nvidia-container-runtime > /dev/null 2>&1
echo "✓ nvidia-container-runtime 已安装"
echo ""

# 配置 Docker Daemon
echo "==============================================="
echo "配置 Docker Daemon..."
echo "==============================================="
echo ""

# 备份原有配置
if [ -f /etc/docker/daemon.json ]; then
    echo "备份原有配置到 /etc/docker/daemon.json.bak..."
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

echo "更新 daemon.json..."
cat > /etc/docker/daemon.json << 'EOF'
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

echo "✓ daemon.json 已更新"
echo ""

# 重启 Docker
echo "==============================================="
echo "重启 Docker 服务..."
echo "==============================================="
echo ""

echo "重载 systemd 配置..."
systemctl daemon-reload
echo "✓ systemd 配置已重载"
echo ""

echo "重启 Docker..."
systemctl restart docker
echo "✓ Docker 已重启"
echo ""

# 等待 Docker 完全启动
sleep 2

# 验证安装
echo "==============================================="
echo "验证 NVIDIA Container Runtime 安装..."
echo "==============================================="
echo ""

# 检查 nvidia-smi 是否可用
echo "检查本地 nvidia-smi..."
if nvidia-smi &> /dev/null; then
    echo "✓ nvidia-smi 命令可用"
    echo ""
    echo "GPU 信息："
    nvidia-smi
    echo ""
else
    echo "⚠️  nvidia-smi 命令不可用"
    exit 1
fi

# 验证 Docker 运行时配置
echo "验证 Docker 运行时配置..."
if grep -q "nvidia" /etc/docker/daemon.json; then
    echo "✓ Docker daemon.json 已配置 nvidia 运行时"
else
    echo "⚠️  Docker daemon.json 未配置 nvidia 运行时"
    exit 1
fi

echo ""
echo "尝试测试 Docker 中的 NVIDIA 容器支持..."
echo "（需要网络连接下载镜像，首次可能需要较长时间）"
echo ""

# 尝试拉取镜像，设置超时
if timeout 300 docker pull nvidia/cuda:12.4.1-runtime-ubuntu22.04 &> /dev/null; then
    echo "✓ 镜像拉取成功"
    echo ""
    if docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi; then
        echo "✓ Docker 容器中的 GPU 测试成功"
    else
        echo "⚠️  Docker 容器中的 GPU 测试失败"
        echo "   这可能是因为运行时未正确配置"
    fi
else
    echo "⚠️  镜像拉取失败（可能是网络问题）"
    echo ""
    echo "离线验证方法："
    echo "1. 检查 nvidia-smi（本地 GPU 支持）："
    echo "   nvidia-smi"
    echo ""
    echo "2. 检查 Docker 配置："
    echo "   cat /etc/docker/daemon.json"
    echo ""
    echo "3. 检查 Docker 信息："
    echo "   docker info | grep nvidia"
    echo ""
    echo "4. 当网络恢复后，拉取镜像进行测试："
    echo "   docker pull nvidia/cuda:12.4.1-runtime-ubuntu22.04"
    echo "   docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi"
fi

echo ""
echo "==============================================="
echo "✅ NVIDIA Container Runtime 安装完成！"
echo "==============================================="
echo ""
echo "你现在可以在 docker-compose.yml 中使用 GPU："
echo ""
echo "services:"
echo "  your-service:"
echo "    image: nvidia/cuda:12.4.1-runtime-ubuntu22.04"
echo "    runtime: nvidia"
echo "    environment:"
echo "      - NVIDIA_VISIBLE_DEVICES=all"
echo "      - NVIDIA_DRIVER_CAPABILITIES=compute,utility"
echo ""
echo "或直接运行 Docker 容器："
echo "  docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi"
echo ""
