#!/bin/bash
set -e
export VENVBIN=/app/bin

if [ -z "${PIP_PARAMS}" ]; then
  PIP_PARAMS=""
fi

if [ -z "${CLIENT_HOME}" ]; then
  CLIENT_HOME="/data/$(hostname)/$(hostid)"
  export CLIENT_HOME=$CLIENT_HOME
fi

USER="$(id -u)"

# Create directories to be used by Plone
mkdir -p /data/filestorage /data/blobstorage /data/cache /data/log $CLIENT_HOME
if [ "$USER" = '0' ]; then
  find /data -not -user plone -exec chown plone:plone {} \+
  sudo="gosu plone"
else
  sudo=""
fi

# Handle ADDONS installation
if [[ -n "${ADDONS}" ]]; then
  echo "======================================================================================="
  echo "Installing ADDONS ${ADDONS}"
  echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
  echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
  echo "======================================================================================="
  $VENVBIN/pip install ${ADDONS} ${PIP_PARAMS}
fi

# Handle development addons
if [[ -v DEVELOP ]]; then
  echo "======================================================================================="
  echo "Installing DEVELOPment addons ${DEVELOP}"
  echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
  echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
  echo "======================================================================================="
  PACKAGES=""
  while read -ra DEVADDONS; do
    for a in "${DEVADDONS[@]}"; do
      PACKAGES+=" --editable ${a}"
    done
  done <<< "$DEVELOP"
  $VENVBIN/pip install ${PACKAGES} ${PIP_PARAMS}
fi

# Render a complete Zope instance for this container.
#
# Pipeline:
#   1. merge the baked default instance.yaml with an optional user-mounted
#      /app/instance.yaml (deep-merged for dict keys);
#   2. translate the legacy environment onto INSTANCE_* (legacy shim);
#   3. overlay INSTANCE_* environment variables (vendored transform);
#   4. render with cookiecutter into $CLIENT_HOME/instance.
render_instance() {
  $sudo /app/render/venv/bin/python /app/render/merge_instance.py \
    /app/render/instance-default.yaml \
    /app/instance.yaml \
    "$CLIENT_HOME/instance-merged.yaml"
  $sudo /app/render/venv/bin/python /app/render/legacy_from_environment.py \
    > "$CLIENT_HOME/instance-legacy-env.sh"
  . "$CLIENT_HOME/instance-legacy-env.sh"
  $sudo /app/render/venv/bin/python \
    /app/render/transform_from_environment.py \
    -i "$CLIENT_HOME/instance-merged.yaml" \
    -o "$CLIENT_HOME/instance-from-environment.yaml"
  # HOME must be writable: cookiecutter caches under $HOME/.cookiecutters, and an
  # arbitrary --user has HOME=/ (unwritable) with only /data writable.
  $sudo env HOME="$CLIENT_HOME" /app/render/venv/bin/cookiecutter -f --no-input \
    --config-file "$CLIENT_HOME/instance-from-environment.yaml" \
    /app/render/cookiecutter-zope-instance.zip \
    -o "$CLIENT_HOME"
  RENDERED_ETC="$CLIENT_HOME/instance/etc"
}

site_banner() {
  echo "======================================================================================="
  echo "Creating Plone ${TYPE} SITE: ${SITE}"
  echo "Aditional profiles: ${PROFILES}"
  echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
  echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
  echo "======================================================================================="
}

if [[ "$1" == "start" ]]; then
  render_instance
  if [[ -v SITE ]]; then
    export TYPE=${TYPE:-volto}
    export SITE_ID=${SITE}
    site_banner
    $sudo $VENVBIN/zconsole run "$RENDERED_ETC/zope.conf" /app/scripts/create_site.py
  fi
  echo "Starting Zope from the rendered instance in $CLIENT_HOME/instance"
  exec $sudo $VENVBIN/runwsgi -v "$RENDERED_ETC/zope.ini"
elif [[ "$1" == "create-classic" || "$1" == "create-volto" || "$1" == "create-site" ]]; then
  case "$1" in
    create-classic) export TYPE=classic ;;
    create-volto) export TYPE=volto ;;
    create-site) export TYPE=${TYPE:-volto} ;;
  esac
  render_instance
  exec $sudo $VENVBIN/zconsole run "$RENDERED_ETC/zope.conf" /app/scripts/create_site.py
elif [[ "$1" == "console" ]]; then
  render_instance
  exec $sudo $VENVBIN/zconsole debug "$RENDERED_ETC/zope.conf"
elif [[ "$1" == "run" ]]; then
  render_instance
  exec $sudo $VENVBIN/zconsole run "$RENDERED_ETC/zope.conf" "${@:2}"
elif [[ "$1" == "addzopeuser" ]]; then
  render_instance
  exec $sudo $VENVBIN/addzopeuser -c "$RENDERED_ETC/zope.conf" "${@:2}"
elif [[ "$1" == "pack" ]]; then
  render_instance
  case "${INSTANCE_db_storage:-direct}" in
    zeo)
      exec $sudo $VENVBIN/zeopack "${@:2}" "${ZEO_ADDRESS:-$INSTANCE_db_zeo_server}"
      ;;
    relstorage)
      exec $sudo $VENVBIN/zodbpack "${@:2}" "$RENDERED_ETC/relstorage-pack.conf"
      ;;
    *)
      exec $sudo $VENVBIN/zconsole run "$RENDERED_ETC/zope.conf" /app/scripts/pack.py
      ;;
  esac
elif [[ "$1" == "render" ]]; then
  render_instance
  exit 0
else
  # Custom
  exec "$@"
fi
