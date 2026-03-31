#!/bin/bash
set -e

MAIL_HOSTNAME=${MAIL_HOSTNAME:-smtp.svc.plus}
CERT_DIR="/etc/letsencrypt/live/$MAIL_HOSTNAME"

while [[ ! -f "$CERT_DIR/fullchain.pem" ]]; do
  echo "[dovecot] Waiting for TLS cert..."
  sleep 3
done

envsubst < /etc/dovecot-tmpl/dovecot.conf.tmpl > /etc/dovecot/dovecot.conf
envsubst < /etc/dovecot-tmpl/local.conf.tmpl > /etc/dovecot/local.conf
envsubst < /etc/dovecot-tmpl/10-master.conf.tmpl > /etc/dovecot/conf.d/10-master.conf

echo "[dovecot] Starting..."
exec dovecot -F
