# UniFi Controller in a Box - Docker Edition

This project has for purpose to run the UniFi Controller inside a Docker
container with the following principles:
- Minimum privilege basis, we expose or need what's required
- Update often, we want security fixes to be includes asap
- Rolling update of the stable UniFi Controller releases

We have currently the following features to progress towards those goals:
- We drop all capabilities Docker usually grant to a container, no privilege container;
- We run the container as a non-root user;
- We provide instructions so you do not need to use the host network;
- We have weekly rebuild, so the full stack (from base image to UniFi Controller package);
- We provide a `stable` tag, which follow the stable branch of UniFi;
- And of course **it works**!

> **WARNING**: in order to guarantee stability of the UID and GID. We are now
creating a `unifi` dedicated user which will always have the UID 750 and its
main group is also called `unifi` and has GID 750. When updating you will need
to perform a change of ownership on your volumes (`chmod -R 750:750 ...`).  
This feature is compatible with the up-coming UniFi Controller 5.6 which supports
a similar feature.

This project container image can be pulled from:
* [Docker Hub](https://hub.docker.com/r/jcberthon/unifi/): e.g. `docker pull jcberthon/unifi:stable`
* [GitLab Registry](https://gitlab.com/huygens/unifi-docker/container_registry): e.g. `docker pull registry.gitlab.com/huygens/unifi-docker/unifi:stable`

## Supported tags and respective `Dockerfile` links
On **Docker Hub**:
* [`latest`, `stable` (Dockerfile)](https://github.com/jcberthon/unifi-docker/blob/master/Dockerfile): currently unifi-5.5 branch
* [`oldstable` (Dockerfile)](https://github.com/jcberthon/unifi-docker/blob/oldstable/Dockerfile): currently unifi-5.4 branch
* [`testing` (Dockerfile)](https://github.com/jcberthon/unifi-docker/blob/testing/Dockerfile): *experimental* currently unifi-5.6 branch
* You will find specific versions (as they build), e.g. `5.5.24` or `5.4.19` or `5.6.19` or etc.
* And "branched versions" tag such as `5.5`, `5.4` and `5.6` which always point to the latest release within a branch (e.g. the most recent `5.5.x` release).
* "Build" versions per release (e.g. `5.5.24-syyyyyyyy`), on GitHub/DockerHub I'm using the first 8 characters of the SHA1 commit ID. The purpose is when I'm changing my image definition but UniFi Controller release has not changed, I need to distinguish between the previous and newer image although both are `5.5.24` variants. So when a user picks one the "built" image he is sure to get the same image definition.

On **GitLab Container Registry**:
* [`latest`, `stable` (Dockerfile)](https://gitlab.com/huygens/unifi-docker/blob/master/Dockerfile): currently unifi-5.5 branch
* [`oldstable` (Dockerfile)](https://gitlab.com/huygens/unifi-docker/blob/oldstable/Dockerfile): currently unifi-5.4 branch
* [`testing` (Dockerfile)](https://gitlab.com/huygens/unifi-docker/blob/testing/Dockerfile): *experimental* currently unifi-5.6 branch
* You will find specific versions (as they build), e.g. `5.5.24` or `5.4.19` or `5.6.19` or etc.
* And "branched versions" tag such as `5.5`, `5.4` and `5.6` which always point to the latest release within a branch (e.g. the most recent `5.5.x` release).
* "Build" versions per release (e.g. `5.5.24-bxxxx` or `5.5.24-syyyyyyyy`), on GitLab Registry I'm using the Build ID of the CI Pipeline and the first 8 characters of the SHA1 commit ID (see above for details). So for each new build of the same release, you get a different Build ID even if there was no new commit (but the underlying base image could have changed).

My recommendation is to either stick to a "rolling tag" (e.g. `stable`) or to pick one of the build tag (for better repeatability, e.g. `5.5.20-b11594497` or `5.5.20-s4255dc00`).

## Description

This is a containerized version of [Ubiquiti Network](https://www.ubnt.com/)'s
UniFi Controller (current stable is version 5.5 branch).

Use `docker run --net=host -d jcberthon/unifi`
to run it using your host network stack and with default user settings (usually
this is `root` unless you configured user namespaces), but you might want to do
better than that see below.

The following options may be of use:

- Set the timezone with `TZ`
- Use volumes to persist application data: the `data` and `log` volumes

Here are a few examples to test with (or simply use the docker-compose.yml file
in the repository).

> *Note: the following examples set permissions on the volumes so that the
container can run with an **unprivileged user**. This is because the examples are
using bind-mount and therefore you must grant permission to read/write/search
those folders just like if you launched a process as another user which should
access those folders. The example shows that we are setting both user and group
ownership, but of course you full flexibility (only setting user or group,
providing the privileges via the group, using ACLs if your filesystem support
them, etc.)*

```console
$ mkdir -p ~/unifi/data
$ mkdir -p ~/unifi/logs
$ sudo chown 750:750 ~/unifi/data ~/unifi/logs
$ docker run --rm --cap-drop ALL -e TZ='Europe/Berlin' \
  -p 8080:8080 -p 8443:8443 -p 8843:8843 \
  -v ~/unifi/data:/var/lib/unifi \
  -v ~/unifi/logs:/var/log/unifi \
  --name unifi jcberthon/unifi
```

In this example, we drop all privileges, activate port forwarding and it can run
on a Docker host with user namespaces configured. However, note that in this
configuration you will need to follow the [UniFi Layer 3 methods for adoption and management]
(https://help.ubnt.com/hc/en-us/articles/204909754-UniFi-Layer-3-methods-for-UAP-adoption-and-management).  
I have personally used the DNS and DHCP approach, both works fine.

A similar example but with the easier L2 adoption, we will need to map the UDP
port 10001.

> *Note that I expect the following to work but I haven't tested it, simply replace
the last line of the commands given above by:*

```console
$ docker run --rm --cap-drop ALL -e TZ='Europe/Berlin' \
  -p 8080:8080 -p 8443:8443 -p 8843:8843 -p 10001:10001/udp \
  -v ~/unifi/data:/var/lib/unifi \
  -v ~/unifi/logs:/var/log/unifi \
  --name unifi jcberthon/unifi
```

You could of course avoid all port mapping and simply use `--net=host`, but by
doing so you give access to the container to your network device(s). If you
run the container as root, it means someone exploiting a future vulnerability
in the UniFi Controller software stack could potentially use that to spy on your
network traffic or worse. So you are removing the isolation layer between your
network stack and your container. It is not bad, it is like if you were running
the UniFi services directly on the host without Docker. Anyway, by default this
container will run as a non-root user, so you could still use that option and
have limited security risk.

## Volumes:

- `/var/lib/unifi`: Configuration data (e.g. `system.properties`)
- `/var/log/unifi`: Log files (not really needed)

> *Note: UniFi Controller writes also data under the `/var/run/unifi` folder.
I do not expose that folder in the Dockerfile because I do not need it to
persist its data (there is a PID file and a json file with information about
firmware or controller update). But if you think this information should be
persisted (e.g. when you delete and recreate the container), you can just add
the volume mapping even if the Dockerfile does not define it.*

## Environment Variables:

- `TZ`: TimeZone. (i.e "Europe/Berlin")

If you want to set UniFi Controller or JVM environment options, you can add
them as environment data when spawning your container or edit the `unifi.default`
file in the current folder and mount the file as a volume (`/etc/default/unifi`),
if we take the previous examples, that would be:

```console
$ docker run --rm --cap-drop ALL -e TZ='Europe/Berlin' \
  -p 8080:8080 -p 8443:8443 -p 8843:8843 -p 10001:10001/udp \
  -v ~/unifi/data:/var/lib/unifi \
  -v ~/unifi/logs:/var/log/unifi \
  -v unifi.default:/etc/default/unifi:ro \
  --name unifi jcberthon/unifi
```

## Ports used by the UniFi Controller:

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

## Running the container on low-memory devices

Our image is based on Java 8u131 or newer, therefore the JVM is container aware,
it is able to optimise itself to support the CPU and RAM limits set on the
container (based on the CGroups limits). Therefore, the JVM will adapt to the
resource limits you will give the container (e.g. if you use the `--cpus 2.0` or
`--memory 2048m`). Our current approach is that the JVM process could use up to
half of the container allowed max memory, the other half can be used by the MongoDB
database. Not that for a home usage (one AP and one switch), the memory usage of
the container did not exceed 600MB with the current 5.5 branch.

I haven't tried running it on devices with less than 1GB. But on devices with 1GB
of RAM or less, you should make sure that the Java process can allocate up to 512MB
heap. This means, you will need to set the maximum heap size manually to 512.

In addition, it is recommended to limit the memory of the complete container. E.g.
if you have 1GB RAM, limit the memory to 768MB so your system (kernel, etc.) 
always so breathing room. And with this setting, there is still enough memory
for MongoDB.

Example with limits to 768MB memory:

```console
$ docker run --rm --cap-drop ALL \
  -e JVM_MAX_HEAP_SIZE="512m" \
  --memory 768m \
  -p 8080:8080 -p 8443:8443 -p 8843:8843 -p 10001:10001/udp \
  -v ~/unifi/data:/var/lib/unifi \
  -v ~/unifi/logs:/var/log/unifi \
  --name unifi jcberthon/unifi
```

## Container Content

This container is based on the Docker Hub official image for OpenJDK 8 (
`FROM openjdk:8-jre-slim`) which is currently based on Debian 9 Stretch. Ubiquiti
recommends using either Debian or Ubuntu, so that image looks good. The official
Mongo image is based on Debian 7 Wheezy which means using outdated packages and
based on OpenJDK 7 by default. Not an option.  
We did not consider Alpine because of it's use of the musl libc instead of the
GNU libc. The former is not as well tested and I did not want to do extensive
tests of MongoDB and Java 8 based on this C library.

Our approach does not strictly follows Docker best practices with respect to
micro-services and running one process per container. Our container includes
everything the UniFi controller needs, it has notably an embedded MongoDB
database, along the 3 Java processes which makes the controller. Therefore we
needed a very lightweight sort of init system. We actually run the official
init script provided by Ubiquiti which make use of `jsvc` which provides signal
handling and multi-process spawning and watching. **All services can run as a
non-privilege user.**

Our solution originally relied on the Docker-provided `init` daemon (triggered
using `--init`) which provides proper signal handling (catching of SIGTERM, and
"propagation" of signals to childs) and zombie reaping. So the init function
traps SIGTERM to issue the appropriate stop command to the UniFi controller
processes so that they shutdown gracefully. It also prevents zombie to linger
and accumulate. However, this solution relied on Docker 1.13+ which is still
not widely available (many vendors are still only providing Docker 1.12 or older
versions). Therefore, the current solution is to embed a tiny init process, the
same that Docker chose to implement its `init` option: [tini]
(https://github.com/krallin/tini). It offers the signal handlings and zombie
reaping we wanted and it is very tiny (<100KB).

Example seen within the container after it was started

```console
$ docker exec -t 49b9e24a58f8 ps -e -o pid,ppid,cmd
   PID   PPID CMD
     1      0 /sbin/init -- /usr/lib/unifi/bin/unifi.init start
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
* `UNIFI_DATA_DIR`: data folder for UniFi Controller, change with caution
* `UNIFI_LOG_DIR`: log folder for UniFi Controller, change with caution
* `UNIFI_RUN_DIR`: runtime folder for UniFi Controller
* `JAVA_ENTROPY_GATHER_DEVICE`: advanced parameter, most people should not require it
* `JVM_MAX_HEAP_SIZE`: limit the JVM maximum heap size (for home and SOHO, 512M or 1024M is a good value)
* `JVM_INIT_HEAP_SIZE`: minimum JVM heap size (on startup), usually not needed
* `UNIFI_JVM_EXTRA_OPTS`: additional JVM parameters can be added here
* `ENABLE_UNIFI`: boolean ('yes' or 'no') leave it to 'yes' or unset, as you want the UniFi Controller to run
* `JSVC_EXTRA_OPTS`: jsvc(the Java as a service command), this option should contain at least "-nodetach"

## Changelog

This work was based on the original project https://github.com/jacobalberty/unifi-docker.
However, there is little left of the original project and not really chances of
merging. So I've decided to cut the link between the parent project and this one.
Anyway, thank you @jacobalberty for getting me kick started on this.

The first change compare to original fork is that I use `tini` init process and
the UniFi Controller init script. So I could remove a lot of unecessary stuff.

In addition, I use the [Debian/Ubuntu APT repository from UniFi](https://help.ubnt.com/hc/en-us/articles/220066768-UniFi-How-to-Install-Update-via-APT-on-Debian-or-Ubuntu)
instead of downloading individual packages, this avoids changing the Dockerfile
for each new release from UniFi. I simply need to rebuild my image. In addition,
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
I've set-up the Dockerfile so that all services can run as non-root user and I have
set a default user (non-root). So you do not need to add special instructions,
when you spawn your container, it will run as non-root user. You still need to
specify proper permissions on the bind-mounted folder (UID should be 750 and GID
should be 750) in order for the processes to have the rights to read or modify
data. If you use Docker named volumes (the provided `docker-compose.yml` does
that by default, or you can create them using the `docker volume create ...`
command), you do not need to specify permissions, Docker will do that to you (at
least with the `local` driver, the default one).  
*Note: If you really want to run as root, you can simply add `--user root` to the
`docker run` command (or `user: root` inside the compose file).*

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
