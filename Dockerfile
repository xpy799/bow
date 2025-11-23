# 基础镜像
FROM ubuntu:24.04

# 作者信息
LABEL maintainer="xiong <255874474@qq.com>"
LABEL description="Ubuntu 24.04 Cinnamon Desktop with NoMachine, noVNC, ToDesk, WeChat (基础版)"

# 环境变量配置
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=desktopuser
ENV PASSWORD=desktop@123
ENV DISPLAY=:1
ENV VNCPORT=5901
ENV NOVNCPORT=6080

# 1. 安装基础依赖与systemd
RUN apt update && apt install -y \
    systemd dbus policykit-1 apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common \
    sudo wget unzip locales && \
    # 配置中文locale
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8 && \
    # 修复systemd在容器中的运行问题
    mkdir -p /run/systemd && echo 'docker' > /run/systemd/container && \
    # 清理缓存
    apt clean && rm -rf /var/lib/apt/lists/*

# 2. 安装Cinnamon桌面环境（Windows风格）
RUN add-apt-repository universe && apt update && \
    apt install -y cinnamon-desktop-environment lightdm network-manager-gnome && \
    # 桌面美化：Windows 10主题+图标+光标
    wget https://github.com/B00merang-Project/Windows-10/releases/download/2024.01/Windows-10.tar.xz -O /tmp/Windows-10.tar.xz && \
    mkdir -p /usr/share/themes/Windows-10 && tar -xf /tmp/Windows-10.tar.xz -C /usr/share/themes/Windows-10 && \
    wget https://github.com/yeyushengfan258/Windows-10-Icon-Theme/archive/refs/tags/v1.2.tar.gz -O /tmp/Windows-10-Icon.tar.gz && \
    mkdir -p /usr/share/icons/Windows-10 && tar -xf /tmp/Windows-10-Icon.tar.gz -C /usr/share/icons/Windows-10 --strip-components=1 && \
    wget https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz -O /tmp/Bibata.tar.xz && \
    mkdir -p /usr/share/icons/Bibata && tar -xf /tmp/Bibata.tar.xz -C /usr/share/icons/Bibata && \
    # 清理临时文件
    rm -rf /tmp/* && apt clean && rm -rf /var/lib/apt/lists/*

# 3. 安装NoMachine（远程桌面）
RUN wget https://download.nomachine.com/download/8.12/Linux/nomachine_8.12.3_1_amd64.deb -O /tmp/nomachine.deb && \
    dpkg -i /tmp/nomachine.deb || apt install -y -f && \
    rm -rf /tmp/nomachine.deb && apt clean && rm -rf /var/lib/apt/lists/*

# 4. 安装noVNC + TigerVNC（网页访问）
RUN apt update && apt install -y tigervnc-standalone-server tigervnc-common websockify && \
    wget https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/noVNC.tar.gz && \
    tar -xf /tmp/noVNC.tar.gz -C /opt && mv /opt/noVNC-1.4.0 /opt/noVNC && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    # 配置VNC密码
    mkdir -p /home/$USER/.vnc && echo "$PASSWORD" | vncpasswd -f > /home/$USER/.vnc/passwd && \
    chmod 600 /home/$USER/.vnc/passwd && \
    rm -rf /tmp/* && apt clean && rm -rf /var/lib/apt/lists/*

# 5. 安装ToDesk
RUN wget https://dl.todesk.com/linux/todesk_4.7.1.0_amd64.deb -O /tmp/todesk.deb && \
    dpkg -i /tmp/todesk.deb || apt install -y -f && \
    rm -rf /tmp/todesk.deb && apt clean && rm -rf /var/lib/apt/lists/*

# 6. 安装微信（deepin-wine适配版）
RUN wget -O- https://deepin-wine.i-m.dev/setup.sh | sh && \
    apt update && apt install -y com.qq.weixin && \
    apt clean && rm -rf /var/lib/apt/lists/*

# 7. 创建普通用户并配置权限
RUN useradd -m $USER -s /bin/bash && \
    echo "$USER:$PASSWORD" | chpasswd && \
    usermod -aG sudo $USER && \
    # 设置用户桌面配置
    mkdir -p /home/$USER/.config/cinnamon && \
    echo '[Desktop]\nTheme=Windows-10\nIconTheme=Windows-10\nCursorTheme=Bibata-Modern-Classic' > /home/$USER/.config/cinnamon/cinnamon-settings.ini && \
    chown -R $USER:$USER /home/$USER

# 8. 配置systemd服务自启
RUN mkdir -p /etc/systemd/system/vncserver.service && \
    echo "[Unit]\nDescription=TigerVNC Server\nAfter=display-manager.service\n\n[Service]\nUser=$USER\nExecStart=/usr/bin/vncserver $DISPLAY -geometry 1920x1080 -depth 24\nExecStop=/usr/bin/vncserver -kill $DISPLAY\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/vncserver.service && \
    mkdir -p /etc/systemd/system/novnc.service && \
    echo "[Unit]\nDescription=noVNC Server\nAfter=vncserver.service\n\n[Service]\nUser=$USER\nExecStart=/usr/bin/websockify --web /opt/noVNC $NOVNCPORT localhost:$VNCPORT\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/novnc.service && \
    # 启用服务
    systemctl enable lightdm nomachine vncserver novnc todesk

# 暴露端口
EXPOSE 4000 5901 6080

# 设置systemd为入口
CMD ["/sbin/init"]