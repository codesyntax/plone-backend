## 6.2.2.1 (2026-10-22)

### Feature

- Added support for zodb-pgjsonb storage, configured with `ZODB_PGJSONB_DSN`, with optional blob storage in S3 enabled by `ZODB_PGJSONB_S3BLOBS_ENABLED`. @erral [#209](https://github.com/plone/container-backend/issues/209)

### Bugfix

- Upgrade to Plone 6.2.2.1 security release.  @mauritsvanrees 

### Internal

- Updated GitHub URLs to reflect the repository rename to plone/container-backend. @ericof [#219](https://github.com/plone/container-backend/issues/219)
- Configured Dependabot to keep GitHub Actions up to date on the 6.2.x, 6.1.x and uv branches. @ericof [#222](https://github.com/plone/container-backend/issues/222)
- Changed the image test workflow to build and test the images locally instead of pushing them to Docker Hub, so it no longer needs registry credentials and also runs on Dependabot and fork pull requests. @ericof 

## 6.2.2 (2026-09-11)

### Bugfix

- Upgrade to Plone 6.2.2.  @mauritsvanrees 

## 6.2.1 (2026-06-27)

### Feature

- Upgrade to Plone 6.2.1.  @mauritsvanrees 

## 6.2.0 (2026-05-19)

### Bugfix

- Upgrade to Plone 6.2.0.  @mauritsvanrees 

## 6.2.0rc2 (2026-05-08)

### Bugfix

- Upgrade to Plone 6.2.0rc2. 

## 6.2.0rc1 (2026-03-27)

### Bugfix

- Upgrade to Plone 6.2.0rc1.

## 6.2.0a1 (2026-01-21)

### Feature

- Upgrade to Plone 6.2.0a1.

## 6.1.4 (2026-01-16)

### Bugfix

- Upgrade to Plone 6.1.4.

## 6.1.3 (2025-10-02)

### Bugfix

- Upgrade to Plone 6.1.3. [#613](https://github.com/plone/volto/issues/613)

## 6.1.2 (2025-06-20)


- Upgrade to Plone 6.1.2.

- Compile po files in the sources folder, where by default the packages from mx.ini are downloaded @erral


## 6.1.1 (2025-03-25)


- Upgrade to Plone 6.1.1 final.


## 6.1.1rc2 (2025-03-21)


- Upgrade to Plone 6.1.1rc2


## 6.1.1rc1 (2025-03-17)

### Features (also collected from previous changes

- Provide command to pack ZODB. @erral [#104](https://github.com/plone/volto/issues/104)

### Bugfixes

- Ensure that zope.conf customizations can never happen twice [Rudd-O] [#93](https://github.com/plone/volto/issues/93)
