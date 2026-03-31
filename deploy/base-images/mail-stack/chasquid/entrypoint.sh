#!/bin/bash
set -e

MAIL_HOSTNAME=${MAIL_HOSTNAME:-smtp.svc.plus}
CERT_DIR="/etc/letsencrypt/live/$MAIL_HOSTNAME"
CERT_DST="/etc/chasquid/certs"

mkdir -p $CERT_DST

while [[ ! -f "$CERT_DIR/fullchain.pem" ]]; do
  echo "[chasquid] Waiting for TLS cert..."
  sleep 3
done

ln -sf $CERT_DIR/fullchain.pem $CERT_DST/fullchain.pem
ln -sf $CERT_DIR/privkey.pem  $CERT_DST/privkey.pem
chmod 640 $CERT_DST/* || true

envsubst < /etc/chasquid-tmpl/chasquid.conf.tmpl > /etc/chasquid/chasquid.conf

echo "[chasquid] Starting..."
exec chasquid
