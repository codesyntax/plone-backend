#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

PLONE_TEST_SLEEP=10
PLONE_TEST_TRIES=10

# Start Postgres
zname="pgjsonb-container-$RANDOM-$RANDOM"
zid="$(docker run -d --name "$zname" -e POSTGRES_USER=plone -e POSTGRES_PASSWORD=plone -e POSTGRES_DB=plone postgres:14-alpine)"

# Start Plone with PGJsonb storage (INSTANCE_* only, no legacy variables)
pname="plone-pgjsonb-$RANDOM-$RANDOM"
pid="$(docker run -d --name "$pname" --link=$zname:db \
	-e INSTANCE_db_storage=pgjsonb \
	-e INSTANCE_db_pgjsonb_dsn="postgresql://plone:plone@db:5432/plone" \
	"$image")"

# Tear down
trap "docker rm -vf $pid $zid > /dev/null" EXIT

get() {
	docker run --rm -i \
		--link "$pname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://plone:8080"

# Plone is up and running from the pgjsonb storage
[[ "$(get 'http://plone:8080')" == *"Welcome to Plone!"* ]]

# The pgjsonb storage created its tables in PostgreSQL.
docker exec "$zname" psql -U plone -d plone -tAc \
	"select to_regclass('public.object_state')" | grep -q 'object_state'
