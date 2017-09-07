FROM openjdk:8-jre-slim

ARG DEBIAN_FRONTEND=noninteractive

# Install Ubiquiti UniFi Controller dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        dirmngr \
        gnupg \
        binutils \
        jsvc \
        mongodb-server \
    && apt-get clean -qy \
    && rm -rf /var/lib/apt/lists/*

# Import GPG key
RUN apt-key adv  \
    --keyserver hkp://keyserver.ubuntu.com \
    --recv 4A228B2D358A5094178285BE06E85760C0A52C50


# Install Ubiquiti UniFi Controller
RUN echo "deb https://www.ubnt.com/downloads/unifi/debian stable ubiquiti" > /etc/apt/sources.list.d/ubiquiti-unifi.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        unifi \
    && apt-get clean -qy \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 750 -o unifi \
    && useradd -u 750 -o -g unifi -M unifi \
    && chgrp -R unifi /usr/lib/unifi \
    && chmod g+sw /usr/lib/unifi \
    && rm -Rf /usr/lib/unifi/dl/* \
    && chmod -R g+sw /usr/lib/unifi/dl

EXPOSE 6789/tcp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 3478/udp 10001/udp

COPY unifi.default /etc/default/unifi

# Enable running Unifi Controller as a standard user
# It requires that we create certain folders and links first
# with the right user ownership and permissions.
RUN mkdir -p -m 775 /var/lib/unifi /var/log/unifi /var/run/unifi && \
    ln -sf /var/lib/unifi /usr/lib/unifi/data && \
    ln -sf /var/log/unifi /usr/lib/unifi/logs && \
    ln -sf /var/run/unifi /usr/lib/unifi/run && \
    chown root:unifi /var/lib/unifi /var/log/unifi /var/run/unifi
USER unifi

# Add healthcheck (requires Docker 1.12)
HEALTHCHECK --interval=30s --timeout=3s --retries=5 --start-period=30s \
  CMD curl --insecure -f https://localhost:8443/ || exit 1

VOLUME ["/var/lib/unifi", "/var/log/unifi"]

# execute the controller by using the init script and the `init` option of Docker
ENTRYPOINT ["/usr/lib/unifi/bin/unifi.init"]
CMD ["start"]
