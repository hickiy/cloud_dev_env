# 使用 NVIDIA CUDA 基础镜像（包含 GPU 支持）
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 设置 locale，VS Code Server 需要
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 创建必要的目录
RUN mkdir -p /run/sshd /var/cache/apt/archives/partial

# 更新包列表并安装必要的软件包
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # SSH 服务
        openssh-server \
        openssh-client \
        # 开发工具
        build-essential \
        ca-certificates \
        curl \
        wget \
        git \
        vim \
        nano \
        # 解压工具
        tar \
        gzip \
        unzip \
        # Shell 和终端
        bash \
        bash-completion \
        # Locale 支持
        locales \
        # 进程管理和监控
        procps \
        htop \
        # 终端复用
        screen \
        tmux \
        # Node.js 运行时与包管理器
        nodejs \
        npm \
        # 其他有用工具
        jq \
        less \
        sudo \
        systemctl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装 uv（Python 包和项目管理器）
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /root/.bashrc

# 配置 locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# 创建 SSH 所需的目录
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# 生成 SSH Host Keys
RUN rm -f /etc/ssh/ssh_host_* && \
    ssh-keygen -A && \
    chmod 600 /etc/ssh/ssh_host_*_key && \
    chmod 644 /etc/ssh/ssh_host_*_key.pub

# 复制 SSH 配置文件
COPY ./sshd_config /etc/ssh/sshd_config
RUN chmod 600 /etc/ssh/sshd_config

# 复制 authorized_keys 到 root 用户
COPY ./authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# 安装 VS Code CLI（使用官方安装脚本）
RUN curl -fsSL https://aka.ms/install-vscode-cli/linux-x64-cli-alpine-tar | tar xzf - -C /usr/local/bin 2>/dev/null || \
    (wget -qO- https://aka.ms/install-vscode-cli/linux-x64-cli-alpine-tar | tar xzf - -C /usr/local/bin) || \
    echo "VS Code CLI 安装跳过（可在容器启动后安装）" && \
    true

# 使用延迟的 VS Code Server 扩展安装（容器运行后执行）
RUN mkdir -p /root/.config/code-server

# 设置环境变量
ENV SHELL=/bin/bash \
    HOME=/root \
    PATH=/root/.cargo/bin:$PATH

# 创建启动脚本
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# 确保 SSH 目录存在' >> /entrypoint.sh && \
    echo 'mkdir -p /run/sshd' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# 生成 SSH host keys（如果不存在）' >> /entrypoint.sh && \
    echo 'if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then' >> /entrypoint.sh && \
    echo '    ssh-keygen -A' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# 启动 SSH 服务' >> /entrypoint.sh && \
    echo 'echo "启动 SSH 服务..."' >> /entrypoint.sh && \
    echo '/usr/sbin/sshd -D -e' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 暴露端口
# SSH 端口
EXPOSE 2224
# VS Code Tunnel 端口（可选，用于本地调试）
EXPOSE 8000-8100

# 创建 yanyun 工作目录
RUN mkdir -p /root/yanyun

# 设置工作目录
WORKDIR /root/yanyun

# 使用启动脚本
ENTRYPOINT ["/entrypoint.sh"]
