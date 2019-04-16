#!/usr/bin/env bash

set -euxo pipefail

function bye {
	echo >&2 "$@"
	exit 1
}

if (( $# )); then
	UNIFI_CHANNEL="$1"
	shift
else
  bye "Unifi channel (stable or oldstable or etc.) is mandatory"
fi

if (( $# )); then
  bye "Wrong number of arguments"
fi

curl -sSL "https://www.ubnt.com/downloads/unifi/debian/dists/${UNIFI_CHANNEL}/ubiquiti/binary-${ARG_ARCH:-amd64}/Packages.gz" \
  | zgrep Version | sed -rn 's/Version: ([[:digit:]]+.[[:digit:]]+.[[:digit:]]+)-.*/\1/p'
