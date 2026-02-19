#!/bin/bash

# Script to generate self-signed certificates for custom domains
# This is for demonstration purposes only - not for production use

set -e

echo "🔐 Generating self-signed certificates for custom domains..."
echo ""

# Configuration
DOMAIN="mycompany.local"
REDIS_UI_DOMAIN="redis.${DOMAIN}"
CUSTOMERS_DB_DOMAIN="customers-db.${DOMAIN}"
VALIDITY_DAYS=365

# Create output directory
mkdir -p certs

# Generate CA (Certificate Authority)
echo "1️⃣  Generating Certificate Authority (CA)..."
openssl genrsa -out certs/ca.key 4096
openssl req -x509 -new -nodes -key certs/ca.key -sha256 -days ${VALIDITY_DAYS} -out certs/ca.crt \
  -subj "/C=US/ST=State/L=City/O=MyCompany/OU=IT/CN=MyCompany Root CA"

echo "✅ CA certificate created"
echo ""

# Generate certificate for Redis UI
echo "2️⃣  Generating certificate for ${REDIS_UI_DOMAIN}..."
openssl genrsa -out certs/redis-ui.key 2048
openssl req -new -key certs/redis-ui.key -out certs/redis-ui.csr \
  -subj "/C=US/ST=State/L=City/O=MyCompany/OU=IT/CN=${REDIS_UI_DOMAIN}"

# Create extension file for SAN (Subject Alternative Name)
cat > certs/redis-ui.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${REDIS_UI_DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

openssl x509 -req -in certs/redis-ui.csr -CA certs/ca.crt -CAkey certs/ca.key \
  -CAcreateserial -out certs/redis-ui.crt -days ${VALIDITY_DAYS} -sha256 \
  -extfile certs/redis-ui.ext

echo "✅ Redis UI certificate created"
echo ""

# Generate certificate for Customers DB
echo "3️⃣  Generating certificate for ${CUSTOMERS_DB_DOMAIN}..."
openssl genrsa -out certs/customers-db.key 2048
openssl req -new -key certs/customers-db.key -out certs/customers-db.csr \
  -subj "/C=US/ST=State/L=City/O=MyCompany/OU=IT/CN=${CUSTOMERS_DB_DOMAIN}"

cat > certs/customers-db.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${CUSTOMERS_DB_DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

openssl x509 -req -in certs/customers-db.csr -CA certs/ca.crt -CAkey certs/ca.key \
  -CAcreateserial -out certs/customers-db.crt -days ${VALIDITY_DAYS} -sha256 \
  -extfile certs/customers-db.ext

echo "✅ Customers DB certificate created"
echo ""

# Display certificate information
echo "📋 Certificate Information:"
echo ""
echo "Redis UI Certificate:"
openssl x509 -in certs/redis-ui.crt -noout -subject -dates
echo ""
echo "Customers DB Certificate:"
openssl x509 -in certs/customers-db.crt -noout -subject -dates
echo ""

# Create base64 encoded versions for Kubernetes secrets
echo "4️⃣  Creating base64 encoded versions for Kubernetes..."
cat certs/redis-ui.crt | base64 > certs/redis-ui.crt.b64
cat certs/redis-ui.key | base64 > certs/redis-ui.key.b64
cat certs/customers-db.crt | base64 > certs/customers-db.crt.b64
cat certs/customers-db.key | base64 > certs/customers-db.key.b64

echo "✅ Base64 encoded files created"
echo ""

# Display next steps
echo "✅ All certificates generated successfully!"
echo ""
echo "📁 Files created in certs/ directory:"
ls -lh certs/
echo ""
echo "📝 Next steps:"
echo "1. Add to /etc/hosts:"
echo "   sudo bash -c 'echo \"<OPENSHIFT_ROUTER_IP> ${REDIS_UI_DOMAIN}\" >> /etc/hosts'"
echo "   sudo bash -c 'echo \"<OPENSHIFT_ROUTER_IP> ${CUSTOMERS_DB_DOMAIN}\" >> /etc/hosts'"
echo ""
echo "2. Update the YAML files with the certificate content:"
echo "   - Use certs/redis-ui.crt and certs/redis-ui.key for the Route"
echo "   - Or use the base64 versions for the Secret"
echo ""
echo "3. Import CA certificate to your browser/system (optional):"
echo "   - Import certs/ca.crt to trust the certificates"
echo ""

