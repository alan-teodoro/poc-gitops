# ArgoCD Applications

This directory contains ArgoCD Application manifests for GitOps deployment.

## 📁 Structure

```
platform/argocd/apps/
├── namespaces.yaml              # Wave 1: Create namespaces
├── gatekeeper-policies.yaml     # Wave 2: Deploy Gatekeeper policies
├── quotas-limitranges.yaml      # Wave 2: Apply quotas and limitranges
├── observability.yaml           # Wave 5: Grafana, Prometheus monitoring
├── logging.yaml                 # Wave 6: Loki logging stack
└── high-availability.yaml       # Wave 7: PodDisruptionBudgets
```

## 🌊 Sync Waves

Applications are deployed in order using sync waves:

| Wave | Application | Purpose |
|------|-------------|---------|
| 1 | `namespaces` | Create all required namespaces |
| 2 | `gatekeeper-policies` | Deploy policy templates and constraints |
| 2 | `quotas-limitranges` | Apply resource quotas and limits |
| 3 | `redis-cluster` | Deploy Redis Enterprise Cluster (in clusters/) |
| 4 | `redis-rbac` | Deploy multi-namespace RBAC (in clusters/) |
| 4 | `redis-databases` | Deploy Redis databases (in clusters/) |
| 5 | `observability` | Deploy Grafana, ServiceMonitor, PrometheusRules |
| 6 | `logging` | Deploy LokiStack and log forwarding |
| 7 | `high-availability` | Deploy PodDisruptionBudgets |

## 🚀 Deployment

### Option 1: Deploy Individual Applications

```bash
# Deploy namespaces
oc apply -f platform/argocd/apps/namespaces.yaml

# Deploy policies
oc apply -f platform/argocd/apps/gatekeeper-policies.yaml

# Deploy quotas
oc apply -f platform/argocd/apps/quotas-limitranges.yaml

# Deploy observability (optional)
oc apply -f platform/argocd/apps/observability.yaml

# Deploy logging (optional)
oc apply -f platform/argocd/apps/logging.yaml

# Deploy HA (optional)
oc apply -f platform/argocd/apps/high-availability.yaml
```

### Option 2: Deploy All at Once

```bash
# Deploy all platform applications
oc apply -f platform/argocd/apps/

# Watch sync status
oc get applications -n openshift-gitops -w
```

## 🔍 Monitoring

```bash
# Check application status
oc get applications -n openshift-gitops

# Check specific application
oc describe application redis-namespaces -n openshift-gitops

# View sync status
argocd app list
argocd app get redis-namespaces
```

## 🎯 AppProjects

Applications are assigned to AppProjects for RBAC:

- **platform-team**: Infrastructure applications (namespaces, policies, observability, HA)
- **app-team1**: Team 1 applications (cache databases)
- **app-team2**: Team 2 applications (session databases)

## 📝 Notes

- All applications use **automated sync** with **prune** and **selfHeal** enabled
- Sync waves ensure proper deployment order
- Applications reference the main branch of the Git repository
- Namespace creation is handled by the `namespaces` application

