FROM graygnuorg/pies:2.26-debian
RUN apt-get -qq update && apt-get -qq install curl gnupg2
RUN . /etc/os-release ; \
   mkdir -p --mode=0755 /usr/share/keyrings && \
   curl -sSL -o /usr/share/keyrings/tailscale-archive-keyring.gpg https://pkgs.tailscale.com/stable/debian/$VERSION_CODENAME.noarmor.gpg && \
   curl -sSL -o /etc/apt/sources.list.d/tailscale.list https://pkgs.tailscale.com/stable/debian/$VERSION_CODENAME.tailscale-keyring.list
RUN apt-get -qq update && apt-get -qq install tailscale tailscale-archive-keyring
COPY tailscaled.conf /pies/conf.d

