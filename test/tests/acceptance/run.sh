#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# A valid baked instance is present, with the acceptance settings.
conf="$(docker run --rm --entrypoint cat "$image" /app/instance/etc/zope.conf)"
grep -q '<filestorage>' <<<"$conf"
ini="$(docker run --rm --entrypoint cat "$image" /app/instance/etc/zope.ini)"
grep -q 'listen = 0.0.0.0:55001' <<<"$ini"
site="$(docker run --rm --entrypoint cat "$image" /app/instance/etc/site.zcml)"
grep -q 'include package="plone.app.contenttypes"' <<<"$site"
grep -q 'include package="plone.volto.cors"' <<<"$site"
docker run --rm --entrypoint sh "$image" \
	-c 'test -f /app/instance/etc/cors.zcml && test ! -e /app/var'

# robot-server starts against the baked instance and serves /ok.
PLONE_TEST_SLEEP=3
PLONE_TEST_TRIES=20

cname="plone-acceptance-$RANDOM-$RANDOM"
cid="$(docker run -d --name "$cname" "$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

get() {
	docker run --rm -i \
		--link "$cname":robot \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://robot:55001/ok"
[[ "$(get 'http://robot:55001/ok')" == *"OK"* ]]
