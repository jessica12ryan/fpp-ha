# -----------------------------------
# -- FPP Add-on for Home Assistant --
# -----------------------------------
# ----------- Dockerfile ------------
# -----------------------------------
# Builds FPP from source on Debian Trixie (master/10.x branch).
# In-app update checker is disabled — updates are managed via Home Assistant.

FROM debian:trixie

ARG FPPBRANCH=master

# ------------------------------------------------------------------
# APT optimisation & package install
# ------------------------------------------------------------------
# (Mirrors the official FalconChristmas/fpp Dockerfile layout)

RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup

RUN echo '\
    Acquire::http {No-Cache=true;};\
    Acquire::https {No-Cache=true;};\
    Acquire::Retries "32";\
    Acquire::https::Timeout "240";\
    Acquire::http::Timeout "240";\
    APT::Get::Assume-Yes "true";\
    APT::Install-Recommends "false";\
    APT::Install-Suggests "false";\
    Debug::Acquire::https "true";\
    ' > /etc/apt/apt.conf.d/99custom

# Cache buster: invalidates Docker layers when FPP master branch advances
ADD https://api.github.com/repos/FalconChristmas/fpp/git/refs/heads/${FPPBRANCH} /tmp/.fpp-ref

RUN apt-get update && apt-get -yq upgrade

ARG PHPVER="8.4"
ARG PACKAGE_LIST="alsa-utils arping avahi-daemon avahi-utils locales nano net-tools \
    apache2 apache2-bin apache2-data apache2-utils libavahi-client-dev \
    bc bash-completion btrfs-progs exfatprogs lsof ethtool curl zip unzip bzip2 wireless-tools dos2unix \
    fbi fbset file flite ca-certificates lshw gettext wget iproute2 \
    build-essential ffmpeg gcc g++ gdb vim vim-common bison flex device-tree-compiler dh-autoreconf \
    git hdparm i2c-tools jq less sysstat tcpdump time usbutils usb-modeswitch \
    samba rsync sudo shellinabox dnsmasq hostapd vsftpd ntpsec sqlite3 at haveged samba samba-common-bin \
    mp3info exim4 mailutils dhcp-helper parprouted bridge-utils libiio-utils \
    php${PHPVER} php${PHPVER}-cli php${PHPVER}-fpm php${PHPVER}-common php${PHPVER}-curl php-pear \
    php${PHPVER}-bcmath php${PHPVER}-sqlite3 php${PHPVER}-zip php${PHPVER}-xml \
    libtag1-dev \
    vorbis-tools libgraphicsmagick++-dev graphicsmagick-libmagick-dev-compat libdrogon-dev \
    gettext x265 libtheora-dev libvorbis-dev libx265-dev iputils-ping mp3gain \
    libmosquitto-dev mosquitto-clients mosquitto libzstd-dev xz-utils zstd gpiod libgpiod-dev libjsoncpp-dev libcurl4-openssl-dev libnl-3-dev libnl-genl-3-dev \
    fonts-freefont-ttf flex bison pkg-config libasound2-dev libsdl2-dev libsdl3-dev mesa-common-dev qrencode libusb-1.0-0-dev \
    flex bison pkg-config libasound2-dev python3-setuptools libssl-dev libtool bsdextrautils iw rsyslog tzdata ccache libsystemd-dev \
    pipewire pipewire-bin pipewire-alsa pipewire-pulse pipewire-jack pipewire-audio-client-libraries wireplumber \
    libpipewire-0.3-dev libspa-0.2-bluetooth pulseaudio-utils \
    yt-dlp"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PACKAGE_LIST

ARG PACKAGE_LIST_DOCKER=ssh
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PACKAGE_LIST_DOCKER

RUN apt-get clean

# ------------------------------------------------------------------
# Clone FPP from the master branch (full depth so git describe works)
# ------------------------------------------------------------------
ARG FPPBRANCH=master
ENV FPPBRANCH=${FPPBRANCH}

WORKDIR /opt
RUN git clone --branch ${FPPBRANCH} https://github.com/FalconChristmas/fpp.git /opt/fpp

# ------------------------------------------------------------------
# Build FPP using the official install script
# ------------------------------------------------------------------
# Copy to /root so the final cleanup step (archiving the install log)
# can find it (the script does cp /root/FPP_Install.* /home/fpp/).
# --skip-apt-install : packages already installed above
# --skip-clone       : repo already cloned above
RUN cp /opt/fpp/SD/FPP_Install.sh /root/FPP_Install.sh && \
    yes | bash /opt/fpp/SD/FPP_Install.sh --skip-apt-install --skip-clone --branch ${FPPBRANCH}

# ------------------------------------------------------------------
# Container setup & cleanup
# ------------------------------------------------------------------
RUN rm -rf /tmp/*
RUN cp /opt/fpp/etc/asoundrc.plain /root/.asoundrc
RUN echo "docker" > /etc/fpp/container
RUN /opt/fpp/src/fppinit start

# ------------------------------------------------------------------
# Add-on entrypoint
# ------------------------------------------------------------------
COPY run.sh /run.sh
RUN chmod +x /run.sh

VOLUME /home/fpp/media

EXPOSE 80 4048/udp 5568/udp 32320/udp

ENTRYPOINT ["/run.sh"]
