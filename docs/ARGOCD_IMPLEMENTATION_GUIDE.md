# ArgoCD Implementation Guide - Step-by-Step

## 📋 Overview

**Goal**: Deploy complete Redis Enterprise platform using ArgoCD GitOps

**Starting Point**: Fresh OpenShift cluster
**End Result**: Production-ready Redis Enterprise with observability, HA, and governance

**Repository**: https://github.com/alan-teodoro/poc-gitops

---

## ✅ Prerequisites

- OpenShift cluster 4.12+ with cluster-admin access
- `oc` CLI installed and logged in
- Git repository cloned locally

---

# 🚀 DEPLOYMENT STEPS

---

## Step 1: Verify Cluster Access

```bash
# Verify cluster version
oc get clusterversion

# Verify nodes
oc get nodes

# Confirm cluster-admin permissions
oc auth can-i '*' '*'
# Expected: yes
```

**✅ Success**: All nodes Ready, cluster-admin confirmed

**⏭️ Next**: If operators already installed, skip to Step 3

---

## Step 2: Install OpenShift GitOps Operator

**Skip if**: GitOps operator already installed

```bash
# Check if GitOps operator exists
oc get csv -n openshift-gitops | grep gitops
```

**If not installed**:
1. Open OpenShift Console → **Operators** → **OperatorHub**
2. Search for: **Red Hat OpenShift GitOps**
3. Click **Install**
4. Settings:
   - **Update channel**: `latest`
   - **Installation mode**: `All namespaces on the cluster`
   - **Installed Namespace**: `openshift-gitops-operator`
   - **Update approval**: `Automatic`
5. Click **Install**
6. Wait 2-3 minutes for installation

**Verify**:
```bash
# Check operator status
oc get csv -n openshift-gitops
# Expected: openshift-gitops-operator.v1.x.x   Succeeded
```

**✅ Success**: Operator shows `Succeeded`

**⏭️ Next**: Continue to Step 3

---

## Step 3: Verify ArgoCD Installation

```bash
# Check ArgoCD pods
oc get pods -n openshift-gitops

# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Get admin password
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
```

**✅ Success**: All ArgoCD pods Running, can access UI

**⏭️ Next**: Continue to Step 4

---

## Step 4: Install Redis Enterprise Operator

**Skip if**: Redis operator already installed

```bash
# Check if Redis operator exists
oc get csv -A | grep redis-enterprise
```

**If not installed**:
1. Open OpenShift Console → **Operators** → **OperatorHub**
2. Search for: **Redis Enterprise Operator**
3. Click **Install**
4. Settings:
   - **Update channel**: `production`
   - **Installation mode**: `A specific namespace on the cluster`
   - **Installed Namespace**: `redis-enterprise` (create if doesn't exist)
   - **Update approval**: `Automatic`
5. Click **Install**
6. Wait 2-3 minutes for installation

**Why `redis-enterprise` namespace?**
- Redis Enterprise Operator must be in the **same namespace** as the Redis cluster
- Our demo cluster will be deployed in `redis-enterprise` namespace
- This is a Redis Enterprise requirement
- This cluster will serve multiple teams (team1, team2)

**Verify**:
```bash
# Check operator status
oc get csv -n redis-enterprise | grep redis
# Expected: redis-enterprise-operator.v8.x.x   Succeeded
```

**✅ Success**: Redis operator shows `Succeeded` in `redis-enterprise` namespace

**⏭️ Next**: Continue to Step 5

---

## Step 5: Install Gatekeeper Operator

**Skip if**: Gatekeeper already installed

```bash
# Check if Gatekeeper exists
oc get csv -A | grep gatekeeper
```

**If not installed**:
1. Open OpenShift Console → **Operators** → **OperatorHub**
2. Search for: **Gatekeeper Operator**
3. Click **Install**
4. Settings:
   - **Update channel**: `stable`
   - **Installation mode**: `All namespaces on the cluster`
   - **Installed Namespace**: `openshift-operators`
   - **Update approval**: `Automatic`
5. Click **Install**
6. Wait 2-3 minutes for installation

**Create Gatekeeper Instance**:
```bash
# Apply Gatekeeper instance
oc apply -f platform/operators/gatekeeper-instance.yaml

# Verify Gatekeeper pods
oc get pods -n openshift-gatekeeper-system
```

**✅ Success**: Gatekeeper pods Running

**⏭️ Next**: Continue to Step 6

---

## Step 6: Install Grafana Operator (Optional)

**Skip if**: Not using observability OR Grafana already installed

```bash
# Check if Grafana operator exists
oc get csv -A | grep grafana
```

**If not installed**:
1. Open OpenShift Console → **Operators** → **OperatorHub**
2. Search for: **Grafana Operator**
3. Click **Install**
4. Settings:
   - **Update channel**: `v5`
   - **Installation mode**: `All namespaces on the cluster`
   - **Installed Namespace**: `openshift-operators`
   - **Update approval**: `Automatic`
5. Click **Install**
6. Wait 2-3 minutes for installation

**Verify**:
```bash
# Check operator status
oc get csv -n openshift-operators | grep grafana
# Expected: grafana-operator.v5.x.x   Succeeded
```

**✅ Success**: Grafana operator shows `Succeeded`

**⏭️ Next**: Continue to Step 7 (or skip to Step 8 if not using logging)

---

## Step 7: Install Loki & Logging Operators (Optional)

**Skip if**: Not using logging OR operators already installed

```bash
# Check if Loki operator exists
oc get csv -A | grep loki
```

**If not installed**:

### 7.1: Install Loki Operator
1. Open OpenShift Console → **Operators** → **OperatorHub**
2. Search for: **Loki Operator**
3. Click **Install**
4. Settings:
   - **Update channel**: `stable-6.2`
   - **Installation mode**: `All namespaces on the cluster`
   - **Installed Namespace**: `openshift-operators-redhat`
   - **Update approval**: `Automatic`
5. Click **Install**

### 7.2: Install Red Hat OpenShift Logging Operator
1. Search for: **Red Hat OpenShift Logging**
2. Click **Install**
3. Settings:
   - **Update channel**: `stable-6.0`
   - **Installation mode**: `All namespaces on the cluster`
   - **Installed Namespace**: `openshift-logging`
   - **Update approval**: `Automatic`
4. Click **Install**
5. Wait 2-3 minutes for both operators

**Verify**:
```bash
# Check both operators
oc get csv -n openshift-operators-redhat | grep loki
oc get csv -n openshift-logging | grep logging
# Expected: Both show Succeeded
```

**✅ Success**: Both operators show `Succeeded`

**⏭️ Next**: Continue to Step 8

---

## Step 8: Create AppProjects

```bash
# Create platform team AppProject
oc apply -f platform/argocd/projects/platform-team.yaml

# Create team1 AppProject (cache databases)
oc apply -f platform/argocd/projects/app-team1.yaml

# Create team2 AppProject (session databases)
oc apply -f platform/argocd/projects/app-team2.yaml

# Verify
oc get appproject -n openshift-gitops
```

**Expected output**:
- `platform-team` AppProject (platform infrastructure)
- `app-team1` AppProject (team1 cache databases)
- `app-team2` AppProject (team2 session databases)

**✅ Success**: 3 AppProjects created with complete isolation

**⏭️ Next**: Continue to Step 9

---

## Step 9: Deploy Gatekeeper Policies (GitOps)

**Skip if**: Not using Gatekeeper policies

```bash
# Deploy Gatekeeper policies via ArgoCD
oc apply -f platform/argocd/apps/gatekeeper-policies.yaml

# Watch ArgoCD sync (1-2 minutes)
oc get application gatekeeper-policies -n openshift-gitops -w

# Verify templates
oc get constrainttemplates
# Expected: redis-immutable-shardcount, redis-mandatory-labels, redis-memory-limit

# Verify constraints
oc get constraints -A
# Expected: Constraints in various namespaces
```

**What this deploys**:
- **ConstraintTemplates**: Policy definitions (3 templates)
- **Constraints**: Policy enforcement rules (4 constraints)

**Policies enforced**:
1. **redis-mandatory-labels**: Requires team, cost-center, environment labels
2. **redis-memory-limit**: Enforces memory limits (dev: 1GB, prod: 2GB)
3. **redis-immutable-shardcount**: Prevents changing shardCount after creation

**✅ Success**: ArgoCD Application synced, policies active

**⏭️ Next**: Continue to Step 10

---

## Step 10: Create Namespaces (GitOps)

```bash
# Deploy namespaces via ArgoCD
oc apply -f platform/argocd/apps/namespaces.yaml

# Watch ArgoCD sync (30 seconds)
oc get application redis-namespaces -n openshift-gitops -w

# Verify namespaces created
oc get namespaces | grep redis
```

**Expected output**:
- `redis-enterprise` (cluster namespace)
- `redis-team1-dev` and `redis-team1-prod` (team1 databases)
- `redis-team2-dev` and `redis-team2-prod` (team2 databases)

**✅ Success**: ArgoCD Application synced, 5 namespaces created

**⏭️ Next**: Continue to Step 12

---

## Step 11: Apply ResourceQuotas & LimitRanges (GitOps)

```bash
# Deploy quotas and limitranges via ArgoCD
oc apply -f platform/argocd/apps/quotas-limitranges.yaml

# Watch ArgoCD sync (30 seconds)
oc get application quotas-limitranges -n openshift-gitops -w

# Verify quotas
oc get resourcequota -n redis-team1-dev
oc get resourcequota -n redis-team1-prod
oc get resourcequota -n redis-team2-dev
oc get resourcequota -n redis-team2-prod

# Verify limitranges
oc get limitrange -A | grep redis-team
```

**✅ Success**: ArgoCD Application synced, quotas and limitranges applied to all team namespaces

**⏭️ Next**: Continue to Step 13

---

## Step 12: Deploy Redis Enterprise Cluster

```bash
# Apply ArgoCD Application for demo cluster
oc apply -f clusters/redis-cluster-demo/argocd-cluster.yaml

# Watch deployment (5-10 minutes)
oc get rec -n redis-enterprise -w

# Verify cluster is ready
oc get rec demo-redis-cluster -n redis-enterprise
# Expected: STATE=Running

# Verify 3 pods are running
oc get pods -n redis-enterprise
# Expected: demo-redis-cluster-0, demo-redis-cluster-1, demo-redis-cluster-2
```

**✅ Success**: Cluster shows `Running` with 3 pods

**⏭️ Next**: Continue to Step 14

---

## Step 13: Deploy Multi-Namespace RBAC

```bash
# Apply RBAC ArgoCD Application
oc apply -f clusters/redis-cluster-demo/argocd-rbac.yaml

# Verify RBAC resources for team1
oc get role -n redis-team1-dev | grep redis
oc get role -n redis-team1-prod | grep redis
oc get rolebinding -n redis-team1-dev | grep redis
oc get rolebinding -n redis-team1-prod | grep redis

# Verify RBAC resources for team2
oc get role -n redis-team2-dev | grep redis
oc get role -n redis-team2-prod | grep redis
oc get rolebinding -n redis-team2-dev | grep redis
oc get rolebinding -n redis-team2-prod | grep redis
```

**✅ Success**: Roles and RoleBindings created in all team namespaces (team1 and team2)

**⏭️ Next**: Continue to Step 15

---

## Step 14: Deploy Redis Databases

```bash
# Apply team1 databases (cache)
oc apply -f clusters/redis-cluster-demo/teams/team1/argocd-cache-dev.yaml
oc apply -f clusters/redis-cluster-demo/teams/team1/argocd-cache-prod.yaml

# Apply team2 databases (session)
oc apply -f clusters/redis-cluster-demo/teams/team2/argocd-session-dev.yaml
oc apply -f clusters/redis-cluster-demo/teams/team2/argocd-session-prod.yaml

# Watch databases (2-3 minutes)
oc get redb -n redis-team1-dev -w
oc get redb -n redis-team1-prod -w
oc get redb -n redis-team2-dev -w
oc get redb -n redis-team2-prod -w

# Verify all databases are active
oc get redb -A
# Expected: 4 databases, all STATUS=active
```

**Expected databases**:
- `team1-cache-dev` in `redis-team1-dev`
- `team1-cache-prod` in `redis-team1-prod`
- `team2-session-dev` in `redis-team2-dev`
- `team2-session-prod` in `redis-team2-prod`

**✅ Success**: All 4 databases show `active`

**⏭️ Next**: Continue to Step 16 (or skip to Step 19 if not using observability)

---

## Step 15: Deploy Observability Stack (GitOps - Optional)

**Skip if**: Not using observability

```bash
# Deploy observability via ArgoCD (Grafana, ServiceMonitor, PrometheusRules, Dashboards)
oc apply -f platform/argocd/apps/observability.yaml

# Watch ArgoCD sync (2-3 minutes)
oc get application redis-observability -n openshift-gitops -w

# Wait for Grafana pod
oc get pods -n redis-enterprise -w
# Wait for grafana-deployment pod to be Running

# Verify all components
oc get grafana -n redis-enterprise
oc get servicemonitor -n redis-enterprise
oc get prometheusrule -n redis-enterprise
oc get grafanadashboard -n redis-enterprise

# Get Grafana URL
oc get route grafana-route -n redis-enterprise -o jsonpath='{.spec.host}'
```

**What this deploys**:
- **Grafana Instance**: Web UI for dashboards
- **ServiceMonitor**: Prometheus scraping configuration
- **PrometheusRules**: 40+ Redis Enterprise alerts
- **Grafana DataSource**: Prometheus connection
- **Grafana Dashboards**: 4 official Redis Enterprise dashboards

**✅ Success**: ArgoCD Application synced, observability stack deployed

**⏭️ Next**: Continue to Step 16 (or skip to Step 18 if not using logging)

---

## Step 16: Deploy Logging Stack (GitOps - Optional)

**Skip if**: Not using logging

```bash
# Deploy logging via ArgoCD (LokiStack, ClusterLogForwarder, Grafana datasource)
oc apply -f platform/argocd/apps/logging.yaml

# Watch ArgoCD sync (3-5 minutes)
oc get application redis-logging -n openshift-gitops -w

# Wait for Loki pods
oc get pods -n openshift-logging -w

# Verify all components
oc get lokistack -n openshift-logging
oc get clusterlogforwarder -n openshift-logging
oc get grafanadatasource -n redis-enterprise | grep loki
```

**What this deploys**:
- **LokiStack**: Log aggregation backend
- **ClusterLogForwarder**: Forwards Redis logs to Loki
- **Grafana DataSource**: Loki connection for Grafana

**✅ Success**: ArgoCD Application synced, logging stack deployed

**⏭️ Next**: Continue to Step 17

---

## Step 17: Deploy High Availability (GitOps - Optional)

**Skip if**: Not using HA features

```bash
# Deploy HA via ArgoCD (PodDisruptionBudgets)
oc apply -f platform/argocd/apps/high-availability.yaml

# Watch ArgoCD sync (30 seconds)
oc get application redis-high-availability -n openshift-gitops -w

# Verify PDB
oc get pdb redis-cluster-pdb -n redis-enterprise
oc describe pdb redis-cluster-pdb -n redis-enterprise

# Expected output:
# Min Available: 2
# Current: 3
# Allowed Disruptions: 1
```

**What this deploys**:
- **PodDisruptionBudget**: Protects cluster quorum during node maintenance

**Note**: Anti-affinity is already configured in Helm chart by default

**✅ Success**: ArgoCD Application synced, PDB protecting demo-redis-cluster

**⏭️ Next**: Continue to Step 18

---

## Step 18: Validation

```bash
# Check all components
oc get rec -A                    # Redis clusters
oc get redb -A                   # Redis databases
oc get pdb -A                    # PodDisruptionBudgets
oc get servicemonitor -A         # Prometheus monitoring
oc get prometheusrule -A         # Alerts
oc get grafanadashboard -A       # Dashboards
oc get lokistack -A              # Logging

# Check pod distribution (anti-affinity)
oc get pods -n redis-enterprise -o wide
# Expected: Each Redis pod on different node (demo-redis-cluster-0, -1, -2)

# Check all team databases
oc get redb -n redis-team1-dev
oc get redb -n redis-team1-prod
oc get redb -n redis-team2-dev
oc get redb -n redis-team2-prod
```

**✅ Success**: All components deployed and healthy

---

## 🎉 DEPLOYMENT COMPLETE

Your Redis Enterprise multi-tenant platform is now fully deployed!

### 📊 What You Have

- ✅ **1 Redis Enterprise Cluster** (`demo-redis-cluster` with 3 nodes)
- ✅ **4 Redis Databases** across 2 teams:
  - Team 1: `team1-cache-dev` and `team1-cache-prod`
  - Team 2: `team2-session-dev` and `team2-session-prod`
- ✅ **5 Namespaces** with complete isolation
- ✅ **Governance** (Gatekeeper policies, quotas, RBAC)
- ✅ **Observability** (Grafana + 40+ alerts + 4 dashboards) - if enabled
- ✅ **Logging** (Loki + log forwarding) - if enabled
- ✅ **High Availability** (PDBs + anti-affinity) - if enabled

### 🔗 Access Points

```bash
# ArgoCD UI
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Grafana UI (if deployed)
oc get route grafana-route -n redis-enterprise -o jsonpath='{.spec.host}'

# Redis Enterprise UI
oc get route demo-redis-cluster-ui -n redis-enterprise -o jsonpath='{.spec.host}'
```

### 📚 Next Steps

1. **Test databases**: See `docs/PERFORMANCE_TESTING.md`
2. **Review alerts**: Check Prometheus alerts in OpenShift console
3. **View dashboards**: Open Grafana and explore 4 Redis dashboards
4. **Test HA**: Try draining a node to verify PDB protection

---

**Last Updated**: 2024-02-18

