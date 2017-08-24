# unifi-docker

## Changelog

The first change compare to original fork is that I use the Docker init and the Unifi Controller init
script. So I could remove a lot of unecessary stuff.

In addition, I use the [Debian/Ubuntu APT repository from Unifi](https://help.ubnt.com/hc/en-us/articles/220066768-UniFi-How-to-Install-Update-via-APT-on-Debian-or-Ubuntu) instead of downloading individual packages,
this avoids changing the Dockerfile for each new release from Unifi. I simply need to rebuild my image. In addition, Ubiquiti is using "rolling updates" so that by using the "stable" branch you get always the latest stable release (was 5.4.x when I started, is now 5.5.x at time of edition)

Finally the last change is about security, I'm dropping every possible privileges, I can user user namespaces
so that the container processes do not run as root, I'm not binding the container to the host networking but
using Docker default bridge network so that I can control which service I expose on my network, but it requires
using L3 adoption (see below).

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

## Description

This is a containerized version of [Ubiquiti Network](https://www.ubnt.com/)'s
Unifi Controller version 5.

Use `docker run --init --net=host -d jcberthon/unifi-docker/unifi`
to run it using your host network stack (you might want to do better than that
see below).

The following options may be of use:

- Set the timezone with `TZ`
- Bind mount the `data` and `log` volumes

Example to test with (or simply use the docker-compose.yml file)

```console
$ mkdir -p ~/unifi/data
$ mkdir -p ~/unifi/logs
$ docker build -t jcberthon/unifi-docker/unifi .
$ docker run --rm --init --cap-drop ALL -p 8080:8080 -p 8443:8443 -p 8843:8843 -e TZ='Europe/Berlin' -v ~/unifi/data:/var/lib/unifi -v ~/unifi/logs:/var/log/unifi --name unifi jcberthon/unifi-docker/unifi
```

In this example, we drop all privileges, activate port forwarding and it can run
on a Docker host with user namespaces configured (so that the container does not
run as root but as a simple user).  However, note that in this configuration you
will need to follow the [Unifi Layer 3 methods for adoption and management]
(https://help.ubnt.com/hc/en-us/articles/204909754-UniFi-Layer-3-methods-for-UAP-adoption-and-management).
I have personnaly used the DNS and DHCP approach, both works fine.

A similar example but with the easier L2 adoption (so we need to use the host
network stack, and if you have user namespaces activated, you need to use the
host user namespace, this means that the container run as root and has access
to the network stack, this could be a security risk.  So make sure to drop as
much privileges as possible).

Note that I expect the following to work but I haven't tested it, simply replace
the last line of the commands given above by:

```console
$ docker run --rm --init --cap-drop ALL --net=host --userns=host  -e TZ='Europe/Berlin' -v ~/unifi/data:/var/lib/unifi -v ~/unifi/logs:/var/log/unifi --name unifi jcberthon/unifi-docker/unifi
```

## Volumes:

- `/var/lib/unifi`: Configuration data
- `/var/log/unifi`: Log files (not really needed)

## Environment Variables:

- `TZ`: TimeZone. (i.e Europe/Berlin)

## Ports used by the Unifi Controller:

The ports which are not exposed by the container image are marked as such. When
not specified, assume the port is exposed.

- 3478/udp: STUN service (for NAT traversal - WebRTC, SIP, etc.)
- 5656-5699/udp: Used for UPA-EDU (not exposed)
- 6789/tcp: Speed Test (unifi5 only)
- 8080/tcp: Device command/control (API)
- 8443/tcp: Web interface + API
- 8843/tcp: HTTPS portal (Guest WiFi?)
- 8880/tcp: HTTP portal (Guest WiFi?)
- 8881/tcp: do not use (reserved, not exposed)
- 8882/tcp: do not use (reserved, not exposed)
- 10001/udp: UBNT Discovery (not exposed)
- 27017/tcp and 27117/tcp: Local-bound port for DB server (for MongoDB, not exposed)
- 54123/udp: ???

A container should at least redirect port 8443/tcp and port 8843/tcp (if usage of
guest network is required).

See [UniFi - Ports Used](https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used)

## Multi-process container

While micro-service patterns try to avoid running multiple processes in a
container, the unifi5 container tries to follow the same process execution model
intended by the original init script, while trying to avoid needing to run a full
init system.

Essentially, it relies on the Docker `init` daemon (triggered using `--init`)
which orchestrates running the controller as a service. AFAIU The init functino also
traps SIGTERM to issue the appropriate stop command to the unifi processes in the
hopes that it helps keep the shutdown graceful.

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

## Advanced options/configurations

Before building your container, you can tweak the file unifi.default.

This files contains several parameters which can override the default configuration. The file contains
descriptions of those parameters. But you should be aware that by changing them you could break the
controller (especially if you try to change the data and log folders, but do not change the volumes
of the container).

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
