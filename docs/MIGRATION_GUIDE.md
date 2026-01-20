# Migration Guide - Kustomize to Helm

## Overview

This guide explains how to migrate from the legacy Kustomize-based approach to the new Helm-based architecture.

## Why Migrate?

### Current Limitations (Kustomize Approach)
- ❌ Single Application manages cluster + all databases
- ❌ Changes to one database trigger sync of all resources
- ❌ Not suitable for hundreds of databases
- ❌ Difficult to delegate to multiple teams
- ❌ Large blast radius on failures

### Benefits of Helm Approach
- ✅ Separate Applications (1 cluster, 1 per database)
- ✅ Changes isolated to specific resources
- ✅ Scales to hundreds of databases
- ✅ Multi-team friendly (teams manage their own databases)
- ✅ Minimal blast radius
- ✅ Presets for common patterns
- ✅ One operator per cluster (better isolation)

## Current State (Working)

You currently have:
- **Application**: `orders-redis-dev` (in `openshift-gitops` namespace)
- **Cluster**: `orders-redis-cluster` (in `redis-enterprise` namespace)
- **Databases**: 
  - `orders-cache-dev` (in `redis-enterprise` namespace)
  - `session-store-dev` (in `redis-enterprise` namespace)
- **Routes**: UI + 2 database routes

**Status**: ✅ All Synced and Healthy

## Migration Strategy

### Option 1: Keep Current Setup (Recommended for Now)

**Keep the current working setup** and use the new Helm approach for:
- New clusters
- New databases
- Future environments

**Rationale**: Don't break what's working. The new structure is ready for scale.

### Option 2: Migrate Existing Resources

If you want to migrate the current setup to Helm:

#### Step 1: Verify New Applications Work

```bash
# Test cluster Application (dry-run)
helm template test-cluster helm-charts/redis-enterprise-cluster \
  -f environments/clusters/orders/values.yaml | \
  kubectl apply --dry-run=client -f -

# Test database Application (dry-run)
helm template test-db helm-charts/redis-enterprise-database \
  -f helm-charts/redis-enterprise-database/values-cache.yaml \
  -f environments/databases/orders/dev/cache.yaml | \
  kubectl apply --dry-run=client -f -
```

#### Step 2: Delete Old Application

```bash
# This will NOT delete the resources (they're already in the cluster)
oc delete application orders-redis-dev -n openshift-gitops
```

#### Step 3: Apply New Applications

```bash
# Apply cluster Application
oc apply -f argocd/infrastructure/redis-cluster-orders.yaml

# Apply database Applications
oc apply -f argocd/databases/orders-cache-dev.yaml
oc apply -f argocd/databases/session-store-dev.yaml
```

#### Step 4: Verify

```bash
# Check Applications
oc get application -n openshift-gitops | grep redis

# Check resources
oc get redisenterprisecluster -n redis-orders-enterprise
oc get redisenterprisedatabase -n redis-orders-enterprise
oc get route -n redis-orders-enterprise
```

## Namespace Changes

### Old Structure
```
redis-enterprise/          # Operator + Cluster + Databases
├── redis-enterprise-operator
├── orders-redis-cluster
├── orders-cache-dev
└── session-store-dev
```

### New Structure (Same for Now)
```
redis-orders-enterprise/   # Operator + Cluster + Databases
├── redis-enterprise-operator (installed via OperatorHub)
├── orders-redis-cluster (managed by Argo CD)
├── orders-cache-dev (managed by Argo CD)
└── session-store-dev (managed by Argo CD)
```

**Note**: The namespace name changes from `redis-enterprise` to `redis-orders-enterprise` to follow the pattern `redis-{cluster-name}-enterprise`. This allows multiple clusters in the same OpenShift cluster.

## Rollback Plan

If migration fails, rollback is simple:

```bash
# Delete new Applications
oc delete application redis-cluster-orders -n openshift-gitops
oc delete application redb-orders-cache-dev -n openshift-gitops
oc delete application redb-session-store-dev -n openshift-gitops

# Re-apply old Application
oc apply -f argocd/orders-redis-dev-app.yaml
```

## Comparison

| Aspect | Kustomize (Old) | Helm (New) |
|--------|----------------|------------|
| **Applications** | 1 (cluster + DBs) | 3 (1 cluster + 2 DBs) |
| **Blast Radius** | High (all resources) | Low (per resource) |
| **Scalability** | Limited (~10 DBs) | High (100s of DBs) |
| **Multi-team** | Difficult | Easy |
| **Presets** | No | Yes (cache, session, persistent) |
| **Operator** | Shared | Per cluster |
| **Namespace** | `redis-enterprise` | `redis-{cluster}-enterprise` |

## Next Steps

1. **Keep current setup working** ✅
2. **Use Helm for new resources** ✅
3. **Migrate when ready** (optional)
4. **Scale to multiple clusters** (future)

## Questions?

- See [HELM_ARCHITECTURE.md](./HELM_ARCHITECTURE.md) for architecture details
- See [ONBOARDING_GUIDE.md](./ONBOARDING_GUIDE.md) for adding new resources
- Contact Platform Team for assistance

