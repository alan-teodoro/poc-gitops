# Architecture Overview

## GitOps Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         DEVELOPER                                │
│                                                                  │
│  1. Edit YAML files                                             │
│  2. git commit -m "Add new database"                            │
│  3. git push                                                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GIT REPOSITORY                              │
│                                                                  │
│  demo-gitops-argocd/                                            │
│  ├── 00-namespace.yaml                                          │
│  ├── 01-operator-subscription.yaml                              │
│  ├── 02-redis-cluster.yaml                                      │
│  ├── 03-database-customers.yaml                                 │
│  └── 04-database-orders.yaml                                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ ArgoCD polls every 3 minutes
                             │ (or webhook triggers immediately)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ARGOCD                                   │
│                                                                  │
│  1. Detects changes in Git                                      │
│  2. Compares Git state vs Cluster state                         │
│  3. Syncs differences (creates/updates/deletes resources)       │
│  4. Reports status (Synced/OutOfSync, Healthy/Degraded)         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OPENSHIFT CLUSTER                             │
│                                                                  │
│  Namespace: redis-demo                                          │
│  ├── Operator (manages clusters)                                │
│  ├── Redis Cluster (3 nodes)                                    │
│  ├── Database: customers-db                                     │
│  └── Database: orders-db                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Order (Sync Waves)

```
Wave 0: Namespace
   │
   ├─> redis-demo namespace created
   │
   ▼
Wave 1: TLS Certificate
   │
   ├─> Secret "redis-cluster-tls" created
   ├─> Contains custom domain certificate
   │
   ▼
Wave 2: Cluster
   │
   ├─> RedisEnterpriseCluster CR created
   ├─> Cluster configured to use custom certificate
   ├─> Operator creates 3 StatefulSet pods
   ├─> Cluster becomes ready with custom TLS
   │
   ▼
Wave 3: Databases
   │
   ├─> RedisEnterpriseDatabase "customers" created
   ├─> RedisEnterpriseDatabase "orders" created
   ├─> Operator creates databases in cluster
   │
   ▼
Wave 4: Custom Route
   │
   ├─> Route "redis-ui-custom" created
   ├─> TLS passthrough configured
   └─> Custom domain accessible
```

## Resource Relationships

```
┌──────────────────────────────────────────────────────────────┐
│                    redis-demo Namespace                       │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │         Redis Enterprise Operator                      │  │
│  │  (Watches for RedisEnterpriseCluster CRs)             │  │
│  └────────────────────────────────────────────────────────┘  │
│                           │                                   │
│                           │ manages                           │
│                           ▼                                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │         RedisEnterpriseCluster: demo-cluster          │  │
│  │                                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │  Node 1  │  │  Node 2  │  │  Node 3  │           │  │
│  │  │  (Pod)   │  │  (Pod)   │  │  (Pod)   │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  └────────────────────────────────────────────────────────┘  │
│                           │                                   │
│                           │ hosts                             │
│                           ▼                                   │
│  ┌─────────────────────┐     ┌─────────────────────┐        │
│  │  Database:          │     │  Database:          │        │
│  │  customers-db       │     │  orders-db          │        │
│  │                     │     │                     │        │
│  │  Memory: 100MB      │     │  Memory: 100MB      │        │
│  │  Replication: Yes   │     │  Replication: Yes   │        │
│  │  Persistence: AOF   │     │  Persistence: AOF   │        │
│  └─────────────────────┘     └─────────────────────┘        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## ArgoCD Application Structure

```
Application: redis-demo
├── Source
│   ├── Repository: https://github.com/alan-teodoro/poc-gitops.git
│   ├── Branch: main
│   └── Path: demo-gitops-argocd/
│
├── Destination
│   ├── Cluster: https://kubernetes.default.svc
│   └── Namespace: redis-demo
│
├── Sync Policy
│   ├── Automated: true
│   ├── Self-Heal: true
│   └── Prune: true
│
└── Resources (managed by ArgoCD)
    ├── Namespace: redis-demo
    ├── OperatorGroup: redis-demo-operator-group
    ├── Subscription: redis-enterprise-operator
    ├── RedisEnterpriseCluster: demo-cluster
    ├── RedisEnterpriseDatabase: customers
    └── RedisEnterpriseDatabase: orders
```

## Key Benefits

### 1. Single Source of Truth
- All configuration in Git
- Easy to audit and review
- Version controlled

### 2. Automated Deployment
- Push to Git → Automatic deployment
- No manual kubectl/oc commands
- Consistent deployments

### 3. Self-Healing
- ArgoCD monitors cluster state
- Automatically fixes drift
- Ensures desired state

### 4. Easy Rollback
- Git revert → Automatic rollback
- Full deployment history
- Safe experimentation

### 5. Visibility
- ArgoCD UI shows all resources
- Health and sync status
- Easy troubleshooting

