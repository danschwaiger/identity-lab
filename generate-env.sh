#!/bin/sh
umask 077

cat > .env <<EOF
LAB_HOST=${LAB_HOST}
KC_ADMIN_USER=admin
KC_ADMIN_PASSWORD=$(openssl rand -hex 24)
TYK_GW_SECRET=$(openssl rand -hex 32)
OAUTH2_PROXY_COOKIE_SECRET=$(openssl rand -base64 32 | tr '+/' '-_')
OAUTH2_PROXY_CLIENT_SECRET=REPLACE_ME
EOF
