# Architecture Overview

This document describes the architecture and workflow of the Redis Enterprise GitOps implementation.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Git Repository                          │
│  (Source of Truth for Redis Enterprise Configuration)          │
│                                                                 │
│  ├── orders-redis-dev/     (Single-environment demo)           │
│  ├── orders-redis/         (Multi-environment pattern)         │
│  └── argocd/               (Argo CD Applications)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Git Pull
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenShift GitOps (Argo CD)                   │
│                                                                 │
│  ├── Monitors Git repository for changes                       │
│  ├── Detects configuration drift                               │
│  ├── Reconciles desired state with actual state                │
│  └── Applies changes to OpenShift cluster                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Apply Resources
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Redis Enterprise Operator                         │ │
│  │  (Watches for REC and REDB custom resources)              │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              │ Creates/Updates                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Redis Enterprise Cluster (REC)                    │ │
│  │                                                           │ │
│  │  ├── Node 1 (StatefulSet Pod)                            │ │
│  │  ├── Node 2 (StatefulSet Pod)                            │ │
│  │  └── Node 3 (StatefulSet Pod)                            │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              │ Hosts                            │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Redis Enterprise Databases (REDB)                 │ │
│  │                                                           │ │
│  │  ├── orders-cache-dev (Port 12000)                       │ │
│  │  └── session-store-dev (Port 12001)                      │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## GitOps Workflow

### 1. Developer Makes Change

```
Developer → Edit YAML → Commit → Push to Git
```

Example: Add a new database

```bash
# Create new database manifest
cat > orders-redis-dev/redb-new-db.yaml <<EOF
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseDatabase
metadata:
  name: new-db
  namespace: orders-redis-dev
spec:
  memorySize: 1GB
  ...
EOF

# Add to kustomization
echo "  - redb-new-db.yaml" >> orders-redis-dev/kustomization.yaml

# Commit and push
git add .
git commit -m "Add new database"
git push
```

### 2. Argo CD Detects Change

```
Git Repository → Argo CD polls (every 3 min) → Detects diff → Triggers sync
```

Argo CD:
- Polls Git repository every 3 minutes (configurable)
- Compares Git state with cluster state
- Detects new/modified/deleted resources
- Triggers automatic sync (if enabled)

### 3. Argo CD Applies Changes

```
Argo CD → Render manifests → Apply to cluster → Monitor health
```

Steps:
1. Fetch latest from Git
2. Render manifests (using Kustomize if configured)
3. Apply to OpenShift cluster
4. Monitor resource health
5. Report sync status

### 4. Operator Creates Resources

```
Kubernetes API → Redis Enterprise Operator → Create/Update Redis resources
```

The operator:
1. Watches for REC and REDB custom resources
2. Validates configuration
3. Creates/updates StatefulSets, Services, ConfigMaps
4. Manages Redis Enterprise cluster lifecycle
5. Reports status back to custom resources

### 5. Application Uses Database

```
Application → Service → Redis Database
```

Applications connect to databases via Kubernetes Services:
- Service name: `<database-name>` (e.g., `orders-cache-dev`)
- Port: As specified in REDB spec (e.g., `12000`)
- Connection string: `redis://<database-name>:<port>`

## Component Responsibilities

### Git Repository
- **Role**: Source of truth for all configuration
- **Contains**: YAML manifests, Kustomize files, Argo CD Applications
- **Managed by**: Developers via pull requests
- **Benefits**: Version control, audit trail, rollback capability

### Argo CD
- **Role**: Continuous deployment and reconciliation
- **Monitors**: Git repository for changes
- **Applies**: Changes to OpenShift cluster
- **Ensures**: Cluster state matches Git state
- **Features**: Auto-sync, self-heal, prune

### Redis Enterprise Operator
- **Role**: Manages Redis Enterprise lifecycle
- **Watches**: RedisEnterpriseCluster and RedisEnterpriseDatabase CRDs
- **Creates**: StatefulSets, Services, ConfigMaps, Secrets
- **Manages**: Cluster scaling, database creation, failover
- **Reports**: Status and health

### Redis Enterprise Cluster
- **Role**: Runs Redis databases
- **Components**: Multiple nodes (StatefulSet pods)
- **Provides**: High availability, persistence, clustering
- **Manages**: Data distribution, replication, failover

## Multi-Environment Pattern

### Base Configuration

```
orders-redis/base/
├── namespace.yaml       # Base namespace (name will be patched)
├── rec.yaml             # Base cluster config (3 nodes, 2Gi)
└── kustomization.yaml   # Base kustomization
```

Shared across all environments.

### Environment Overlays

```
orders-redis/overlays/
├── dev/
│   ├── namespace-patch.yaml    # Set namespace to orders-redis-dev
│   ├── redb-dev.yaml           # Dev databases (no TLS, no persistence)
│   └── kustomization.yaml      # References base + adds dev resources
├── nonprod/
│   ├── namespace-patch.yaml    # Set namespace to orders-redis-nonprod
│   ├── redb-nonprod.yaml       # Nonprod databases (persistence enabled)
│   └── kustomization.yaml      # References base + adds nonprod resources
└── prod/
    ├── namespace-patch.yaml    # Set namespace to orders-redis-prod
    ├── rec-patch.yaml          # Override cluster (5 nodes, 4Gi)
    ├── redb-prod.yaml          # Prod databases (TLS, persistence, sharding)
    └── kustomization.yaml      # References base + adds prod resources
```

Each overlay:
1. References base configuration
2. Patches namespace
3. Adds environment-specific resources
4. Optionally patches base resources (e.g., prod cluster size)

### Kustomize Build Process

```
kustomize build orders-redis/overlays/prod
```

Process:
1. Load base resources
2. Apply namespace patch
3. Apply REC patch (prod only)
4. Add environment-specific REDB resources
5. Apply common labels and annotations
6. Output final manifests

## Security Architecture

### Network Security

```
Application Pod → Service → Redis Database Pod
     │                           │
     └─── NetworkPolicy ─────────┘
```

Recommended:
- NetworkPolicies to restrict traffic
- TLS for encryption in transit
- Private networks for sensitive data

### Authentication & Authorization

```
User → OpenShift RBAC → Namespace → Redis Database
                                          │
                                          └─── Password Auth (optional)
```

Layers:
1. **OpenShift RBAC**: Controls who can deploy/modify resources
2. **Namespace isolation**: Separate namespaces per environment
3. **Redis authentication**: Password or certificate-based auth
4. **TLS**: Encrypted connections

### Secrets Management

```
External Secret Store → Kubernetes Secret → Redis Database
(e.g., Vault)
```

Best practices:
- Store passwords in Kubernetes Secrets
- Use external secret management (Vault, AWS Secrets Manager)
- Rotate credentials regularly
- Never commit secrets to Git

## Monitoring and Observability

### Metrics Flow

```
Redis Database → Prometheus Metrics → Prometheus → Grafana
                                          │
                                          └─── Alertmanager
```

Components:
- **Redis Enterprise**: Exposes Prometheus metrics
- **Prometheus**: Scrapes and stores metrics
- **Grafana**: Visualizes metrics
- **Alertmanager**: Sends alerts

### Logging Flow

```
Redis Database → Container Logs → OpenShift Logging → Elasticsearch → Kibana
```

## Disaster Recovery

### Backup Strategy

```
Redis Database → Backup Job → S3/Object Storage
                                    │
                                    └─── Restore Job → New Database
```

### GitOps Recovery

```
Git Repository (Source of Truth)
     │
     └─── Argo CD → Recreate all resources
```

Benefits:
- Git is the backup for configuration
- Can recreate entire environment from Git
- Data backups separate from configuration

## Scalability

### Horizontal Scaling

```
3-node cluster → 5-node cluster (Edit REC, commit, push)
1 shard → 4 shards (Edit REDB, commit, push)
```

### Vertical Scaling

```
2Gi per node → 4Gi per node (Edit REC, commit, push)
1GB database → 2GB database (Edit REDB, commit, push)
```

All scaling operations:
1. Edit YAML in Git
2. Commit and push
3. Argo CD applies changes
4. Operator performs scaling

## Next Steps

- Review [DEPLOYMENT.md](DEPLOYMENT.md) for deployment instructions
- See [OPERATIONS.md](OPERATIONS.md) for operational workflows
- Check [../examples/](../examples/) for configuration examples

