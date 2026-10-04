#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-render-$RANDOM-$RANDOM"
vuser="/tmp/plone-render-user-$RANDOM-$RANDOM"
mkdir -p "$vname" "$vuser"
cleanup() {
	docker rm -vf "$cname" > /dev/null 2>&1 || true
	if [ -d "$vname" ]; then
		# The rendered files are owned by the in-image plone user, so clear them
		# from inside a (root) container before removing the host directory.
		docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
			-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	fi
	rm -rf "$vname" "$vuser" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# 1. Render a direct instance at a deterministic client home.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/render-test "$image" render

conf="$vname/render-test/instance/etc/zope.conf"
ini="$vname/render-test/instance/etc/zope.ini"
inituser="$vname/render-test/instance/inituser"

for f in "$conf" "$ini" "$inituser"; do
	if [ ! -f "$f" ]; then
		echo >&2 "missing rendered file: $f"
		exit 1
	fi
done

# Targeted assertions on the generated configuration (no whole-file diffs).
grep -q '%define INSTANCEHOME /data/render-test/instance' "$conf"
grep -q '%define CLIENTHOME /data' "$conf"
grep -q '<filestorage>' "$conf"
grep -q 'path /data/filestorage/Data.fs' "$conf"
grep -q 'blob-dir /data/blobstorage' "$conf"
grep -q 'zope_conf = %(here)s/zope.conf' "$ini"
grep -q '^admin:' "$inituser"

# 2. Rendering must also work as an arbitrary user with only /data writable.
docker run --rm --user="$(id -u)" -v "$vuser:/data" \
	-e CLIENT_HOME=/data/render-test "$image" render
test -f "$vuser/render-test/instance/etc/zope.conf"

# 3. Boot from the rendered instance with the internal switch on.
PLONE_TEST_SLEEP=3
PLONE_TEST_TRIES=10

cname="plone-render-$RANDOM-$RANDOM"
cid="$(docker run -d --name "$cname" -v "$vname:/data" -e CLIENT_HOME=/data/render-test -e PLONE_RENDER=on "$image" start)"

get() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://plone:8080"

# Plone is up and running from the rendered instance.
[[ "$(get 'http://plone:8080')" == *"Welcome to Plone!"* ]]
