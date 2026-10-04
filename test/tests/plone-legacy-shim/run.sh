#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-legacy-shim-$RANDOM-$RANDOM"
mkdir -p "$vname"
cleanup() {
	docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
		-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	rm -rf "$vname" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# A pure direct render must not warn about legacy variables.
direct_out="$(docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/direct \
	"$image" render 2>&1)"
if grep -q 'DEPRECATION' <<<"$direct_out"; then
	echo >&2 "unexpected deprecation warning for a direct render:"
	echo "$direct_out" >&2
	exit 1
fi

# Legacy RelStorage variables are translated and warned about.
relstorage_out="$(docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/relstorage \
	-e RELSTORAGE_DSN="dbname='plone' user='plone' host='db' password='plone'" \
	"$image" render 2>&1)"
grep -q 'DEPRECATION' <<<"$relstorage_out"
grep -q 'RELSTORAGE_DSN' <<<"$relstorage_out"
conf="$vname/relstorage/instance/etc/zope.conf"
grep -q '<relstorage>' "$conf"
grep -q "dsn dbname='plone'" "$conf"
# RELSTORAGE_SHARED_BLOB_DIR defaults to false, i.e. the cache blob mode.
grep -q 'shared-blob-dir false' "$conf"

# Behaviour, path and listen-port variables render into the instance.
behaviour_out="$(docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/behaviour \
	-e DEBUG_MODE=on -e VERBOSE_SECURITY=off \
	-e ZOPE_FORM_MEMORY_LIMIT=8MB -e ZODB_CACHE_SIZE=1234 \
	-e COMPILE_MO_FILES=false -e LISTEN_PORT=8081 \
	"$image" render 2>&1)"
bconf="$vname/behaviour/instance/etc/zope.conf"
bini="$vname/behaviour/instance/etc/zope.ini"
grep -q 'debug-mode on' "$bconf"
grep -q 'form-memory-limit 8MB' "$bconf"
grep -q 'cache-size 1234' "$bconf"
grep -qi 'zope_i18n_compile_mo_files false' "$bconf"
grep -q '%define CLIENTHOME /data/behaviour' "$bconf"
grep -q 'listen = 0.0.0.0:8081' "$bini"
grep -q 'ZOPE_FORM_MEMORY_LIMIT' <<<"$behaviour_out"
grep -q 'LISTEN_PORT' <<<"$behaviour_out"

# ZEO with a shared blob dir inverts onto db_blob_mode: shared.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/zeo \
	-e ZEO_ADDRESS=zeo:8100 -e ZEO_SHARED_BLOB_DIR=on \
	"$image" render > /dev/null 2>&1
zeo_conf="$vname/zeo/instance/etc/zope.conf"
grep -q '<zeoclient>' "$zeo_conf"
grep -q 'server zeo:8100' "$zeo_conf"
grep -q 'shared-blob-dir true' "$zeo_conf"

# An explicit INSTANCE_db_storage wins over a legacy backend variable.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/explicit \
	-e INSTANCE_db_storage=direct -e RELSTORAGE_DSN="dbname='x'" \
	"$image" render > /dev/null 2>&1
explicit_conf="$vname/explicit/instance/etc/zope.conf"
grep -q '<filestorage>' "$explicit_conf"
if grep -q '<relstorage>' "$explicit_conf"; then
	echo >&2 "INSTANCE_db_storage=direct did not win over RELSTORAGE_DSN"
	exit 1
fi
