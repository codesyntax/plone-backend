#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# Reuse the DEVELOP fixture, which declares a z3c.autoinclude.plugin entry point
# and now ships a configure.zcml with a browser page.
fixture="$dir/../plone-develop/helloworld"

cname="plone-autoinclude-$RANDOM-$RANDOM"
docker run -d --name "$cname" -v "$fixture:/app/src/helloworld" \
	-e DEVELOP="/app/src/helloworld" \
	-e PIP_PARAMS="-q --disable-pip-version-check" \
	-e PLONE_RENDER=on "$image" start > /dev/null
cleanup() {
	docker rm -vf "$cname" > /dev/null 2>&1 || true
}
trap cleanup EXIT

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
