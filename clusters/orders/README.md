# Orders Redis Enterprise Cluster

This directory contains **all configuration** for the Orders Redis Enterprise cluster.

## 📁 Structure

```
orders/
├── README.md                    # This file
├── cluster.yaml                 # Cluster configuration (REC)
├── argocd-cluster.yaml         # Argo CD Application for cluster
└── databases/                   # Organized by database
    ├── cache/                   # Cache database (all environments)
    │   ├── dev.yaml            # Dev configuration
    │   ├── prod.yaml           # Prod configuration
    │   ├── argocd-dev.yaml     # Argo CD App for dev
    │   └── argocd-prod.yaml    # Argo CD App for prod
    └── session/                 # Session database (all environments)
        ├── dev.yaml
        ├── prod.yaml
        ├── argocd-dev.yaml
        └── argocd-prod.yaml
```

**Why organized by database?**
- ✅ Easy to see all environments of a database in one place
- ✅ Easy to compare dev vs prod configurations
- ✅ Only 4 files per database (not 100 files in one directory)
- ✅ Logical: "I want to see cache database" → `databases/cache/`

## 🎯 Cluster Information

- **Cluster Name**: `orders-redis-cluster`
- **Namespace**: `redis-orders-enterprise`
- **Team**: orders-team
- **Datacenter**: dc1
- **Nodes**: 3
- **Storage**: 50Gi (dev), 100Gi (prod)

## 📊 Databases

### Development
| Database | Type | Memory | Port | Persistence | TLS |
|----------|------|--------|------|-------------|-----|
| orders-cache-dev | Cache | 1GB | 12000 | No | No |
| session-store-dev | Session | 512MB | 12001 | No | No |

### Production
| Database | Type | Memory | Port | Persistence | TLS | Shards |
|----------|------|--------|------|-------------|-----|--------|
| orders-cache-prod | Cache | 4GB | 12000 | AOF | Yes | 2 |
| session-store-prod | Session | 2GB | 12001 | AOF | Yes | 2 |

## 🚀 Deployment

### Deploy Cluster

```bash
# Apply cluster Application
oc apply -f argocd-cluster.yaml

# Monitor deployment
oc get application redis-cluster-orders -n openshift-gitops -w
oc get redisenterprisecluster -n redis-orders-enterprise -w
```

### Deploy Databases

```bash
# Deploy dev databases
oc apply -f databases/cache/argocd-dev.yaml
oc apply -f databases/session/argocd-dev.yaml

# Deploy prod databases
oc apply -f databases/cache/argocd-prod.yaml
oc apply -f databases/session/argocd-prod.yaml

# Monitor deployment
oc get redisenterprisedatabase -n redis-orders-enterprise -w
```

## 📝 Adding a New Database

1. **Create database directory**:
   ```bash
   mkdir databases/analytics
   ```

2. **Create database configs**:
   ```bash
   # Dev config
   cp databases/cache/dev.yaml databases/analytics/dev.yaml
   # Edit: name, port, memory, type

   # Prod config
   cp databases/cache/prod.yaml databases/analytics/prod.yaml
   # Edit: name, port, memory, type
   ```

3. **Create Argo CD Applications**:
   ```bash
   # Dev Application
   cp databases/cache/argocd-dev.yaml databases/analytics/argocd-dev.yaml
   # Edit: metadata.name, valueFiles path

   # Prod Application
   cp databases/cache/argocd-prod.yaml databases/analytics/argocd-prod.yaml
   # Edit: metadata.name, valueFiles path
   ```

4. **Deploy**:
   ```bash
   oc apply -f databases/analytics/argocd-dev.yaml
   oc apply -f databases/analytics/argocd-prod.yaml
   ```

## 🔗 Routes

- **UI**: `https://redis-enterprise-ui-redis-orders-enterprise.apps.cluster-smjw5.dynamic.redhatworkshops.io`
- **Cache Dev**: `orders-cache-dev-redis-orders-enterprise.apps.cluster-smjw5.dynamic.redhatworkshops.io:12000`
- **Session Dev**: `session-store-dev-redis-orders-enterprise.apps.cluster-smjw5.dynamic.redhatworkshops.io:12001`

## 📚 Documentation

- [Helm Architecture](../../docs/HELM_ARCHITECTURE.md)
- [Onboarding Guide](../../docs/ONBOARDING_GUIDE.md)
- [Migration Guide](../../docs/MIGRATION_GUIDE.md)

## 👥 Team

- **Owner**: Orders Team
- **Contact**: orders-team@example.com
- **Slack**: #orders-team

