# Redis Enterprise Logging - Multi-Option Reference Architecture

## Overview

This directory contains **TWO logging implementations** for Redis Enterprise, demonstrating different enterprise approaches:

### **Option 1: Loki (Open Source)** 📁 `loki/`
- **Stack**: Prometheus + Loki + Grafana (PLG)
- **License**: Open Source (Apache 2.0)
- **Cost**: FREE, unlimited
- **Best for**: Cloud-native, cost-conscious, integrated observability

### **Option 2: Splunk (Enterprise)** 📁 `splunk/`
- **Stack**: Splunk Enterprise
- **License**: Trial (60 days) or Enterprise
- **Cost**: FREE trial (500 MB/day), then paid
- **Best for**: Enterprises with existing Splunk, advanced features

---

## Quick Comparison

| Feature | **Loki** | **Splunk** |
|---------|----------|------------|
| **License** | ✅ Open Source (Free) | ⚠️ Trial 60 days or Paid |
| **Data Limit** | ✅ Unlimited | ⚠️ 500 MB/day (trial) |
| **Storage** | ✅ NooBaa (ODF) | ✅ PVC (ODF) |
| **Query Language** | LogQL (simple) | SPL (powerful) |
| **UI** | Grafana (integrated) | Splunk Web (built-in) |
| **Grafana Integration** | ✅ Native | ⚠️ Plugin required |
| **Learning Curve** | ✅ Easy | ⚠️ Steeper |
| **Production Cost** | ✅ Free | ❌ High |
| **Lab/POC** | ✅ Perfect | ✅ Perfect (60 days) |

---

## Architecture

### Loki Architecture
```
Redis Pods → Vector (collector) → LokiStack → Grafana
                                      ↓
                                  S3 (NooBaa)
```

### Splunk Architecture
```
Redis Pods → Vector (collector) → Splunk HEC → Splunk Enterprise
                                                    ↓
                                                PVC Storage
```

---

## 🎯 Which Option Should You Choose?

### Choose **Loki** if:
- ✅ You want a **free, unlimited** solution
- ✅ You already use **Grafana** for metrics
- ✅ You prefer **open source** technologies
- ✅ You want **integrated observability** (metrics + logs in one UI)
- ✅ You're building a **cloud-native** architecture
- ✅ **Budget is limited**

### Choose **Splunk** if:
- ✅ Organization **already has Splunk license**
- ✅ Team is **trained in SPL** (Splunk Processing Language)
- ✅ You need **advanced features** (Machine Learning, SIEM)
- ✅ **Compliance requires Splunk**
- ✅ You're doing a **short-term lab/POC** (60-day trial is perfect)

### For This Lab/POC:
**Both options work perfectly!** Since your cluster lasts only 3 days:
- ✅ **Loki**: No limitations, fully functional
- ✅ **Splunk**: 60-day trial is more than enough

**Recommendation**: Implement **BOTH** to show different enterprise approaches! 🎯

---

## Components

### Option 1: Loki Components (`loki/`)

1. **Loki Operator Subscription** (`loki-operator-subscription.yaml`)
   - Installs Loki Operator from Red Hat catalog

2. **LokiStack Instance** (`lokistack-instance.yaml`)
   - Deploys Loki with object storage (NooBaa)
   - Size: `1x.demo` (7 components)
   - Retention: 7 days

3. **Secret Sync Job** (`loki-secret-sync-job.yaml`)
   - Automatically syncs S3 credentials from OBC
   - 100% declarative (no manual steps)

4. **ClusterLogForwarder** (`clusterlogforwarder.yaml`)
   - Collects logs from Redis namespaces
   - Forwards to LokiStack

5. **Grafana Datasource** (`grafana-datasource-loki.yaml`)
   - Configures Loki in Grafana
   - Enables log queries in Explore

### Option 2: Splunk Components (`splunk/`)

1. **Splunk Standalone** (`splunk-standalone.yaml`)
   - Deploys Splunk Enterprise instance
   - Trial license (60 days, 500 MB/day)
   - HEC enabled on port 8088

2. **HEC Setup Job** (`splunk-hec-setup-job.yaml`)
   - Automatically creates HEC token
   - Syncs token to openshift-logging namespace
   - 100% declarative

3. **ClusterLogForwarder** (`clusterlogforwarder-splunk.yaml`)
   - Collects logs from Redis namespaces
   - Forwards to Splunk HEC

4. **Splunk Web UI**
   - Built-in UI for log search and analysis
   - SPL query language

---

## Prerequisites

### Common (Both Options)
- ✅ Red Hat OpenShift Logging Operator installed
- ✅ ODF/Ceph for storage
- ✅ `openshift-logging` namespace exists

### Loki-Specific
- ✅ Loki Operator (install via `loki-operator-subscription.yaml`)
- ✅ Grafana Operator installed
- ✅ NooBaa (ODF) for object storage

### Splunk-Specific
- ✅ Splunk Operator installed (already done)
- ✅ 60 GB storage available (PVCs)

---

## Deployment Order

### Option 1: Loki
1. Install Loki Operator
2. Deploy ObjectBucketClaim (auto-creates S3 bucket)
3. Run secret sync job (auto-syncs credentials)
4. Deploy LokiStack instance
5. Deploy ClusterLogForwarder
6. Configure Grafana datasource

### Option 2: Splunk
1. Deploy Splunk Standalone instance
2. Wait for Splunk to be ready
3. Run HEC setup job (auto-creates token)
4. Deploy ClusterLogForwarder
5. Access Splunk Web UI

## Storage Requirements

### Demo/POC (1x.demo)
- **Ingester**: 10Gi PVC
- **Querier**: 10Gi PVC
- **Compactor**: 10Gi PVC
- **Total**: ~30Gi

### Production (1x.small)
- **Ingester**: 3x 10Gi PVC
- **Querier**: 3x 10Gi PVC
- **Compactor**: 10Gi PVC
- **Total**: ~70Gi

## Log Retention

Default retention: **7 days**

To customize, edit LokiStack spec:
```yaml
spec:
  limits:
    global:
      retention:
        days: 7
```

---

## Querying Logs

### Loki (in Grafana Explore)

**Access**: Grafana → Explore → Select "Loki (Redis Logs)" datasource

**LogQL Examples**:
```logql
# All Redis Enterprise logs
{kubernetes_namespace_name="redis"}

# Specific database logs
{kubernetes_namespace_name="redis-orders-dev"}

# Error logs only
{kubernetes_namespace_name=~"redis.*"} |= "error"

# Logs from specific pod
{kubernetes_pod_name="orders-redis-cluster-0"}

# Latency-related logs
{kubernetes_namespace_name="redis"} |= "latency"

# Last 15 minutes
{kubernetes_namespace_name="redis"} [15m]

# Count by namespace
sum by (kubernetes_namespace_name) (count_over_time({kubernetes_namespace_name=~"redis.*"}[5m]))
```

### Splunk (in Splunk Web UI)

**Access**: Splunk Web → Search & Reporting

**SPL Examples**:
```spl
# All Redis logs
index=redis_logs

# Specific namespace
index=redis_logs kubernetes.namespace_name="redis-orders-dev"

# Error logs
index=redis_logs "error" OR "ERROR"

# Logs from specific pod
index=redis_logs kubernetes.pod_name="orders-redis-cluster-0"

# Latency-related logs
index=redis_logs "latency"

# Last 15 minutes
index=redis_logs earliest=-15m

# Count by namespace
index=redis_logs | stats count by kubernetes.namespace_name

# Timeline chart
index=redis_logs | timechart count by kubernetes.namespace_name
```

## Troubleshooting

### Check Loki Operator
```bash
oc get csv -n openshift-operators-redhat | grep loki
```

### Check LokiStack Status
```bash
oc get lokistack -n openshift-logging
oc describe lokistack logging-loki -n openshift-logging
```

### Check Log Forwarder
```bash
oc get clusterlogforwarder -n openshift-logging
oc logs -n openshift-logging -l app.kubernetes.io/component=collector
```

### Check Loki Pods
```bash
oc get pods -n openshift-logging
oc logs -n openshift-logging -l app.kubernetes.io/component=ingester
```

## References

- [OpenShift Logging Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/logging/)
- [Loki Operator Documentation](https://loki-operator.dev/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)

