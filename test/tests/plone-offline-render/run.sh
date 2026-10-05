#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-offline-$RANDOM-$RANDOM"
mkdir -p "$vname"
cleanup() {
	docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
		-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	rm -rf "$vname" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# With no network the render must still succeed from the vendored template and
# local venv: the rendered instance needs no network at container start.
docker run --rm --network none -v "$vname:/data" \
	-e CLIENT_HOME=/data/offline "$image" render

conf="$vname/offline/instance/etc/zope.conf"
test -f "$conf"
grep -q '<filestorage>' "$conf"
