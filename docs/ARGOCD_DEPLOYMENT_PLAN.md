# ArgoCD Deployment Plan - New Cluster

## 📋 Overview

This document outlines the plan to deploy the entire Redis Enterprise platform using **ArgoCD only** on a fresh OpenShift cluster.

---

## ✅ What We Have Ready

### Git Repository
- **Main branch**: Latest code with all Loki fixes
- **Backup branch**: `backup/loki-manual-testing-2024-02-17` (safe fallback)
- **Repository**: https://github.com/alan-teodoro/poc-gitops.git

### All Resources with Sync Waves
All YAML manifests already have `argocd.argoproj.io/sync-wave` annotations for proper ordering:

**Phase 1-4: Foundation** (Waves 1-7)
- AppProjects
- Namespaces
- ResourceQuotas
- LimitRanges
- Gatekeeper
- Redis Enterprise Operator
- Redis Enterprise Cluster
- Redis Databases

**Phase 5: Observability** (Waves 8-12)
- Grafana Operator
- Grafana Instance
- Prometheus ServiceMonitor
- PrometheusRules (40+ alerts)
- Grafana Dashboards (4 official dashboards)

**Phase 5.5: Logging** (Waves 8-12)
- **Loki Option**:
  - Wave 8: ObjectBucketClaim
  - Wave 9: RBAC + ServiceAccount + Secrets
  - Wave 10: LokiStack + Secret sync Job + ClusterLogForwarder SA
  - Wave 11: ClusterLogForwarder
  - Wave 12: Grafana Datasource
- **Splunk Option**: Similar wave structure

**Phase 6: Performance Testing** (Wave 20)
- 5 memtier_benchmark test scenarios

---

## 🎯 Deployment Strategy

### Option 1: Single Root Application (Recommended)
Create one ArgoCD Application that deploys everything in order using sync waves.

**Pros**:
- Single source of truth
- Automatic ordering via sync waves
- Easy to manage
- One sync = entire platform

**Cons**:
- Harder to debug individual components
- All-or-nothing deployment

### Option 2: App of Apps Pattern
Create a root Application that deploys child Applications for each phase.

**Pros**:
- Modular deployment
- Easy to enable/disable phases
- Better for troubleshooting
- Can sync phases independently

**Cons**:
- More complex structure
- Need to manage multiple Applications

---

## 🚀 Recommended Approach: App of Apps

### Structure
```
clusters/
└── {cluster-name}/
    ├── argocd/
    │   ├── root-app.yaml              # Root Application (App of Apps)
    │   ├── apps/
    │   │   ├── foundation.yaml        # Phases 1-4
    │   │   ├── observability.yaml     # Phase 5
    │   │   ├── logging-loki.yaml      # Phase 5.5 Option A
    │   │   ├── logging-splunk.yaml    # Phase 5.5 Option B (disabled)
    │   │   └── testing.yaml           # Phase 6 (disabled initially)
    │   └── projects/
    │       └── redis-platform.yaml    # AppProject for all apps
```

### Benefits for Your Use Case
1. **Easy to switch between Loki and Splunk**: Just enable/disable the app
2. **Testing on-demand**: Enable testing app when ready
3. **Clear separation**: Each phase is independent
4. **Backup-friendly**: Can rollback individual phases

---

## 📝 Tomorrow's Action Plan

### Step 1: Prepare Cluster
```bash
# Login to new OpenShift cluster
oc login --server=https://api.cluster-xxxxx.com:6443

# Verify cluster is ready
oc get nodes
oc get clusterversion
```

### Step 2: Install ArgoCD (if not already installed)
```bash
# Install OpenShift GitOps Operator
oc apply -f platform/gitops/openshift-gitops-operator.yaml

# Wait for operator to be ready
oc get csv -n openshift-gitops-operator

# Verify ArgoCD is running
oc get pods -n openshift-gitops
```

### Step 3: Create Cluster Directory Structure
```bash
# Create cluster-specific directory
CLUSTER_NAME="cluster-$(date +%Y%m%d)"
mkdir -p clusters/${CLUSTER_NAME}/argocd/{apps,projects}
```

### Step 4: Create AppProject
Create `clusters/${CLUSTER_NAME}/argocd/projects/redis-platform.yaml`

### Step 5: Create Child Applications
Create Application manifests for each phase in `clusters/${CLUSTER_NAME}/argocd/apps/`

### Step 6: Create Root Application
Create `clusters/${CLUSTER_NAME}/argocd/root-app.yaml` (App of Apps)

### Step 7: Deploy Everything
```bash
# Apply root application
oc apply -f clusters/${CLUSTER_NAME}/argocd/root-app.yaml

# Watch ArgoCD sync
argocd app list
argocd app get redis-platform-root
```

### Step 8: Monitor Deployment
```bash
# Watch all resources being created
watch -n 5 'oc get pods -A | grep -E "(redis|grafana|loki|vector)"'

# Check ArgoCD UI
ARGOCD_URL=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
echo "ArgoCD UI: https://$ARGOCD_URL"
```

---

## 🔧 What We Need to Create Tomorrow

1. **Cluster directory**: `clusters/${CLUSTER_NAME}/`
2. **AppProject**: Define source repos, destinations, allowed resources
3. **Child Applications**: One per phase (foundation, observability, logging, testing)
4. **Root Application**: App of Apps that deploys all child apps
5. **Kustomization** (optional): If we want to customize per cluster

---

## 📚 Reference Documents

- **LOKI_QUICK_START.md**: Fast deployment guide (manual)
- **LOKI_FIXES_SUMMARY.md**: All fixes and learnings
- **docs/IMPLEMENTATION_ORDER.md**: Detailed step-by-step guide
- **Backup branch**: `backup/loki-manual-testing-2024-02-17`

---

## 🎯 Success Criteria

After ArgoCD deployment completes:
- ✅ All ArgoCD Applications synced and healthy
- ✅ Redis Enterprise Cluster running (3 pods)
- ✅ Redis Databases created (2 databases)
- ✅ Grafana accessible with dashboards
- ✅ Prometheus scraping Redis metrics
- ✅ Loki collecting logs (6/7 components running)
- ✅ Vector collectors forwarding logs (6 pods)
- ✅ Grafana showing Redis logs

---

## 🚨 Rollback Plan

If something goes wrong:
```bash
# Delete root application (cascades to all child apps)
oc delete application redis-platform-root -n openshift-gitops

# Or switch to backup branch
git checkout backup/loki-manual-testing-2024-02-17
```

---

**Ready for tomorrow! 🚀**

