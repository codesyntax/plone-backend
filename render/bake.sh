#!/bin/sh
# Render a Zope instance from a cookiecutter config file with the vendored
# cookiecutter-zope-instance template.
#
# Usage: bake.sh CONFIG_FILE OUTPUT_DIR
#   Produces OUTPUT_DIR/instance/etc/{zope.conf,zope.ini,...}
set -e

CONFIG="$1"
OUTDIR="$2"
RENDER_DIR="$(cd "$(dirname "$0")" && pwd)"

"$RENDER_DIR/venv/bin/python" "$RENDER_DIR/transform_from_environment.py" \
    -i "$CONFIG" -o "$RENDER_DIR/bake-from-environment.yaml"
"$RENDER_DIR/venv/bin/cookiecutter" -f --no-input \
    --config-file "$RENDER_DIR/bake-from-environment.yaml" \
    "$RENDER_DIR/cookiecutter-zope-instance.zip" \
    -o "$OUTDIR"
rm -f "$RENDER_DIR/bake-from-environment.yaml"
