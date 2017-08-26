#!/bin/sh

set -eu

UNIFI_CHANNEL="$1"

curl -sSL "http://www.ubnt.com/downloads/unifi/debian/dists/${UNIFI_CHANNEL}/ubiquiti/binary-armhf/Packages.gz" \
  | zgrep Version | sed -rn 's/Version: ([[:digit:]].[[:digit:]].[[:digit:]]+)-.*/\1/p'
