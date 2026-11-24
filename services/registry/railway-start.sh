#!/bin/sh
# Railway start wrapper for the registry. ROLE=registry (default) serves the
# registry; ROLE=gc runs garbage collection once and exits (cron service).
# Never exits because of a variable value (STANDARD 8.29).
set -u

log() { echo "railway-start: $*"; }
random_secret() { tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 40; }
yaml_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

CONFIG=/etc/distribution/railway.yml
role="${ROLE:-registry}"
case "$role" in registry|gc) ;; *) log "WARNING: ROLE='${role}' is not registry or gc, using registry"; role=registry ;; esac

# --- Port ---
case "${PORT:-}" in
  ''|*[!0-9]*) [ -n "${PORT:-}" ] && log "WARNING: PORT='${PORT}' is not a number, using 5000"; PORT=5000 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then log "WARNING: PORT=${PORT} out of range, using 5000"; PORT=5000; fi

# --- Storage: Railway Bucket via the S3 driver, else a local folder (lost on redeploy) ---
if [ -n "${S3_BUCKET:-}" ] && [ -n "${S3_ENDPOINT:-}" ] && [ -n "${S3_ACCESS_KEY_ID:-}" ] && [ -n "${S3_SECRET_ACCESS_KEY:-}" ]; then
  storage=$(cat <<YAML
  s3:
    region: "$(yaml_str "${S3_REGION:-auto}")"
    regionendpoint: "$(yaml_str "$S3_ENDPOINT")"
    bucket: "$(yaml_str "$S3_BUCKET")"
    forcepathstyle: false
    secure: true
    v4auth: true
    rootdirectory: /registry
YAML
)
  export REGISTRY_STORAGE_S3_ACCESSKEY="$S3_ACCESS_KEY_ID" REGISTRY_STORAGE_S3_SECRETKEY="$S3_SECRET_ACCESS_KEY"
  where="Railway Bucket ${S3_BUCKET}"
else
  log "WARNING: S3_* variables are empty: images are stored inside the container and are LOST on every redeploy."
  log "         Reference the Railway Bucket variables (S3_ENDPOINT, S3_BUCKET, S3_REGION, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY)."
  storage="  filesystem:
    rootdirectory: /var/lib/registry"
  mkdir -p /var/lib/registry
  where="container filesystem (not persistent)"
fi

redirect="${REGISTRY_DISABLE_REDIRECT:-false}"
case "$redirect" in true|false) ;; *) log "WARNING: REGISTRY_DISABLE_REDIRECT must be true or false, using false"; redirect=false ;; esac

cat > "$CONFIG" <<YAML
version: 0.1
log:
  level: info
  accesslog:
    disabled: false
storage:
${storage}
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  redirect:
    disable: ${redirect}
http:
  addr: ":${PORT}"
  relativeurls: false
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 30s
    threshold: 3
YAML

if [ "$role" = gc ]; then
  log "garbage collection on ${where} (blobs no longer referenced by any manifest are deleted)"
  registry garbage-collect "$CONFIG"
  rc=$?
  log "garbage collection finished with exit code ${rc}"
  exit "$rc"
fi

# --- Login (htpasswd, bcrypt) ---
user="${REGISTRY_USERNAME:-}"
if ! printf '%s' "$user" | grep -Eq '^[A-Za-z0-9._-]{1,64}$'; then
  log "WARNING: REGISTRY_USERNAME is empty or has characters other than letters, digits and . _ -; using 'registry'"
  user=registry
fi
pass="${REGISTRY_PASSWORD:-}"
bytes=$(printf '%s' "$pass" | wc -c | tr -d ' ')
if [ "$bytes" -lt 16 ] || [ "$bytes" -gt 72 ] || printf '%s' "$pass" | grep -q '[[:space:][:cntrl:]]'; then
  log "WARNING: REGISTRY_PASSWORD is empty, shorter than 16 characters, longer than 72 bytes or contains spaces."
  log "         The registry is LOCKED with a random password nobody knows (pushes and pulls get 401)."
  log "         Fix: set a password of 16-72 characters without spaces in the Variables tab and redeploy."
  pass="$(random_secret)"
fi
mkdir -p /etc/distribution/auth
printf '%s\n' "$pass" | htpasswd -iBC 10 -c /etc/distribution/auth/htpasswd "$user" 2>/dev/null \
  || { log "WARNING: htpasswd failed; locking the registry"; random_secret | htpasswd -iBC 10 -c /etc/distribution/auth/htpasswd "$user"; }
chmod 0600 /etc/distribution/auth/htpasswd
unset pass
export REGISTRY_AUTH=htpasswd REGISTRY_AUTH_HTPASSWD_REALM="Registry" REGISTRY_AUTH_HTPASSWD_PATH=/etc/distribution/auth/htpasswd

# --- Shared secret for upload state (must be the same on every replica) ---
secret="${REGISTRY_HTTP_SECRET:-}"
if [ "${#secret}" -lt 16 ]; then
  log "WARNING: REGISTRY_HTTP_SECRET is shorter than 16 characters; using a random one (uploads in progress fail after a restart)"
  secret="$(random_secret)"
fi
export REGISTRY_HTTP_SECRET="$secret"
unset secret

if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export REGISTRY_HTTP_HOST="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
log "registry on port ${PORT}, user '${user}', storage: ${where}"
exec registry serve "$CONFIG"
