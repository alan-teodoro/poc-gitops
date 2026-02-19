# TLS Architecture - Certificate Configuration

This document explains how TLS certificates are configured in this demo and why.

## 🔐 Two Approaches to TLS in OpenShift

### Approach 1: Edge Termination (Route handles TLS)

```
┌─────────┐         ┌──────────────┐         ┌─────────────┐
│ Browser │ HTTPS   │   OpenShift  │  HTTP   │    Redis    │
│         ├────────>│    Router    ├────────>│ Enterprise  │
│         │  TLS    │ (terminates  │  Plain  │   Cluster   │
└─────────┘         │     TLS)     │         └─────────────┘
                    └──────────────┘
                    Certificate here
```

**Pros:**
- Simple to configure
- Certificate managed in Route

**Cons:**
- Not end-to-end encryption
- Traffic between Router and Redis is unencrypted
- Certificate not managed by Redis Enterprise

---

### Approach 2: Passthrough Termination (Redis handles TLS) ✅ **USED IN THIS DEMO**

```
┌─────────┐         ┌──────────────┐         ┌─────────────┐
│ Browser │ HTTPS   │   OpenShift  │  HTTPS  │    Redis    │
│         ├────────>│    Router    ├────────>│ Enterprise  │
│         │  TLS    │ (passthrough)│   TLS   │   Cluster   │
└─────────┘         └──────────────┘         └─────────────┘
                                              Certificate here
```

**Pros:**
- End-to-end encryption
- Certificate managed by Redis Enterprise
- More secure
- More realistic for production

**Cons:**
- Slightly more complex setup
- Certificate must be configured in cluster

---

## 📋 How It Works in This Demo

### 1. Certificate Secret (Wave 1)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-cluster-tls
  namespace: redis-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
type: kubernetes.io/tls
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    ...certificate content...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    ...key content...
    -----END PRIVATE KEY-----
```

**Purpose:** Store the TLS certificate and private key

---

### 2. Redis Enterprise Cluster Configuration (Wave 2)

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: demo-cluster
spec:
  nodes: 3
  
  # Reference the certificate secret
  certificates:
    apiCertificateSecretName: redis-cluster-tls
```

**Purpose:** Configure the cluster to use the custom certificate for API and UI

**What happens:**
- Redis Enterprise Cluster uses this certificate for HTTPS
- All API calls and UI access use this certificate
- The certificate is used for the custom domain

---

### 3. Route with Passthrough (Wave 4)

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: redis-ui-custom
spec:
  host: redis.mycompany.local
  
  to:
    kind: Service
    name: demo-cluster-ui
  
  # Passthrough - don't terminate TLS at router
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
```

**Purpose:** Route traffic to the cluster without terminating TLS

**What happens:**
- Router forwards encrypted traffic directly to Redis
- Redis Enterprise handles TLS termination
- End-to-end encryption maintained

---

## 🔄 Traffic Flow

```
1. Browser requests: https://redis.mycompany.local
   │
   ├─> DNS resolution via /etc/hosts
   │   redis.mycompany.local → OpenShift Router IP
   │
   ▼
2. TLS handshake with Redis Enterprise Cluster
   │
   ├─> Browser connects to Router
   ├─> Router forwards encrypted traffic to Redis pod
   ├─> Redis presents certificate (from redis-cluster-tls secret)
   ├─> Browser validates certificate
   │
   ▼
3. Encrypted connection established
   │
   └─> All traffic encrypted end-to-end
```

---

## 🎯 Why This Approach?

### For Demo Purposes:
1. **Shows real-world configuration** - This is how you'd configure it in production
2. **Demonstrates GitOps** - Certificate managed as code in Git
3. **Shows Redis Enterprise features** - Certificate management in the cluster
4. **End-to-end security** - More secure than edge termination

### For Production:
1. **Better security** - Traffic encrypted all the way to Redis
2. **Certificate lifecycle** - Managed by Redis Enterprise
3. **Compliance** - Meets security requirements for encryption in transit
4. **Flexibility** - Can use different certificates for different services

---

## 🔧 Certificate Management

### Initial Setup:
```bash
cd tls-setup
./generate-certs.sh              # Generate self-signed certificate
./update-yaml-with-certs.sh      # Update YAML with certificate
git add ../04-custom-certificate.yaml
git commit -m "Add custom TLS certificate"
git push
```

### Certificate Rotation:
```bash
cd tls-setup
./generate-certs.sh              # Generate new certificate
./update-yaml-with-certs.sh      # Update YAML
git add ../04-custom-certificate.yaml
git commit -m "Rotate TLS certificate"
git push
# ArgoCD automatically syncs and updates the cluster
```

---

## 📚 Key Concepts

### Sync Waves:
- **Wave 1:** Certificate Secret must exist first
- **Wave 2:** Cluster references the secret
- **Wave 4:** Route created after cluster is ready

### GitOps:
- Certificate stored in Git (as code)
- Changes tracked in version control
- ArgoCD automatically applies changes
- Easy to audit and rollback

### Security:
- Private key stored in Kubernetes Secret
- End-to-end encryption
- Custom domain with valid certificate
- No unencrypted traffic

---

## 🎓 Demo Talking Points

1. **"We're using end-to-end encryption"**
   - Show the passthrough configuration
   - Explain traffic is encrypted all the way to Redis

2. **"Certificate is managed by Redis Enterprise"**
   - Show the cluster configuration
   - Explain how the cluster uses the certificate

3. **"Everything is in Git"**
   - Show the YAML files
   - Explain GitOps workflow

4. **"Easy to rotate certificates"**
   - Show the scripts
   - Explain the update process

5. **"Custom domain with custom certificate"**
   - Show /etc/hosts configuration
   - Access https://redis.mycompany.local
   - Show certificate in browser

