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
RUN apt-get -qq update && apt-get -qq install tailscale tailscale-archive-keyring pound
COPY pies/*.conf /pies/conf.d/
COPY pound /etc/

