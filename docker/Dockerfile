FROM graygnuorg/pies:2.26-debian
RUN apt-get -qq update && apt-get -qq install curl gnupg2
RUN . /etc/os-release ; \
   mkdir -p --mode=0755 /usr/share/keyrings && \
   curl -sSL -o /usr/share/keyrings/tailscale-archive-keyring.gpg https://pkgs.tailscale.com/stable/debian/$VERSION_CODENAME.noarmor.gpg && \
   curl -sSL -o /etc/apt/sources.list.d/tailscale.list https://pkgs.tailscale.com/stable/debian/$VERSION_CODENAME.tailscale-keyring.list
RUN gpg --keyserver keyserver.ubuntu.com \
        --recv-keys 79FFD94BFCE230B1 && \
    gpg --output=/etc/apt/keyrings/norsedigital.gpg --export 79FFD94BFCE230B1
RUN . /etc/os-release ; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/norsedigital.gpg] https://${ID}.archive.norse.digital ${VERSION_CODENAME} main" > "/etc/apt/sources.list.d/norse.list"

# Notes regarding lua installation on Debian 12:
# 1. lua-redis does not exist for lua 5.4, neither can it be installed via
#    luarocks. Hence, lua5.3 has to be used.
# 2. There is no lua-md5 module for 5.3, hence it is installed from rocks.
# 3. luaossl for 5.3 is botched, so openssl is installed from rocks.
ARG BUILD_DEPS=libssl-dev
RUN apt-get -qq update && \
    apt-get -qq install \
      tailscale tailscale-archive-keyring pound \
      netcat-traditional liblua5.3-dev\
      luarocks lua-socket lua-dkjson lua-redis \
      ${BUILD_DEPS}
RUN luarocks --lua-version=5.3 install base64
RUN luarocks --lua-version=5.3 install md5
RUN luarocks --lua-version=5.3 install openssl
COPY pies/*.conf /pies/conf.d/
COPY pound /etc
COPY rc.pound /etc/
RUN chmod +x /etc/rc.pound
# A hack nexessary until
# https://api.dev.alotta.aws.norse.digital/.well-known/jwks.json works again.
COPY jwks.json /tmp
