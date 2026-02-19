# Custom Domain and TLS Certificate Setup

This directory contains scripts and instructions to create self-signed certificates for custom domains in the demo.

## 🎯 Goal

Demonstrate how to:
1. Create a self-signed certificate for a custom domain
2. Configure Redis Enterprise Cluster to use the custom certificate
3. Configure OpenShift Routes with TLS passthrough (cluster handles TLS)
4. Access Redis Enterprise UI using custom domain with end-to-end encryption
5. Update certificates in a GitOps workflow

## 📋 Prerequisites

- OpenSSL installed on your system
- Access to modify `/etc/hosts` (requires sudo)
- OpenShift cluster with Redis Enterprise deployed

## 🚀 Quick Start

### Step 1: Generate Certificates

```bash
cd demo-gitops-argocd/tls-setup
./generate-certs.sh
```

This will create:
- `certs/ca.crt` and `certs/ca.key` - Certificate Authority
- `certs/redis-ui.crt` and `certs/redis-ui.key` - Certificate for Redis UI
- `certs/customers-db.crt` and `certs/customers-db.key` - Certificate for database
- Base64 encoded versions (`.b64` files) for Kubernetes secrets

### Step 2: Get OpenShift Router IP

```bash
# Get the router IP address
oc get svc router-default -n openshift-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Or if using hostname
oc get route -n openshift-console console -o jsonpath='{.spec.host}' | cut -d'.' -f2-
```

### Step 3: Update /etc/hosts

Add the custom domains to your `/etc/hosts` file:

```bash
# Replace <ROUTER_IP> with the actual IP from Step 2
sudo bash -c 'echo "<ROUTER_IP> redis.mycompany.local" >> /etc/hosts'
sudo bash -c 'echo "<ROUTER_IP> customers-db.mycompany.local" >> /etc/hosts'
```

Example:
```bash
sudo bash -c 'echo "192.168.1.100 redis.mycompany.local" >> /etc/hosts'
sudo bash -c 'echo "192.168.1.100 customers-db.mycompany.local" >> /etc/hosts'
```

### Step 4: Update the Certificate Secret

#### Option A: Automatic (Recommended)

Use the provided script to automatically update the YAML file:

```bash
./update-yaml-with-certs.sh
```

This will update `../04-custom-certificate.yaml` with the certificate content.

#### Option B: Manual

Edit `../04-custom-certificate.yaml` and replace the certificate placeholders:

```bash
# Get the certificate content
cat certs/redis-ui.crt

# Get the key content
cat certs/redis-ui.key
```

Copy the content and paste into the Secret's `tls.crt` and `tls.key` fields in `04-custom-certificate.yaml`.

**Important:** The certificate will be used by the Redis Enterprise Cluster itself (not just the Route).
The Route uses TLS passthrough, so the cluster handles the TLS termination with this certificate.

### Step 5: Apply the Configuration

```bash
# If using GitOps (recommended)
cd ../..
git add demo-gitops-argocd/
git commit -m "Add custom domain certificates"
git push

# ArgoCD will automatically sync the changes

# Or apply manually for testing
oc apply -f demo-gitops-argocd/04-custom-certificate.yaml
```

### Step 6: Access the Custom Domain

```bash
# Get the route
oc get route redis-ui-custom -n redis-demo

# Access in browser
https://redis.mycompany.local
```

## 🔐 Trust the Certificate (Optional)

To avoid browser warnings, import the CA certificate:

### macOS
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
```

### Linux
```bash
sudo cp certs/ca.crt /usr/local/share/ca-certificates/mycompany-ca.crt
sudo update-ca-certificates
```

### Windows
```powershell
certutil -addstore -f "ROOT" certs\ca.crt
```

### Browser (Firefox)
1. Open Firefox Settings
2. Privacy & Security → Certificates → View Certificates
3. Authorities → Import
4. Select `certs/ca.crt`
5. Check "Trust this CA to identify websites"

## 🧪 Testing

### Test DNS Resolution
```bash
# Should resolve to the IP you added in /etc/hosts
ping redis.mycompany.local
ping customers-db.mycompany.local
```

### Test HTTPS Connection
```bash
# Test with curl (will show certificate error if CA not trusted)
curl -v https://redis.mycompany.local

# Test with curl using CA certificate
curl --cacert certs/ca.crt https://redis.mycompany.local
```

### Test in Browser
1. Open browser
2. Navigate to `https://redis.mycompany.local`
3. You should see the Redis Enterprise UI
4. Check the certificate details (should show "MyCompany")

## 🔄 Updating Certificates

To update certificates in a GitOps workflow:

1. Generate new certificates:
   ```bash
   ./generate-certs.sh
   ```

2. Update the YAML files with new certificate content

3. Commit and push:
   ```bash
   git add .
   git commit -m "Update TLS certificates"
   git push
   ```

4. ArgoCD will automatically sync the changes

## 🎓 Demo Script

### Show Custom Domain Setup

1. **Show the certificate generation:**
   ```bash
   cd demo-gitops-argocd/tls-setup
   cat generate-certs.sh
   ./generate-certs.sh
   ```

2. **Show the generated certificates:**
   ```bash
   ls -la certs/
   openssl x509 -in certs/redis-ui.crt -noout -text | grep -A2 "Subject:"
   ```

3. **Show /etc/hosts configuration:**
   ```bash
   cat /etc/hosts | grep mycompany.local
   ```

4. **Show the Route configuration:**
   ```bash
   cat ../04-custom-certificate.yaml
   ```

5. **Access the custom domain:**
   - Open browser to `https://redis.mycompany.local`
   - Show the certificate details
   - Show the Redis Enterprise UI

6. **Show GitOps workflow:**
   - Make a change to the certificate
   - Commit and push
   - Show ArgoCD detecting and syncing the change

## 🧹 Cleanup

```bash
# Remove from /etc/hosts
sudo sed -i '' '/mycompany.local/d' /etc/hosts

# Remove certificates
rm -rf certs/

# Remove trusted CA (macOS)
sudo security delete-certificate -c "MyCompany Root CA" /Library/Keychains/System.keychain
```

## 📚 Additional Resources

- [OpenShift Routes Documentation](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html)
- [Kubernetes TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- [OpenSSL Certificate Generation](https://www.openssl.org/docs/man1.1.1/man1/openssl-req.html)

