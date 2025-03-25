# Custom plone/plone-backend images

These are custom Plone docker images.

They address some issues found in original [plone/plone-backend](https://github.com/plone/plone-backend) images that are already merged but not released, and some others that are not merged yet.

The purpose of the repository is to have a public container registry in order to base our deployment images on them.

The generated docker images are:

- ghcr.io/codesyntax/plone-backend/server-builder
- ghcr.io/codesyntax/plone-backend/server-prod-config
- ghcr.io/codesyntax/plone-backend/plone-backend

The issues included here are:

Unmerged:

- Do not do a `find & chown` for all files in /data: https://github.com/plone/plone-backend/issues/172
