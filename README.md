# Unifi Controller in a Box - Docker Edition

This project has for purpose to run the Unifi Controller inside a Docker
container with the following principles:
- Minimum privilege basis, we expose or need what's required
- Update often, we want security fixes to be includes asap
- Rolling update of the stable Unifi Controller releases

This project container image can be pulled from:
* [Docker Hub](https://hub.docker.com/r/jcberthon/unifi/): e.g. `docker pull jcberthon/unifi:stable`
* [GitLab Registry](https://gitlab.com/huygens/unifi-docker/container_registry): e.g. `docker pull registry.gitlab.com/huygens/unifi-docker/unifi:stable`

## Supported tags and respective `Dockerfile` links
On **Docker Hub**:
* [`latest`, `stable` (Dockerfile)](https://github.com/jcberthon/unifi-docker/blob/master/Dockerfile): currently unifi-5.5 branch
* [`oldstable` (Dockerfile)](https://github.com/jcberthon/unifi-docker/blob/oldstable/Dockerfile): currently unifi-5.4 branch

On **GitLab Container Registry**:
* [`latest`, `stable` (Dockerfile)](https://gitlab.com/huygens/unifi-docker/blob/master/Dockerfile): currently unifi-5.5 branch
* [`oldstable` (Dockerfile)](https://gitlab.com/huygens/unifi-docker/blob/oldstable/Dockerfile): currently unifi-5.4 branch
* And you will find specific versions (as they build), e.g. `5.5.20` or `5.4.19` or etc.

## Description

This is a containerized version of [Ubiquiti Network](https://www.ubnt.com/)'s
Unifi Controller (current stable is version 5.5 branch).

Use `docker run --init --net=host -d jcberthon/unifi`
to run it using your host network stack (you might want to do better than that
see below).

The following options may be of use:

- Set the timezone with `TZ`
- Use volumes to persist application data: the `data` and `log` volumes

Example to test with (or simply use the docker-compose.yml file in the repository)

```console
$ mkdir -p ~/unifi/data
$ mkdir -p ~/unifi/logs
$ docker run --rm --init --cap-drop ALL -e TZ='Europe/Berlin' \
  -p 8080:8080 -p 8443:8443 -p 8843:8843 \
  -v ~/unifi/data:/var/lib/unifi \
  -v ~/unifi/logs:/var/log/unifi \
  --name unifi jcberthon/unifi
```

In this example, we drop all privileges, activate port forwarding and it can run
on a Docker host with user namespaces configured. However, note that in this
configuration you will need to follow the [Unifi Layer 3 methods for adoption and management]
(https://help.ubnt.com/hc/en-us/articles/204909754-UniFi-Layer-3-methods-for-UAP-adoption-and-management).  
I have personally used the DNS and DHCP approach, both works fine.

A similar example but with the easier L2 adoption, we will need to map the UDP
port 10001.

*Note that I expect the following to work but I haven't tested it, simply replace
the last line of the commands given above by:*

```console
$ docker run --rm --init --cap-drop ALL -e TZ='Europe/Berlin' \
  -p 8080:8080 -p 8443:8443 -p 8843:8843 -p 10001:10001/udp \
  -v ~/unifi/data:/var/lib/unifi \
  -v ~/unifi/logs:/var/log/unifi \
  --name unifi jcberthon/unifi
```

You could of course avoid all port mapping and simply use `--net=host`, but by
doing so you give access to the container to your network device(s). If you
run the container as root, it means someone exploiting a future vulnerability
in the Unifi Controller software stack could potentially use that to spy on your
network traffic or worse. So you are removing the isolation layer between your
network stack and your container. It is not bad, it is like if you were running
the Unifi services directly on the host without Docker.

## Volumes:

- `/var/lib/unifi`: Configuration data (e.g. `system.properties`)
- `/var/log/unifi`: Log files (not really needed)

## Environment Variables:

- `TZ`: TimeZone. (i.e "Europe/Berlin")

## Ports used by the Unifi Controller:

The ports which are not exposed by the container image are marked as such. When
not specified, assume the port is exposed.

- `3478/udp`: STUN service (for NAT traversal - WebRTC, SIP, etc.) - I think it is used only when you use the "cloud" part of the controller, then it uses WebRTC to communicate. I don't use that, so I don't map that port and it is working fine.
- `5656-5699/udp`: Used for UPA-EDU (not exposed)
- `6789/tcp`: Speed Test (unifi5 only)
- `8080/tcp`: Device command/control (API)
- `8443/tcp`: Web interface + API
- `8843/tcp`: HTTPS portal (Guest WiFi?)
- `8880/tcp`: HTTP portal (Guest WiFi?)
- `8881/tcp`: do not use (reserved, not exposed)
- `8882/tcp`: do not use (reserved, not exposed)
- `10001/udp`: UBNT Discovery
- `27017/tcp` and 27117/tcp: Local-bound port for DB server (for MongoDB, not exposed)
- `54123/udp`: ???

A container should at least redirect port 8443/tcp and port 8843/tcp (if usage of
guest network is required).

See [UniFi - Ports Used](https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used)

## Container Content

This container is based on the Docker Hub official image for Ubuntu 16.04 LTS (
`FROM ubuntu:16.04`). It is possible to use smaller image from Debian but
Debian 8 has slightly outdated (but up-to-date w.r.t. to security vulnerabilities)
packages compared to Ubuntu 16.04 (notably it is defaulting to Java 7), and as
both are the recommended system by Ubiquiti, we selected Ubuntu.
We did not consider Alpine because of it's use of the musl libc instead of the
GNU libc. The former is not as well tested and I did not want to do extensive
tests of MongoDB and Java 8 based on this C library.

Our approach does not strictly follows Docker best practices with respect to
micro-services and running one process per container. Our container includes
everything the Unifi controller needs, it has notably an embedded MongoDB
database, along the 3 Java processes which makes the controller. Therefore we
needed a very lightweight sort of init system. We actually run the official
init script provided by Ubiquiti. **All services run as a non-privilege user.**

Our solution relies on the Docker-provided `init` daemon (triggered using `--init`)
which orchestrates running the controller as a service. AFAIU The init function also
traps SIGTERM to issue the appropriate stop command to the Unifi controller processes
in the hopes that it helps keep the shutdown graceful.

Example seen within the container after it was started

```console
$ docker exec -t 49b9e24a58f8 ps -e -o pid,ppid,cmd
   PID   PPID CMD
     1      0 /dev/init -- /usr/lib/unifi/bin/unifi.init start
     6      1 /bin/bash /usr/lib/unifi/bin/unifi.init start
    55      6 unifi -home /usr/lib/jvm/java-8-openjdk-amd64 -cp /usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar -p
    56     55 unifi -home /usr/lib/jvm/java-8-openjdk-amd64 -cp /usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar -p
    57     55 unifi -home /usr/lib/jvm/java-8-openjdk-amd64 -cp /usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar -p
    70     57 /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java -Xmx1024M -XX:ErrorFile=/usr/lib/unifi/data/logs/hs_err_pid<pid>.lo
    89     70 bin/mongod --dbpath /usr/lib/unifi/data/db --port 27117 --logappend --logpath logs/mongod.log --nohttpinterface --
   959      0 ps -e -o pid,ppid,cmd
```

## Build and Advanced options/configurations

We provide the `Dockerfile` so of course you can build your own container image.
Example build instructions:

```console
$ docker build -t jcberthon/unifi .
```

Before building your container, you can tweak the file `unifi.default`.

This files contains several parameters which can override the default configuration.
The file contains descriptions of those parameters. But you should be aware that
by changing them you could break the controller (especially if you try to change
the data and log folders, but do not change the volumes of the container).

The possible parameters can be (they are described in the unifi.default file in much details):
* `UNIFI_DATA_DIR`: data folder for Unifi Controller, change with caution
* `UNIFI_LOG_DIR`: log folder for Unifi Controller, change with caution
* `UNIFI_RUN_DIR`: runtime folder for Unifi Controller
* `JAVA_ENTROPY_GATHER_DEVICE`: advanced parameter, most people should not require it
* `JVM_MAX_HEAP_SIZE`: limit the JVM maximum heap size (for home and SOHO, 512M or 1024M is a good value)
* `JVM_INIT_HEAP_SIZE`: minimum JVM heap size (on startup), usually not needed
* `UNIFI_JVM_EXTRA_OPTS`: additional JVM parameters can be added here
* `ENABLE_UNIFI`: boolean ('yes' or 'no') leave it to 'yes' or unset, as you want the Unifi Controller to run
* `JSVC_EXTRA_OPTS`: jsvc(the Java as a service command), this option should contain at least "-nodetach"

## Changelog

This work was based on the original project https://github.com/jacobalberty/unifi-docker.
However, there is little left of the original project and not really chances of
merging. So I've decided to cut the link between the parent project and this one.
Anyway, thank you @jacobalberty for getting me kick started on this.

The first change compare to original fork is that I use the Docker init and the
Unifi Controller init script. So I could remove a lot of unecessary stuff.

In addition, I use the [Debian/Ubuntu APT repository from Unifi](https://help.ubnt.com/hc/en-us/articles/220066768-UniFi-How-to-Install-Update-via-APT-on-Debian-or-Ubuntu)
instead of downloading individual packages, this avoids changing the Dockerfile
for each new release from Unifi. I simply need to rebuild my image. In addition,
Ubiquiti is using "rolling updates" so that by using the "stable" branch you get
always the latest stable release (was 5.4.x when I started, is now 5.5.x at time
of edition)

Finally the last change is about security, I'm dropping every possible privileges,
I can use user namespaces so that the container processes do not run as root,
I'm not binding the container to the host networking but using Docker default
bridge network so that I can control which service I expose on my network, it
works very good using L3 adoption, it should work with L2 adoption if you
expose the port `10001/udp` but I haven't tried it.

Note that with the latest update, you do not need to have user namespaces activated,
I've set-up the Dockerfile so that all services can run as non-root user. So by
default, your container will run non-root improving your security.

A small extra touch, I've added a `HEALTHCHECK` directive in the `Dockerfile`, it
will require you to build the container image with at least Docker 1.12. But it
provides a neat visualisation when querying the container for its state (starting,
healthy, etc.) and can be used by others (e.g. Swarm) for better orchestration.

Example:
```console
$ docker ps
CONTAINER ID        IMAGE                                 CREATED             STATUS                             NAMES
7bb52a751107        jcberthon/unifi-docker/unifi:latest   44 seconds ago      Up 43 seconds (health: starting)   unifi
$ docker ps
CONTAINER ID        IMAGE                                 CREATED             STATUS                   NAMES
7bb52a751107        jcberthon/unifi-docker/unifi:latest   3 minutes ago       Up 3 minutes (healthy)   unifi
```
