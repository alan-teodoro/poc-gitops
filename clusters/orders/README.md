# Orders Redis Enterprise Cluster

This directory contains **all configuration** for the Orders Redis Enterprise cluster.

## 📁 Structure

```
orders/
├── README.md                    # This file
├── cluster.yaml                 # Cluster configuration (REC)
├── argocd-cluster.yaml         # Argo CD Application for cluster
└── databases/
    ├── dev/
    │   ├── cache.yaml          # Cache database config
    │   ├── session.yaml        # Session database config
    │   ├── argocd-cache.yaml   # Argo CD App for cache
    │   └── argocd-session.yaml # Argo CD App for session
    └── prod/
        ├── cache.yaml          # Cache database config (prod)
        └── session.yaml        # Session database config (prod)
```

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
oc apply -f databases/dev/argocd-cache.yaml
oc apply -f databases/dev/argocd-session.yaml

# Monitor deployment
oc get redisenterprisedatabase -n redis-orders-enterprise -w
```

## 📝 Adding a New Database

1. **Create database config**:
   ```bash
   # Create: databases/{env}/{db-name}.yaml
   cp databases/dev/cache.yaml databases/dev/new-db.yaml
   # Edit with your configuration
   ```

2. **Create Argo CD Application**:
   ```bash
   # Create: databases/{env}/argocd-{db-name}.yaml
   cp databases/dev/argocd-cache.yaml databases/dev/argocd-new-db.yaml
   # Update paths and names
   ```

3. **Apply**:
   ```bash
   oc apply -f databases/dev/argocd-new-db.yaml
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

