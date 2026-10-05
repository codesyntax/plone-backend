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
    dos_protection_form_memory_limit: 99MB
    environment:
        PTS_LANGUAGES: "de en"
    logging_loggers:
        plone: DEBUG
YAML
cnames=()
cleanup() {
	for c in "${cnames[@]}"; do
		docker rm -vf "$c" > /dev/null 2>&1 || true
	done
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
conf="$vname/merge/instance/etc/zope.conf"
grep -q '^threads = 8$' "$ini"
grep -A1 '^\[logger_plone\]' "$ini" | grep -q '^level = DEBUG$'
# The baked logging_loggers and environment keys survive the deep merge.
grep -qE '^\[logger_waitress\]' "$ini"
grep -qE '^[[:space:]]*PTS_LANGUAGES de en$' "$conf"
grep -qE '^[[:space:]]*zope_i18n_compile_mo_files true$' "$conf"

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

# 5. A legacy-derived value overrides the mounted file (legacy sits above mount).
docker run --rm -v "$vname:/data" -v "$ufile:/app/instance.yaml:ro" \
	-e CLIENT_HOME=/data/legacy -e ZOPE_FORM_MEMORY_LIMIT=8MB \
	"$image" render > /dev/null 2>&1
grep -qE '^[[:space:]]*form-memory-limit 8MB$' "$vname/legacy/instance/etc/zope.conf"
# 6. The server boots with a mounted file.
boot() {
	cname="$1"
	cnames+=( "$cname" )
	shift
	docker run -d --name "$cname" "$@" "$image" start > /dev/null
}

check_root() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('http://plone:8080'); print(con.read())"
}

PLONE_TEST_SLEEP=3
PLONE_TEST_TRIES=10

boot "plone-merge-mount-$RANDOM-$RANDOM" \
	-v "$vname:/data" -v "$ufile:/app/instance.yaml:ro" \
	-e CLIENT_HOME=/data/boot-mount
. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" check_root
[[ "$(check_root)" == *"Welcome to Plone!"* ]]
# Free /data's Data.fs before the second boot.
docker rm -vf "$cname" > /dev/null 2>&1 || true

# 7. The server boots with INSTANCE_* overrides (no mounted file).
boot "plone-merge-instance-$RANDOM-$RANDOM" \
	-v "$vname:/data" \
	-e CLIENT_HOME=/data/boot-instance \
	-e INSTANCE_wsgi_listen=0.0.0.0:8080
. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" check_root
[[ "$(check_root)" == *"Welcome to Plone!"* ]]
