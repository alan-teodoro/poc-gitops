# Network Policies - Simplified Security

**Purpose:** Implement practical network security for Redis Enterprise using Kubernetes Network Policies.

**Approach:** Simplified strategy that provides security without breaking Redis Enterprise functionality.

---

## 🎯 Overview

This directory contains **4 simplified Network Policies**:

1. **Allow All Egress** - Permit all outbound traffic (DNS, K8s API, inter-pod, etc.)
2. **Allow Client Access** - Permit applications from labeled namespaces
3. **Allow Prometheus** - Permit Prometheus metrics scraping (port 8070)
4. **Allow Redis Internode** - Permit all traffic between Redis Enterprise pods

---

## 💡 Design Philosophy

### Why Simplified Approach?

**PROBLEM with complex Network Policies:**
- ❌ Redis Enterprise requires **40+ ports** for internal communication
- ❌ Kubernetes Network Policies use **"default deny"** behavior
- ❌ Testing policies "one by one" doesn't work due to implicit deny
- ❌ Complex port lists are **hard to maintain** and error-prone
- ❌ Missing even ONE port can cause **pod crashes**

**SOLUTION - Simplified Strategy:**
- ✅ **Allow ALL egress** (outbound traffic) - Redis pods can communicate freely
- ✅ **Restrict only ingress** (inbound traffic) - Protect from unwanted external access
- ✅ **Keep it simple and functional** - Avoid listing ports individually

### Security Benefits

Even with simplified approach, we still provide:
- ✅ **Ingress protection** - Only labeled namespaces can access Redis
- ✅ **Prometheus isolation** - Only monitoring namespace can scrape metrics
- ✅ **Pod-to-pod security** - Only Redis Enterprise pods can communicate
- ✅ **Better than no Network Policy** - Provides baseline security

---

## 📋 Network Policies

### 1. Allow All Egress

**File:** `01-allow-all-egress.yaml`

**Purpose:** Allow all pods to communicate outbound.

**Effect:** Permits DNS, K8s API, inter-pod communication, external services.

### 2. Allow Client Access

**File:** `02-allow-client-access.yaml`

**Purpose:** Allow application clients to access Redis databases.

**Source:** Namespaces labeled with `redis-client=true`

**How to enable:**
```bash
oc label namespace my-app-namespace redis-client=true
```

### 3. Allow Prometheus

**File:** `03-allow-prometheus.yaml`

**Purpose:** Allow Prometheus to scrape Redis Enterprise metrics.

**Source:** `openshift-monitoring` namespace

**Ports:** 8070 (metrics endpoint)

### 4. Allow Redis Internode

**File:** `04-allow-redis-internode.yaml`

**Purpose:** Allow Redis Enterprise cluster nodes to communicate.

**Ports:** ALL (covers 40+ required ports)

---

## 🚀 Deployment

### Apply via ArgoCD

```bash
# Apply the ArgoCD Application
oc apply -f platform/argocd/apps/network-policies.yaml

# Verify deployment
oc get application redis-network-policies -n openshift-gitops
oc get networkpolicies -n redis-enterprise
```

### Sync Wave

**Wave 2** - Applied BEFORE Redis Cluster (Wave 3)

---

## ✅ Validation

### Check Network Policies

```bash
# List all Network Policies
oc get networkpolicies -n redis-enterprise

# Describe a specific policy
oc describe networkpolicy allow-redis-internode -n redis-enterprise
```

### Verify Cluster Health

```bash
# Check Redis Enterprise Cluster
oc get rec -n redis-enterprise

# Check pods (should be Running)
oc get pods -n redis-enterprise -l app=redis-enterprise

# Check operator logs (should have no errors)
oc logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50
```

---

## ⚠️ Important Notes

### ArgoCD Health vs Pod Health

**CRITICAL:** ArgoCD can show "Synced" and "Healthy" even when pods are crashing!

**Why:** ArgoCD checks if resources match Git, NOT if pods are running.

**Solution:** Always verify pod status separately:
```bash
# Check ArgoCD status
oc get application redis-network-policies -n openshift-gitops

# ALSO check pod status
oc get pods -n redis-enterprise -l app=redis-enterprise
```

### Fresh vs Existing Cluster

- ✅ **Fresh cluster:** Network Policies in Wave 2 work perfectly
- ⚠️ **Existing cluster:** May cause temporary disruption

**Recommendation:** Deploy Network Policies BEFORE creating Redis Cluster.

---

## 📚 References

- [Redis Enterprise Port Configurations](https://redis.io/docs/latest/operate/rs/networking/port-configurations/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

