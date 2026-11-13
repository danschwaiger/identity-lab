#!/bin/sh
# Destructive reset: remove this Compose project's containers, volumes and generated configuration.
set -eu
cd "$(dirname "$0")"
: "${LAB_HOST:?Set LAB_HOST, for example LAB_HOST=lab.example.test sh rebuild.sh}"
if ! printf '%s\n' "$LAB_HOST" | grep -Eq '^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$'; then
  echo 'LAB_HOST must be a DNS hostname (not an IP address or URL).' >&2
  exit 1
fi
command -v openssl >/dev/null || { echo 'openssl is required.' >&2; exit 1; }
command -v docker >/dev/null || { echo 'Docker and Docker Compose are required.' >&2; exit 1; }
docker compose version >/dev/null
# Verify that the daemon is reachable before changing anything.
docker info >/dev/null
printf '%s\n' 'WARNING: This destroys the identity-lab Compose project, including its Keycloak and Redis volumes.' \
  'It also deletes this directory’s .env and certs directory and generates a new CA and new secrets.' \
  'You will need to configure Keycloak again and trust the new CA on your workstation.'
printf 'Type RESET to continue: '
IFS= read -r answer
if [ "$answer" != RESET ]; then
  echo 'Cancelled; nothing was changed.'
  exit 1
fi
# The sample file supplies non-secret interpolation values even if .env was lost.
docker compose --project-name identity-lab --file compose.yaml --env-file .env.example down --volumes --remove-orphans
rm -f .env
rm -rf certs
LAB_HOST="$LAB_HOST" sh ./setup.sh
