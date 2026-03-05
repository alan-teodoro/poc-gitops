# End-to-End Test Runbook

This runbook is for full validation day after deployment.

Canonical flow: `docs/ARGOCD_IMPLEMENTATION_GUIDE.md`

## 0. Setup

```bash
export ARGO_NS=openshift-gitops
export REDIS_NS=redis-enterprise
export TEAM1_DEV_NS=redis-team1-dev
export TEAM1_PROD_NS=redis-team1-prod
export TEAM2_DEV_NS=redis-team2-dev
export TEAM2_PROD_NS=redis-team2-prod
```

## 1. Cluster and Operators

```bash
oc get clusterversion
oc get nodes
oc get csv -n openshift-gitops | grep gitops
oc get csv -n "$REDIS_NS" | grep redis
oc get csv -n openshift-operators | grep gatekeeper
oc get csv -n openshift-operators | grep grafana || true
oc get csv -n openshift-operators-redhat | grep loki || true
oc get csv -n openshift-logging | grep logging || true
```

## 2. Argo CD Applications Health

```bash
oc get application -n "$ARGO_NS"
```

Mandatory apps:
- `gatekeeper-instance`
- `redis-namespaces`
- `gatekeeper-templates`
- `quotas-limitranges`
- `gatekeeper-constraints`
- `redis-cluster-demo`
- `redis-rbac-demo`
- team REDB apps

Optional apps (if enabled):
- `redis-network-policies`
- `redis-observability-prometheus`
- `redis-observability-grafana`
- `redis-logging`
- `redis-high-availability`

## 3. Namespaces, Policies, and Quotas

```bash
oc get ns | grep -E 'redis-enterprise|redis-team1|redis-team2'
oc get constrainttemplates
oc get constraints -A
oc get resourcequota -n "$REDIS_NS"
oc get resourcequota -n "$TEAM1_DEV_NS"
oc get resourcequota -n "$TEAM1_PROD_NS"
oc get resourcequota -n "$TEAM2_DEV_NS"
oc get resourcequota -n "$TEAM2_PROD_NS"
oc get networkpolicies -n "$REDIS_NS" || true
```

## 4. Redis Control Plane and Databases

```bash
oc get rec -n "$REDIS_NS"
oc get pods -n "$REDIS_NS" -l app=redis-enterprise
oc get redb -A
oc get route -A | grep -E 'team1-cache|team2-session|demo-redis-cluster-ui'
```

Expected:
- REC state `Running`
- REDBs state `active`
- Redis pods all `Running`

## 5. Redis Connectivity (No Client Certificate)

```bash
DB_HOST=$(oc get route team1-cache-dev -n "$REDIS_NS" -o jsonpath='{.spec.host}')
redis-cli -h "$DB_HOST" -p 443 --tls --insecure PING
```

If mTLS is enabled for this database, this command should fail by design.

## 6. Observability and Logging (If Enabled)

```bash
oc get prometheusrule -n openshift-monitoring | grep redis || true
oc get grafana -n openshift-monitoring || true
oc get grafanadatasource -n openshift-monitoring || true
oc get grafanadashboard -n openshift-monitoring || true
oc get lokistack -n openshift-logging || true
oc get clusterlogforwarder -n openshift-logging || true
oc get daemonset grafana-alloy -n openshift-logging || true
```

## 7. Performance Tests

```bash
# Dev smoke test
oc apply -f platform/testing/test-scenarios/baseline-test.yaml
oc wait --for=condition=complete job/memtier-baseline -n "$TEAM1_DEV_NS" --timeout=5m
oc logs job/memtier-baseline -n "$TEAM1_DEV_NS"

# Optional heavier tests
oc apply -f platform/testing/test-scenarios/high-throughput-test.yaml
oc apply -f platform/testing/test-scenarios/latency-test.yaml
oc apply -f platform/testing/test-scenarios/sustained-load-test.yaml

# Optional production-safe validation
oc apply -f platform/testing/test-scenarios/production-validation-test.yaml
```

## 8. Cleanup Test Jobs

```bash
oc delete job memtier-baseline -n "$TEAM1_DEV_NS" --ignore-not-found
oc delete job memtier-high-throughput -n "$TEAM1_DEV_NS" --ignore-not-found
oc delete job memtier-latency -n "$TEAM1_DEV_NS" --ignore-not-found
oc delete job memtier-sustained-load -n "$TEAM1_DEV_NS" --ignore-not-found
oc delete job memtier-production-validation -n "$TEAM1_PROD_NS" --ignore-not-found
```

## Pass/Fail

Pass:
- Required apps `Synced/Healthy`
- REC `Running` and REDBs `active`
- Connectivity behavior matches TLS/mTLS mode
- Baseline performance job completes without Redis errors

Fail:
- Required apps `OutOfSync/Degraded`
- REC not running, REDB not active, repeated restarts
- Connectivity inconsistent with configured TLS mode
