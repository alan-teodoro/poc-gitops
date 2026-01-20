# Redis Enterprise Clusters

This directory contains **all Redis Enterprise clusters** and their databases.

## 📁 Structure

Each cluster has its own directory with **everything related to that cluster**:

```
clusters/
├── orders/                      # Orders cluster
│   ├── cluster.yaml            # Cluster configuration
│   ├── argocd-cluster.yaml     # Argo CD Application
│   └── databases/              # All databases for this cluster
│       ├── dev/
│       │   ├── cache.yaml
│       │   └── argocd-cache.yaml
│       └── prod/
│           └── cache.yaml
│
├── payments/                    # Payments cluster
│   ├── cluster.yaml
│   ├── argocd-cluster.yaml
│   └── databases/
│       └── dev/
│
└── inventory/                   # Inventory cluster
    ├── cluster.yaml
    └── databases/
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
# Navigate to cluster directory
cd clusters/{cluster-name}/databases/{env}/

# Create database config
cp cache.yaml new-db.yaml
# Edit configuration

# Create Argo CD Application
cp argocd-cache.yaml argocd-new-db.yaml
# Edit Application

# Apply
oc apply -f argocd-new-db.yaml
```

## 🔍 Finding Resources

### Find all databases for a cluster
```bash
ls clusters/orders/databases/dev/
ls clusters/orders/databases/prod/
```

### Find all dev databases across clusters
```bash
find clusters -path "*/databases/dev/*.yaml" -not -name "argocd-*"
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

