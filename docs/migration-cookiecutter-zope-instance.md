# Migrating to the cookiecutter-zope-instance configuration model

The `plone/server-*` and `plone/plone-backend` images can now generate the Zope
configuration at container start with
[`cookiecutter-zope-instance`](https://github.com/plone/cookiecutter-zope-instance),
driven by the same `instance.yaml` / `INSTANCE_*` vocabulary used by cookieplone.

This guide covers what changed and how to migrate. Read it before upgrading.

## Opt-in experimental tag

The new configuration model is published first under the opt-in experimental tag
`6.2.2-cczi` (and matching `plone/server-*-cczi` images). The normal tags (`6.2`,
`latest`, `6.2.2`, …) keep the previous build until the model is promoted in a later
release.

```console
$ docker run -p 8080:8080 plone/plone-backend:6.2.2-cczi
```

## How the new model works

1. The image bakes a default `instance.yaml`.
2. At container start, an optional mounted `/app/instance.yaml` is deep-merged over it.
3. The legacy environment variables are translated onto `INSTANCE_*` (a single aggregated
   deprecation warning is printed).
4. Explicit `INSTANCE_*` variables overlay everything.
5. `cookiecutter-zope-instance` renders the instance into `$CLIENT_HOME/instance`.

Precedence, lowest to highest: **baked default → mounted `instance.yaml` → legacy env →
explicit `INSTANCE_*`**.

## What stays the same

- The documented environment variables (`RELSTORAGE_DSN`, `ZEO_ADDRESS`,
  `ZEO_SHARED_BLOB_DIR`, `DEBUG_MODE`, `VERBOSE_SECURITY`, `ZODB_CACHE_SIZE`,
  `ZOPE_FORM_*`, `COMPILE_MO_FILES`, `CHAMELEON_CACHE`, `LISTEN_PORT`, `CLIENT_HOME`,
  `CORS_*`, `ADDONS`, `DEVELOP`, `SITE`, `TYPE`, `PROFILES`, `DELETE_EXISTING`) keep
  working. Backend defaults are applied for parity, and one aggregated deprecation warning
  names the variables you used.
- The subcommands (`start`, `create-site`, `create-volto`, `create-classic`, `console`,
  `run`, `addzopeuser`, `pack`) and the arbitrary-command passthrough are unchanged, and
  now operate on the rendered instance. A new `render` subcommand materializes the
  instance and exits.
- `pgjsonb` and the S3 blob wrapper now ship in the main image; select them with
  `INSTANCE_db_storage=pgjsonb` (+ `INSTANCE_db_pgjsonb_dsn`) or
  `INSTANCE_db_z3blobs_enabled=true` (+ bucket/cache dir).

## Dropped: `etc/package-includes/*.zcml`

The `package-includes/` directory is gone. To keep loading ZCML, choose one of:

- Set `INSTANCE_zcml_package_includes=my.addon,another.addon` (or the
  `zcml_package_includes` key in a mounted `instance.yaml`); each package's
  `configure.zcml` is included.
- `Products.*` add-ons keep loading automatically.
- Add-ons using `plone.autoinclude` (or the legacy `z3c.autoinclude`) keep loading
  automatically — verified for `plone.restapi`, `plone.volto` and `ADDONS`/`DEVELOP`
  installs.

## Dropped: `etc/zope.conf.d/*.conf`

The `zope.conf.d/` directory is gone. Move each fragment into a mounted
`/app/instance.yaml` (or `INSTANCE_*` variables). Most `zope.conf` directives map to a
cookiecutter-zope-instance key:

| `zope.conf` | `instance.yaml` |
|---|---|
| `<environment>` | `environment` / `environment_paths` |
| `<dos_protection>` | `dos_protection_*` |
| `<zodb_db>` backends | `db_*` |
| WSGI / `waitress` tuning | `wsgi_*` |
| WSGI filters | `wsgi_filters` |

Example mounted `/app/instance.yaml`:

```yaml
default_context:
    wsgi_threads: 8
    environment:
        CHAMELEON_CACHE: /data/cache
```

## Behaviour changes

These legacy variables have no independent equivalent:

- **`SECURITY_POLICY_IMPLEMENTATION`** — the policy is derived from `verbose_security`
  (`PYTHON` iff `verbose_security` is on, otherwise `C`). `PYTHON` maps to
  `verbose_security=true`; `C` is a no-op. Setting `C` together with
  `VERBOSE_SECURITY=on` is no longer possible.
- **`DEFAULT_ZPUBLISHER_ENCODING`** — the rendered `zope.conf` hardcodes `utf-8`; other
  values are ignored with a warning. The legacy default was already `utf-8`.
- **`RELSTORAGE_CACHE_DELTA_SIZE_LIMIT`** — not a RelStorage or cookiecutter option;
  ignored.

The instance is rendered into `$CLIENT_HOME/instance` (under `/data`), and the default
`CLIENT_HOME` is still `/data/<hostname>/<hostid>`, so per-container separation survives.

## Rollback

The new entrypoint writes only under `$CLIENT_HOME/instance` and does not change the ZODB
format, so the data under `/data` is untouched. Roll back by redeploying the previous,
immutable image tag:

```console
$ docker run -p 8080:8080 plone/plone-backend:6.2.2
```

There is no in-image fallback to the old entrypoint; the previous tag is the rollback path.

## Extending the image

Mount your project's `instance.yaml` and/or set `INSTANCE_*` variables. If you build a
derived image, place your `instance.yaml` at `/app/instance.yaml` (it is merged over the
baked defaults) instead of copying files into `etc/`.

## Compatibility matrix

| Legacy mechanism | Status |
|---|---|
| `RELSTORAGE_DSN`, `RELSTORAGE_*`, `ZEO_ADDRESS`, `ZEO_*` | Mapped to `INSTANCE_*` (deprecated) |
| `DEBUG_MODE`, `VERBOSE_SECURITY`, `ZODB_CACHE_SIZE`, `ZOPE_FORM_*`, `COMPILE_MO_FILES`, `CHAMELEON_CACHE`, `LISTEN_PORT`, `CLIENT_HOME` | Mapped to `INSTANCE_*` (deprecated) |
| `CORS_*` | Mapped; any `CORS_*` enables CORS |
| `ADDONS`, `DEVELOP`, `SITE`, `TYPE`, `PROFILES`, `DELETE_EXISTING` | Unchanged |
| `SECURITY_POLICY_IMPLEMENTATION` | Behaviour change (see above) |
| `DEFAULT_ZPUBLISHER_ENCODING` | Ignored; `utf-8` hardcoded |
| `RELSTORAGE_CACHE_DELTA_SIZE_LIMIT` | Ignored |
| `etc/package-includes/*.zcml` | Removed; use `INSTANCE_zcml_package_includes` |
| `etc/zope.conf.d/*.conf` | Removed; use a mounted `instance.yaml` |
