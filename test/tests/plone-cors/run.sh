#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-cors-$RANDOM-$RANDOM"
mkdir -p "$vname"
cleanup() {
	docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
		-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	rm -rf "$vname" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# A CORS_* variable enables CORS and renders the policy into the instance.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/cors \
	-e CORS_ALLOW_ORIGIN="www.example.com" "$image" render > /dev/null 2>&1

cors="$vname/cors/instance/etc/cors.zcml"
test -f "$cors"
grep -q '<plone:CORSPolicy' "$cors"
grep -q 'allow_origin="www.example.com"' "$cors"
grep -q 'allow_credentials="True"' "$cors"
grep -q 'allow_methods="DELETE,GET,OPTIONS,PATCH,POST,PUT"' "$cors"

# Without any CORS_* variable the instance stays CORS-free.
docker run --rm -v "$vname:/data" -e CLIENT_HOME=/data/nocors \
	"$image" render > /dev/null 2>&1
test ! -f "$vname/nocors/instance/etc/cors.zcml"
