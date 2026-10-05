#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# The obsolete /app/var symlink is gone from the ClassicUI image.
docker run --rm --entrypoint sh "$image" -c 'test ! -e /app/var'

PLONE_TEST_SLEEP=3
PLONE_TEST_TRIES=15

site="Plone$RANDOM"
cname="plone-classicui-$RANDOM-$RANDOM"
cid="$(docker run -d --name "$cname" -e SITE=$site "$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

get() {
	docker run --rm -i \
		--link "$cname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://plone:8080/$site"

# The site responds from the rendered instance, and TYPE=classic (the image
# default) drove its creation.
[[ "$(get "http://plone:8080/$site")" == *"Welcome to Plone"* ]]
docker logs "$cid" 2>&1 | grep -q "the classic distribution"

# The render hook did not recreate the removed /app/var directory.
docker exec "$cid" sh -c 'test ! -e /app/var'
