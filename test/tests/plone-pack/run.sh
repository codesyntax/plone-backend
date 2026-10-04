#!/bin/bash
set -eo pipefail

# Direct-storage packing operates on the rendered instance.
docker run --rm -e PLONE_RENDER=on "$1" pack
