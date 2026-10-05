# Vendor a pinned template in an isolated render venv inside server-builder

Status: accepted (proposed for the 6.2.x image line)

The runtime image must render offline, so `server-builder` bakes a pinned
`cookiecutter-zope-instance` tag archive, the matching
`transform_from_environment.py`, the in-repo `legacy_from_environment.py`, and the
default `instance.yaml` under `/app/render/`. The render dependencies (`cookiecutter`,
`PyYAML`) are installed into a **separate venv** at `/app/render/venv`, never the
Plone `/app` venv, because cookiecutter pulls Jinja2/click/requests and could
otherwise perturb Plone's resolution. The pin is a build
`ARG COOKIECUTTER_ZOPE_INSTANCE_VERSION=3.1.0` threaded through the Makefile. Placing
the tooling in `server-prod-config` was rejected because `dev` is `FROM server-builder`
and would then lack it; folding it into the Plone venv was rejected for the dependency
conflict above.

## Consequences

- The existing `COPY --from=builder /app /app` carries the tooling to main/classicui/
  acceptance with no new `COPY`; `dev` inherits because it is `FROM server-builder`;
  `nightly` replicates the setup in its self-contained build.
- A build-time smoke render catches template breakage at build, not first run.
- Upgrading the template is a one-line ARG bump.
