# syntax=docker/dockerfile:1
#
# Distribution (Docker Registry) 3.1.2 for Railway: one image for the registry
# and the weekly garbage-collection cron job.
#
# The Docker Official Image, plus htpasswd (apache2-utils, for bcrypt) and a
# start script that writes the config from the template variables: htpasswd
# auth from generated credentials, storage in the Railway Bucket (S3 driver),
# deletes enabled.
#
# Pin (checked 2026-11-24 on Docker Hub): registry:3.1.2 index digest, pushed
# 2026-11-11 (distribution v3.1.2).
ARG REGISTRY_IMAGE=registry:3.1.2@sha256:82f6ff4a7f982960c8aa51617fea3aabc485df6e55cce80d22deb1de36f1bc3c
FROM ${REGISTRY_IMAGE}

RUN apk add --no-cache apache2-utils
COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start

EXPOSE 5000
ENTRYPOINT ["/usr/local/bin/railway-start"]
CMD []
