# Quick Start Guide

Get the Redis Enterprise GitOps demo running in 10 minutes using Kustomize overlays!

## Prerequisites Check

Before starting, ensure you have:

- [ ] OpenShift 4.x cluster access
- [ ] `oc` CLI installed and logged in
- [ ] Redis Enterprise Operator installed
- [ ] OpenShift GitOps (Argo CD) installed and configured
- [ ] Git repository (fork or clone this repo)

See [docs/PREREQUISITES.md](docs/PREREQUISITES.md) for detailed requirements.

> **New to OpenShift GitOps?** Check out the [OpenShift GitOps Setup Guide](docs/OPENSHIFT_GITOPS_SETUP.md) for complete installation and configuration instructions.

## Step 1: Clone and Configure (2 minutes)

```bash
# Clone your fork/copy of this repository
git clone https://github.com/your-org/poc-gitops.git
cd poc-gitops

# Update the Argo CD Application with your repository URL
sed -i 's|https://github.com/your-org/poc-gitops.git|YOUR_REPO_URL|g' argocd/orders-redis-dev-app.yaml

# Find your storage class
oc get storageclass

# Update the storage class in the base REC manifest
# Edit orders-redis/base/rec.yaml
# Change storageClassName to match your cluster
```

## Step 2: Grant Argo CD Permissions (1 minute)

```bash
# Allow Argo CD to deploy into the target namespace
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n orders-redis-dev
```

## Step 3: Commit and Push (1 minute)

```bash
# Commit your configuration changes
git add .
git commit -m "Configure repository URL and storage class"
git push origin main
```

## Step 4: Deploy with Argo CD (1 minute)

```bash
# Apply the Argo CD Application
oc apply -f argocd/orders-redis-dev-app.yaml

# Verify the Application was created
oc get application orders-redis-dev -n openshift-gitops
```

## Step 5: Monitor Deployment (5 minutes)

```bash
# Watch the Application sync
oc get application orders-redis-dev -n openshift-gitops -w

# In another terminal, watch the pods come up
oc get pods -n orders-redis-dev -w
```

Expected pods:
- `orders-redis-cluster-0` (Redis Enterprise node 1)
- `orders-redis-cluster-1` (Redis Enterprise node 2)
- `orders-redis-cluster-2` (Redis Enterprise node 3)
- `orders-redis-cluster-services-rigger-*` (Services controller)
- `redis-enterprise-operator-*` (Operator)

## Step 6: Verify Deployment

```bash
# Check namespace
oc get ns orders-redis-dev

# Check Redis Enterprise Cluster
oc get redisenterprisecluster -n orders-redis-dev

# Check Redis Enterprise Database
oc get redisenterprisedatabase -n orders-redis-dev

# Get detailed status
oc describe redisenterprisecluster orders-redis-cluster -n orders-redis-dev
oc describe redisenterprisedatabase orders-cache-dev -n orders-redis-dev
```

Look for:
- Cluster status: `Running`
- Database status: `active`

## Step 7: Test the Database

```bash
# Create a test pod with redis-cli
oc run redis-cli --image=redis:latest -n orders-redis-dev --rm -it -- bash

# Inside the pod, connect to the database
redis-cli -h orders-cache-dev -p 12000

# Test some commands
PING
SET demo "Hello from GitOps!"
GET demo
INFO server
EXIT

# Exit the pod
exit
```

## Step 8: View in Argo CD UI (Optional)

```bash
# Get the Argo CD route
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Get the admin password
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-

# Open the URL in your browser and log in
# You should see the 'orders-redis-dev' application
```

## Success! 🎉

You now have:
- ✅ Redis Enterprise cluster with 3 nodes
- ✅ Redis database (orders-cache-dev) on port 12000
- ✅ GitOps workflow with Argo CD
- ✅ Automatic sync from Git to cluster

## Next Steps

### Try GitOps Workflow

1. **Add a new database**:
   ```bash
   # Create a new database file
   cat > orders-redis-dev/redb-session-store-dev.yaml <<EOF
   apiVersion: app.redislabs.com/v1
   kind: RedisEnterpriseDatabase
   metadata:
     name: session-store-dev
     namespace: orders-redis-dev
   spec:
     memorySize: 512MB
     replication: true
     persistence: disabled
     databasePort: 12001
     tlsMode: disabled
   EOF
   
   # Add to kustomization
   echo "  - redb-session-store-dev.yaml" >> orders-redis-dev/kustomization.yaml
   
   # Commit and push
   git add orders-redis-dev/
   git commit -m "Add session-store-dev database"
   git push origin main
   
   # Watch Argo CD create the new database
   oc get redisenterprisedatabase -n orders-redis-dev -w
   ```

2. **Modify database configuration**:
   ```bash
   # Edit the database manifest
   # Change memorySize from 1GB to 2GB
   sed -i 's/memorySize: 1GB/memorySize: 2GB/' orders-redis-dev/redb-orders-cache-dev.yaml
   
   # Commit and push
   git add orders-redis-dev/redb-orders-cache-dev.yaml
   git commit -m "Increase cache memory to 2GB"
   git push origin main
   
   # Verify the change
   oc get redisenterprisedatabase orders-cache-dev -n orders-redis-dev -o yaml | grep memorySize
   ```

### Explore Multi-Environment Pattern

```bash
# Deploy the dev overlay (alternative pattern)
oc apply -f argocd/orders-redis-dev-overlay-app.yaml

# This deploys the same resources but using Kustomize overlays
# See orders-redis/ directory for the structure
```

### Learn More

- [Full Deployment Guide](docs/DEPLOYMENT.md)
- [Operations Guide](docs/OPERATIONS.md)
- [Multi-Environment Pattern](orders-redis/README.md)
- [CI Validation](ci/README.md)

## Troubleshooting

### Application Not Syncing

```bash
# Check Application status
oc describe application orders-redis-dev -n openshift-gitops

# Check Argo CD logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller --tail=50
```

### Cluster Not Starting

```bash
# Check operator logs
oc logs -n openshift-operators -l name=redis-enterprise-operator --tail=50

# Check events
oc get events -n orders-redis-dev --sort-by='.lastTimestamp'

# Check PVCs
oc get pvc -n orders-redis-dev
```

### Database Not Creating

```bash
# Ensure cluster is running first
oc get redisenterprisecluster -n orders-redis-dev

# Check database status
oc describe redisenterprisedatabase orders-cache-dev -n orders-redis-dev
```

## Clean Up

To remove the demo:

```bash
# Delete the Argo CD Application (this will delete all resources)
oc delete application orders-redis-dev -n openshift-gitops

# Verify namespace is deleted
oc get ns orders-redis-dev
```

## Support

For issues or questions:
- Check the [documentation](docs/)
- Review [Redis Enterprise documentation](https://redis.io/docs/latest/operate/kubernetes/)
- Check [OpenShift GitOps documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)

