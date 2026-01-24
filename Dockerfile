FROM debian:latest

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 设置 locale，VS Code Server 需要
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# 创建必要的目录
RUN mkdir -p /run/sshd /var/cache/apt/archives/partial

# 更新包列表并安装必要的软件
# 仅包含 SSH 服务 + VS Code Server 运行时依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # SSH 服务
        openssh-server \
        # VS Code Server 下载和基础工具
        ca-certificates \
        curl \
        git \
        # 解压工具（Local Server Download 必需）
        tar \
        gzip \
        # VS Code Server 启动脚本需要 bash
        bash \
        # locale 支持
        locales \
        # 进程管理
        procps \
        # 终端复用
        screen \
        # Node.js 运行时与包管理器（供构建/脚本使用）
        nodejs \
        npm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装 VS Code CLI（轻量版，无 GUI 依赖）
RUN curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64" -o /tmp/vscode-cli.tar.gz && \
    tar -xzf /tmp/vscode-cli.tar.gz -C /usr/local/bin && \
    rm -f /tmp/vscode-cli.tar.gz && \
    chmod +x /usr/local/bin/code

# 配置 locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# 创建 SSH 所需的目录
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# 生成 SSH Host Keys（先清理再一次生成全部）
RUN rm -f /etc/ssh/ssh_host_* && \
    ssh-keygen -A && \
    chmod 600 /etc/ssh/ssh_host_*_key && \
    chmod 644 /etc/ssh/ssh_host_*_key.pub

# 复制 SSH 配置文件
COPY ./sshd_config /etc/ssh/sshd_config
RUN chmod 600 /etc/ssh/sshd_config

# 复制 authorized_keys（客户端公钥）
COPY ./authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# 设置环境变量
ENV SHELL=/bin/bash

# 暴露 SSH 端口（host 模式下仅作文档说明）
EXPOSE 2224

# 设置工作目录
WORKDIR /root

# 启动 SSH 服务
CMD ["/usr/sbin/sshd", "-D", "-e"]
