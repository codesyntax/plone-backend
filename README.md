<p align="center">
    <img alt="Plone Logo" width="200px" src="https://raw.githubusercontent.com/plone/container-backend/5.2.x/docs/logo.png">
</p>

<h1 align="center">
  plone/plone-backend
</h1>

<div align="center">

[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/plone/plone-backend?sort=semver)](https://hub.docker.com/r/plone/plone-backend)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/plone/plone-backend?sort=semver)](https://hub.docker.com/r/plone/plone-backend)

![GitHub Repo stars](https://img.shields.io/github/stars/plone/plone-backend?style=flat-square)
[![license badge](https://img.shields.io/github/license/plone/plone-backend)](./LICENSE)

</div>

Plone backend [Docker](https://docker.com) images using Python 3 and [pip](https://pip.pypa.io/en/stable/).

**Note:**
These are the official images for the [Plone 6](https://plone.org/) release, together with [plone-frontend](https://github.com/plone/container-frontend).
These images are **not** Buildout based!

## Tags
### Supported tags and respective Dockerfile links

| Plone Version | Tags | Dockerfile |
| --- | --- | --- |
| 6 | `6.0.15`, `6.0` | [(6.0.x/Dockerfile)](https://github.com/plone/container-backend/blob/v6.0.15/Dockerfile)|
| 6.1 | `6.1.5`, `6.1` | [(6.1.x/Dockerfile)](https://github.com/plone/container-backend/blob/v6.1.5/Dockerfile)|
| 6.2 | `6.2.2`, `6.2`, `6`, `latest` | [(6.2.x/Dockerfile)](https://github.com/plone/container-backend/blob/v6.2.1/Dockerfile)|

**Possible breaking changes in upcoming Plone 6.2 dependencies**

Please note that the backend images in the 6.2.x series may get several updated dependencies, which you should verify and test before using them in any existing project. Even if you extend from these images.
Python has been updated from 3.12 to 3.13.

### Possible breaking changes: new configuration model

The backend images can now generate the Zope configuration at container start with
`cookiecutter-zope-instance`, driven by the same `instance.yaml` / `INSTANCE_*` vocabulary used
by cookieplone. This is published first under the opt-in experimental tag `6.2.2-cczi`; the
normal tags keep the previous build until it is promoted.

If you adopt it:

- The `etc/package-includes/*.zcml` and `etc/zope.conf.d/*.conf` drop-ins are **removed**.
  Replace them with `INSTANCE_zcml_package_includes`, a mounted `instance.yaml`, or
  `wsgi_filters`.
- Legacy environment variables (`RELSTORAGE_*`, `ZEO_ADDRESS`, `DEBUG_MODE`, `CORS_*`, …) keep
  working with a deprecation warning, but `SECURITY_POLICY_IMPLEMENTATION` and
  `DEFAULT_ZPUBLISHER_ENCODING` no longer have an independent setting.
- Roll back by redeploying a previous, immutable image tag: the data under `/data` is
  unchanged.

See the [migration guide](docs/migration-cookiecutter-zope-instance.md).

### Experimental UV-based images

A parallel track of images built with [UV](https://docs.astral.sh/uv/) lives on the [`uv` branch](https://github.com/plone/container-backend/tree/uv) and is published as `plone/server-builder:uv-<python>` and `plone/server-prod-config:uv-<python>` for Python 3.11, 3.12, 3.13 and 3.14. These images are rebuilt weekly (Mondays, 05:00 UTC) so they stay in sync with upstream Debian, Python, UV and Plone dependency updates.

### Unsupported tags

**Note:**
These images for Plone 5 are **not** officially supported by the Plone community.


| Plone Version | Tags | Dockerfile |
| --- | --- | --- |
| 5.2 | `5`, `5.2`, `5.2.14` | [(5.2.x/Dockerfile)](https://github.com/plone/container-backend/blob/v5.2.14/Dockerfile) |


 See also the official [Buildout-based Plone 5 images](https://hub.docker.com/_/plone).

## Usage

Please refer to the [Official Plone Documentation](https://6.docs.plone.org/install/containers/images/backend.html) for further documentation and examples.

## Contribute

- [Issue Tracker](https://github.com/plone/container-backend/issues)
- [Source Code](https://github.com/plone/container-backend/)
- [Documentation](https://6.docs.plone.org/install/containers/images/backend.html)

Please **DO NOT** commit to version branches directly. Even for the smallest and most trivial fix.
**ALWAYS** open a pull request and ask somebody else to merge your code. **NEVER** merge it yourself.

## Credits

This project is supported by:

[![Plone Foundation](https://raw.githubusercontent.com/plone/.github/main/plone-foundation.png)](https://plone.org/)

## License

The project is licensed under GPLv2.
