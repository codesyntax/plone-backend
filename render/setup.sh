#!/bin/sh
# Install the cookiecutter-zope-instance render tooling into /app/render/venv,
# download the pinned template + transform helper, and run a smoke render so a
# broken template fails the image build.
#
# Usage: setup.sh [OWNER]   (OWNER defaults to 500:500)
set -e

OWNER="${1:-500:500}"

python -m venv /app/render/venv
/app/render/venv/bin/pip install -U pip wheel
/app/render/venv/bin/pip install cookiecutter pyyaml
curl -L --fail -o /app/render/cookiecutter-zope-instance.zip \
    "https://github.com/plone/cookiecutter-zope-instance/archive/refs/tags/${COOKIECUTTER_ZOPE_INSTANCE_VERSION}.zip"
curl -L --fail -o /app/render/transform_from_environment.py \
    "https://raw.githubusercontent.com/plone/cookiecutter-zope-instance/${COOKIECUTTER_ZOPE_INSTANCE_VERSION}/helpers/transform_from_environment.py"

# Smoke-render the baked default so a broken template fails the build.
/app/render/bake.sh /app/render/instance-default.yaml /app/render/smoke-render
test -f /app/render/smoke-render/instance/etc/zope.conf
test -f /app/render/smoke-render/instance/etc/zope.ini
test -f /app/render/smoke-render/instance/etc/site.zcml
test -f /app/render/smoke-render/instance/inituser
rm -rf /app/render/smoke-render

chown -R "$OWNER" /app/render
