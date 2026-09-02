# -----------------------------------
# -- FPP Add-on for Home Assistant --
# -----------------------------------
# ----------- Dockerfile ------------
# -----------------------------------
# Dev variant: fpp-ha-dev
# - NOT prebuilt: no `image` in config.yaml, built locally on the
#   Home Assistant host via build.yaml + this Dockerfile.
# - ALWAYS builds the `master` branch of FalconChristmas/fpp;
#   FPP_REF is hardcoded to `master` and is not parameterized by
#   a publish workflow (unlike fpp-ha which is built/pushed for
#   each version tag).
# Two-stage build:
#   stage "build" : compiles FPP on Debian Trixie (FPP git ref is
#                   always `master`) and strips the build toolchain
#                   + *-dev packages that FPP no longer needs at runtime.
#   stage "final" : a clean Debian base that receives the fully-built
#                   runtime filesystem via COPY, so the removed packages
#                   never contribute bytes to the shipped image (a plain
#                   single-stage apt purge would leave their data in
#                   lower layers and not shrink the image).
# In-app update checker is disabled — updates are managed via Home Assistant
# (rebuild the add-on to pick up the latest master).

ARG BUILD_FROM=debian:trixie
FROM $BUILD_FROM AS build

# Dev add-on always tracks master - not overridden by workflow.
ARG FPP_REF=master

# ------------------------------------------------------------------
# APT optimisation & package install
# ------------------------------------------------------------------
# The dependency list is not hardcoded here: it is extracted from the exact
# FPP_Install.sh of the FPP_REF being built, so the packages always match the
# FPP repo instead of drifting out of sync.

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

# curl is not present in the base image but is needed to fetch FPP_Install.sh
RUN apt-get update && apt-get install -yq --no-install-recommends curl ca-certificates

# Fetch the exact FPP_Install.sh for master. It is later run
# with --skip-apt-install, so we install its package list ourselves below.
# Pulling it here keeps the dependency set in lockstep with the FPP repo and
# doubles as a cache buster for the apt layers whenever master changes.
RUN FPPBRANCH="master" && \
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
# Clone FPP from master (full depth so git describe works)
# ------------------------------------------------------------------

# Cache buster: invalidates Docker layers when the FPP remote master ref changes.
RUN FPPBRANCH="master" && \
    curl -sS -o /tmp/.fpp-ref "https://api.github.com/repos/FalconChristmas/fpp/git/refs/heads/${FPPBRANCH}"

WORKDIR /opt
RUN FPPBRANCH="master" && \
    git clone --branch "${FPPBRANCH}" https://github.com/FalconChristmas/fpp.git /opt/fpp

# ------------------------------------------------------------------
# Build FPP using the official install script
# ------------------------------------------------------------------
# Copy to /root so the final cleanup step (archiving the install log)
# can find it (the script does cp /root/FPP_Install.* /home/fpp/).
# --skip-apt-install : packages already installed above
# --skip-clone       : repo already cloned above
RUN cp /opt/fpp/SD/FPP_Install.sh /root/FPP_Install.sh && \
    FPPBRANCH="master" && \
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
# Image shrink: drop the build toolchain and *-dev packages while
# keeping every shared library FPP needs at runtime.
# ------------------------------------------------------------------
# 1. Resolve the runtime .so dependencies of every FPP executable and
#    map them back to their owning packages; mark those manual so
#    autoremove cannot touch them.
# 2. Demote the build toolchain and *-dev packages to auto so they
#    become eligible for removal.
# 3. autoremove --purge everything no longer required.
# 4. Sanity-check that every runtime ELF dependency still resolves.
RUN set -e; \
    PROTECTED_PKGS=$(find /opt/fpp -type f -executable -exec ldd {} \; 2>/dev/null \
        | awk '/=>/ { print $3 } { print $1 }' | grep '^/' | sort -u \
        | while read -r lib; do \
            dpkg-query -S "$(realpath -m "$lib")" 2>/dev/null \
              | sed -n 's/^\(.*\): \/.*$/\1/p' | sed 's/:.*//'; \
          done | sort -u \
        | while read -r pkg; do dpkg-query -W -f='${Package}\n' "$pkg" 2>/dev/null; done | sort -u); \
    echo "PROTECTED_PKGS: $(printf '%s\n' "$PROTECTED_PKGS" | grep -c .) packages"; \
    echo "$PROTECTED_PKGS"; \
    if [ -n "$PROTECTED_PKGS" ]; then apt-mark manual $PROTECTED_PKGS; fi; \
    REMOVABLE=$(dpkg-query -W -f='${Package}\n' | grep -E -- '(-dev$|^gcc$|^gcc-[0-9]+$|^gcc-[a-z]|^g\+\+$|^g\+\+-[0-9]+$|^g\+\+-[a-z]|^cpp$|^cpp-[0-9]+$|^cpp-[a-z]|^make$|^cmake|^binutils|^build-essential$|^pkg-config|^libtool$|^libtool-bin$|^autoconf|^automake|^autopoint|^intltool|^gettext|^debhelper|^dh-|^dpkg-dev|^libc6-dev$|^linux-libc-dev$)' || true); \
    echo "REMOVABLE (dev/toolchain) count: $(printf '%s\n' "$REMOVABLE" | grep -c .)"; \
    if [ -n "$REMOVABLE" ]; then \
        apt-mark auto $REMOVABLE >/dev/null; \
        apt-get purge -yq --auto-remove $REMOVABLE; \
    fi; \
    apt-get autoremove -yq --purge; \
    apt-get clean

RUN MISSING=$(LD_LIBRARY_PATH=/opt/fpp/src find /opt/fpp -type f -executable -exec ldd {} \; 2>/dev/null | grep "not found" | sort -u | head -20); \
    if [ -n "$MISSING" ]; then echo "ERROR: missing shared libraries after shrink"; echo "$MISSING"; exit 1; fi; \
    echo "OK: all runtime shared libraries present"

# ------------------------------------------------------------------
# Final stage: a clean Debian base carrying only the post-shrink
# filesystem, so toolchain/dev data never enters the shipped image.
# ------------------------------------------------------------------
ARG BUILD_FROM=debian:trixie
FROM $BUILD_FROM

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
# rsync is required by run.sh fallback persistence (rsync loop) and must
# survive the toolchain autoremove — install explicitly in final stage.
RUN apt-get update && apt-get install -yq --no-install-recommends dbus rsync && apt-get clean && command -v rsync >/dev/null

# VOLUME removed: HA Supervisor provides persistence via map: data -> /home/fpp/media
# (config.yaml). Declaring VOLUME would create an anonymous volume that can
# shadow the Supervisor mount on local builds.

EXPOSE 80 4048/udp 5568/udp 32320/udp 32322 9000/udp 9000/tcp

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1/api/fppd/status >/dev/null 2>&1 || curl -fsS http://127.0.0.1/ >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/run.sh"]
