ARG BASEIMG=ubuntu
ARG BASEVERS=bionic
FROM ${BASEIMG}:${BASEVERS}

ARG ARCH=amd64
ENV ARCH=${ARCH}
ARG DEBIAN_FRONTEND=noninteractive
ENV TINI_VERSION=v0.18.0
ARG MONGODB_VERSION=3.4
ENV MONGODB_VERSION=${MONGODB_VERSION}


# Install Ubiquiti UniFi Controller dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        binutils \
        curl \
        dirmngr \
        gnupg \
        jsvc \
        procps \
    && curl -OL "https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc" \
    && apt-key add server-${MONGODB_VERSION}.asc \
    && echo "deb https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/${MONGODB_VERSION} multiverse" > /etc/apt/sources.list.d/mongodb-org.list \
    && rm -f server-${MONGODB_VERSION}.asc \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        mongodb-org-server \
    && apt-get clean -qy \
    && rm -rf /var/lib/apt/lists/* \
    && curl -L "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${ARCH}" -o /sbin/tini \
    && curl -L "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${ARCH}.asc" -o /sbin/tini.asc \
    && gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
    && gpg --batch --verify /sbin/tini.asc /sbin/tini \
    && rm -f /sbin/tini.asc \
    && chmod 0755 /sbin/tini \
    && curl -OL "https://dl.ui.com/unifi/unifi-repo.gpg" \
    && apt-key add unifi-repo.gpg \
    && rm -f unifi-repo.gpg



# Install Ubiquiti UniFi Controller
ARG UNIFI_CHANNEL=stable
ENV UNIFI_CHANNEL=${UNIFI_CHANNEL}
RUN groupadd -g 750 -o unifi \
    && useradd -u 750 -o -g unifi -M unifi \
    && echo "deb https://www.ubnt.com/downloads/unifi/debian ${UNIFI_CHANNEL} ubiquiti" > /etc/apt/sources.list.d/ubiquiti-unifi.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        unifi \
    && apt-get clean -qy \
    && rm -rf /var/lib/apt/lists/* \
    && find /usr/lib/unifi/dl/firmware -mindepth 1 \! -name bundles.json -delete

EXPOSE 6789/tcp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 3478/udp 10001/udp

COPY unifi.default /etc/default/unifi
COPY unifi.init /usr/lib/unifi/bin/unifi.init

# Enable running Unifi Controller as a standard user
# It requires that we create certain folders and links first
# with the right user ownership and permissions.
RUN mkdir -p -m 755 /var/lib/unifi /var/log/unifi /var/run/unifi /usr/lib/unifi/work \
    && ln -sf /var/lib/unifi /usr/lib/unifi/data \
    && ln -sf /var/log/unifi /usr/lib/unifi/logs \
    && ln -sf /var/run/unifi /usr/lib/unifi/run \
    && chown unifi:unifi /var/lib/unifi /var/log/unifi /var/run/unifi /usr/lib/unifi/work \
    && chmod 755 /usr/lib/unifi/bin/unifi.init
USER unifi

# Add healthcheck (requires Docker 1.12)
HEALTHCHECK --interval=30s --timeout=3s --retries=5 --start-period=30s \
  CMD curl --insecure -f https://localhost:8443/ || exit 1

VOLUME ["/var/lib/unifi", "/var/log/unifi"]

# execute the controller by using the init script and the `init` option of Docker
# Requires to send the TERM signal to all process as JSVC does not know mongod
# was launched by the Unifi application. Therefore mongod was not shutdown
# cleanly.
ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/lib/unifi/bin/unifi.init"]
