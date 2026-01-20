# Quick Start Guide

This guide shows you how to quickly add new clusters and databases using the cluster-centric structure.

## 🚀 Add a New Cluster

### Step 1: Create Directory Structure

```bash
# Replace {cluster-name} with your cluster name (e.g., payments, inventory)
CLUSTER_NAME="payments"

mkdir -p clusters/${CLUSTER_NAME}/databases
```

### Step 2: Create Cluster Configuration

```bash
# Copy template from orders cluster
cp clusters/orders/cluster.yaml clusters/${CLUSTER_NAME}/cluster.yaml

# Edit the file and update:
# - cluster.name: payments
# - namespace: redis-payments-enterprise
# - cluster.team: payments-team
# - redis.clusterName: payments-redis-cluster
# - Adjust resources if needed
```

### Step 3: Create Argo CD Application

```bash
# Copy template
cp clusters/orders/argocd-cluster.yaml clusters/${CLUSTER_NAME}/argocd-cluster.yaml

# Edit the file and update:
# - metadata.name: redis-cluster-payments
# - metadata.labels.cluster: payments
# - spec.source.helm.valueFiles: ../../clusters/payments/cluster.yaml
# - spec.destination.namespace: redis-payments-enterprise
```

### Step 4: Install Operator

```bash
# Install Redis Enterprise Operator via OpenShift OperatorHub
# Namespace: redis-payments-enterprise
# This is done manually via OpenShift Console
```

### Step 5: Deploy Cluster

```bash
# Apply the Argo CD Application
oc apply -f clusters/${CLUSTER_NAME}/argocd-cluster.yaml

# Monitor deployment
oc get application redis-cluster-${CLUSTER_NAME} -n openshift-gitops -w

# Check cluster status
oc get redisenterprisecluster -n redis-${CLUSTER_NAME}-enterprise -w
```

### Step 6: Create README (Optional but Recommended)

```bash
# Copy template
cp clusters/orders/README.md clusters/${CLUSTER_NAME}/README.md

# Edit with your cluster information
```

---

## 📊 Add a New Database to Existing Cluster

### Step 1: Create Database Directory

```bash
CLUSTER_NAME="orders"
DB_NAME="analytics"
DB_TYPE="persistent"  # cache, session, or persistent

# Navigate to cluster databases directory
cd clusters/${CLUSTER_NAME}/databases/

# Create database directory
mkdir ${DB_NAME}
```

### Step 2: Create Database Configurations

```bash
# Create dev config
cp cache/dev.yaml ${DB_NAME}/dev.yaml

# Edit dev.yaml and update:
# - database.name: orders-analytics
# - database.env: dev
# - database.type: persistent
# - redis.memorySize: 2GB
# - redis.databasePort: 12002 (increment from last port)
# - redis.persistence: aofEverySecond (for persistent)
# - redis.tlsMode: disabled (dev)

# Create prod config
cp cache/prod.yaml ${DB_NAME}/prod.yaml

# Edit prod.yaml and update:
# - database.name: orders-analytics
# - database.env: prod
# - database.type: persistent
# - redis.memorySize: 8GB
# - redis.databasePort: 12002
# - redis.persistence: aofEverySecond
# - redis.tlsMode: enabled (prod)
# - redis.shardCount: 2
```

### Step 3: Create Argo CD Applications

```bash
# Create dev Application
cp cache/argocd-dev.yaml ${DB_NAME}/argocd-dev.yaml

# Edit argocd-dev.yaml and update:
# - metadata.name: redb-orders-analytics-dev
# - metadata.labels.database: orders-analytics
# - spec.source.helm.valueFiles:
#   - values-persistent.yaml (change from values-cache.yaml)
#   - ../../../../clusters/orders/databases/analytics/dev.yaml

# Create prod Application
cp cache/argocd-prod.yaml ${DB_NAME}/argocd-prod.yaml

# Edit argocd-prod.yaml and update:
# - metadata.name: redb-orders-analytics-prod
# - metadata.labels.database: orders-analytics
# - metadata.labels.env: prod
# - spec.source.helm.valueFiles:
#   - values-persistent.yaml
#   - ../../../../clusters/orders/databases/analytics/prod.yaml
```

### Step 4: Deploy Database

```bash
# Deploy dev
oc apply -f ${DB_NAME}/argocd-dev.yaml

# Deploy prod
oc apply -f ${DB_NAME}/argocd-prod.yaml

# Monitor deployment
oc get application -n openshift-gitops | grep analytics

# Check database status
oc get redisenterprisedatabase -n redis-${CLUSTER_NAME}-enterprise
```

---

## 🎯 Database Types and Presets

### Cache Database (Volatile, No Persistence)

```yaml
# Use: values-cache.yaml
redis:
  memorySize: 1GB
  replication: true
  persistence: disabled
  tlsMode: disabled
  evictionPolicy: volatile-lru
  shardCount: 1
```

**Use case**: Application cache, temporary data

### Session Database (Volatile with TTL)

```yaml
# Use: values-session.yaml
redis:
  memorySize: 512MB
  replication: true
  persistence: disabled
  tlsMode: disabled
  evictionPolicy: volatile-ttl
  shardCount: 1
```

**Use case**: User sessions, temporary tokens

### Persistent Database (Durable, AOF)

```yaml
# Use: values-persistent.yaml
redis:
  memorySize: 2GB
  replication: true
  persistence: aofEverySecond
  tlsMode: enabled
  evictionPolicy: noeviction
  shardCount: 2
```

**Use case**: Critical data, queues, durable storage

---

## 📝 Port Assignment Strategy

Each database needs a unique port within the cluster:

| Database | Port | Type |
|----------|------|------|
| orders-cache-dev | 12000 | Cache |
| session-store-dev | 12001 | Session |
| orders-analytics-dev | 12002 | Persistent |
| orders-queue-dev | 12003 | Persistent |

**Rule**: Increment port number for each new database in the cluster.

---

## 🔍 Verify Deployment

### Check Argo CD Application

```bash
oc get application -n openshift-gitops | grep redis
```

### Check Cluster Status

```bash
oc get rec -n redis-orders
```

### Check Database Status

```bash
oc get redb -A | grep redis-orders
```

### Check Routes

```bash
oc get routes -n redis-orders
oc get routes -n redis-orders-dev
oc get routes -n redis-orders-prod
```

---

## 🎓 Examples

### Example 1: Add Payments Cluster

```bash
# Create structure
mkdir -p clusters/payments/databases/{dev,prod}

# Copy and edit configs
cp clusters/orders/cluster.yaml clusters/payments/cluster.yaml
cp clusters/orders/argocd-cluster.yaml clusters/payments/argocd-cluster.yaml

# Edit files (update names, namespaces, teams)
# Install operator via OperatorHub
# Deploy
oc apply -f clusters/payments/argocd-cluster.yaml
```

### Example 2: Add Analytics Database to Orders

```bash
cd clusters/orders/databases/dev/

# Create database config
cp cache.yaml analytics.yaml
# Edit: name=orders-analytics, port=12002, memory=4GB, type=persistent

# Create Argo CD Application
cp argocd-cache.yaml argocd-analytics.yaml
# Edit: name, valueFiles (use values-persistent.yaml)

# Deploy
oc apply -f argocd-analytics.yaml
```

---

## 📚 Next Steps

- Read [Helm Architecture](HELM_ARCHITECTURE.md) for detailed architecture
- Read [Onboarding Guide](ONBOARDING_GUIDE.md) for team onboarding
- Check [clusters/README.md](../clusters/README.md) for cluster organization

