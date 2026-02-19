#!/bin/bash

# Script to update the 04-custom-certificate.yaml with generated certificates
# This makes it easy to update the YAML file with the certificate content

set -e

CERT_FILE="certs/redis-ui.crt"
KEY_FILE="certs/redis-ui.key"
YAML_FILE="../04-custom-certificate.yaml"

# Check if certificates exist
if [ ! -f "$CERT_FILE" ]; then
    echo "❌ Certificate file not found: $CERT_FILE"
    echo "Run ./generate-certs.sh first!"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Key file not found: $KEY_FILE"
    echo "Run ./generate-certs.sh first!"
    exit 1
fi

echo "🔐 Updating YAML file with certificate content..."
echo ""

# Create a temporary file with the updated content
cat > /tmp/04-custom-certificate.yaml << 'EOF'
---
# Custom TLS Certificate Secret for Redis Enterprise Cluster
# This certificate will be used by the Redis Enterprise Cluster for API and UI
# Generated using: cd tls-setup && ./generate-certs.sh
apiVersion: v1
kind: Secret
metadata:
  name: redis-cluster-tls
  namespace: redis-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app: redis-demo
    component: tls-certificate
type: kubernetes.io/tls
stringData:
  tls.crt: |
EOF

# Add certificate content with proper indentation
sed 's/^/    /' "$CERT_FILE" >> /tmp/04-custom-certificate.yaml

# Add key section
cat >> /tmp/04-custom-certificate.yaml << 'EOF'
  tls.key: |
EOF

# Add key content with proper indentation
sed 's/^/    /' "$KEY_FILE" >> /tmp/04-custom-certificate.yaml

# Add the Route section
cat >> /tmp/04-custom-certificate.yaml << 'EOF'

---
# Route with custom domain using TLS passthrough
# The Redis Enterprise Cluster handles the TLS termination using the certificate above
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: redis-ui-custom
  namespace: redis-demo
  annotations:
    argocd.argoproj.io/sync-wave: "4"
  labels:
    app: redis-demo
    component: custom-route
spec:
  # Custom hostname - add this to /etc/hosts pointing to OpenShift router IP
  host: redis.mycompany.local
  
  # Target service (Redis Enterprise UI)
  to:
    kind: Service
    name: demo-cluster-ui
    weight: 100
  
  # TLS passthrough - let Redis Enterprise handle TLS with its certificate
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
  
  port:
    targetPort: https
EOF

# Move the temporary file to the actual location
mv /tmp/04-custom-certificate.yaml "$YAML_FILE"

echo "✅ YAML file updated successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Review the changes:"
echo "   cat $YAML_FILE"
echo ""
echo "2. Commit and push to Git:"
echo "   git add $YAML_FILE"
echo "   git commit -m 'Update TLS certificate for Redis cluster'"
echo "   git push"
echo ""
echo "3. ArgoCD will automatically sync the changes"
echo ""

