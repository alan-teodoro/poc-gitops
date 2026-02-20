# Grafana Alloy for Redis Enterprise Internal Logs

## Overview

This directory contains the configuration for **Grafana Alloy** to collect **Redis Enterprise internal logs** from `/var/opt/redislabs/log/` and forward them to Loki.

## Why Grafana Alloy?

According to the [official Grafana documentation for Redis Enterprise](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-redis-enterprise/), the recommended approach for collecting Redis Enterprise internal logs is to use **Grafana Alloy** with the `loki.source.file` component.

### What Logs Are Collected?

**Redis Enterprise Internal Logs** (files inside pods):
- `/var/opt/redislabs/log/redis-*.log` - Database logs
- `/var/opt/redislabs/log/node-*.log` - Node logs
- `/var/opt/redislabs/log/cluster-*.log` - Cluster logs

**Note**: Kubernetes stdout/stderr logs are collected separately by ClusterLogForwarder (see `../loki/clusterlogforwarder.yaml`).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Redis Enterprise Pods                                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /var/opt/redislabs/log/                                 │ │
│ │   ├── redis-1.log                                       │ │
│ │   ├── node-1.log                                        │ │
│ │   └── cluster.log                                       │ │
│ └─────────────────────────────────────────────────────────┘ │
│                          ▲                                   │
│                          │ (hostPath mount)                  │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           │
┌──────────────────────────▼───────────────────────────────────┐
│ Grafana Alloy DaemonSet (on each node)                      │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ loki.source.file component                              │ │
│ │   - Reads log files from /var/log/pods/                │ │
│ │   - Parses and labels logs                              │ │
│ │   - Forwards to Loki                                    │ │
│ └─────────────────────────────────────────────────────────┘ │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Loki (openshift-logging namespace)                          │
│   - Stores logs                                              │
│   - Indexed by labels (namespace, pod, cluster, etc.)       │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Grafana (openshift-monitoring namespace)                    │
│   - Visualize logs in dashboards                            │
│   - Query logs with LogQL                                   │
│   - Correlate with metrics                                  │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Grafana Alloy ConfigMap
**File**: `alloy-config.yaml`

Contains the Alloy configuration in River format:
- `loki.source.file` - Reads Redis internal log files
- `loki.write` - Forwards logs to Loki

### 2. Grafana Alloy DaemonSet
**File**: `alloy-daemonset.yaml`

Deploys Alloy on every node to collect logs:
- **Runs as**: Privileged container (needs access to host filesystem)
- **Mounts**: `/var/log/pods` from host
- **Permissions**: Added to `redislabs` group

### 3. RBAC
**File**: `alloy-rbac.yaml`

ServiceAccount, ClusterRole, ClusterRoleBinding for Alloy.

### 4. Grafana Dashboards
**File**: `grafana-dashboards-redis-internal-logs.yaml`

Dashboards to visualize Redis internal logs:
- Redis Cluster Logs Dashboard
- Redis Node Logs Dashboard
- Redis Database Logs Dashboard

## Deployment Order (Sync Waves)

```
Wave 13: RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
Wave 14: ConfigMap (Alloy configuration)
Wave 15: DaemonSet (Alloy pods)
Wave 16: Dashboards (Grafana dashboards)
```

## Installation

Deployed automatically via ArgoCD Application `redis-logging` (sync-wave 6).

## Verification

```bash
# Check Alloy pods
oc get pods -n openshift-logging -l app=grafana-alloy

# Check Alloy logs
oc logs -n openshift-logging -l app=grafana-alloy --tail=50

# Check if logs are being collected
oc logs -n openshift-logging -l app=grafana-alloy | grep "loki.source.file"

# Query logs in Grafana
# LogQL: {job="integrations/redis-enterprise"}
```

## Troubleshooting

### Alloy pods not starting
```bash
# Check DaemonSet status
oc get daemonset grafana-alloy -n openshift-logging

# Check pod events
oc describe pod -n openshift-logging -l app=grafana-alloy
```

### No logs being collected
```bash
# Check if log files exist in Redis pods
oc exec -n redis-enterprise demo-redis-cluster-0 -- ls -la /var/opt/redislabs/log/

# Check Alloy configuration
oc get configmap grafana-alloy-config -n openshift-logging -o yaml

# Check Alloy logs for errors
oc logs -n openshift-logging -l app=grafana-alloy | grep -i error
```

### Permission denied errors
```bash
# Verify Alloy is running as privileged
oc get pod -n openshift-logging -l app=grafana-alloy -o jsonpath='{.items[0].spec.containers[0].securityContext}'

# Verify hostPath mount
oc get pod -n openshift-logging -l app=grafana-alloy -o jsonpath='{.items[0].spec.volumes}'
```

## References

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Grafana Redis Enterprise Integration](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-redis-enterprise/)
- [Loki Source File Component](https://grafana.com/docs/alloy/latest/reference/components/loki.source.file/)

