#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# The obsolete /app/var symlink is gone from the ClassicUI image.
docker run --rm --entrypoint sh "$image" -c 'test ! -e /app/var'

site="Plone$RANDOM"
cname="plone-classicui-$RANDOM-$RANDOM"
cid="$(docker run -d --name "$cname" -e PLONE_RENDER=on -e SITE=$site "$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

get() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries 15 --sleep 3 get "http://plone:8080/$site"

# A ClassicUI distribution site is served by the rendered instance (TYPE=classic).
[[ "$(get "http://plone:8080/$site")" == *"Welcome to Plone"* ]]
