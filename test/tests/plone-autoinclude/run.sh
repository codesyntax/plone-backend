#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# Reuse the DEVELOP fixture, which declares a z3c.autoinclude.plugin entry point
# and ships a configure.zcml with a browser page. Install it via ADDONS (not
# DEVELOP) to prove that an ADDONS-installed add-on's ZCML is registered.
src="$dir/../plone-develop/helloworld"
sdir="$(mktemp -d)"
chmod 755 "$sdir"
cp -r "$src" "$sdir/helloworld"

cname="plone-autoinclude-$RANDOM-$RANDOM"
cleanup() {
	docker rm -vf "$cname" > /dev/null 2>&1 || true
	rm -rf "$sdir" > /dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "$cname" -v "$sdir/helloworld:/app/src/helloworld" \
	-e ADDONS="/app/src/helloworld" \
	-e PIP_PARAMS="-q --disable-pip-version-check --no-build-isolation" \
	"$image" start > /dev/null

get() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

# The add-on's ZCML is registered via autoinclude (five:loadProducts) on the
# rendered path, so its browser page is reachable.
. "$dir/../../retry.sh" --tries 10 --sleep 3 get "http://plone:8080/@@helloworld"
[[ "$(get 'http://plone:8080/@@helloworld')" == *"Hello World ZCML!"* ]]
