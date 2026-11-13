#!/bin/sh
# Generate a fresh local configuration and start the services needed for setup.
set -eu
umask 077
cd "$(dirname "$0")"

: "${LAB_HOST:?Set LAB_HOST, for example LAB_HOST=lab.example.test sh setup.sh}"
# Restrict input because it is used in a dotenv file, NGINX configuration, and a certificate.
if ! printf '%s\n' "$LAB_HOST" | grep -Eq '^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$'; then
  echo 'LAB_HOST must be a DNS hostname (not an IP address or URL).' >&2
  exit 1
fi
command -v openssl >/dev/null || { echo 'openssl is required.' >&2; exit 1; }
command -v docker >/dev/null || { echo 'Docker and Docker Compose are required.' >&2; exit 1; }
docker compose version >/dev/null
if ! docker info >/dev/null 2>&1; then
  echo 'Cannot connect to the Docker daemon as the current user.' >&2
  echo 'Run "docker info" for details and see the Docker permissions section in README.md.' >&2
  exit 1
fi
docker info >/dev/null
if [ -e .env ] || [ -e certs ]; then
  echo 'Existing .env or certs found. Nothing was changed. Use rebuild.sh to reset the lab.' >&2
  exit 1
fi
# Do not silently attach to an existing named volume from an earlier lab.
for vol in identity-lab_keycloak-data identity-lab_redis-data; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "Existing lab volume $vol found. Use rebuild.sh to reset the lab." >&2
    exit 1
  fi
done

# These files contain no secrets and must be readable by non-root containers.
chmod 755 nginx nginx/templates tyk tyk/apps
chmod 644 nginx/templates/default.conf.template tyk/tyk.conf tyk/apps/demo-

admin_password=$(openssl rand -hex 24)
gateway_secret=$(openssl rand -hex 32)
cookie_secret=$(openssl rand -base64 32 | tr '+/' '-_')
printf 'LAB_HOST=%s\nKC_ADMIN_USER=admin\nKC_ADMIN_PASSWORD=%s\nTYK_GW_SECRET=%s\nOAUTH2_PROXY_COOKIE_SECRET=%s\nOAUTH2_PROXY_CLIENT_SECRET=REPLACE_ME\n' \
  "$LAB_HOST" "$admin_password" "$gateway_secret" "$cookie_secret" > .env

mkdir certs
openssl req -x509 -newkey rsa:3072 -nodes \
  -keyout certs/lab-ca.key -out certs/lab-ca.crt -days 365 \
  -subj '/CN=Identity Lab CA'
openssl req -new -newkey rsa:2048 -nodes \
  -keyout certs/lab-server.key -out certs/lab-server.csr \
  -subj "/CN=${LAB_HOST}"
cat > certs/server-extensions.cnf <<EOF
subjectAltName=DNS:${LAB_HOST}
extendedKeyUsage=serverAuth
EOF
openssl x509 -req -in certs/lab-server.csr \
  -CA certs/lab-ca.crt -CAkey certs/lab-ca.key -CAcreateserial \
  -out certs/lab-server.crt -days 365 -sha256 \
  -extfile certs/server-extensions.cnf

# The CA certificate is public; oauth2-proxy needs to read it.
chmod 644 certs/lab-ca.crt

docker compose --project-name identity-lab --file compose.yaml up -d nginx keycloak redis tyk demo-api
printf '\nInitial services started. Follow README.md to trust the CA, configure Keycloak and start oauth2-proxy.\n'
