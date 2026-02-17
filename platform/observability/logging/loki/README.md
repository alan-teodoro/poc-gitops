# Redis Enterprise Logging with Loki

## Overview

This directory contains the configuration for centralized logging using **Loki** (open source).

**Use Case**: Cloud-native environments, integrated observability with Grafana, cost-conscious deployments.

## Architecture

```
Redis Pods → Vector (collector) → LokiStack → Grafana
                                      ↓
                                  S3 (NooBaa/ODF)
```

## Components

### 1. Loki Operator Subscription
**File**: `loki-operator-subscription.yaml`

Installs the Loki Operator from Red Hat catalog (stable-6.2 channel).

### 2. LokiStack Instance
**File**: `lokistack-instance.yaml`

Deploys complete Loki stack with:
- **Size**: `1x.demo` (7 components, 1 replica each)
- **Storage**: Object storage via ObjectBucketClaim (NooBaa)
- **Retention**: 7 days
- **Components**:
  - Distributor
  - Ingester
  - Querier
  - Query Frontend
  - Compactor
  - Index Gateway
  - Gateway

### 3. ObjectBucketClaim
**File**: `lokistack-instance.yaml` (included)

Automatically creates S3 bucket using ODF/Ceph NooBaa:
- **Bucket**: `loki-logs`
- **StorageClass**: `openshift-storage.noobaa.io`
- **Auto-generates**: Secret and ConfigMap with credentials

### 4. Secret Sync Job
**File**: `loki-secret-sync-job.yaml`

Kubernetes Job that:
- Waits for ObjectBucketClaim to be ready
- Reads auto-generated credentials
- Creates `logging-loki-s3` secret for LokiStack
- **100% declarative** - no manual steps!

### 5. ClusterLogForwarder
**File**: `clusterlogforwarder.yaml`

Configures Vector to collect logs from:
- `redis` namespace
- `redis-orders-dev` namespace
- `redis-orders-prod` namespace
- `redis-session-dev` namespace
- `redis-session-prod` namespace

### 6. Grafana Datasource
**File**: `grafana-datasource-loki.yaml`

Configures Loki as datasource in Grafana:
- Uses existing Prometheus service account token
- Enables log queries in Grafana Explore
- Allows correlation with metrics

## Prerequisites

- ✅ Loki Operator (installed via subscription)
- ✅ Red Hat OpenShift Logging Operator
- ✅ ODF/Ceph with NooBaa
- ✅ Grafana Operator
- ✅ `openshift-logging` namespace

## Deployment Order

```bash
# 1. Install Loki Operator
oc apply -f loki-operator-subscription.yaml

# 2. Deploy LokiStack (includes OBC and secret sync job)
oc apply -f lokistack-instance.yaml

# 3. Wait for LokiStack to be ready
oc get lokistack -n openshift-logging -w

# 4. Deploy ClusterLogForwarder
oc apply -f clusterlogforwarder.yaml

# 5. Configure Grafana datasource
oc apply -f grafana-datasource-loki.yaml
```

## Storage Requirements

### Demo/POC (1x.demo)
- **Object Storage**: 10-50 GB (depends on log volume)
- **PVCs**: ~30 GB (Loki components)
- **Total**: ~40-80 GB

### Production (1x.small)
- **Object Storage**: 100-500 GB
- **PVCs**: ~70 GB
- **Total**: ~170-570 GB

## Accessing Logs

### In Grafana
1. Get Grafana URL:
   ```bash
   oc get route grafana-redis-monitoring -n openshift-monitoring -o jsonpath='{.spec.host}'
   ```

2. Navigate to **Explore** (compass icon)

3. Select **"Loki (Redis Logs)"** datasource

4. Use LogQL queries (see examples in main README.md)

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

### Check Loki Pods
```bash
oc get pods -n openshift-logging | grep loki
oc logs -n openshift-logging -l app.kubernetes.io/component=ingester
```

### Check ObjectBucketClaim
```bash
oc get obc -n openshift-logging
oc get secret loki-logs-bucket -n openshift-logging
oc get configmap loki-logs-bucket -n openshift-logging
```

### Check Log Forwarder
```bash
oc get clusterlogforwarder -n openshift-logging
oc logs -n openshift-logging -l app.kubernetes.io/component=collector --tail=50
```

## Advantages of Loki

✅ **Free and Open Source**
- No licensing costs
- No data limits
- No trial expiration

✅ **Integrated with Grafana**
- Same UI for metrics and logs
- Correlation between metrics and logs
- Unified observability

✅ **Cloud-Native**
- Kubernetes-native
- Scales horizontally
- GitOps-friendly

✅ **Cost-Effective**
- Uses existing ODF storage
- Efficient compression
- Low resource footprint

## References

- [Loki Operator Documentation](https://loki-operator.dev/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [OpenShift Logging Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/logging/)

