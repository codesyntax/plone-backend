# Bake a default instance.yaml and translate legacy env vars onto INSTANCE_*

Status: accepted (proposed for the 6.2.x image line)

`docker run plone/plone-backend` must work with zero mounts, so the image bakes a
default `instance.yaml` and layers configuration on top of it: baked default →
user-mounted `/app/instance.yaml` (deep-merged for dicts) → legacy-derived
`INSTANCE_*` → explicit `INSTANCE_*`. A standalone `legacy_from_environment.py`
translates the existing env contract (`RELSTORAGE_*`, `ZEO_*`, `DEBUG_MODE`,
`LISTEN_PORT`, `CLIENT_HOME`, `CORS_*`, …) onto `INSTANCE_*` before the vendored
transform, leaving that helper pristine. Requiring every deployment to author a
complete `instance.yaml` was rejected as user-hostile; dropping the legacy vars was
rejected because these are the *official* images and a clean break would break every
existing compose file.

## Considered Options

- **No merge** (a mounted file replaces the baked one): simpler, but a sparse
  cookieplone-style `instance.yaml` would lose all defaults.
- **Clean break to `INSTANCE_*` only**: smaller surface, but breaks existing
  deployments — the reason the original request has stayed open since 2022.

## Consequences

- The four-layer precedence must be implemented by a small pre-render merge step.
- Each legacy variable is either mapped, defaulted for parity, or documented as a
  breakage (`SECURITY_POLICY_IMPLEMENTATION`, `DEFAULT_ZPUBLISHER_ENCODING`,
  `RELSTORAGE_CACHE_DELTA_SIZE_LIMIT`).
- Legacy use emits one aggregated deprecation warning; removal is deferred to a
  future major.
