#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

vname="/tmp/plone-create-site-$RANDOM-$RANDOM"
mkdir -p "$vname"
cname="plone-create-site-$RANDOM-$RANDOM"
site="Plone$RANDOM"
cleanup() {
	docker rm -vf "$cname" > /dev/null 2>&1 || true
	if [ -d "$vname" ]; then
		docker run --rm -v "$vname:/data" --entrypoint sh "$image" \
			-c 'rm -rf /data/* /data/.[!.]*' > /dev/null 2>&1 || true
	fi
	rm -rf "$vname" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Create the site with the create-site subcommand on the rendered instance.
docker run --rm -v "$vname:/data" \
	-e CLIENT_HOME=/data/client -e SITE_ID="$site" \
	"$image" create-site

# Then boot the same instance and check the site is reachable.
docker run -d --name "$cname" -v "$vname:/data" \
	-e CLIENT_HOME=/data/client "$image" start > /dev/null

get() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries 15 --sleep 3 get "http://plone:8080/$site"
[[ "$(get "http://plone:8080/$site")" == *"Welcome to Plone"* ]]
