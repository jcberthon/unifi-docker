FROM ubuntu:16.04

ARG DEBIAN_FRONTEND=noninteractive

# Making sure we have the latest update of all packages
RUN apt-get update && \
    apt-get full-upgrade -y && \
    apt-get clean -qy && \
    rm -rf /var/lib/apt/lists/*

# Import GPG key
RUN apt-key adv  \
    --keyserver hkp://keyserver.ubuntu.com \
    --recv 4A228B2D358A5094178285BE06E85760C0A52C50

# Install Ubiquiti UniFi Controller
RUN echo "deb http://www.ubnt.com/downloads/unifi/debian oldstable ubiquiti" > /etc/apt/sources.list.d/ubiquiti-unifi.list && \
    apt-get update && \
    apt-get install -y curl unifi && \
    apt-get clean -qy && \
    rm -rf /var/lib/apt/lists/* && \
    chgrp -R mongodb /usr/lib/unifi && \
    chmod g+sw /usr/lib/unifi && \
    rm -Rf /usr/lib/unifi/dl/* && \
    chmod g+sw /usr/lib/unifi/dl

VOLUME ["/var/lib/unifi", "/var/log/unifi"]

EXPOSE 6789/tcp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 3478/udp 10001/udp

COPY unifi.default /etc/default/unifi

# Enable running Unifi Controller as a standard user
# It requires that we create certain folders and links first
# with the right user ownership and permissions.
RUN mkdir -p -m 775 /var/lib/unifi /var/log/unifi /var/run/unifi && \
    ln -sf /var/lib/unifi /usr/lib/unifi/data && \
    ln -sf /var/log/unifi /usr/lib/unifi/logs && \
    ln -sf /var/run/unifi /usr/lib/unifi/run && \
    chown root:mongodb /var/lib/unifi /var/log/unifi /var/run/unifi
# USER mongodb

# Add healthcheck (requires Docker 1.12)
HEALTHCHECK --interval=2m --timeout=3s \
  CMD curl --insecure -f https://localhost:8443/ || exit 1

# execute the controller by using the init script and the `init` option of Docker
ENTRYPOINT ["/usr/lib/unifi/bin/unifi.init"]
CMD ["start"]
