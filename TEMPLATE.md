# Docker Registry 3 Private Container Registry: Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **Docker Registry 3 Private Container Registry** |
| Description | Private image registry with login, Bucket storage, deletes and weekly GC. (73 chars) |
| Category | Other |
| Icon | Distribution favicon (commit-tag pinned on jsDelivr) |
| Repo | `baranberkay96/docker-registry-railway`, root `/services/registry` (both services) |

## Base market templates

| Code | Active | Notes |
|---|---|---|
| `docker-registry` | 35 | `registry:2`, **no authentication**, volume |
| `docker-registry-private` | 13 | third-party image, login, volume |
| `docker` | 4 | third-party image, GC on start |

### Improvements over market templates

- Official `registry:3.1.2` (Distribution v3) pinned by digest instead of `registry:2`/third-party images.
- htpasswd (bcrypt) login from generated credentials; fail-closed on unusable passwords (8.29).
- Storage in a Railway Bucket (S3 driver): stateless registry, replicas possible, pulls redirected to signed Bucket URLs, GC can run in a separate cron service (a volume cannot be shared, Rule 3b).
- Deletes enabled; weekly `garbage-collect` cron (Sunday 04:00 UTC) exercised in the test (8.25).
- No in-memory blob-descriptor cache: with GC in a separate service a cached descriptor kept answering 307 for deleted layers (seen in the test), which would make clients skip re-uploading them.
- Storage-driver health check: `/` answers 503 when the Bucket is unreachable, so the deploy healthcheck is real.

## Pinned versions

| Component | Pin | Checked |
|---|---|---|
| registry | `3.1.2@sha256:82f6ff4a…` (2026-11-11) | 2026-11-24 |

## Services

| Service | Source | Healthcheck | Domain | Volume | Cron |
|---|---|---|---|---|---|
| Registry | repo, `ROLE=registry` | `/` | public, 5000 | none | |
| Registry GC | repo, `ROLE=gc` | none (cron job) | none | none | `0 4 * * 0`, restart NEVER |
| Bucket | Railway Bucket | | | | |

## Resource profile

Registry idle 11-37 MB (measured 2026-11-24); GC job runs seconds to minutes weekly. < $1/month RAM plus Bucket storage. Minimum plan: Trial.

## Verification checklist

1. Deploy SUCCESS; `/` 200; `/v2/` 401 without login, 200 with.
2. Push a test image (blob + config + manifest via the API), pull the manifest, list `_catalog`.
3. Delete the manifest; run Registry GC once; the layer blob is gone (404).
4. Short password: service starts, 401 for everyone, log explains.

## Open questions

- GC overlapping a push can delete a just-uploaded layer (upstream limitation); documented with the schedule.
- Using the registry as a Railway image source needs Railway's private-registry credentials (Pro feature per Railway docs).
