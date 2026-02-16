# Resource Quotas and LimitRanges

## Overview

This directory contains **ResourceQuota** and **LimitRange** templates for Redis Enterprise namespaces.

**Purpose**: Control resource consumption and prevent cluster exhaustion

**Managed by**: Platform Team

---

## Files

| File | Purpose | Applied To |
|------|---------|------------|
| `dev-quota-template.yaml` | ResourceQuota for dev namespaces | `redis-*-dev` |
| `dev-limitrange-template.yaml` | LimitRange for dev namespaces | `redis-*-dev` |
| `prod-quota-template.yaml` | ResourceQuota for prod namespaces | `redis-*-prod` |
| `prod-limitrange-template.yaml` | LimitRange for prod namespaces | `redis-*-prod` |

---

## Quick Reference

### Dev Namespaces

```yaml
ResourceQuota (total namespace):
  requests.cpu: 4
  requests.memory: 8Gi
  limits.cpu: 8
  limits.memory: 16Gi

LimitRange (per container):
  max: 4 CPU, 8Gi
  min: 100m, 128Mi
  default: 500m, 1Gi
```

### Prod Namespaces

```yaml
ResourceQuota (total namespace):
  requests.cpu: 16
  requests.memory: 32Gi
  limits.cpu: 32
  limits.memory: 64Gi

LimitRange (per container):
  max: 8 CPU, 16Gi
  min: 100m, 128Mi
  default: 1 CPU, 2Gi
```

---

## ⚠️ Avoiding Conflicts with Redis Enterprise Operator

### Problem

The **Redis Enterprise Operator** creates pods with specific resource requirements. If **LimitRange** or **ResourceQuota** are too restrictive, pods will fail to create.

### Typical Redis Enterprise Resource Requirements

**Cluster Nodes** (RedisEnterpriseCluster):
```yaml
# Small cluster (dev)
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 2
    memory: 4Gi

# Large cluster (prod)
resources:
  requests:
    cpu: 4
    memory: 8Gi
  limits:
    cpu: 8
    memory: 16Gi
```

**Database Pods** (RedisEnterpriseDatabase):
- Usually inherit from cluster node resources
- Typically smaller (500m CPU, 1Gi RAM)

### How These Templates Accommodate the Operator

✅ **Dev LimitRange**:
- `max: 4 CPU, 8Gi` per container
- Allows Redis Enterprise nodes up to 2 CPU, 4Gi (with headroom)

✅ **Prod LimitRange**:
- `max: 8 CPU, 16Gi` per container
- Allows Redis Enterprise nodes up to 8 CPU, 16Gi

✅ **ResourceQuota**:
- Dev: 8 CPU total (can fit 3 nodes × 2 CPU + databases)
- Prod: 32 CPU total (can fit 3 nodes × 8 CPU + databases)

### Checking for Conflicts

```bash
# 1. Check if pods are pending
oc get pods -n redis-orders-dev

# 2. Check events for quota/limit errors
oc get events -n redis-orders-dev --sort-by='.lastTimestamp' | grep -i "quota\|limit"

# 3. Check current resource usage vs quota
oc describe resourcequota -n redis-orders-dev

# 4. Check what the operator is trying to create
oc describe pod <pending-pod-name> -n redis-orders-dev
```

### Common Error Messages

**LimitRange Violation**:
```
Error: maximum cpu usage per Container is 2, but requested 4
```
**Solution**: Increase `max` in LimitRange

**ResourceQuota Violation**:
```
Error: exceeded quota: redis-dev-quota, 
requested: requests.cpu=2, 
used: requests.cpu=3, 
limited: requests.cpu=4
```
**Solution**: Increase quota OR reduce pod resources OR delete unused pods

---

## How to Apply

### For New Namespaces

```bash
# Dev namespace
oc apply -f platform/quotas/dev-quota-template.yaml -n redis-orders-dev
oc apply -f platform/quotas/dev-limitrange-template.yaml -n redis-orders-dev

# Prod namespace
oc apply -f platform/quotas/prod-quota-template.yaml -n redis-orders-prod
oc apply -f platform/quotas/prod-limitrange-template.yaml -n redis-orders-prod
```

### For Additional Teams

```bash
# Payments team
oc apply -f platform/quotas/dev-quota-template.yaml -n redis-payments-dev
oc apply -f platform/quotas/dev-limitrange-template.yaml -n redis-payments-dev
oc apply -f platform/quotas/prod-quota-template.yaml -n redis-payments-prod
oc apply -f platform/quotas/prod-limitrange-template.yaml -n redis-payments-prod
```

---

## Monitoring Resource Usage

```bash
# View quota usage
oc describe resourcequota -n redis-orders-dev

# View per-pod resource requests
oc get pods -n redis-orders-dev -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory,\
CPU_LIM:.spec.containers[*].resources.limits.cpu,\
MEM_LIM:.spec.containers[*].resources.limits.memory

# View total usage across all namespaces
oc get resourcequota --all-namespaces | grep redis
```

---

## Adjusting Quotas

If you need to adjust quotas (e.g., cluster growing):

```bash
# Edit the template file
vim platform/quotas/dev-quota-template.yaml

# Re-apply
oc apply -f platform/quotas/dev-quota-template.yaml -n redis-orders-dev

# Verify
oc describe resourcequota redis-dev-quota -n redis-orders-dev
```

---

## References

- [Kubernetes ResourceQuota](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Kubernetes LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Redis Enterprise Resource Requirements](https://docs.redis.com/latest/kubernetes/deployment/quick-start/)

