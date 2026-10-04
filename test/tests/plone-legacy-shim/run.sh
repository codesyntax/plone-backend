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
