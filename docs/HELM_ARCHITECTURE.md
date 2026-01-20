# Helm-based Architecture for Redis Enterprise

## Overview

This document describes the new Helm-based architecture for deploying Redis Enterprise clusters and databases at scale.

## Architecture Principles

### 1. **Separation of Concerns**
- **Infrastructure Layer**: Redis Enterprise Clusters (managed by Platform Team)
- **Application Layer**: Redis Databases (managed by Dev Teams)

### 2. **One Operator per Cluster**
- Each Redis Enterprise Cluster has its own dedicated operator
- Operator installed via OperatorHub (not managed by Argo CD)
- Operator and all resources in the same namespace: `redis-{cluster-name}-enterprise`

### 3. **Isolation and Blast Radius Control**
- Each cluster in its own namespace
- Separate Argo CD Application per cluster
- Separate Argo CD Application per database
- Changes to one database don't trigger sync of others

### 4. **Helm + Kustomize Strategy**
- **Helm**: Templating and parameterization
- **Values files**: Environment-specific configuration
- **Presets**: Common database types (cache, session, persistent)

## Directory Structure

```
poc-gitops/
├── helm-charts/                          # Helm charts
│   ├── redis-enterprise-cluster/         # Chart for REC
│   │   ├── Chart.yaml
│   │   ├── values.yaml                   # Default values
│   │   └── templates/
│   │       ├── namespace.yaml
│   │       ├── rec.yaml
│   │       └── route-ui.yaml
│   │
│   └── redis-enterprise-database/        # Chart for REDB
│       ├── Chart.yaml
│       ├── values.yaml                   # Default values
│       ├── values-cache.yaml             # Preset for cache DBs
│       ├── values-session.yaml           # Preset for session DBs
│       ├── values-persistent.yaml        # Preset for persistent DBs
│       └── templates/
│           ├── redb.yaml
│           └── route.yaml
│
├── environments/                         # Environment configs
│   ├── clusters/                         # Cluster configurations
│   │   └── orders/
│   │       └── values.yaml               # Orders cluster config
│   │
│   └── databases/                        # Database configurations
│       └── orders/
│           ├── dev/
│           │   ├── cache.yaml
│           │   └── session.yaml
│           └── prod/
│               ├── cache.yaml
│               └── session.yaml
│
└── argocd/                               # Argo CD Applications
    ├── infrastructure/                   # Cluster Applications
    │   └── redis-cluster-orders.yaml
    │
    └── databases/                        # Database Applications
        ├── orders-cache-dev.yaml
        └── session-store-dev.yaml
```

## Components

### Helm Charts

#### 1. redis-enterprise-cluster
Deploys a complete Redis Enterprise Cluster including:
- Namespace
- RedisEnterpriseCluster (REC)
- Route for UI

**Key Parameters**:
- `cluster.name`: Cluster identifier (e.g., "orders")
- `redis.nodes`: Number of nodes (3, 5, 9)
- `redis.resources`: CPU/Memory per node
- `redis.persistence`: Storage configuration

#### 2. redis-enterprise-database
Deploys a Redis Enterprise Database including:
- RedisEnterpriseDatabase (REDB)
- Route for database access

**Key Parameters**:
- `database.name`: Database name
- `database.env`: Environment (dev, prod)
- `database.type`: Type (cache, session, persistent)
- `redis.memorySize`: Memory allocation
- `redis.databasePort`: Port number

### Presets

#### values-cache.yaml
Optimized for caching:
- No persistence
- `volatile-lru` eviction
- TLS disabled (dev)

#### values-session.yaml
Optimized for sessions:
- No persistence
- `volatile-ttl` eviction
- TLS disabled (dev)

#### values-persistent.yaml
Optimized for durable data:
- AOF persistence
- `noeviction` policy
- TLS enabled
- 2 shards

## Deployment Workflow

### Deploy a New Cluster

1. **Install Operator** (via OperatorHub):
```bash
# Install Redis Enterprise Operator in namespace: redis-{cluster-name}-enterprise
```

2. **Create cluster configuration**:
```bash
# Create: environments/clusters/{cluster-name}/values.yaml
```

3. **Create Argo CD Application**:
```bash
# Create: argocd/infrastructure/redis-cluster-{cluster-name}.yaml
oc apply -f argocd/infrastructure/redis-cluster-{cluster-name}.yaml
```

### Deploy a New Database

1. **Create database configuration**:
```bash
# Create: environments/databases/{cluster-name}/{env}/{db-name}.yaml
```

2. **Create Argo CD Application**:
```bash
# Create: argocd/databases/{db-name}-{env}.yaml
oc apply -f argocd/databases/{db-name}-{env}.yaml
```

## Scaling Strategy

### Current (Simple)
- 1 cluster: `orders`
- 2 databases: `orders-cache-dev`, `session-store-dev`
- Manual Application creation

### Future (Scale)
- Multiple clusters per datacenter
- Hundreds of databases
- ApplicationSets for automation
- Self-service via Git PRs

## Benefits

✅ **Isolation**: Each cluster independent  
✅ **Scalability**: Supports hundreds of databases  
✅ **Flexibility**: Helm templating + values files  
✅ **Reusability**: Presets for common patterns  
✅ **GitOps**: All config in Git  
✅ **Multi-team**: Teams manage their own databases  

## Migration from Kustomize

The old Kustomize-based structure (`orders-redis/`) is being replaced by this Helm-based approach.

**Old**: Single Application managing cluster + databases  
**New**: Separate Applications for cluster and each database

This allows independent lifecycle management and reduces blast radius.

