# Loki Quick Start - New Cluster

## ⚡ Fast Track Implementation

Copy and paste these commands in order:

```bash
# Step 1: Apply all Loki resources
oc apply -f platform/observability/logging/loki/lokistack-instance.yaml
sleep 30

# Step 2: Wait for OBC and apply secret sync
oc wait --for=condition=Ready obc/logging-loki-s3 -n openshift-logging --timeout=120s
oc apply -f platform/observability/logging/loki/loki-secret-sync-job.yaml
sleep 20

# Step 3: Apply ClusterLogForwarder
oc apply -f platform/observability/logging/loki/clusterlogforwarder.yaml
sleep 30

# Step 4: Create Grafana ServiceAccount with RBAC
oc apply -f platform/observability/logging/loki/grafana-loki-sa.yaml
sleep 10

# Step 5: Apply Grafana datasource
oc apply -f platform/observability/logging/loki/grafana-datasource-loki.yaml
sleep 15

# Step 6: Verify everything
echo "=== LokiStack Components ==="
oc get pods -n openshift-logging | grep loki

echo -e "\n=== Vector Collectors ==="
oc get pods -n openshift-logging | grep collector

echo -e "\n=== Grafana RBAC ==="
oc get clusterrolebinding | grep grafana-loki

echo -e "\n=== Grafana Datasource ==="
oc get grafanadatasource -n openshift-monitoring

echo -e "\n=== Grafana URL ==="
GRAFANA_URL=$(oc get route grafana-redis-monitoring -n openshift-monitoring -o jsonpath='{.spec.host}')
echo "https://$GRAFANA_URL"
```

## ✅ Expected Results

### LokiStack Components (6 of 7 running)
```
logging-loki-compactor-0                    0/1     CrashLoopBackOff   (OK - non-critical)
logging-loki-distributor-xxxxx              1/1     Running
logging-loki-gateway-xxxxx                  2/2     Running
logging-loki-index-gateway-0                1/1     Running
logging-loki-ingester-0                     1/1     Running
logging-loki-querier-xxxxx                  1/1     Running
logging-loki-query-frontend-xxxxx           1/1     Running
```

### Vector Collectors (6 pods)
```
collector-xxxxx   2/2   Running
collector-xxxxx   2/2   Running
collector-xxxxx   2/2   Running
collector-xxxxx   2/2   Running
collector-xxxxx   2/2   Running
collector-xxxxx   2/2   Running
```

### Grafana RBAC (3 bindings)
```
grafana-loki-application-logs-reader
grafana-loki-auth-delegator
grafana-loki-metrics-view
```

### Grafana Datasource
```
NAME                AGE
loki-redis-logs     30s
prometheus-redis    5h
```

## 🧪 Test in Grafana

1. Open Grafana URL (from output above)
2. Login: `admin` / `admin`
3. Click **Explore** (compass icon)
4. Select datasource: **"Loki (Redis Logs)"**
5. Run query:
   ```logql
   {kubernetes_namespace_name="redis"}
   ```
6. Should see logs from Redis namespaces

## 🐛 Troubleshooting

### No logs appearing?
```bash
# Check Vector collectors are forwarding logs
oc logs -n openshift-logging -l app.kubernetes.io/component=collector --tail=50

# Check Loki ingester is receiving logs
oc logs -n openshift-logging logging-loki-ingester-0 --tail=50
```

### Grafana datasource error?
```bash
# Check ServiceAccount token exists
oc get secret grafana-loki-token -n openshift-monitoring -o jsonpath='{.data.token}' | base64 -d | head -c 50

# Check Loki gateway logs
oc logs -n openshift-logging deployment/logging-loki-gateway --tail=50
```

### Permission denied error?
```bash
# Verify all 3 ClusterRoleBindings exist
oc get clusterrolebinding grafana-loki-auth-delegator
oc get clusterrolebinding grafana-loki-application-logs-reader
oc get clusterrolebinding grafana-loki-metrics-view
```

## 📚 Full Documentation

See `LOKI_FIXES_SUMMARY.md` for complete details on all fixes and changes.
See `docs/IMPLEMENTATION_ORDER.md` Step 23a-23h for detailed step-by-step guide.

---

**Good luck tomorrow! 🚀**

