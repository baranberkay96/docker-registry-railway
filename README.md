# Deploy and Host Docker Registry with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/docker-registry-3-private-container-regi?referralCode=20H68q)

Docker Registry (the CNCF Distribution project) is the open-source server behind private container image registries. This template runs Registry 3.1 with a password login, image storage in a Railway Bucket, image deletion enabled and a weekly garbage-collection job, so you can `docker push` and `docker pull` your own images over HTTPS.

> Community template, not affiliated with Docker, Inc. or the CNCF Distribution project.

## About Hosting Docker Registry

A registry stores image layers (blobs) and manifests and speaks the OCI distribution API that Docker, Podman, containerd, Kubernetes and CI systems use. Self-hosting one gives you private images without per-seat pricing or pull limits.

On Railway the registry is stateless: layers and manifests live in a Railway Bucket through the S3 storage driver, so redeploys never lose images and you can add replicas. Pulls are redirected to short-lived signed Bucket links, so large layers download straight from storage. Login uses htpasswd with a bcrypt hash generated at start from the template variables. Deleting a tag only removes the reference; the **Registry GC** cron job deletes unreferenced layers every Sunday at 04:00 UTC to free space.

## Common Use Cases

- Private registry for your own application images, built locally or in CI
- Image cache close to your Railway services, without Docker Hub pull limits
- Store images for customer deployments or air-gapped handover
- OCI artifact storage (Helm charts, WASM modules, SBOMs) with tools like ORAS

## Dependencies for Docker Registry Hosting

- Registry service (repo build on `registry:3.1.2`, pinned by digest)
- Registry GC cron service (same image, weekly)
- Railway Bucket (image storage)

### Deployment Dependencies

- [Distribution documentation](https://distribution.github.io/distribution/)
- [Garbage collection](https://distribution.github.io/distribution/about/garbage-collection/)
- [Railway Buckets](https://docs.railway.com/guides/storage-buckets)
- [Template source](https://github.com/baranberkay96/docker-registry-railway)

### Implementation Details

| Service | Purpose |
|---|---|
| Registry | OCI/Docker registry API on port 5000, public HTTPS domain, htpasswd login |
| Registry GC | Cron job (Sundays 04:00 UTC): `registry garbage-collect`, then exits |
| Bucket | Layers and manifests under `/registry` |

**Log in and push**

1. Copy `REGISTRY_USERNAME` (default `registry`) and `REGISTRY_PASSWORD` from the Registry service's Variables tab.
2. Log in with your Railway domain (no port, HTTPS is automatic):

```bash
docker login {your-domain}.up.railway.app -u registry
docker tag myapp:latest {your-domain}.up.railway.app/myapp:1.0
docker push {your-domain}.up.railway.app/myapp:1.0
docker pull {your-domain}.up.railway.app/myapp:1.0
```

3. List repositories: `curl -u registry:{password} https://{your-domain}/v2/_catalog`.

To use the images in another Railway service, set the service's source to the image (`{your-domain}.up.railway.app/myapp:1.0`) and add the registry credentials under the service's Settings, Private Registry credentials (a Pro plan feature on Railway).

**Delete images**

Get the digest with `curl -sI -u registry:{password} -H "Accept: application/vnd.oci.image.manifest.v1+json" https://{your-domain}/v2/myapp/manifests/1.0` (header `Docker-Content-Digest`), then `curl -X DELETE -u registry:{password} https://{your-domain}/v2/myapp/manifests/{digest}`. The next Registry GC run frees the layers; run it now from the Registry GC service's cron menu if you need the space immediately.

**Garbage collection caveat**: upstream recommends no pushes while GC runs, because a layer uploaded but not yet referenced by a manifest can be deleted. The job runs weekly at a quiet time; change `cronSchedule` of the Registry GC service if you push at that time, or retry a push that failed during GC.

**Security defaults**

- Every API call needs the login; `/` (used by the healthcheck) only returns an empty page.
- A password that is empty, shorter than 16 or longer than 72 bytes, or contains spaces locks the registry with a random password and the log explains the fix. The service still starts.
- Layers are private in the Bucket; download links are signed and expire after 20 minutes.

**Resources**: the registry idles at about 20-30 MB RAM and uses CPU only while serving requests. It fits every plan. Bucket storage is billed per GB stored.

**Upgrading**: the image is pinned by digest in `services/registry/Dockerfile` of the template repository; change tag and digest and redeploy. Data in the Bucket is kept.

### Why Deploy Docker Registry on Railway?

Railway gives the registry HTTPS, a public domain and Bucket storage without servers or certificates to manage. You get a private, password-protected image registry in a few minutes and pay for the storage you use.
