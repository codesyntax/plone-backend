#!/bin/bash
set -eo pipefail

image="$1"

# Direct-storage packing operates on the rendered instance.
docker run --rm "$image" pack
