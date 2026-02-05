FROM graygnuorg/pies:2.27-debian
RUN apt-get -qq update && apt-get -qq install curl gnupg2
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
ARG BUILD_DEPS="libssl-dev vim procps"
RUN apt-get -qq update && \
    apt-get -qq install \
      pound m4 micron bind9-dnsutils direvent rsync xxd liblockfile-bin \
      netcat-traditional liblua5.3-dev\
      luarocks lua-socket lua-dkjson lua-redis \
      ${BUILD_DEPS}
RUN luarocks --lua-version=5.3 install base64
RUN luarocks --lua-version=5.3 install md5
RUN luarocks --lua-version=5.3 install openssl
COPY direvent.conf /etc
COPY pies/*.conf /pies/conf.d/
COPY pound /etc
RUN mkdir -p /etc/rc.d /etc/pound/conf.d \
	     /var/lib/pound/.well-known/acme-challenge \
	     /proxycam
COPY rc.d/rc.* /etc/rc.d/
COPY bacme /proxycam
COPY certupdate /proxycam
COPY certupdate.crontab /etc/cron.d/certupdate
VOLUME [ "/etc/ssl/acme" ]
