# Network Policies - Zero-Trust Security

**Purpose:** Implement zero-trust network security for Redis Enterprise using Kubernetes Network Policies.

**Compliance:** Required for banking, fintech, and healthcare environments (PCI-DSS, SOC2, ISO 27001).

---

## 🎯 Overview

This directory contains **7 Network Policies** that implement a zero-trust security model:

1. **Default Deny All** - Block all traffic by default
2. **Allow DNS** - Allow DNS resolution (CoreDNS)
3. **Allow Kubernetes API** - Allow pods to communicate with K8s API
4. **Allow Redis Internode** - Allow Redis cluster communication
5. **Allow Client Access** - Allow applications to access Redis databases
6. **Allow Prometheus** - Allow Prometheus to scrape metrics
7. **Allow Backup** - Allow backup traffic (future use)

---

## 🔒 Security Model

### Zero-Trust Principles

1. **Default Deny** - All traffic blocked by default
2. **Explicit Allow** - Only required traffic is allowed
3. **Least Privilege** - Minimal permissions for each component
4. **Defense in Depth** - Multiple layers of security

### Traffic Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Default Deny All (Baseline)                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Allow DNS (CoreDNS on port 53)                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Allow Kubernetes API (port 443)                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Allow Redis Internode (ports 3333-3354, 8001, 8070, etc.)  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Allow Client Access (port 443 for databases)                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Allow Prometheus (port 8070 for metrics)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Network Policies

### 1. Default Deny All (`01-default-deny-all.yaml`)

**Purpose:** Block all ingress and egress traffic by default.

**Applies to:** All pods in `redis-enterprise` namespace.

**Effect:** Creates baseline security - all traffic must be explicitly allowed.

### 2. Allow DNS (`02-allow-dns.yaml`)

**Purpose:** Allow DNS resolution via CoreDNS.

**Ports:** 53 (UDP/TCP)

**Destination:** `kube-system` namespace (CoreDNS)

### 3. Allow Kubernetes API (`03-allow-k8s-api.yaml`)

**Purpose:** Allow Redis Enterprise Operator to communicate with Kubernetes API.

**Ports:** 443 (TCP)

**Destination:** Kubernetes API server

### 4. Allow Redis Internode (`04-allow-redis-internode.yaml`)

**Purpose:** Allow Redis cluster nodes to communicate with each other.

**Ports:**
- 3333-3354: Cluster communication
- 8001: REST API
- 8070: Metrics
- 8443: Admin UI
- 9443: Admission controller
- 12000-12003: Database ports (example)
- 36379: Sentinel

### 5. Allow Client Access (`05-allow-client-access.yaml`)

**Purpose:** Allow applications to access Redis databases.

**Ports:** 443 (TLS), 10000-19999 (database ports)

**Source:** Namespaces with label `redis-client=true`

### 6. Allow Prometheus (`06-allow-prometheus.yaml`)

**Purpose:** Allow Prometheus to scrape Redis metrics.

**Ports:** 8070 (metrics endpoint)

**Source:** `openshift-monitoring` namespace

### 7. Allow Backup (`07-allow-backup.yaml`)

**Purpose:** Allow backup traffic to S3/NooBaa (future use).

**Ports:** 443 (HTTPS)

**Destination:** Object storage endpoints

---

## 🚀 Deployment

### Prerequisites

- Namespaces created (`redis-enterprise`, `redis-team1-dev`, etc.)
- Redis Enterprise Cluster not yet deployed (policies must exist first)

### Deploy via ArgoCD

```bash
# Apply ArgoCD Application
oc apply -f platform/argocd/apps/network-policies.yaml

# Verify deployment
oc get networkpolicies -n redis-enterprise
```

### Manual Deployment (Testing)

```bash
# Apply all policies
oc apply -f platform/security/network-policies/

# Verify
oc get networkpolicies -n redis-enterprise
```

---

## ✅ Validation

### Test DNS Resolution

```bash
# Should work (DNS allowed)
oc exec -n redis-enterprise <pod-name> -- nslookup kubernetes.default.svc.cluster.local
```

### Test Redis Internode Communication

```bash
# Should work (internode allowed)
oc exec -n redis-enterprise <pod-name> -- curl -k https://localhost:8443
```

### Test Unauthorized Access

```bash
# Should FAIL (default deny)
oc run test-pod --image=busybox -n default -- sleep 3600
oc exec -n default test-pod -- nc -zv <redis-pod-ip> 8443
# Expected: Connection refused or timeout
```

---

## 🔧 Troubleshooting

### Issue: DNS not working

**Symptom:** Pods cannot resolve DNS names

**Solution:** Verify `02-allow-dns.yaml` is applied and CoreDNS is in `kube-system`

### Issue: Redis cluster not forming

**Symptom:** REC pods cannot communicate

**Solution:** Verify `04-allow-redis-internode.yaml` allows all required ports

### Issue: Prometheus cannot scrape metrics

**Symptom:** No metrics in Grafana

**Solution:** Verify `06-allow-prometheus.yaml` allows port 8070 from `openshift-monitoring`

---

## 📚 References

- Kubernetes Network Policies: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Redis Enterprise Ports: https://redis.io/docs/latest/operate/rs/networking/port-configurations/
- OpenShift Network Policy: https://docs.openshift.com/container-platform/latest/networking/network_policy/about-network-policy.html

---

**Next:** Deploy Redis Enterprise Cluster (Step 12)

