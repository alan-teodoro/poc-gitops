# Argo CD Applications (Platform)

This directory contains platform-level Argo CD `Application` manifests used by the canonical implementation flow.

Reference order: `docs/ARGOCD_IMPLEMENTATION_GUIDE.md`

## Files and Waves

| Wave | File | Application Name | Scope |
|---|---|---|---|
| 0 | `gatekeeper-instance.yaml` | `gatekeeper-instance` | Gatekeeper instance bootstrap |
| 1 | `namespaces.yaml` | `redis-namespaces` | Create Redis namespaces |
| 2 | `gatekeeper-templates.yaml` | `gatekeeper-templates` | ConstraintTemplates (CRDs) |
| 2 | `quotas-limitranges.yaml` | `quotas-limitranges` | ResourceQuota + LimitRange |
| 2 | `network-policies.yaml` | `redis-network-policies` | Optional network policies |
| 3 | `gatekeeper-constraints.yaml` | `gatekeeper-constraints` | Policy constraints enforcement |
| 5 | `observability-prometheus.yaml` | `redis-observability-prometheus` | Prometheus rules |
| 5 | `observability-grafana.yaml` | `redis-observability-grafana` | Grafana instance + datasource + dashboards |
| 6 | `logging.yaml` | `redis-logging` | Optional Loki logging stack |
| 7 | `high-availability.yaml` | `redis-high-availability` | Optional PDBs |

Notes:
- Redis cluster/RBAC/REDB applications are in `clusters/redis-cluster-demo/`.
- Optional modules can be skipped based on your feature toggle strategy.

## Apply Sequence

```bash
oc apply -f platform/argocd/apps/gatekeeper-instance.yaml
oc apply -f platform/argocd/apps/namespaces.yaml
oc apply -f platform/argocd/apps/gatekeeper-templates.yaml
oc apply -f platform/argocd/apps/quotas-limitranges.yaml
# Optional: security hardening
oc apply -f platform/argocd/apps/network-policies.yaml
oc apply -f platform/argocd/apps/gatekeeper-constraints.yaml

# Optional observability stack
oc apply -f platform/argocd/apps/observability-prometheus.yaml
oc apply -f platform/argocd/apps/observability-grafana.yaml

# Optional logging and HA
oc apply -f platform/argocd/apps/logging.yaml
oc apply -f platform/argocd/apps/high-availability.yaml
```

## Quick Validation

```bash
oc get application -n openshift-gitops
oc get application gatekeeper-instance -n openshift-gitops
oc get application redis-namespaces -n openshift-gitops
oc get application quotas-limitranges -n openshift-gitops
oc get application gatekeeper-constraints -n openshift-gitops
```

Expected for active modules: `SYNC STATUS=Synced` and `HEALTH STATUS=Healthy`.

## Test Day Tip

Use `platform/testing/TEST_RUNBOOK.md` for end-to-end validation commands after sync.

## Single Apply Option (Recommended)

If you want one root apply with `enabled: true/false` toggles per component, use:

```bash
oc apply -f platform/argocd/bootstrap/root-application.yaml
```

Then toggle components in:

- `platform/argocd/bootstrap/chart/values.yaml`
