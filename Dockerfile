FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive \
  container=docker

# Making sure we have the latest update of all packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean -qy && \
    rm -rf /var/lib/apt/lists/*

# Import GPG key
RUN apt-key adv  \
    --keyserver hkp://keyserver.ubuntu.com \
    --recv 4A228B2D358A5094178285BE06E85760C0A52C50

# Install Ubiquiti UniFi Controller
RUN echo "deb http://www.ubnt.com/downloads/unifi/debian stable ubiquiti" > /etc/apt/sources.list.d/ubiquiti-unifi.list && \
    apt-get update && \
    apt-get install -y unifi && \
    mkdir -p /usr/lib/unifi/run && \
    apt-get clean -qy && \
    rm -rf /var/lib/apt/lists/*


VOLUME ['/var/lib/unifi', 'var/log/unifi']

#EXPOSE 6789/tcp 8080/tcp 8081/tcp 8443/tcp 8843/tcp 8880/tcp 3478/udp
EXPOSE 6789/tcp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 3478/udp

COPY unifi.default /etc/default/unifi

# Add healthcheck (requires Docker 1.12)
HEALTHCHECK --interval=5m --timeout=3s --start-period=1m \
  CMD curl --insecure -f https://localhost:8443/ || exit 1

# execute the controller by using the init script and the `init` option of Docker
ENTRYPOINT ["/usr/lib/unifi/bin/unifi.init"]
CMD ["start"]
