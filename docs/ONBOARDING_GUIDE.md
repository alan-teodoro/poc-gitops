# Onboarding Guide - Adding New Clusters and Databases

## Prerequisites

- Access to OpenShift cluster
- Access to Git repository
- Argo CD installed and configured
- Redis Enterprise Operator available in OperatorHub

## Adding a New Redis Enterprise Cluster

### Step 1: Install Redis Enterprise Operator

Install via OperatorHub in the target namespace:

```bash
# Namespace format: redis-{cluster-name}-enterprise
# Example: redis-payments-enterprise

# Via OpenShift Console:
# 1. Navigate to OperatorHub
# 2. Search for "Redis Enterprise"
# 3. Install in namespace: redis-{cluster-name}-enterprise
# 4. Use default settings
```

### Step 2: Create Cluster Configuration

Create a values file for your cluster:

```bash
# File: environments/clusters/{cluster-name}/values.yaml
```

**Example** (`environments/clusters/payments/values.yaml`):
```yaml
cluster:
  name: payments
  team: payments-team
  datacenter: dc1

namespace: redis-payments-enterprise

redis:
  clusterName: payments-redis-cluster
  nodes: 5
  version: "8.0.6-54"
  
  resources:
    requests:
      cpu: "2"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
  
  persistence:
    enabled: true
    storageClassName: ocs-external-storagecluster-ceph-rbd
    volumeSize: 100Gi

routes:
  ui:
    enabled: true
    tlsTermination: passthrough

labels:
  app.kubernetes.io/managed-by: argocd
  gitops: argocd
  cluster: payments
```

### Step 3: Create Argo CD Application

Create an Application manifest:

```bash
# File: argocd/infrastructure/redis-cluster-{cluster-name}.yaml
```

**Example** (`argocd/infrastructure/redis-cluster-payments.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-cluster-payments
  namespace: openshift-gitops
  labels:
    cluster: payments
    component: infrastructure
spec:
  project: default
  
  source:
    repoURL: https://github.com/alan-teodoro/poc-gitops.git
    targetRevision: main
    path: helm-charts/redis-enterprise-cluster
    helm:
      valueFiles:
        - ../../environments/clusters/payments/values.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: redis-payments-enterprise
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### Step 4: Deploy

```bash
# Commit and push
git add environments/clusters/payments/
git add argocd/infrastructure/redis-cluster-payments.yaml
git commit -m "Add payments Redis Enterprise cluster"
git push

# Apply Application
oc apply -f argocd/infrastructure/redis-cluster-payments.yaml

# Monitor deployment
oc get application redis-cluster-payments -n openshift-gitops -w
oc get redisenterprisecluster -n redis-payments-enterprise -w
```

## Adding a New Database

### Step 1: Choose Database Type

Select the appropriate preset:
- **cache**: High-throughput caching, no persistence
- **session**: Session storage with TTL
- **persistent**: Durable data with AOF

### Step 2: Create Database Configuration

Create a values file:

```bash
# File: environments/databases/{cluster-name}/{env}/{db-name}.yaml
```

**Example** (`environments/databases/payments/dev/transactions.yaml`):
```yaml
database:
  name: transactions
  env: dev
  type: persistent

cluster:
  name: payments
  team: payments-team

namespace: redis-payments-enterprise

redis:
  clusterName: payments-redis-cluster
  memorySize: 2GB
  replication: true
  persistence: aofEverySecond
  databasePort: 12002
  tlsMode: disabled
  evictionPolicy: noeviction
  shardCount: 2

route:
  enabled: true
```

### Step 3: Create Argo CD Application

```bash
# File: argocd/databases/{db-name}-{env}.yaml
```

**Example** (`argocd/databases/transactions-dev.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redb-transactions-dev
  namespace: openshift-gitops
  labels:
    cluster: payments
    database: transactions
    env: dev
spec:
  project: default
  
  source:
    repoURL: https://github.com/alan-teodoro/poc-gitops.git
    targetRevision: main
    path: helm-charts/redis-enterprise-database
    helm:
      valueFiles:
        - values-persistent.yaml
        - ../../environments/databases/payments/dev/transactions.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: redis-payments-enterprise
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Step 4: Deploy

```bash
# Commit and push
git add environments/databases/payments/dev/transactions.yaml
git add argocd/databases/transactions-dev.yaml
git commit -m "Add transactions database for payments cluster (dev)"
git push

# Apply Application
oc apply -f argocd/databases/transactions-dev.yaml

# Monitor deployment
oc get application redb-transactions-dev -n openshift-gitops -w
oc get redisenterprisedatabase -n redis-payments-enterprise -w
```

## Port Assignment Strategy

To avoid conflicts, use this port assignment strategy:

- **12000-12099**: Cache databases
- **12100-12199**: Session databases
- **12200-12299**: Persistent databases
- **12300-12399**: Reserved for future use

## Naming Conventions

### Clusters
- **Namespace**: `redis-{cluster-name}-enterprise`
- **Cluster Name**: `{cluster-name}-redis-cluster`
- **Application**: `redis-cluster-{cluster-name}`

### Databases
- **Database Name**: `{db-name}-{env}`
- **Application**: `redb-{db-name}-{env}`
- **Route**: `{db-name}-{env}`

## Troubleshooting

### Cluster not starting
```bash
# Check operator logs
oc logs -n redis-{cluster}-enterprise -l name=redis-enterprise-operator

# Check cluster status
oc describe redisenterprisecluster -n redis-{cluster}-enterprise

# Check PVCs
oc get pvc -n redis-{cluster}-enterprise
```

### Database not provisioning
```bash
# Check database status
oc describe redisenterprisedatabase {db-name}-{env} -n redis-{cluster}-enterprise

# Verify cluster is ready
oc get redisenterprisecluster -n redis-{cluster}-enterprise

# Check operator is watching the namespace
oc get deployment redis-enterprise-operator -n redis-{cluster}-enterprise
```

## Next Steps

- Review [HELM_ARCHITECTURE.md](./HELM_ARCHITECTURE.md) for architecture details
- See [examples](../environments/) for more configuration examples
- Contact Platform Team for assistance

