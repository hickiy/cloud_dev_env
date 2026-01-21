FROM debian:latest

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 创建必要的目录
RUN mkdir -p /run/sshd /var/cache/apt/archives/partial

# 更新包列表并安装必要的软件
RUN apt-get update && \
    apt-get install -y \
        openssh-server \
        iputils-ping \
        screen \
        git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

# 暴露 SSH 端口
EXPOSE 22

# 启动 SSH 服务
CMD ["/usr/sbin/sshd", "-D"]
