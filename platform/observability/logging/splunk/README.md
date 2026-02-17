# Redis Enterprise Logging with Splunk

## Overview

This directory contains the configuration for centralized logging using **Splunk Enterprise**.

**Use Case**: Enterprise environments that already have Splunk licenses or require Splunk-specific features.

## Architecture

```
Redis Pods → Vector (collector) → Splunk HEC → Splunk Enterprise
```

## Components

### 1. Splunk Standalone Instance
**File**: `splunk-standalone.yaml`

Deploys a single Splunk Enterprise instance with:
- **License**: 60-day Enterprise Trial (500 MB/day)
- **Storage**: 50 GB for indexes, 10 GB for config
- **HEC**: HTTP Event Collector enabled on port 8088
- **Indexes**: `redis_logs`, `redis_metrics`
- **Retention**: 7 days

### 2. HEC Setup Job
**File**: `splunk-hec-setup-job.yaml`

Automatically configures Splunk HEC:
- Creates HEC token via Splunk API
- Syncs token to `openshift-logging` namespace
- Enables HEC input for `redis_logs` index

### 3. ClusterLogForwarder
**File**: `clusterlogforwarder-splunk.yaml`

Configures log collection from:
- `redis` namespace (Redis Enterprise Cluster)
- `redis-orders-dev` namespace
- `redis-orders-prod` namespace
- `redis-session-dev` namespace
- `redis-session-prod` namespace

## Prerequisites

- ✅ Splunk Operator installed (already done)
- ✅ Red Hat OpenShift Logging Operator installed
- ✅ ODF/Ceph for persistent storage
- ✅ `openshift-logging` namespace exists

## Deployment Order

1. Deploy Splunk Standalone instance
2. Wait for Splunk to be ready
3. Run HEC setup job (creates token)
4. Deploy ClusterLogForwarder

## License Information

### Trial License (Default)
- **Duration**: 60 days
- **Data Limit**: 500 MB/day
- **Features**: Full Enterprise features
- **Cost**: FREE
- **Perfect for**: Labs, POCs, demos (3-day clusters)

### Production License
For production use, you need:
- Splunk Enterprise License
- Configure via `licenseUrl` or `licenseMasterRef` in Standalone spec

## Storage Requirements

### Lab/Demo (Standalone)
- **Config**: 10 GB (PVC)
- **Data**: 50 GB (PVC)
- **Total**: ~60 GB

### Production (Distributed)
- **Indexers**: 3x 100 GB
- **Search Heads**: 3x 50 GB
- **Total**: ~450 GB

## Accessing Splunk

### Web UI
```bash
# Get Splunk URL
SPLUNK_URL=$(oc get route splunk-web -n splunk -o jsonpath='{.spec.host}')
echo "Splunk URL: https://$SPLUNK_URL"

# Get admin password
ADMIN_PASSWORD=$(oc get secret splunk-admin -n splunk -o jsonpath='{.data.password}' | base64 -d)
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"
```

### Searching Logs

1. Login to Splunk Web UI
2. Navigate to **Search & Reporting**
3. Use SPL (Splunk Processing Language):

```spl
# All Redis logs
index=redis_logs

# Logs from specific namespace
index=redis_logs kubernetes.namespace_name="redis-orders-dev"

# Error logs
index=redis_logs "error" OR "ERROR"

# Logs from specific pod
index=redis_logs kubernetes.pod_name="orders-redis-cluster-0"

# Latency-related logs
index=redis_logs "latency"

# Time range: Last 15 minutes
index=redis_logs earliest=-15m

# Statistics: Count by namespace
index=redis_logs | stats count by kubernetes.namespace_name
```

## Troubleshooting

### Check Splunk Operator
```bash
oc get csv -n openshift-operators | grep splunk
```

### Check Splunk Pod
```bash
oc get pods -n splunk
oc logs -n splunk -l app.kubernetes.io/component=standalone
```

### Check HEC Status
```bash
# Get HEC token
oc get secret splunk-hec-token -n openshift-logging -o jsonpath='{.data.hecToken}' | base64 -d

# Test HEC endpoint
HEC_TOKEN=$(oc get secret splunk-hec-token -n openshift-logging -o jsonpath='{.data.hecToken}' | base64 -d)
curl -k -H "Authorization: Splunk $HEC_TOKEN" \
  https://splunk-hec-splunk.apps.cluster.com/services/collector/event \
  -d '{"event": "test", "sourcetype": "_json"}'
```

### Check Log Forwarder
```bash
oc get clusterlogforwarder -n openshift-logging
oc logs -n openshift-logging -l app.kubernetes.io/component=collector --tail=50
```

## Comparison: Splunk vs Loki

| Feature | Splunk | Loki |
|---------|--------|------|
| **License** | Trial (60 days) or Paid | Open Source (Free) |
| **Data Limit** | 500 MB/day (trial) | Unlimited |
| **Query Language** | SPL (powerful) | LogQL (simpler) |
| **UI** | Built-in (rich) | Grafana (integrated) |
| **Learning Curve** | Steeper | Easier |
| **Enterprise Features** | Advanced (ML, SIEM) | Basic |
| **Cost** | High (production) | Low/Free |
| **Best For** | Enterprises with license | Cloud-native, cost-conscious |

## When to Use Splunk

✅ **Use Splunk if**:
- Organization already has Splunk license
- Need advanced features (Machine Learning, SIEM)
- Team is trained in SPL
- Compliance requires Splunk
- Budget approved for licensing

❌ **Don't use Splunk if**:
- No existing license
- 500 MB/day limit is too restrictive
- Budget constrained
- Prefer open source solutions

## References

- [Splunk Operator Documentation](https://splunk.github.io/splunk-operator/)
- [Splunk HEC Documentation](https://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector)
- [SPL Reference](https://docs.splunk.com/Documentation/Splunk/latest/SearchReference/)

