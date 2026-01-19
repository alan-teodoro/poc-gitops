# Deployment Guide

This guide provides step-by-step instructions for deploying the Redis Enterprise GitOps demo on OpenShift.

## Prerequisites

Ensure all prerequisites from [PREREQUISITES.md](PREREQUISITES.md) are met before proceeding.

## Deployment Options

This repository provides two deployment patterns:

1. **Single-Environment Demo** (`orders-redis-dev/`) - Recommended for first-time users
2. **Multi-Environment Pattern** (`orders-redis/`) - Shows base + overlays structure

This guide covers both options.

---

## Option 1: Single-Environment Demo

This is the simplest way to get started with the demo.

### Step 1: Prepare Your Repository

1. **Fork or clone this repository**:
   ```bash
   git clone <your-repo-url>
   cd poc-gitops
   ```

2. **Update the Git repository URL** in the Argo CD Application:
   ```bash
   # Edit argocd/orders-redis-dev-app.yaml
   # Change spec.source.repoURL to your repository URL
   ```

### Step 2: Configure Storage Class

1. **Identify your storage class**:
   ```bash
   oc get storageclass
   ```

2. **Update the REC manifest**:
   ```bash
   # Edit orders-redis-dev/rec-orders-redis-cluster.yaml
   # Update spec.storageClassName to match your cluster
   ```

   Example:
   ```yaml
   spec:
     storageClassName: ocs-storagecluster-ceph-rbd  # Change this
   ```

### Step 3: Commit and Push Changes

```bash
git add .
git commit -m "Configure repository URL and storage class"
git push origin main
```

### Step 4: Deploy with Argo CD

1. **Apply the Argo CD Application**:
   ```bash
   oc apply -f argocd/orders-redis-dev-app.yaml
   ```

2. **Verify the Application is created**:
   ```bash
   oc get application -n openshift-gitops
   ```

3. **Watch Argo CD sync the resources**:
   ```bash
   # Via CLI
   oc get application orders-redis-dev -n openshift-gitops -w
   
   # Or via Argo CD UI
   # Navigate to the Argo CD web console
   ```

### Step 5: Verify Deployment

1. **Check namespace**:
   ```bash
   oc get ns orders-redis-dev
   ```

2. **Check Redis Enterprise Cluster**:
   ```bash
   oc get redisenterprisecluster -n orders-redis-dev
   oc describe redisenterprisecluster orders-redis-cluster -n orders-redis-dev
   ```

   Wait for the cluster to show `Running` state.

3. **Check Redis Enterprise Database**:
   ```bash
   oc get redisenterprisedatabase -n orders-redis-dev
   oc describe redisenterprisedatabase orders-cache-dev -n orders-redis-dev
   ```

4. **Check pods**:
   ```bash
   oc get pods -n orders-redis-dev
   ```

   You should see:
   - 3 Redis Enterprise cluster pods (e.g., `orders-redis-cluster-0`, `orders-redis-cluster-1`, `orders-redis-cluster-2`)
   - Redis Enterprise operator pod
   - Services controller pod

### Step 6: Access Redis Database

1. **Get database connection details**:
   ```bash
   oc get redisenterprisedatabase orders-cache-dev -n orders-redis-dev -o yaml
   ```

   Look for:
   - `status.databasePort` - The port to connect to
   - Service name (typically `<database-name>`)

2. **Test connection** (from within the cluster):
   ```bash
   # Create a test pod
   oc run redis-cli --image=redis:latest -n orders-redis-dev --rm -it -- bash
   
   # Inside the pod, connect to Redis
   redis-cli -h orders-cache-dev -p 12000
   
   # Test commands
   PING
   SET test "Hello from GitOps"
   GET test
   ```

---

## Option 2: Multi-Environment Pattern

This pattern uses Kustomize overlays for multiple environments.

### Step 1: Prepare Repository

Same as Option 1, Step 1.

### Step 2: Configure Storage Class

Update storage class in the base configuration:
```bash
# Edit orders-redis/base/rec.yaml
# Update spec.storageClassName
```

### Step 3: Choose Environment to Deploy

You can deploy one or more environments:

- **Development**: `argocd/orders-redis-dev-overlay-app.yaml`
- **Non-Production**: `argocd/orders-redis-nonprod-app.yaml`
- **Production**: `argocd/orders-redis-prod-app.yaml`

### Step 4: Update Argo CD Application(s)

Edit the Application manifest(s) for your chosen environment(s):
```bash
# Example for dev
# Edit argocd/orders-redis-dev-overlay-app.yaml
# Update spec.source.repoURL
```

### Step 5: Commit and Deploy

```bash
git add .
git commit -m "Configure multi-environment deployment"
git push origin main

# Deploy chosen environment(s)
oc apply -f argocd/orders-redis-dev-overlay-app.yaml
# oc apply -f argocd/orders-redis-nonprod-app.yaml
# oc apply -f argocd/orders-redis-prod-app.yaml
```

### Step 6: Verify Deployment

Similar to Option 1, but check the appropriate namespace:
```bash
# For dev overlay
oc get all -n orders-redis-dev

# For nonprod overlay
oc get all -n orders-redis-nonprod

# For prod overlay
oc get all -n orders-redis-prod
```

---

## Troubleshooting

### Argo CD Application Not Syncing

1. **Check Application status**:
   ```bash
   oc describe application orders-redis-dev -n openshift-gitops
   ```

2. **Check Argo CD logs**:
   ```bash
   oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
   ```

3. **Verify repository access**:
   - Ensure Argo CD can access your Git repository
   - For private repos, configure credentials in Argo CD

### Redis Enterprise Cluster Not Starting

1. **Check operator logs**:
   ```bash
   oc logs -n openshift-operators -l name=redis-enterprise-operator
   ```

2. **Check cluster events**:
   ```bash
   oc get events -n orders-redis-dev --sort-by='.lastTimestamp'
   ```

3. **Verify storage**:
   ```bash
   oc get pvc -n orders-redis-dev
   ```

### Database Not Creating

1. **Check database status**:
   ```bash
   oc describe redisenterprisedatabase orders-cache-dev -n orders-redis-dev
   ```

2. **Verify cluster is ready**:
   ```bash
   oc get redisenterprisecluster -n orders-redis-dev
   ```

   Cluster must be in `Running` state before databases can be created.

## Next Steps

Once deployment is complete, proceed to [OPERATIONS.md](OPERATIONS.md) to learn about day-2 operations and GitOps workflows.

