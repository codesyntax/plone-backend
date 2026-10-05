# Render Zope configuration with cookiecutter-zope-instance at container startup

Status: accepted (proposed for the 6.2.x image line)

The images currently ship a static `skeleton/etc` configuration and select the
backend with shell branches in `docker-entrypoint.sh`. We are replacing that path
entirely: configuration is generated at **container startup** from a
`cookiecutter-zope-instance` template, so one tool renders `zope.conf`, `zope.ini`,
`site.zcml` and `inituser`, and runtime secrets/DSNs are available. This matches what
cookieplone already uses for local development and closes the long-standing request
`plone/container-backend#39`. Rendering at *build* time was rejected because database
credentials and hostnames only exist at runtime; keeping the skeleton as a second
engine was rejected because it perpetuates the split-brain the change exists to remove.

## Consequences

- The rendered instance lives at `$CLIENT_HOME/instance` (under `/data`), not `/app`,
  so arbitrary-user mode keeps working.
- `runwsgi` no longer takes a `config_file=` argument; `zope.ini` references
  `zope.conf` directly.
- The `post_gen_project` hook creates absolute `/data/...` directories at render
  time, so the entrypoint must ensure `/data` is writable before rendering.
- The documented drop-in mechanisms `package-includes/` and `zope.conf.d/` are
  removed and must be documented as breaking, each with a replacement.
