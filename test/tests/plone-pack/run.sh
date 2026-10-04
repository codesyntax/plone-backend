#!/bin/bash
set -eo pipefail

image="$1"

# Direct-storage packing operates on the rendered instance.
docker run --rm -e PLONE_RENDER=on "$image" pack
