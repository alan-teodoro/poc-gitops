# Redis Enterprise Observability

This directory contains **production-grade observability resources** for Redis Enterprise monitoring based on official Redis best practices.

## 📁 Structure

```
platform/observability/
├── prometheus/              # Prometheus monitoring (Wave 5)
│   └── prometheus-rules-redis.yaml
├── grafana/                 # Grafana dashboards (Wave 5)
│   ├── grafana-instance.yaml
│   ├── grafana-datasource-prometheus.yaml
│   ├── grafana-dashboards.yaml
│   ├── grafana-dashboards-configmaps.yaml
│   ├── grafana-prometheus-sa.yaml
│   ├── grafana-token-secret-job.yaml
│   └── grafana-route.yaml
├── dashboards/              # Dashboard JSON files
│   ├── redis-cluster-dashboard.json
│   ├── redis-database-dashboard.json
│   ├── redis-node-dashboard.json
│   ├── redis-shard-dashboard.json
│   ├── redis-logs-overview.json
│   └── redis-logs-errors.json
└── logging/                 # Logging stack (Wave 6 - optional)
    └── loki/
        ├── lokistack-instance.yaml
        ├── clusterlogforwarder.yaml
        ├── grafana-datasource-loki.yaml
        ├── grafana-dashboards-loki.yaml
        ├── grafana-dashboards-loki-crs.yaml
        └── ...
```

## 🚀 ArgoCD Applications

This observability stack is deployed via **2 separate ArgoCD Applications**:

1. **`redis-observability-prometheus`** (Wave 5)
   - **Namespace**: `openshift-monitoring`
   - **Components**: PrometheusRule (40+ alerts)
   - **Path**: `platform/observability/prometheus`

2. **`redis-observability-grafana`** (Wave 5)
   - **Namespace**: `openshift-monitoring`
   - **Components**: Grafana instance, Prometheus datasource, Prometheus dashboards, RBAC
   - **Path**: `platform/observability/grafana`

3. **`redis-logging`** (Wave 6 - Optional)
   - **Namespace**: `openshift-logging` and `openshift-monitoring`
   - **Components**: LokiStack, ClusterLogForwarder, Loki datasource, Loki dashboards
   - **Path**: `platform/observability/logging`

**Why separate?**
- ✅ Independent deployment (can deploy Prometheus without Grafana, Grafana without Loki)
- ✅ Easier troubleshooting
- ✅ Better modularity
- ✅ Can disable Grafana but keep alerts
- ✅ Can disable logging but keep metrics

---

## 📊 Components

### 1. **Prometheus Rules** (`prometheus-rules-redis.yaml`)
- **Purpose**: Production-grade alerting rules for Redis Enterprise
- **Based on**: Official Redis Enterprise Observability repository
- **Total Alerts**: 40+ comprehensive alerts
- **Alert Categories**:
  - **Latency** (2 alerts) - Average latency warning/critical
  - **Connections** (2 alerts) - No connections, excessive connections
  - **Throughput** (2 alerts) - No requests, excessive requests
  - **Capacity** (2 alerts) - Database full, predictive capacity alerts
  - **Utilization** (2 alerts) - Low hit ratio, unexpected evictions
  - **Synchronization** (4 alerts) - Replica/CRDT sync status and lag
  - **Nodes** (5 alerts) - Node health, storage, memory, CPU
  - **Shards** (5 alerts) - Shard health, CPU, hot shards, proxy
  - **Certificates & License** (6 alerts) - Certificate/license expiration, shard limits
  - **Cluster Health** (3 alerts) - Quorum, primary status, cluster down

### 2. **Grafana Dashboards**

#### **Automated Deployment** ⭐ (Recommended)
**Fully automated GitOps deployment** - dashboards appear automatically in Grafana!

```bash
# Apply Prometheus datasource + 4 official dashboards
oc apply -f platform/observability/grafana-datasource-prometheus.yaml
oc apply -f platform/observability/grafana-dashboards-configmaps.yaml
```

**📖 See**: [`docs/AUTOMATED_DASHBOARDS.md`](../../docs/AUTOMATED_DASHBOARDS.md) for complete guide.

#### **Official Redis Dashboards** (Included)
See [`docs/GRAFANA_DASHBOARDS.md`](../../docs/GRAFANA_DASHBOARDS.md) for details.

**Available Dashboards**:

**Prometheus Metrics Dashboards**:
- **Cluster Dashboard** - Overall cluster health and status
- **Database Dashboard** - Database-level metrics and performance
- **Node Dashboard** - Node-level resource monitoring
- **Shard Dashboard** - Shard-level performance and health
- **Active-Active Dashboard** - CRDB replication monitoring (optional)
- **Synchronization Overview** - Replication monitoring (optional)

**Loki Logs Dashboards**:
- **Redis Logs Overview** - Log volume metrics and log viewer
- **Redis Logs Errors** - Error and warning detection dashboard

**Source**: [Redis Enterprise Observability Repository](https://github.com/redis-field-engineering/redis-enterprise-observability)

---

## 🚀 How Monitoring Works

### Architecture

```
Redis Enterprise Pods (port 8070)
    ↓
Service (redis-cluster-metrics)
    ↓
ServiceMonitor (Prometheus scraping config)
    ↓
OpenShift Prometheus (collects metrics)
    ↓
PrometheusRule (evaluates alerts)
    ↓
Alertmanager (sends notifications)
    ↓
Grafana (visualizes metrics)
```

### Metrics Endpoint

Redis Enterprise exposes Prometheus metrics at:
- **Port**: `8070`
- **Path**: `/v2`
- **Format**: Prometheus text format

---

## 📋 Implementation Steps

### Step 1: Enable Monitoring in Cluster

Edit `clusters/orders/cluster.yaml`:

```yaml
monitoring:
  enabled: true
  scrapeInterval: 30s
  scrapeTimeout: 10s
```

### Step 2: Apply Prometheus Rules

```bash
oc apply -f platform/observability/prometheus-rules-redis.yaml
```

### Step 3: Sync Argo CD Application

```bash
# Sync cluster application (will create ServiceMonitor and Service)
argocd app sync redis-cluster-orders

# Or via oc
oc patch application redis-cluster-orders -n openshift-gitops \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Step 4: Verify Metrics Collection

```bash
# Check ServiceMonitor
oc get servicemonitor -n redis

# Check Service
oc get svc -n redis | grep metrics

# Check if Prometheus is scraping
oc exec -n openshift-monitoring prometheus-k8s-0 -- \
  curl -s http://localhost:9090/api/v1/targets | \
  jq '.data.activeTargets[] | select(.labels.job=="redis-enterprise-metrics")'
```

### Step 5: Access Grafana

```bash
# Get Grafana route
oc get route grafana -n openshift-monitoring

# Import dashboard from ConfigMap
# 1. Access Grafana UI
# 2. Go to Dashboards → Import
# 3. Copy JSON from grafana-dashboard-redis.yaml
# 4. Paste and import
```

---

## 🔍 Verifying Metrics

### Test Metrics Endpoint Directly

```bash
# Get a Redis Enterprise pod
POD=$(oc get pods -n redis -l app=redis-enterprise -o name | head -1)

# Curl metrics endpoint
oc exec -n redis $POD -- curl -s localhost:8070/v2 | head -50
```

### Query Prometheus

```bash
# Port-forward to Prometheus
oc port-forward -n openshift-monitoring prometheus-k8s-0 9090:9090 &

# Query metrics (in browser or curl)
curl "http://localhost:9090/api/v1/query?query=up{job='redis-enterprise-metrics'}"
```

---

## 📈 Key Metrics (v2 Metrics)

### Cluster Metrics
- `has_quorum` - Cluster quorum status (1=has quorum, 0=lost quorum)
- `is_primary` - Cluster primary status (1=primary, 0=not primary)
- `generation` - Cluster generation number
- `license_expiration_days` - Days until license expires
- `license_shards_limit` - Maximum shards allowed by license

### Node Metrics
- `node_metrics_up` - Node health (1=up, 0=down)
- `node_available_memory_bytes` - Available memory on node
- `node_persistent_storage_avail_bytes` - Persistent storage available
- `node_persistent_storage_free_bytes` - Persistent storage free
- `node_ephemeral_storage_free_bytes` - Ephemeral storage free
- `node_cert_expires_in_seconds` - Seconds until certificate expires
- `namedprocess_namegroup_cpu_seconds_total` - CPU usage per process

### Database Metrics
- `endpoint_up` - Database endpoint health (1=up, 0=down)
- `endpoint_total_req` - Total requests (counter)
- `endpoint_conns` - Active connections
- `endpoint_acc_latency` - Accumulated latency
- `endpoint_read_requests_latency_histogram_*` - Read latency histogram
- `endpoint_write_requests_latency_histogram_*` - Write latency histogram
- `endpoint_other_requests_latency_histogram_*` - Other requests latency histogram
- `endpoint_acc_read_hits` - Cache hits (counter)
- `endpoint_acc_read_misses` - Cache misses (counter)
- `endpoint_evicted_objects` - Evicted objects (counter)

### Shard Metrics
- `redis_server_up` - Shard health (1=up, 0=down)
- `redis_server_master_link_status` - Master link status for replicas
- `redis_server_used_memory` - Memory used by shard
- `shard_ping_failures` - Shard ping failures

### Replication Metrics
- `database_syncer_status` - Syncer status (1=active, 0=inactive)
- `database_syncer_lag_ms` - Replication lag in milliseconds
- `database_syncer_ingress_bytes` - Bytes received
- `database_syncer_egress_bytes` - Bytes sent

---

## 🚨 Alerts (40+ Production-Grade Alerts)

See [`docs/OBSERVABILITY_PRODUCTION_UPGRADE.md`](../../docs/OBSERVABILITY_PRODUCTION_UPGRADE.md) for complete details.

### Alert Categories

#### **Latency Alerts** (2)
- **RedisAverageLatencyWarning**: Average latency > 2ms
- **RedisAverageLatencyCritical**: Average latency > 5ms

#### **Connection Alerts** (2)
- **RedisNoConnections**: No connections detected
- **RedisExcessiveConnections**: Connections > 64,000

#### **Throughput Alerts** (2)
- **RedisNoRequests**: No requests detected
- **RedisExcessiveRequests**: Requests > 100,000 ops/sec

#### **Capacity Alerts** (2)
- **RedisDatabaseFull**: Memory usage > 95%
- **RedisDatabaseWillBeFull**: Database will be full in 2 hours (predictive)

#### **Utilization Alerts** (2)
- **RedisLowCacheHitRatio**: Hit ratio < 1:1
- **RedisUnexpectedEvictions**: Unexpected object evictions

#### **Synchronization Alerts** (4)
- **RedisReplicaSyncStatus**: Replica sync issues
- **RedisCRDTSyncStatus**: CRDT sync issues
- **RedisReplicaLagStatus**: Replica lag > 500ms
- **RedisCRDTLagStatus**: CRDT lag > 500ms

#### **Node Alerts** (5)
- **RedisNodeNotResponding**: Node down for 5+ minutes
- **RedisNodePersistentStorageLow**: Persistent storage < 5%
- **RedisNodeEphemeralStorageLow**: Ephemeral storage < 5GB
- **RedisNodeFreeMemoryLow**: Free memory < 5GB
- **RedisNodeHighCPUUsage**: CPU usage > 80%

#### **Shard Alerts** (5)
- **RedisShardDown**: Shard down for 1+ minute
- **RedisMasterShardDown**: Master shard down
- **RedisShardHighCPUUsage**: Shard CPU > 80%
- **RedisHotMasterShard**: Master shard CPU > 80%
- **RedisProxyHighCPUUsage**: Proxy CPU > 80%

#### **Certificate & License Alerts** (6)
- **RedisCertificateExpiringSoon**: Certificate expires in < 30 days
- **RedisCertificateExpiringCritical**: Certificate expires in < 7 days
- **RedisLicenseExpiringSoon**: License expires in < 30 days
- **RedisLicenseExpiringCritical**: License expires in < 7 days
- **RedisLicenseShardLimitApproaching**: Using > 80% of licensed shards
- **RedisLicenseShardLimitCritical**: Using > 95% of licensed shards

#### **Cluster Health Alerts** (3)
- **RedisClusterQuorumLost**: Cluster lost quorum
- **RedisClusterNotPrimary**: Cluster not in primary state
- **RedisClusterDown**: Cluster down for 5+ minutes

---

## 🛠️ Troubleshooting

### Metrics Not Appearing

```bash
# 1. Check if monitoring is enabled
oc get cm -n redis | grep cluster
oc describe rec orders-redis-cluster -n redis

# 2. Check ServiceMonitor
oc get servicemonitor -n redis
oc describe servicemonitor orders-redis-cluster-metrics -n redis

# 3. Check Service
oc get svc -n redis | grep metrics
oc describe svc orders-redis-cluster-metrics -n redis

# 4. Check Prometheus targets
oc exec -n openshift-monitoring prometheus-k8s-0 -- \
  curl -s http://localhost:9090/api/v1/targets | jq .
```

### Alerts Not Firing

```bash
# Check PrometheusRule
oc get prometheusrule -n openshift-monitoring
oc describe prometheusrule redis-enterprise-alerts -n openshift-monitoring

# Check Prometheus rules
oc exec -n openshift-monitoring prometheus-k8s-0 -- \
  curl -s http://localhost:9090/api/v1/rules | jq .
```

---

## 📚 References

### Official Redis Documentation
- [Redis Enterprise Observability](https://redis.io/docs/latest/integrate/prometheus-with-redis-enterprise/observability/)
- [Prometheus Metrics v2](https://redis.io/docs/latest/integrate/prometheus-with-redis-enterprise/prometheus-metrics-definitions/)
- [Redis Enterprise Monitoring](https://docs.redis.com/latest/rs/clusters/monitoring/prometheus-integration/)

### Official Redis Repository
- [Redis Enterprise Observability Repository](https://github.com/redis-field-engineering/redis-enterprise-observability)
- [Official Grafana Dashboards](https://github.com/redis-field-engineering/redis-enterprise-observability/tree/main/grafana_v2/dashboards)
- [Official Prometheus Rules](https://github.com/redis-field-engineering/redis-enterprise-observability/tree/main/prometheus_v2/rules)

### OpenShift Documentation
- [OpenShift Monitoring](https://docs.openshift.com/container-platform/latest/monitoring/monitoring-overview.html)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)

### Project Documentation
- [`docs/GRAFANA_DASHBOARDS.md`](../../docs/GRAFANA_DASHBOARDS.md) - Official dashboard guide
- [`docs/AUTOMATED_DASHBOARDS.md`](../../docs/AUTOMATED_DASHBOARDS.md) - Automated dashboard deployment
- [`docs/OBSERVABILITY_PRODUCTION_UPGRADE.md`](../../docs/OBSERVABILITY_PRODUCTION_UPGRADE.md) - Production upgrade summary
- [`docs/OBSERVABILITY.md`](../../docs/OBSERVABILITY.md) - Complete observability guide
- [`docs/OBSERVABILITY_IMPLEMENTATION.md`](../../docs/OBSERVABILITY_IMPLEMENTATION.md) - Implementation steps

