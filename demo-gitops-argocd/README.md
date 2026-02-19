# GitOps Demo with ArgoCD - Redis Enterprise

This is a simple demonstration of how to use GitOps and ArgoCD to deploy Redis Enterprise clusters and databases.

## 📁 Directory Structure

```
demo-gitops-argocd/
├── README.md                          # This file
├── 00-namespace.yaml                  # Namespace for the demo
├── 01-redis-cluster.yaml              # Redis Enterprise Cluster
├── 02-database-customers.yaml         # First database (customers)
├── 03-database-orders.yaml            # Second database (orders)
├── 04-custom-certificate.yaml         # Custom domain and TLS certificate
├── argocd-application.yaml            # ArgoCD Application to deploy everything
├── DEMO-COMMANDS.md                   # Quick reference commands
├── ARCHITECTURE.md                    # Architecture diagrams
└── tls-setup/                         # Custom certificate generation
    ├── README.md                      # Certificate setup instructions
    └── generate-certs.sh              # Script to generate certificates
```

## ✨ Features Demonstrated

1. **GitOps Workflow**: All infrastructure as code in Git
2. **ArgoCD Automation**: Automatic deployment and sync
3. **Sync Waves**: Controlled deployment order
4. **Custom Domains**: Using custom domains with TLS certificates
5. **Self-Healing**: Automatic drift correction

## 🚀 Quick Start

### Option 1: Deploy with ArgoCD (Recommended for Demo)

1. **Create the ArgoCD Application:**
   ```bash
   oc apply -f demo-gitops-argocd/argocd-application.yaml
   ```

2. **Watch ArgoCD sync the resources:**
   - Open ArgoCD UI
   - Find the `redis-demo` application
   - Watch it create: Namespace → Operator → Cluster → Databases

3. **Show the sync waves:**
   - Wave 0: Namespace
   - Wave 1: Operator
   - Wave 2: Cluster
   - Wave 3: Databases

### Option 2: Manual Deployment (for testing)

```bash
# Apply in order
oc apply -f demo-gitops-argocd/00-namespace.yaml

# Wait for namespace to be ready
sleep 5

oc apply -f demo-gitops-argocd/01-redis-cluster.yaml

# Wait for cluster to be ready
sleep 60

oc apply -f demo-gitops-argocd/02-database-customers.yaml
oc apply -f demo-gitops-argocd/03-database-orders.yaml

# Optional: Apply custom certificate
oc apply -f demo-gitops-argocd/04-custom-certificate.yaml
```

## 🔐 Custom Domain Demo (Optional)

To demonstrate custom domains with TLS certificates:

1. **Generate certificates:**
   ```bash
   cd demo-gitops-argocd/tls-setup
   ./generate-certs.sh
   ```

2. **Update /etc/hosts:**
   ```bash
   # Get OpenShift router IP
   ROUTER_IP=$(oc get svc router-default -n openshift-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

   # Add to /etc/hosts
   sudo bash -c "echo \"${ROUTER_IP} redis.mycompany.local\" >> /etc/hosts"
   sudo bash -c "echo \"${ROUTER_IP} customers-db.mycompany.local\" >> /etc/hosts"
   ```

3. **Access custom domain:**
   ```bash
   # Open in browser
   open https://redis.mycompany.local
   ```

See `tls-setup/README.md` for detailed instructions.

## 🎯 Demo Script

### 1. Show the Git Repository
- Show this directory structure
- Explain: "Everything is defined as code in Git"
- Highlight: Namespace → Cluster → Databases → Custom Certificate

### 2. Create the ArgoCD Application
```bash
oc apply -f demo-gitops-argocd/argocd-application.yaml
```

### 3. Open ArgoCD UI
- Show the application being created
- Show the sync waves (resources created in order):
  - Wave 0: Namespace
  - Wave 1: Cluster
  - Wave 2: Databases
  - Wave 3: Custom Certificate
- Show the health status

### 4. Show the Resources Created
```bash
# Show namespace
oc get namespace redis-demo

# Show cluster
oc get rec -n redis-demo

# Show databases
oc get redb -n redis-demo

# Show routes
oc get route -n redis-demo
```

### 5. Make a Change (GitOps in Action)
Edit `03-database-orders.yaml` and change memory size:
```yaml
memorySize: 200MB  # Change from 100MB to 200MB
```

Commit and push:
```bash
git add .
git commit -m "Increase orders database memory"
git push
```

Watch ArgoCD detect the change and sync automatically!

### 6. Show Custom Domain (Optional)
```bash
# Generate certificates
cd tls-setup && ./generate-certs.sh

# Show certificate details
openssl x509 -in certs/redis-ui.crt -noout -text | grep -A2 "Subject:"

# Access custom domain
open https://redis.mycompany.local
```

### 7. Show Database Connection
```bash
# Get database password
oc get secret redb-customers -n redis-demo -o jsonpath='{.data.password}' | base64 -d

# Connect to database
CLUSTER_POD=$(oc get pods -n redis-demo -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}')
oc exec -it $CLUSTER_POD -n redis-demo -- redis-cli -h redb-customers -a <password>
```

## 🎓 Key Concepts to Explain

1. **GitOps**: Git is the single source of truth
2. **Declarative**: We declare what we want, not how to do it
3. **Sync Waves**: Control the order of resource creation
4. **Self-Healing**: ArgoCD automatically fixes drift
5. **Automated Sync**: Changes in Git automatically deploy

## 🧹 Cleanup

```bash
# Delete the ArgoCD application (this deletes everything)
oc delete application redis-demo -n openshift-gitops

# Or delete manually
oc delete -f demo-gitops-argocd/
```

