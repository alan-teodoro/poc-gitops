# Redis Enterprise GitOps on OpenShift

GitOps-based management of Redis Enterprise on Red Hat OpenShift using Argo CD and Helm.

## 📋 Overview

This repository demonstrates enterprise-scale Redis deployment using:

- **Helm charts** for templating and reusability
- **Cluster-centric organization** for managing hundreds of databases
- **GitOps** with Argo CD for automated deployment
- **One operator per cluster** for isolation and scalability

## 🏗️ Repository Structure

```
.
├── README.md                           # This file
│
├── docs/                               # Documentation
│   ├── HELM_ARCHITECTURE.md            # Architecture overview
│   └── QUICK_START.md                  # Quick start guide
│
├── helm-charts/                        # Reusable Helm charts
│   ├── redis-enterprise-cluster/       # Chart for Redis Enterprise Cluster
│   │   ├── Chart.yaml
│   │   ├── values.yaml                 # Default values
│   │   └── templates/
│   │       ├── namespace.yaml
│   │       ├── rec.yaml
│   │       └── route-ui.yaml
│   │
│   └── redis-enterprise-database/      # Chart for Redis Enterprise Database
│       ├── Chart.yaml
│       ├── values.yaml                 # Default values
│       ├── values-cache.yaml           # Preset: cache (volatile-lru)
│       ├── values-session.yaml         # Preset: session (volatile-ttl)
│       ├── values-persistent.yaml      # Preset: persistent (AOF, TLS)
│       └── templates/
│           ├── redb.yaml
│           └── route.yaml
│
└── clusters/                           # Cluster-centric organization
    ├── README.md                       # Clusters overview
    └── orders/                         # Everything for Orders cluster
        ├── README.md                   # Cluster documentation
        ├── cluster.yaml                # Cluster configuration
        ├── argocd-cluster.yaml         # Argo CD Application
        └── databases/                  # Organized by database
            ├── cache/                  # Cache database (all environments)
            │   ├── dev.yaml           # Dev config
            │   ├── prod.yaml          # Prod config
            │   ├── argocd-dev.yaml    # Argo CD App for dev
            │   └── argocd-prod.yaml   # Argo CD App for prod
            └── session/                # Session database (all environments)
                ├── dev.yaml
                ├── prod.yaml
                ├── argocd-dev.yaml
                └── argocd-prod.yaml
```

## 🎯 Key Design Principles

### 1. Cluster-Centric Organization
Everything related to a cluster lives in one directory:
- Cluster configuration
- All databases (dev, prod)
- Argo CD Applications
- Documentation

**Benefits**: Easy to find resources, clear ownership, scales to 500+ databases.

### 2. Helm for Templating
Reusable charts with environment-specific values:
- `helm-charts/` = Generic templates
- `clusters/{name}/` = Specific values

**Benefits**: DRY principle, consistent deployments, easy to scale.

### 3. One Operator Per Cluster
Each cluster has its own operator in its own namespace:
- Namespace: `redis-{cluster-name}-enterprise`
- Operator watches only its namespace
- Complete isolation between clusters

**Benefits**: Blast radius control, independent upgrades, multi-team support.

## 🚀 Quick Start

### Prerequisites

1. **OpenShift 4.x cluster** with storage class
2. **OpenShift GitOps (Argo CD)** installed
3. **Redis Enterprise Operator** installed via OperatorHub in namespace `redis-orders`
4. **CLI tools**: `oc`, `git`, `helm` (optional)

### Deploy Orders Cluster

1. **Fork/clone this repository**

2. **Update Git repository URL** in Argo CD Applications:
   ```bash
   # Update all argocd-*.yaml files
   find clusters/orders -name "argocd-*.yaml" -exec sed -i '' \
     's|https://github.com/alan-teodoro/poc-gitops.git|YOUR_REPO_URL|g' {} \;
   ```

3. **Grant Argo CD permissions**:
   ```bash
   oc adm policy add-role-to-user admin \
     system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
     -n redis-orders
   ```

4. **Deploy cluster**:
   ```bash
   oc apply -f clusters/orders/argocd-cluster.yaml
   ```

5. **Deploy databases**:
   ```bash
   # Dev databases
   oc apply -f clusters/orders/databases/cache/argocd-dev.yaml
   oc apply -f clusters/orders/databases/session/argocd-dev.yaml

   # Prod databases (optional)
   oc apply -f clusters/orders/databases/cache/argocd-prod.yaml
   oc apply -f clusters/orders/databases/session/argocd-prod.yaml
   ```

6. **Verify deployment**:
   ```bash
   # Check Applications
   oc get applications -n openshift-gitops | grep redis

   # Check cluster
   oc get rec -n redis-orders

   # Check databases
   oc get redb -A | grep redis-orders

   # Check routes
   oc get routes -n redis-orders
   ```

See [docs/QUICK_START.md](docs/QUICK_START.md) for detailed instructions.

## 📚 Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Add clusters and databases step-by-step
- **[Helm Architecture](docs/HELM_ARCHITECTURE.md)** - Architecture overview and design decisions
- **[Clusters README](clusters/README.md)** - Cluster organization and structure

## 🔄 Common Operations

### Add a New Cluster

```bash
# 1. Create directory structure
mkdir -p clusters/payments/databases/{dev,prod}

# 2. Copy and edit cluster config
cp clusters/orders/cluster.yaml clusters/payments/cluster.yaml
# Edit: cluster name, namespace, team, resources

# 3. Copy and edit Argo CD Application
cp clusters/orders/argocd-cluster.yaml clusters/payments/argocd-cluster.yaml
# Edit: name, labels, valueFiles path

# 4. Install operator via OperatorHub in namespace: redis-payments

# 5. Deploy
oc apply -f clusters/payments/argocd-cluster.yaml
```

### Add a New Database

```bash
# 1. Navigate to cluster databases directory
cd clusters/orders/databases/

# 2. Create database directory
mkdir analytics

# 3. Create dev config
cp cache/dev.yaml analytics/dev.yaml
# Edit: name, port, memory, type

# 4. Create prod config
cp cache/prod.yaml analytics/prod.yaml
# Edit: name, port, memory, type

# 5. Create Argo CD Applications
cp cache/argocd-dev.yaml analytics/argocd-dev.yaml
cp cache/argocd-prod.yaml analytics/argocd-prod.yaml
# Edit: metadata.name, valueFiles paths

# 6. Deploy
oc apply -f analytics/argocd-dev.yaml
oc apply -f analytics/argocd-prod.yaml
```

See [docs/QUICK_START.md](docs/QUICK_START.md) for detailed examples.

## 🎯 Architecture Highlights

### Cluster-Centric Organization
```
clusters/orders/          # Everything for Orders cluster
├── cluster.yaml         # Cluster config (3 nodes, 4GB RAM)
├── argocd-cluster.yaml  # Argo CD Application
└── databases/           # Organized by database
    ├── cache/           # Cache database (all environments)
    │   ├── dev.yaml            # 1GB, port 12000
    │   ├── prod.yaml           # 4GB, port 12000, AOF, TLS
    │   ├── argocd-dev.yaml     # Argo CD App for dev
    │   └── argocd-prod.yaml    # Argo CD App for prod
    └── session/         # Session database (all environments)
        ├── dev.yaml
        ├── prod.yaml
        ├── argocd-dev.yaml
        └── argocd-prod.yaml
```

**Benefits**:
- ✅ Easy to find all environments of a database
- ✅ Easy to compare dev vs prod configurations
- ✅ Only 4 files per database (not 100 files in one directory)
- ✅ Clear team ownership (one cluster directory per team)

### Helm + Values Pattern
```
helm-charts/redis-enterprise-database/  # Generic template
    + values-cache.yaml                 # Preset (volatile-lru)
    + clusters/orders/databases/dev/cache.yaml  # Specific values
    = Final Kubernetes manifest
```

**Benefits**:
- ✅ DRY: One template for all databases
- ✅ Consistency: Presets ensure best practices
- ✅ Flexibility: Override any value per database

### One Operator Per Cluster
```
redis-orders/                # Namespace
├── operator                 # Dedicated operator
├── orders-redis-cluster     # REC
└── RBAC configuration       # Multi-namespace support

redis-orders-dev/            # Dev databases namespace
└── databases (REDBs)

redis-orders-prod/           # Prod databases namespace
└── databases (REDBs)
```

**Benefits**:
- ✅ Isolation: Operator failure doesn't affect other clusters
- ✅ Independent upgrades: Upgrade operators separately
- ✅ Multi-team: Each team manages their own cluster

## 🔗 References

- [Redis Enterprise for Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)
- [OpenShift GitOps](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)
- [Argo CD](https://argo-cd.readthedocs.io/)
- [Helm](https://helm.sh/docs/)

## 📝 License

Educational demonstration project.

