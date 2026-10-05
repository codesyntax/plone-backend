# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.13
FROM python:${PYTHON_VERSION}-slim-bookworm

ARG PLONE_VERSION
ARG COOKIECUTTER_ZOPE_INSTANCE_VERSION=3.1.0

ENV EXTRA_PACKAGES="relstorage==4.1.1 psycopg2==2.9.10 python-ldap==3.4.4 ZEO zodb-pgjsonb==1.16.2 zodb-s3blobs==1.1.0"


LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="server-builder" \
      org.label-schema.description="Plone $PLONE_VERSION builder image with Python $PYTHON_VERSION" \
      org.label-schema.vendor="Plone Foundation"


# Script used for pre-compilation of po files
COPY /helpers/compile_mo.py /compile_mo.py

# Install Plone
#  - Install build dependencies
#  - Download constraints.txt file to /app folder
#  - Install Plone using pip
#  - Create /data folder
#  - Pre-compile po files in the /app/lib folder
#  - Remove .pyc and .pyo files
#
RUN <<EOT
    set -e
    apt-get update
    apt-get -y upgrade
    buildDeps="build-essential busybox ca-certificates curl git gosu libbz2-dev libffi-dev libjpeg62-turbo-dev libmagic1 libsasl2-dev libldap2-dev libopenjp2-7-dev libpcre3-dev libpq-dev libssl-dev libtiff6 libtiff5-dev libxml2-dev libxslt1-dev wget zlib1g-dev"
    apt-get install -y --no-install-recommends $buildDeps
    busybox --install -s
    python -m venv /app
    curl -L -o /app/constraints.txt https://dist.plone.org/release/$PLONE_VERSION/constraints.txt
    /app/bin/pip install -U pip wheel setuptools -c /app/constraints.txt
    /app/bin/pip install Plone ${EXTRA_PACKAGES} -c /app/constraints.txt
    bash -c 'mkdir -p /data/{filestorage,blobstorage,cache,logs}'
    /app/bin/python /compile_mo.py
    find /app \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' +
EOT

# Copy the entrypoint and helper scripts
COPY /skeleton/scripts /app/scripts
COPY /skeleton/docker-entrypoint.sh /app/

# Bake the render tooling used to generate the Zope instance at container start.
# The default instance.yaml and, on later tickets, the in-repo legacy shim are
# copied from the repository; everything else is fetched from the pinned tag.
COPY /render /app/render

# Install the render dependencies in an isolated venv (never the Plone /app venv),
# download the pinned template + transform helper, and smoke-render the baked
# default so a broken template fails the build.
RUN /app/render/setup.sh 500:500
