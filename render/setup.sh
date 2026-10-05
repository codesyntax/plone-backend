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

cd /app/render
./venv/bin/python transform_from_environment.py \
    -i /app/render/instance-default.yaml \
    -o /app/render/instance-from-environment.yaml
./venv/bin/cookiecutter -f --no-input \
    --config-file /app/render/instance-from-environment.yaml \
    /app/render/cookiecutter-zope-instance.zip \
    -o /app/render/smoke-render
test -f /app/render/smoke-render/instance/etc/zope.conf
test -f /app/render/smoke-render/instance/etc/zope.ini
test -f /app/render/smoke-render/instance/etc/site.zcml
test -f /app/render/smoke-render/instance/inituser
rm -rf /app/render/smoke-render /app/render/instance-from-environment.yaml

chown -R "$OWNER" /app/render
