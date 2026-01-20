# Redis Enterprise Multi-Namespace Support

## Overview

This setup allows Redis Enterprise databases (REDBs) to be deployed in different namespaces than the Redis Enterprise Cluster (REC), enabling better isolation between environments (dev/prod).

## Architecture

```
redis-orders (namespace)
├── Redis Enterprise Operator
├── Redis Enterprise Cluster (REC)
└── RBAC Configuration

redis-orders-dev (namespace)
└── Development Databases (REDBs)

redis-orders-prod (namespace)
└── Production Databases (REDBs)
```

## How It Works

### 1. RBAC Configuration (Automatic)

The `redis-multi-namespace-rbac` Helm chart automatically creates:

- **ClusterRole**: Allows operator to list/watch namespaces
- **ClusterRoleBinding**: Binds ClusterRole to operator service account
- **Role** (per database namespace): Permissions for REDB management
- **RoleBinding** (per database namespace): Binds Role to operator and cluster service accounts
- **Namespaces**: Creates database namespaces with proper labels
- **ConfigMap**: Configures operator to watch labeled namespaces

### 2. Namespace Labeling

All database namespaces are automatically labeled with:
```yaml
redis-db-namespace: enabled
```

The operator watches for namespaces with this label.

### 3. Operator Configuration

The operator ConfigMap is automatically updated with:
```yaml
REDB_NAMESPACES_LABEL: redis-db-namespace
```

## Adding a New Cluster

To add a new cluster with multi-namespace support:

### 1. Create cluster directory structure

```bash
clusters/
└── {cluster-name}/
    ├── cluster.yaml              # Cluster configuration
    ├── rbac.yaml                 # RBAC configuration
    ├── argocd-cluster.yaml       # Argo CD App for cluster
    ├── argocd-rbac.yaml          # Argo CD App for RBAC
    └── databases/
        ├── {database-name}/
        │   ├── dev.yaml
        │   ├── prod.yaml
        │   ├── argocd-dev.yaml
        │   └── argocd-prod.yaml
```

### 2. Create `rbac.yaml`

```yaml
cluster:
  name: {cluster-name}
  operatorNamespace: redis-{cluster-name}
  clusterName: {cluster-name}-redis-cluster

databaseNamespaces:
  - name: redis-{cluster-name}-dev
    env: dev
  - name: redis-{cluster-name}-prod
    env: prod

namespaceLabel:
  key: redis-db-namespace
  value: enabled

operator:
  serviceAccount: redis-enterprise-operator
  configMapName: operator-environment-config
```

### 3. Create `argocd-rbac.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-rbac-{cluster-name}
  namespace: openshift-gitops
spec:
  source:
    repoURL: https://github.com/alan-teodoro/poc-gitops.git
    targetRevision: main
    path: helm-charts/redis-multi-namespace-rbac
    helm:
      valueFiles:
        - ../../clusters/{cluster-name}/rbac.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: redis-{cluster-name}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 4. Deploy in order

```bash
# 1. Deploy RBAC (creates namespaces and permissions)
oc apply -f clusters/{cluster-name}/argocd-rbac.yaml

# 2. Wait for RBAC to sync
oc get application redis-rbac-{cluster-name} -n openshift-gitops

# 3. Deploy cluster
oc apply -f clusters/{cluster-name}/argocd-cluster.yaml

# 4. Wait for cluster to be Running
oc get rec -n redis-{cluster-name}

# 5. Deploy databases
oc apply -f clusters/{cluster-name}/databases/*/argocd-*.yaml
```

## Benefits

✅ **Automatic**: No manual RBAC configuration needed
✅ **Scalable**: Easy to add new clusters
✅ **Isolated**: Dev and prod databases in separate namespaces
✅ **GitOps**: Everything managed via Argo CD
✅ **Consistent**: Same pattern for all clusters

## Troubleshooting

### Databases not becoming active

Check if operator is watching the namespace:
```bash
oc get configmap operator-environment-config -n redis-{cluster-name} -o yaml
```

Check namespace labels:
```bash
oc get namespace redis-{cluster-name}-dev --show-labels
```

Check RBAC:
```bash
oc get role,rolebinding -n redis-{cluster-name}-dev
```

Restart operator:
```bash
oc delete pod -l name=redis-enterprise-operator -n redis-{cluster-name}
```

