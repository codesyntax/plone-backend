#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-merge-$RANDOM-$RANDOM"
udir="/tmp/plone-merge-user-$RANDOM-$RANDOM"
mkdir -p "$vname" "$udir"
ufile="$udir/instance.yaml"
cat > "$ufile" <<'YAML'
default_context:
    wsgi_threads: 8
    logging_loggers:
        plone: DEBUG
YAML
cleanup() {
	docker rm -vf "$cname" > /dev/null 2>&1 || true
	if [ -d "$vname" ]; then
		docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
			-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	fi
	rm -rf "$vname" "$udir" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# 1. A sparse mounted file merges over the baked default; dict keys deep-merge.
docker run --rm -v "$vname:/data" -v "$ufile:/app/instance.yaml:ro" \
	-e CLIENT_HOME=/data/merge "$image" render > /dev/null 2>&1
ini="$vname/merge/instance/etc/zope.ini"
grep -q '^threads = 8$' "$ini"
grep -qE '^\[logger_plone\]' "$ini"
grep -A1 '^\[logger_plone\]' "$ini" | grep -q '^level = DEBUG$'
# The baked logging_loggers survive the deep merge.
grep -qE '^\[logger_waitress\]' "$ini"

# 2. An explicit INSTANCE_* value wins over the mounted file.
docker run --rm -v "$vname:/data" -v "$ufile:/app/instance.yaml:ro" \
	-e CLIENT_HOME=/data/override -e INSTANCE_wsgi_threads=16 \
	"$image" render > /dev/null 2>&1
grep -q '^threads = 16$' "$vname/override/instance/etc/zope.ini"

# 3. An explicit empty value overrides to empty (no fallback to the mounted value).
docker run --rm -v "$vname:/data" -v "$ufile:/app/instance.yaml:ro" \
	-e CLIENT_HOME=/data/empty -e INSTANCE_wsgi_threads= \
	"$image" render > /dev/null 2>&1
grep -qE '^threads = *$' "$vname/empty/instance/etc/zope.ini"

# 4. Any template key can be set through INSTANCE_*, not only legacy-mapped ones.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/realm \
	-e INSTANCE_http_realm=Example "$image" render > /dev/null 2>&1
grep -q '^http-realm Example$' "$vname/realm/instance/etc/zope.conf"

# 5. The server boots with a mounted file and an INSTANCE_* override.
PLONE_TEST_SLEEP=3
PLONE_TEST_TRIES=10

cname="plone-merge-$RANDOM-$RANDOM"
docker run -d --name "$cname" -v "$vname:/data" -v "$ufile:/app/instance.yaml:ro" \
	-e CLIENT_HOME=/data/boot -e PLONE_RENDER=on -e INSTANCE_wsgi_threads=6 \
	"$image" start > /dev/null

get() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://plone:8080"
[[ "$(get 'http://plone:8080')" == *"Welcome to Plone!"* ]]
