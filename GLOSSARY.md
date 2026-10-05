# plone-backend image configuration

Vocabulary for how the `plone/server-*` and `plone/plone-backend` images produce
their Zope configuration. Single context (this repo).

## Language

**Instance**:
The generated Zope configuration tree (`etc/zope.conf`, `etc/zope.ini`,
`etc/site.zcml`, `inituser`) plus its clienthome.
_Avoid_: config, config file, etc

**instance.yaml**:
The declarative input that `cookiecutter-zope-instance` renders the instance from.
_Avoid_: config file, settings

**Render**:
Producing an instance from `instance.yaml` with the `cookiecutter-zope-instance`
template at container startup.
_Avoid_: build, generate, bake (except "bake at build time" for the acceptance image)

**Transform**:
The upstream `transform_from_environment.py` step that overlays `INSTANCE_*`
environment variables onto a copy of `instance.yaml`.
_Avoid_: shim

**Legacy shim**:
This repo's `legacy_from_environment.py`, which translates the pre-migration
environment contract (e.g. `RELSTORAGE_*`, `ZEO_ADDRESS`) onto `INSTANCE_*` before
the transform.
_Avoid_: adapter, compat layer, migration shim

**Render tooling**:
The `/app/render/` directory baked into `server-builder`: the isolated venv, the
pinned template archive, the transform and legacy-shim helpers, and the default
`instance.yaml`.
_Avoid_: toolchain, build tools

**Skeleton**:
The legacy static configuration tree (`skeleton/`) and its shell backend selection,
which the render path replaces.
_Avoid_: template (that is the cookiecutter template)

**server-builder** and **server-prod-config**:
The two base images. `server-builder` installs Plone and the render tooling;
`server-prod-config` is the thin runtime base (user, `/data`, healthcheck, entrypoint
declaration).
_Avoid_: base image (ambiguous), server image

**Clienthome**:
The single writable Zope client home; defaults under `/data/<hostname>/<hostid>`.
_Avoid_: instance home, var dir

**Backend**:
The ZODB storage configuration selected by `db_storage`: `direct`, `relstorage`,
`zeo`, `pgjsonb`, or the `z3blobs` S3 blob wrapper.
_Avoid_: storage engine, database

**Drop-in**:
A file placed in a magic directory to extend configuration without rebuilding —
`etc/package-includes/*.zcml` for ZCML and `etc/zope.conf.d/*.conf` for `zope.conf`.
Both are removed by this migration and replaced by a mounted `instance.yaml`.
_Avoid_: fragment, override

**Consumer image**:
An image built on the main contract that does not change it — `plone/plone-classicui`
and the acceptance image.
_Avoid_: derived image
