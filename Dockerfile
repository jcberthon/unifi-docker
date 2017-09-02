FROM ubuntu:16.04

ARG DEBIAN_FRONTEND=noninteractive

# Import GPG key
RUN apt-key adv  \
    --keyserver hkp://keyserver.ubuntu.com \
    --recv 4A228B2D358A5094178285BE06E85760C0A52C50

# Install Ubiquiti UniFi Controller
# I do not use the `--no-install-recommends`, because it has currently the following
# weird effects:
# - it install 77 packages instead of 87 without the flag BUT that's 397 MB of
#   downloads instead of 242MB respectively, so we end up with a bigger install (+200MB image)
# - it selects openjdk-9-jre-headless (Java 9), instead of openjdk-8-jre-headless
#   without the flag
# Ubiquiti recommends Java 8, so I do not use the flag.
RUN apt-get update && \
    apt-get install -y apt-transport-https && \
    echo "deb https://www.ubnt.com/downloads/unifi/debian stable ubiquiti" > /etc/apt/sources.list.d/ubiquiti-unifi.list && \
    apt-get update && \
    apt-get install -y curl unifi && \
    apt-get clean -qy && \
    rm -rf /var/lib/apt/lists/* && \
    chgrp -R mongodb /usr/lib/unifi && \
    chmod g+sw /usr/lib/unifi && \
    rm -Rf /usr/lib/unifi/dl/* && \
    chmod -R g+sw /usr/lib/unifi/dl

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
USER mongodb

VOLUME ["/var/lib/unifi", "/var/log/unifi"]

# Add healthcheck (requires Docker 1.12)
HEALTHCHECK --interval=30s --timeout=3s --retries=5 --start-period=30s \
  CMD curl --insecure -f https://localhost:8443/ || exit 1

# execute the controller by using the init script and the `init` option of Docker
ENTRYPOINT ["/usr/lib/unifi/bin/unifi.init"]
CMD ["start"]
