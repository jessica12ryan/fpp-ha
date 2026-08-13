# -----------------------------------
# -- FPP Add-on for Home Assistant --
# -----------------------------------
# ----------- Dockerfile ------------
# -----------------------------------
# Builds FPP from source on Debian Trixie (branch/tag set in config.yaml).
# In-app update checker is disabled — updates are managed via Home Assistant.

FROM debian:trixie

COPY config.yaml /tmp/config.yaml

# ------------------------------------------------------------------
# APT optimisation & package install
# ------------------------------------------------------------------
# The dependency list is not hardcoded here: it is extracted from the exact
# FPP_Install.sh of the version being built (set in config.yaml), so the
# packages always match the FPP repo instead of drifting out of sync.

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

RUN apt-get update && apt-get -yq upgrade

ARG PHPVER="8.4"

# Fetch the exact FPP_Install.sh for the FPP ref being built. It is later run
# with --skip-apt-install, so we install its package list ourselves below.
# Pulling it here keeps the dependency set in lockstep with the FPP repo and
# doubles as a cache buster for the apt layers whenever the FPP ref changes.
RUN FPPBRANCH=$(grep '^version:' /tmp/config.yaml | awk '{print $2}' | tr -d '"') && \
    curl -sS -o /tmp/FPP_Install.sh "https://raw.githubusercontent.com/FalconChristmas/fpp/${FPPBRANCH}/SD/FPP_Install.sh"

# Extract the base PACKAGE_LIST from FPP_Install.sh, then add the platform
# extras the script installs on a Debian host (libva-dev smartmontools
# chrony pipewire). The PHP version is injected from the ARG above.
RUN PACKAGE_LIST=$(awk '/^[[:space:]]*PACKAGE_LIST="/{sub(/^[[:space:]]*PACKAGE_LIST="/,"");gsub(/\\/,"");buf=$0;inlist=1;next} inlist{gsub(/\\/,"");buf=buf " " $0} inlist&&/"$/{sub(/"$/,"",buf);print buf;exit}' /tmp/FPP_Install.sh) && \
    PACKAGE_LIST="${PACKAGE_LIST} libva-dev smartmontools chrony pipewire" && \
    PACKAGE_LIST=$(printf '%s' "$PACKAGE_LIST" | sed "s/\${PHPVER}/${PHPVER}/g") && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PACKAGE_LIST

# Packages unique to the docker build
ARG PACKAGE_LIST_DOCKER=ssh
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PACKAGE_LIST_DOCKER

RUN apt-get clean

# ------------------------------------------------------------------
# Clone FPP from the version specified in config.yaml (full depth so git describe works)
# ------------------------------------------------------------------

# Cache buster: invalidates Docker layers when the FPP remote ref changes.
# The FPP 10 official release is tracked as a branch, so check heads first,
# then fall back to tags.
RUN FPPBRANCH=$(grep '^version:' /tmp/config.yaml | awk '{print $2}' | tr -d '"') && \
    STATUS=$(curl -sS -o /tmp/.fpp-ref -w '%{http_code}' "https://api.github.com/repos/FalconChristmas/fpp/git/refs/heads/${FPPBRANCH}") && \
    if [ "$STATUS" != "200" ]; then \
        curl -sS -o /tmp/.fpp-ref "https://api.github.com/repos/FalconChristmas/fpp/git/refs/tags/${FPPBRANCH}"; \
    fi

WORKDIR /opt
RUN FPPBRANCH=$(grep '^version:' /tmp/config.yaml | awk '{print $2}' | tr -d '"') && \
    git clone --branch ${FPPBRANCH} https://github.com/FalconChristmas/fpp.git /opt/fpp

# ------------------------------------------------------------------
# Build FPP using the official install script
# ------------------------------------------------------------------
# Copy to /root so the final cleanup step (archiving the install log)
# can find it (the script does cp /root/FPP_Install.* /home/fpp/).
# --skip-apt-install : packages already installed above
# --skip-clone       : repo already cloned above
RUN cp /opt/fpp/SD/FPP_Install.sh /root/FPP_Install.sh && \
    FPPBRANCH=$(grep '^version:' /tmp/config.yaml | awk '{print $2}' | tr -d '"') && \
    yes | bash /opt/fpp/SD/FPP_Install.sh --skip-apt-install --skip-clone --branch ${FPPBRANCH}

# Install nocc (distributed C++ compiler) from FPP's apt repo, which
# FPP_Install.sh just configured above (under --skip-apt-install it
# defers the actual apt install to us).
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq nocc \
    || echo "WARNING: nocc install skipped (FPP apt repo unreachable)"

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

EXPOSE 80 4048/udp 5568/udp 32320/udp 32322 9000/udp 9000/tcp

ENTRYPOINT ["/run.sh"]
