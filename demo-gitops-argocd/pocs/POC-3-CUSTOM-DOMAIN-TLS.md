# POC 3: Custom Domain and TLS Certificate

## Objective

Demonstrate the ability to configure Redis Enterprise Cluster with a custom domain and TLS certificate, different from the default OpenShift-generated domain. This validates enterprise requirements for custom branding and certificate management.

---

## Test Scenarios

### 1. Generate Custom TLS Certificate
### 2. Configure Cluster with Custom Certificate
### 3. Validate TLS Configuration
### 4. Access Cluster UI via Custom Domain
### 5. Access Database via Custom Domain

---

## Prerequisites

- Redis Enterprise Cluster running in `redis-demo` namespace
- `openssl` tool installed
- DNS or `/etc/hosts` configuration capability

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     Custom Domain Flow                      │
└────────────────────────────────────────────────────────────┘

  Client Request
       │
       │ https://redis.mycompany.local
       ▼
┌──────────────────────┐
│  OpenShift Router    │
│  (Passthrough)       │
└──────────────────────┘
       │
       │ TLS Passthrough (no termination)
       ▼
┌──────────────────────┐
│  Redis Enterprise    │
│  Cluster API         │
│                      │
│  Custom Certificate: │
│  - CN: redis.mycompany.local
│  - SAN: *.redis.mycompany.local
└──────────────────────┘
```

---

## Step 1: Generate Custom TLS Certificate

```bash
# Set custom domain
CUSTOM_DOMAIN="redis.mycompany.local"
WILDCARD_DOMAIN="*.redis.mycompany.local"

# Create certificate directory
mkdir -p evidence/poc3/certificates
cd evidence/poc3/certificates

# Generate private key
openssl genrsa -out custom-redis.key 2048

# Generate certificate signing request (CSR)
cat > custom-redis.conf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=California
L=San Francisco
O=MyCompany
OU=IT
CN=$CUSTOM_DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CUSTOM_DOMAIN
DNS.2 = $WILDCARD_DOMAIN
DNS.3 = demo-cluster-api.redis-demo.svc.cluster.local
DNS.4 = demo-cluster-ui.redis-demo.svc.cluster.local
EOF

# Generate CSR
openssl req -new -key custom-redis.key -out custom-redis.csr -config custom-redis.conf

# Generate self-signed certificate (valid for 365 days)
openssl x509 -req -in custom-redis.csr \
  -signkey custom-redis.key \
  -out custom-redis.crt \
  -days 365 \
  -extensions v3_req \
  -extfile custom-redis.conf

# Verify certificate
openssl x509 -in custom-redis.crt -text -noout | grep -A 5 "Subject Alternative Name"

cd ../../..
```

**Evidence**: 
- Save certificate details to `evidence/poc3/01-certificate-details.txt`
- Save certificate files in `evidence/poc3/certificates/`

---

## Step 2: Create Kubernetes Secret with Custom Certificate

```bash
# Create secret with custom certificate
oc create secret tls redis-cluster-custom-tls \
  --cert=evidence/poc3/certificates/custom-redis.crt \
  --key=evidence/poc3/certificates/custom-redis.key \
  -n redis-demo \
  --dry-run=client -o yaml > evidence/poc3/02-custom-tls-secret.yaml

# Apply secret
oc apply -f evidence/poc3/02-custom-tls-secret.yaml

# Verify secret
oc get secret redis-cluster-custom-tls -n redis-demo -o yaml
```

**Evidence**: Save secret YAML to `evidence/poc3/02-custom-tls-secret.yaml`

---

## Step 3: Update Cluster Configuration with Custom Certificate

```bash
# Update Redis Enterprise Cluster to use custom certificate
oc patch redisenterprisecluster demo-cluster -n redis-demo --type merge -p '
{
  "spec": {
    "certificates": {
      "apiCertificateSecretName": "redis-cluster-custom-tls"
    }
  }
}'

# Wait for cluster to reconcile
echo "Waiting for cluster to apply new certificate..."
sleep 30

# Verify certificate is applied
oc get rec demo-cluster -n redis-demo -o jsonpath='{.spec.certificates}' | jq .
```

**Evidence**: Save output to `evidence/poc3/03-cluster-certificate-config.txt`

---

## Step 4: Configure DNS/Hosts for Custom Domain

```bash
# Get cluster API route
CLUSTER_ROUTE=$(oc get route demo-cluster-api -n redis-demo -o jsonpath='{.spec.host}')

# Get route IP (from router)
ROUTE_IP=$(dig +short $CLUSTER_ROUTE | head -1)

echo "Add this to /etc/hosts or DNS:"
echo "$ROUTE_IP    $CUSTOM_DOMAIN"
echo ""
echo "Example:"
echo "sudo bash -c 'echo \"$ROUTE_IP    $CUSTOM_DOMAIN\" >> /etc/hosts'"
```

**Evidence**: Save DNS configuration to `evidence/poc3/04-dns-configuration.txt`

**Manual Step**: Add entry to `/etc/hosts` or configure DNS

---

## Step 5: Create Custom Route with Custom Domain

```bash
# Create custom route for cluster API
cat > evidence/poc3/05-custom-route.yaml <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: demo-cluster-custom-api
  namespace: redis-demo
spec:
  host: $CUSTOM_DOMAIN
  to:
    kind: Service
    name: demo-cluster-api
  port:
    targetPort: api
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
EOF

# Apply custom route
oc apply -f evidence/poc3/05-custom-route.yaml

# Verify route
oc get route demo-cluster-custom-api -n redis-demo
```

**Evidence**: Save route YAML to `evidence/poc3/05-custom-route.yaml`

---

## Step 6: Validate TLS Certificate

```bash
# Test TLS connection with custom domain
echo | openssl s_client -connect $CUSTOM_DOMAIN:443 -servername $CUSTOM_DOMAIN 2>/dev/null | \
  openssl x509 -noout -text | \
  grep -A 5 "Subject Alternative Name" > evidence/poc3/06-tls-validation.txt

# Verify certificate matches
echo | openssl s_client -connect $CUSTOM_DOMAIN:443 -servername $CUSTOM_DOMAIN 2>/dev/null | \
  openssl x509 -noout -fingerprint >> evidence/poc3/06-tls-validation.txt

# Display results
cat evidence/poc3/06-tls-validation.txt
```

**Evidence**: Save output to `evidence/poc3/06-tls-validation.txt`

---

## Step 7: Access Cluster UI via Custom Domain

```bash
# Get cluster credentials
ADMIN_USER=$(oc get secret demo-cluster -n redis-demo -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(oc get secret demo-cluster -n redis-demo -o jsonpath='{.data.password}' | base64 -d)

echo "Access Cluster UI:"
echo "URL: https://$CUSTOM_DOMAIN"
echo "Username: $ADMIN_USER"
echo "Password: $ADMIN_PASS"
echo ""
echo "Test API access:"
curl -k -u "$ADMIN_USER:$ADMIN_PASS" https://$CUSTOM_DOMAIN/v1/cluster | jq .
```

**Evidence**: 
- Save API response to `evidence/poc3/07-api-access-test.json`
- Screenshot of UI access via custom domain

---

## Step 8: Test Database Access via Custom Domain

```bash
# Get database service
DB_SERVICE=$(oc get svc -n redis-demo -l redis.io/bdb=customers -o jsonpath='{.items[0].metadata.name}')

# Create route for database with custom subdomain
cat > evidence/poc3/08-database-custom-route.yaml <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: customers-db-custom
  namespace: redis-demo
spec:
  host: db.$CUSTOM_DOMAIN
  to:
    kind: Service
    name: $DB_SERVICE
  port:
    targetPort: redis
  tls:
    termination: passthrough
EOF

oc apply -f evidence/poc3/08-database-custom-route.yaml

# Get database password
DB_PASS=$(oc get secret redb-customers -n redis-demo -o jsonpath='{.data.password}' | base64 -d)

# Test database connection via custom domain
redis-cli -h db.$CUSTOM_DOMAIN -p 443 -a "$DB_PASS" --tls --insecure PING

# Write test data
redis-cli -h db.$CUSTOM_DOMAIN -p 443 -a "$DB_PASS" --tls --insecure \
  SET poc3:test "Custom Domain Success"

# Read test data
redis-cli -h db.$CUSTOM_DOMAIN -p 443 -a "$DB_PASS" --tls --insecure \
  GET poc3:test
```

**Evidence**: Save output to `evidence/poc3/08-database-access-test.txt`

---

## Cleanup (Optional)

```bash
# Remove custom certificate from cluster
oc patch redisenterprisecluster demo-cluster -n redis-demo --type json \
  -p '[{"op": "remove", "path": "/spec/certificates"}]'

# Delete custom routes
oc delete route demo-cluster-custom-api customers-db-custom -n redis-demo

# Delete custom secret
oc delete secret redis-cluster-custom-tls -n redis-demo

# Remove /etc/hosts entry
sudo sed -i '' "/$CUSTOM_DOMAIN/d" /etc/hosts
```

---

## Success Criteria

- ✅ Custom TLS certificate generated successfully
- ✅ Certificate configured on Redis Enterprise Cluster
- ✅ Custom domain accessible via Route
- ✅ TLS validation successful
- ✅ Cluster UI accessible via custom domain
- ✅ Database accessible via custom subdomain

---

## Conclusion

This POC demonstrates the ability to configure Redis Enterprise with custom domains and TLS certificates, independent of OpenShift's default domain. This validates enterprise requirements for custom branding, certificate management, and compliance with corporate security policies.

---

**Test Duration**: ~30 minutes  
**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed  
**Tested By**: _________________  
**Date**: _________________

