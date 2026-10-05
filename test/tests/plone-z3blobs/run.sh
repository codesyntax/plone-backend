#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-z3blobs-$RANDOM-$RANDOM"
mkdir -p "$vname"
cleanup() {
	docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
		-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	rm -rf "$vname" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# z3blobs wraps direct storage in an S3 blob store.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/z3 \
	-e INSTANCE_db_z3blobs_enabled=true \
	-e INSTANCE_db_z3blobs_bucket_name=mybucket \
	-e INSTANCE_db_z3blobs_cache_dir=/data/s3cache \
	"$image" render > /dev/null 2>&1
conf="$vname/z3/instance/etc/zope.conf"
grep -q '%import zodb_s3blobs' "$conf"
grep -q '<s3blobstorage>' "$conf"
grep -q 'bucket-name mybucket' "$conf"
grep -q 'cache-dir /data/s3cache' "$conf"
# The wrapped backend's blob settings are suppressed.
if grep -q 'blob-dir' "$conf"; then
	echo >&2 "z3blobs did not suppress the wrapped blob settings"
	exit 1
fi

# Invalid combinations and missing requirements are rejected with a clear error.
expect_error() {
	local needle="$1"
	shift
	local out
	if out="$(docker run --rm -v "$vname:/data" "$@" "$image" render 2>&1)"; then
		echo >&2 "expected an error, but render succeeded"
		exit 1
	fi
	if ! grep -q "$needle" <<<"$out"; then
		echo >&2 "missing error message: $needle"
		echo "$out" >&2
		exit 1
	fi
}

expect_error "requires 'db_pgjsonb_dsn'" \
	-e CLIENT_HOME=/data/e1 -e INSTANCE_db_storage=pgjsonb
expect_error "cannot be used with 'pgjsonb'" \
	-e CLIENT_HOME=/data/e2 -e INSTANCE_db_storage=pgjsonb \
	-e INSTANCE_db_pgjsonb_dsn=postgresql://x \
	-e INSTANCE_db_z3blobs_enabled=true \
	-e INSTANCE_db_z3blobs_bucket_name=b \
	-e INSTANCE_db_z3blobs_cache_dir=/data/c
expect_error "requires 'db_z3blobs_bucket_name'" \
	-e CLIENT_HOME=/data/e3 -e INSTANCE_db_z3blobs_enabled=true
expect_error "requires 'db_z3blobs_cache_dir'" \
	-e CLIENT_HOME=/data/e4 -e INSTANCE_db_z3blobs_enabled=true \
	-e INSTANCE_db_z3blobs_bucket_name=b
