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

# Internal, temporary switch selecting the rendered configuration path instead
# of the legacy skeleton path. Removed once the migration is complete (ticket 10).
render_enabled=""
case "${PLONE_RENDER:-}" in
  1|true|True|TRUE|yes|Yes|YES|on|On|ON) render_enabled=1 ;;
esac

# Legacy environment defaults. These feed the skeleton configuration path; on
# the rendered path (PLONE_RENDER) the legacy shim fills the backend defaults
# and the baked instance.yaml covers the rest, so that the shim only ever warns
# about variables the operator actually set.
if [[ -z "$render_enabled" ]]; then
  # MAIN ENV Vars
  [ -z ${SECURITY_POLICY_IMPLEMENTATION+x} ] && export SECURITY_POLICY_IMPLEMENTATION=C
  [ -z ${VERBOSE_SECURITY+x} ] && export VERBOSE_SECURITY=off
  [ -z ${DEFAULT_ZPUBLISHER_ENCODING+x} ] && export DEFAULT_ZPUBLISHER_ENCODING=utf-8
  [ -z ${COMPILE_MO_FILES+x} ] && export COMPILE_MO_FILES=true
  [ -z ${DEBUG_MODE+x} ] && export DEBUG_MODE=off
  [ -z ${ZOPE_FORM_MEMORY_LIMIT+x} ] && export ZOPE_FORM_MEMORY_LIMIT=4MB
  [ -z ${ZOPE_FORM_DISK_LIMIT+x} ] && export ZOPE_FORM_DISK_LIMIT=1GB
  [ -z ${ZOPE_FORM_MEMFILE_LIMIT+x} ] && export ZOPE_FORM_MEMFILE_LIMIT=4KB


  # ZODB ENV Vars
  [ -z ${ZODB_CACHE_SIZE+x} ] && export ZODB_CACHE_SIZE=50000
fi

if [[ -v RELSTORAGE_DSN ]]; then
  MSG="Using Relstorage configuration"
  CONF=relstorage.conf
  if [[ -z "$render_enabled" ]]; then
    # Relstorage ENV Vars
    [ -z ${RELSTORAGE_NAME+x} ] && export RELSTORAGE_NAME=storage
    [ -z ${RELSTORAGE_READ_ONLY+x} ] && export RELSTORAGE_READ_ONLY=off
    [ -z ${RELSTORAGE_KEEP_HISTORY+x} ] && export RELSTORAGE_KEEP_HISTORY=true
    [ -z ${RELSTORAGE_COMMIT_LOCK_TIMEOUT+x} ] && export RELSTORAGE_COMMIT_LOCK_TIMEOUT=30
    [ -z ${RELSTORAGE_CREATE_SCHEMA+x} ] && export RELSTORAGE_CREATE_SCHEMA=true
    [ -z ${RELSTORAGE_SHARED_BLOB_DIR+x} ] && export RELSTORAGE_SHARED_BLOB_DIR=false
    [ -z ${RELSTORAGE_BLOB_CACHE_SIZE+x} ] && export RELSTORAGE_BLOB_CACHE_SIZE=100mb
    [ -z ${RELSTORAGE_BLOB_CACHE_SIZE_CHECK+x} ] && export RELSTORAGE_BLOB_CACHE_SIZE_CHECK=10
    [ -z ${RELSTORAGE_BLOB_CACHE_SIZE_CHECK_EXTERNAL+x} ] && export RELSTORAGE_BLOB_CACHE_SIZE_CHECK_EXTERNAL=false
    [ -z ${RELSTORAGE_BLOB_CHUNK_SIZE+x} ] && export RELSTORAGE_BLOB_CHUNK_SIZE=1048576
    [ -z ${RELSTORAGE_CACHE_LOCAL_MB+x} ] && export RELSTORAGE_CACHE_LOCAL_MB=10
    [ -z ${RELSTORAGE_CACHE_LOCAL_OBJECT_MAX+x} ] && export RELSTORAGE_CACHE_LOCAL_OBJECT_MAX=16384
    [ -z ${RELSTORAGE_CACHE_LOCAL_COMPRESSION+x} ] && export RELSTORAGE_CACHE_LOCAL_COMPRESSION=none
    [ -z ${RELSTORAGE_CACHE_DELTA_SIZE_LIMIT+x} ] && export RELSTORAGE_CACHE_DELTA_SIZE_LIMIT=100000
  fi
elif  [[ -v ZEO_ADDRESS ]]; then
  MSG="Using ZEO configuration"
  CONF=zeo.conf
  if [[ -z "$render_enabled" ]]; then
    # Check ZEO variables
    [ -z ${ZEO_SHARED_BLOB_DIR+x} ] && export ZEO_SHARED_BLOB_DIR=off
    [ -z ${ZEO_READ_ONLY+x} ] && export ZEO_READ_ONLY=false
    [ -z ${ZEO_CLIENT_READ_ONLY_FALLBACK+x} ] && export ZEO_CLIENT_READ_ONLY_FALLBACK=false
    [ -z ${ZEO_STORAGE+x} ] && export ZEO_STORAGE=1
    [ -z ${ZEO_CLIENT_CACHE_SIZE+x} ] && export ZEO_CLIENT_CACHE_SIZE=128MB
    [ -z ${ZEO_DROP_CACHE_RATHER_VERIFY+x} ] && export ZEO_DROP_CACHE_RATHER_VERIFY=false
  fi
else
  MSG="Using default configuration"
  CONF=zope.conf
fi

# Add anything inside etc/zope.conf.d to the configuration file
# prior to starting the respective Zope server.
# This provides a counterpart for the ZCML package-includes
# functionality, but for Zope configuration snippets.
#
# This must be executed only once during the container lifetime,
# as container can be stopped and then restarted... double-additions
# of the same snippet cause the Zope server not to start.
if grep -q '# Runtime customizations:' etc/${CONF} ; then
  # Note in the log this was customized.  Useful for bug reports.
  MSG="${MSG} -- with customizations"
else
  # Assume there will be no customizations.
  zope_conf_vanilla=true
  for f in etc/zope.conf.d/*.conf ; do
    test -f ${f} || continue
    # Oh, it looks like there is at least one customization.
    if [[ -v zope_conf_vanilla ]] ; then
      # Make a note both in the file and in the log.
      echo >> etc/${CONF}
      echo "# Runtime customizations:" >> etc/${CONF}
      MSG="${MSG} -- with customizations"
      # We don't need to rerun the same snippet twice here.
      unset zope_conf_vanilla
    fi
    echo >> etc/${CONF}
    cat ${f} >> etc/${CONF}
  done
fi

# Handle CORS
$sudo $VENVBIN/python /app/scripts/cors.py

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
#   1. copy the baked default instance.yaml (mounted-file merge is ticket 05);
#   2. translate the legacy environment onto INSTANCE_* (legacy shim);
#   3. overlay INSTANCE_* environment variables (vendored transform);
#   4. render with cookiecutter into $CLIENT_HOME/instance.
render_instance() {
  cp /app/render/instance-default.yaml "$CLIENT_HOME/instance-merged.yaml"
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
}

if [[ "$1" == "start" ]]; then
  if [[ -n "$render_enabled" ]]; then
    render_instance
    echo "Starting Zope from the rendered instance in $CLIENT_HOME/instance"
    exec $sudo $VENVBIN/runwsgi -v "$CLIENT_HOME/instance/etc/zope.ini"
  fi
  # Handle Site creation
  if [[ -v SITE ]]; then
    export TYPE=${TYPE:-volto}
    echo "======================================================================================="
    echo "Creating Plone ${TYPE} SITE: ${SITE}"
    echo "Aditional profiles: ${PROFILES}"
    echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
    echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
    echo "======================================================================================="
    export SITE_ID=${SITE}
    $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
  fi
  echo $MSG
  if [[ -v LISTEN_PORT ]] ; then
    # Ensure the listen port can be set via container --environment.
    # Necessary to run multiple backends in a single Podman / Kubernetes pod.
    sed -i "s/port = 8080/port = ${LISTEN_PORT}/" etc/zope.ini
  fi
  exec $sudo $VENVBIN/runwsgi -v etc/zope.ini config_file=${CONF}
elif  [[ "$1" == "create-classic" ]]; then
  export TYPE=classic
  exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
elif  [[ "$1" == "create-volto" ]]; then
  export TYPE=volto
  exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
elif  [[ "$1" == "create-site" ]]; then
  export TYPE=${TYPE:-volto}
  exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
elif  [[ "$1" == "console" ]]; then
  exec $sudo $VENVBIN/zconsole debug etc/${CONF}
elif  [[ "$1" == "run" ]]; then
  exec $sudo $VENVBIN/zconsole run etc/${CONF} "${@:2}"
elif  [[ "$1" == "addzopeuser" ]]; then
  exec $sudo $VENVBIN/addzopeuser -c etc/${CONF} "${@:2}"
elif  [[ "$1" == "pack" ]]; then
  if [[ -v ZEO_ADDRESS ]]; then
    exec $sudo $VENVBIN/zeopack "${@:2}" ${ZEO_ADDRESS}
  elif [[ -v RELSTORAGE_DSN ]]; then
    exec $sudo $VENVBIN/zodbpack "${@:2}" etc/relstorage_pack.conf
  else
    exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/pack.py
  fi
elif  [[ "$1" == "render" ]]; then
  render_instance
  exit 0
else
  # Custom
  exec "$@"
fi
