# Redis Enterprise Clusters

This directory contains **all Redis Enterprise clusters** and their databases.

## 📁 Structure

Each cluster has its own directory with **everything related to that cluster**:

```
clusters/
├── orders/                      # Orders cluster
│   ├── cluster.yaml            # Cluster configuration
│   ├── argocd-cluster.yaml     # Argo CD Application
│   └── databases/              # Organized by database
│       ├── cache/              # Cache database (all environments)
│       │   ├── dev.yaml
│       │   ├── prod.yaml
│       │   ├── argocd-dev.yaml
│       │   └── argocd-prod.yaml
│       └── session/            # Session database (all environments)
│           ├── dev.yaml
│           ├── prod.yaml
│           ├── argocd-dev.yaml
│           └── argocd-prod.yaml
│
├── payments/                    # Payments cluster
│   ├── cluster.yaml
│   ├── argocd-cluster.yaml
│   └── databases/
│       └── cache/
│           ├── dev.yaml
│           └── prod.yaml
│
└── inventory/                   # Inventory cluster
    ├── cluster.yaml
    └── databases/
        └── cache/
```

## 🎯 Design Principles

### 1. **Cluster-Centric Organization**
- ✅ Everything for a cluster in one directory
- ✅ Easy to find all related resources
- ✅ Scales to hundreds of databases per cluster
- ✅ Clear ownership boundaries

### 2. **Self-Contained**
- ✅ Each cluster directory is independent
- ✅ Can be managed by different teams
- ✅ Easy to add/remove entire clusters

### 3. **Consistent Structure**
- ✅ Same structure for all clusters
- ✅ Predictable file locations
- ✅ Easy onboarding for new teams

## 📊 Current Clusters

| Cluster | Namespace | Team | Nodes | Databases | Status |
|---------|-----------|------|-------|-----------|--------|
| orders | redis-orders-enterprise | orders-team | 3 | 2 dev, 2 prod | ✅ Active |
| payments | redis-payments-enterprise | payments-team | - | - | 📝 Planned |
| inventory | redis-inventory-enterprise | inventory-team | - | - | 📝 Planned |

## 🚀 Adding a New Cluster

### Step 1: Create Directory Structure

```bash
# Create cluster directory
mkdir -p clusters/{cluster-name}/databases/dev
mkdir -p clusters/{cluster-name}/databases/prod
```

### Step 2: Create Cluster Configuration

```bash
# Copy template
cp clusters/orders/cluster.yaml clusters/{cluster-name}/cluster.yaml

# Edit configuration
# - Update cluster.name
# - Update namespace
# - Update team
# - Adjust resources
```

### Step 3: Create Argo CD Application

```bash
# Copy template
cp clusters/orders/argocd-cluster.yaml clusters/{cluster-name}/argocd-cluster.yaml

# Edit Application
# - Update metadata.name
# - Update labels
# - Update valueFiles path
```

### Step 4: Install Operator

```bash
# Install Redis Enterprise Operator via OperatorHub
# Namespace: redis-{cluster-name}-enterprise
```

### Step 5: Deploy

```bash
# Apply cluster Application
oc apply -f clusters/{cluster-name}/argocd-cluster.yaml

# Monitor
oc get application redis-cluster-{cluster-name} -n openshift-gitops -w
```

## 📝 Adding a Database to Existing Cluster

```bash
# Navigate to cluster databases directory
cd clusters/{cluster-name}/databases/

# Create database directory
mkdir analytics

# Create dev config
cp cache/dev.yaml analytics/dev.yaml
# Edit: name, port, memory

# Create prod config
cp cache/prod.yaml analytics/prod.yaml
# Edit: name, port, memory

# Create Argo CD Applications
cp cache/argocd-dev.yaml analytics/argocd-dev.yaml
cp cache/argocd-prod.yaml analytics/argocd-prod.yaml
# Edit: metadata.name, valueFiles paths

# Deploy
oc apply -f analytics/argocd-dev.yaml
oc apply -f analytics/argocd-prod.yaml
```

## 🔍 Finding Resources

### Find all databases for a cluster
```bash
ls clusters/orders/databases/
# Output: cache/ session/ analytics/
```

### Find all environments for a database
```bash
ls clusters/orders/databases/cache/
# Output: dev.yaml prod.yaml argocd-dev.yaml argocd-prod.yaml
```

### Find all dev configs across clusters
```bash
find clusters -name "dev.yaml" -path "*/databases/*"
```

### Find all Argo CD Applications
```bash
find clusters -name "argocd-*.yaml"
```

## 📚 Documentation

- [Helm Architecture](../docs/HELM_ARCHITECTURE.md)
- [Onboarding Guide](../docs/ONBOARDING_GUIDE.md)
- [Migration Guide](../docs/MIGRATION_GUIDE.md)

## 🎯 Benefits of This Structure

### For 500 Databases Across 50 Clusters

**Old Structure** (Bad):
```
databases/
├── cluster1-db1.yaml
├── cluster1-db2.yaml
├── cluster2-db1.yaml
...
└── cluster50-db500.yaml  # 😱 500 files in one directory!
```

**New Structure** (Good):
```
clusters/
├── cluster1/databases/dev/  # 10 databases
├── cluster2/databases/dev/  # 10 databases
...
└── cluster50/databases/dev/ # 10 databases
```

✅ **Easy to navigate**: Find cluster, then find database  
✅ **Team ownership**: Each team owns their cluster directory  
✅ **Scalable**: 10 files per directory instead of 500  
✅ **Maintainable**: Changes isolated to cluster directory  

## 🔐 Access Control

Each cluster directory can have different RBAC:

```bash
# Orders team can only modify orders/
# Payments team can only modify payments/
# Platform team can modify all
```

## 📊 Monitoring

Each cluster directory can have its own:
- Monitoring dashboards
- Alert rules
- SLOs/SLIs
- Runbooks

Add them to the cluster directory for easy access.

