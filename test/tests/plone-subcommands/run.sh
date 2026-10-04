#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

# addzopeuser operates on the rendered instance.
out="$(docker run --rm -e PLONE_RENDER=on "$image" addzopeuser testuser secret 2>&1)"
grep -q 'User testuser created' <<<"$out"

# run executes an arbitrary script against the rendered instance.
sdir="$(mktemp -d)"
chmod 755 "$sdir"
cleanup() {
	rm -rf "$sdir" > /dev/null 2>&1 || true
}
trap cleanup EXIT
printf 'print("run-ok")\n' > "$sdir/hello.py"
out="$(docker run --rm -e PLONE_RENDER=on -v "$sdir:/scripts:ro" \
	"$image" run /scripts/hello.py 2>&1)"
grep -q 'run-ok' <<<"$out"
