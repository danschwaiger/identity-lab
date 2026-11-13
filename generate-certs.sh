#!/bin/sh
set -eu
umask 077

: "${LAB_HOST:?Set LAB_HOST before running this script}"

mkdir -p certs

# Avoid accidentally replacing an existing CA or server certificate.
for file in certs/lab-ca.key certs/lab-ca.crt certs/lab-ca.srl \
            certs/lab-server.key certs/lab-server.csr \
            certs/lab-server.crt certs/server-extensions.cnf
do
  if [ -e "$file" ]; then
    echo "Error: $file already exists. Remove or back up the existing certificate files first." >&2
    exit 1
  fi
done

openssl req -x509 -newkey rsa:3072 -nodes \
  -keyout certs/lab-ca.key \
  -out certs/lab-ca.crt \
  -days 365 \
  -subj "/CN=Identity Lab CA"

openssl req -new -newkey rsa:2048 -nodes \
  -keyout certs/lab-server.key \
  -out certs/lab-server.csr \
  -subj "/CN=${LAB_HOST}"

cat > certs/server-extensions.cnf <<EOF
subjectAltName=DNS:${LAB_HOST}
extendedKeyUsage=serverAuth
EOF

openssl x509 -req \
  -in certs/lab-server.csr \
  -CA certs/lab-ca.crt \
  -CAkey certs/lab-ca.key \
  -CAcreateserial \
  -out certs/lab-server.crt \
  -days 365 \
  -sha256 \
  -extfile certs/server-extensions.cnf
