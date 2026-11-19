# -----------------------------------
# -- FPP Add-on for Home Assistant --
# -----------------------------------
# ----------- Dockerfile ------------
# -----------------------------------
# Two-stage build:
#   stage "build" : compiles FPP on Debian Trixie (FPP git ref set via the
#                   FPP_REF build arg, passed from the build workflow) and
#                   retains the full dependency set installed by FPP_Install.sh
#                   — including all *-dev packages and the build toolchain,
#                   which FPP needs at runtime and which we cannot modify.
#   stage "final" : a clean Debian base that receives the fully-built
#                   runtime filesystem via COPY.
# In-app update checker is disabled — updates are managed via Home Assistant.

FROM debian:trixie AS build

# The FPP git ref (branch or tag) to fetch/build. Passed explicitly from the
# build workflow (build-args: FPP_REF=...) so the image is always built from
# the dispatched ref -- never from a stale config.yaml in the build context.
ARG FPP_REF=master

# ------------------------------------------------------------------
# APT optimisation & package install
# ------------------------------------------------------------------
# The dependency list is not hardcoded here: it is extracted from the exact
# FPP_Install.sh of the FPP_REF being built, so the packages always match the
# FPP repo instead of drifting out of sync.

RUN mkdir -p /etc/dpkg/dpkg.cfg.d && echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup

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

# curl is not present in the base image but is needed to fetch FPP_Install.sh
RUN apt-get update && apt-get install -yq --no-install-recommends curl ca-certificates

# Fetch the exact FPP_Install.sh for the FPP ref being built. It is later run
# with --skip-apt-install, so we install its package list ourselves below.
# Pulling it here keeps the dependency set in lockstep with the FPP repo and
# doubles as a cache buster for the apt layers whenever the FPP ref changes.
RUN FPPBRANCH="${FPP_REF}" && \
    curl -sS -o /tmp/FPP_Install.sh "https://raw.githubusercontent.com/FalconChristmas/fpp/${FPPBRANCH}/SD/FPP_Install.sh"

# Extract the base PACKAGE_LIST from FPP_Install.sh, then add the platform
# extras the script installs on a Debian host (libva-dev smartmontools
# chrony pipewire). The PHP version is injected from the ARG above.
RUN PACKAGE_LIST=$(awk '/^[[:space:]]*PACKAGE_LIST="/{sub(/^[[:space:]]*PACKAGE_LIST="/,"");gsub(/\\/,"");buf=$0;inlist=1;next} inlist{gsub(/\\/,"");buf=buf " " $0} inlist&&/"$/{sub(/"$/,"",buf);print buf;exit}' /tmp/FPP_Install.sh) && \
    test -n "$PACKAGE_LIST" || { echo "ERROR: failed to extract PACKAGE_LIST from FPP_Install.sh" >&2; exit 1; } && \
    PACKAGE_LIST="${PACKAGE_LIST} libva-dev smartmontools chrony pipewire" && \
    PACKAGE_LIST=$(printf '%s' "$PACKAGE_LIST" | sed "s/\${PHPVER}/${PHPVER}/g") && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PACKAGE_LIST

# Packages unique to the docker build
ARG PACKAGE_LIST_DOCKER=ssh
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PACKAGE_LIST_DOCKER

RUN apt-get clean

# ------------------------------------------------------------------
# Clone FPP from the ref specified by the FPP_REF build arg (full depth so
# git describe works)
# ------------------------------------------------------------------

# Cache buster: invalidates Docker layers when the FPP remote ref changes.
# The FPP 10 official release is tracked as a branch, so check heads first,
# then fall back to tags.
RUN FPPBRANCH="${FPP_REF}" && \
    STATUS=$(curl -sS -o /tmp/.fpp-ref -w '%{http_code}' "https://api.github.com/repos/FalconChristmas/fpp/git/refs/heads/${FPPBRANCH}") && \
    if [ "$STATUS" != "200" ]; then \
        curl -sS -o /tmp/.fpp-ref "https://api.github.com/repos/FalconChristmas/fpp/git/refs/tags/${FPPBRANCH}"; \
    fi

WORKDIR /opt
RUN FPPBRANCH="${FPP_REF}" && \
    git clone --branch "${FPPBRANCH}" https://github.com/FalconChristmas/fpp.git /opt/fpp

# ------------------------------------------------------------------
# Build FPP using the official install script
# ------------------------------------------------------------------
# Copy to /root so the final cleanup step (archiving the install log)
# can find it (the script does cp /root/FPP_Install.* /home/fpp/).
# --skip-apt-install : packages already installed above
# --skip-clone       : repo already cloned above
RUN cp /opt/fpp/SD/FPP_Install.sh /root/FPP_Install.sh && \
    FPPBRANCH="${FPP_REF}" && \
    yes | bash /opt/fpp/SD/FPP_Install.sh --skip-apt-install --skip-clone --branch "${FPPBRANCH}"

# Install nocc (distributed C++ compiler) from FPP's apt repo, which
# FPP_Install.sh just configured above (under --skip-apt-install it
# defers the actual apt install to us).
# nocc is optional (distributed compile) — warn but don't fail build if repo unreachable.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq nocc \
    || { echo "WARNING: nocc install skipped (FPP apt repo unreachable) - distributed compile disabled" >&2; true; }

# ------------------------------------------------------------------
# Container setup & cleanup
# ------------------------------------------------------------------
RUN rm -rf /tmp/*
RUN cp /opt/fpp/etc/asoundrc.plain /root/.asoundrc
RUN echo "docker" > /etc/fpp/container
RUN /opt/fpp/src/fppinit start

# ------------------------------------------------------------------
# Dependency retention: FPP needs its full dependency set at runtime,
# including every *-dev package and the build toolchain. Do NOT purge
# any installed packages — only drop apt metadata to save space.
# ------------------------------------------------------------------
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Sanity-check that every runtime ELF dependency still resolves.
RUN MISSING=$(LD_LIBRARY_PATH=/opt/fpp/src find /opt/fpp -type f -executable -exec ldd {} \; 2>/dev/null | grep "not found" | sort -u | head -20); \
    if [ -n "$MISSING" ]; then echo "ERROR: missing runtime shared libraries"; echo "$MISSING"; exit 1; fi; \
    echo "OK: all runtime shared libraries present"

# ------------------------------------------------------------------
# Final stage: a clean Debian base carrying the built FPP filesystem
# (including the full dev/toolchain dependency set).
# ------------------------------------------------------------------
FROM debian:trixie

COPY --from=build / /

# ------------------------------------------------------------------
# Add-on entrypoint
# ------------------------------------------------------------------
COPY run.sh /run.sh
RUN chmod +x /run.sh

# ------------------------------------------------------------------
# Avahi: ensure D-Bus is enabled (default) - FPPs libavahi-client
# talks to avahi-daemon via D-Bus, so run.sh must start dbus-daemon
# before avahi-daemon.  Baked here to undo any prior enable-dbus=no
# and make the requirement explicit.
# ------------------------------------------------------------------
RUN sed -i 's/^#\?enable-dbus=.*/enable-dbus=yes/' /etc/avahi/avahi-daemon.conf && \
    grep -q '^enable-dbus=' /etc/avahi/avahi-daemon.conf || \
    echo 'enable-dbus=yes' >> /etc/avahi/avahi-daemon.conf
# Ensure the D-Bus daemon binary is present even if avahi pulled
# only libdbus (dependency alternative allows dbus-broker).
# rsync is required by run.sh fallback persistence (rsync loop) —
# install explicitly in final stage.
RUN apt-get update && apt-get install -yq --no-install-recommends dbus rsync && apt-get clean && command -v rsync >/dev/null

# VOLUME removed: HA Supervisor provides persistence via map: data -> /home/fpp/media
# (config.yaml). Declaring VOLUME would create an anonymous volume that can
# shadow the Supervisor mount on local builds.

EXPOSE 80 4048/udp 5568/udp 32320/udp 32322 9000/udp 9000/tcp

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1/api/fppd/status >/dev/null 2>&1 || curl -fsS http://127.0.0.1/ >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/run.sh"]
