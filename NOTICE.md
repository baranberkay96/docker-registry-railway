# NOTICE: Docker Registry 3 Private Container Registry template

This is a community template. It is not affiliated with or endorsed by Docker, Inc., the CNCF Distribution project or Railway. Docker is a trademark of Docker, Inc.; "Docker Registry" refers to the `registry` Docker Official Image built from CNCF Distribution.

## Components

| Component | Source | License | How it is used |
|---|---|---|---|
| Distribution (registry) 3.1.2 | https://github.com/distribution/distribution, image `registry:3.1.2@sha256:82f6ff4a7f982960c8aa51617fea3aabc485df6e55cce80d22deb1de36f1bc3c` | Apache-2.0 | Base image, binary unmodified |
| apache2-utils (htpasswd) | Alpine package | Apache-2.0 | Generates the bcrypt htpasswd file at start |
| Distribution icon | https://github.com/distribution/distribution `docs/static/favicon/favicon.svg` at v3.1.2 | Apache-2.0 | Marketplace icon |

## Files written for this template

`services/registry/Dockerfile` and `services/registry/railway-start.sh` were written for this template (no upstream file copied) and are offered under the MIT License.

## Upstream checked (2026-11-24, v3.1.2)

- distribution-library-image `Dockerfile` and `config-example.yml` (binary at `/bin/registry`, config `/etc/distribution/config.yml`, port 5000).
- `docs/content/storage-drivers/s3.md` (region, regionendpoint, forcepathstyle default false, rootdirectory), `docs/content/about/configuration.md` (auth.htpasswd, storage.delete, storage.redirect, http.secret, environment overrides), `docs/content/about/garbage-collection.md` (GC must not overlap with pushes; `--delete-untagged` not used because it can remove manifests that an index still references).

## Market templates reviewed

`docker-registry` (35 active; `registry:2`, no auth, filesystem on a volume), `docker-registry-private` (13 active; third-party image with login and a volume) and `docker` (4 active; third-party image with GC on start). Nothing was copied.
