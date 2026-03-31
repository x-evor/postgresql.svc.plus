#!/bin/bash
# Generate self-signed certificates for stunnel

set -e

CERTS_DIR="./certs"
DAYS=365
DOMAIN="${1:-${DOMAIN:-postgresql.svc.plus}}"

mkdir -p "$CERTS_DIR"

echo "🔐 Generating self-signed certificates for $DOMAIN (stunnel)..."

# Generate server certificate
openssl req -new -x509 -days $DAYS -nodes \
    -out "$CERTS_DIR/server-cert.pem" \
    -keyout "$CERTS_DIR/server-key.pem" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Combine cert and key for stunnel
cat "$CERTS_DIR/server-cert.pem" "$CERTS_DIR/server-key.pem" > "$CERTS_DIR/server.pem"

# Generate CA certificate (for client verification)
openssl req -new -x509 -days $DAYS -nodes \
    -out "$CERTS_DIR/ca-cert.pem" \
    -keyout "$CERTS_DIR/ca-key.pem" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=postgres-ca"

# Generate client certificate signed by CA
echo "🔑 Generating client certificate..."
openssl genrsa -out "$CERTS_DIR/client-key.pem" 2048
openssl req -new -key "$CERTS_DIR/client-key.pem" \
    -out "$CERTS_DIR/client-req.pem" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=postgres-client"
openssl x509 -req -in "$CERTS_DIR/client-req.pem" \
    -CA "$CERTS_DIR/ca-cert.pem" \
    -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$CERTS_DIR/client-cert.pem" \
    -days $DAYS

# Combine client cert and key for stunnel client
cat "$CERTS_DIR/client-cert.pem" "$CERTS_DIR/client-key.pem" > "$CERTS_DIR/client.pem"

# Set permissions
chmod 600 "$CERTS_DIR"/*.pem
chmod 644 "$CERTS_DIR"/*-cert.pem

echo "✅ Certificates generated in $CERTS_DIR/"
echo ""
echo "Files created:"
echo "  Server certificates:"
echo "    - server-cert.pem (server certificate)"
echo "    - server-key.pem (server private key)"
echo "    - server.pem (combined cert + key)"
echo "  CA certificates:"
echo "    - ca-cert.pem (CA certificate)"
echo "    - ca-key.pem (CA private key)"
echo "  Client certificates (for mutual TLS):"
echo "    - client-cert.pem (client certificate)"
echo "    - client-key.pem (client private key)"
echo "    - client.pem (combined cert + key)"
echo ""
echo "⚠️  These are self-signed certificates for testing only!"
echo "For production, use certificates from a trusted CA."
echo ""
echo "📝 To use client authentication, clients must present client-cert.pem"

