#!/usr/bin/env bash

# Usage:
#   unifi-publi.sh [-c channel] [-e extra_tags] [-g git_commit] [-t tag_name] repository
#
# Example:
#   unifi-publi.sh -c stable -e latest docker.io/jcberthon/unifi

set -euxo pipefail

function bye {
	echo >&2 "$@"
	exit 1
}


opt_channel=0; channel=stable
opt_extratag=0
opt_tag=0
opt_commit=0

while getopts c:e:g:t: opt
do
	case $opt in
	c) opt_channel=1; channel=$OPTARG ;;
  e) opt_extratag=1; extratag=$OPTARG ;;
  g) opt_commit=1; commit=$OPTARG ;;
	t) opt_tag=1; tag=$OPTARG ;;
	?) bye "Option not understood" ;;
	esac
done
shift $(( $OPTIND - 1 ))
if (( $# )); then
	repo_name=$1
	shift
else
  bye "Repository name mandatory"
fi

if (( $# )); then
  bye "Wrong number of arguments"
fi

(( ! opt_tag )) && tag=${channel}

# Push default tag
docker push "${repo_name}:${tag}"

# Push full version (e.g. 5.10.21)
VERSION_UNIFI="$(./scripts/ci-get-unifi-version.sh ${channel})"
docker push "${repo_name}:${VERSION_UNIFI}"

# Push major.minor version (e.g. 5.10)
VERSION_UNIFI_BRANCH="$(echo ${VERSION_UNIFI} | cut -d. -f-2)"
docker push "${repo_name}:${VERSION_UNIFI_BRANCH}"

# Push full version + short commit ID if possible
if (( opt_commit )); then
  short_commit="$(echo ${commit} | cut -b-8)"
  docker push "${repo_name}:${VERSION_UNIFI}-s${short_commit}"
fi

# Push extra tag
if (( opt_extratag )); then
  docker push "${repo_name}:${extratag}"
fi
