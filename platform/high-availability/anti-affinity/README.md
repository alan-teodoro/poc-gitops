# Anti-Affinity Configuration for Redis Enterprise

## 🎯 Overview

Anti-affinity rules ensure Redis pods are **spread across different nodes and availability zones** to maximize fault tolerance.

---

## 🌐 Two Levels of Anti-Affinity

### 1. Node-Level Anti-Affinity (Priority: HIGH)
**Goal**: Spread Redis pods across different physical nodes

**Benefit**: Node failure affects only 1 Redis pod

### 2. Zone-Level Anti-Affinity (Priority: MEDIUM)
**Goal**: Spread Redis pods across different availability zones

**Benefit**: Zone failure affects only 1 Redis pod

---

## 🔧 Configuration Methods

### Method 1: Helm Chart Values (Recommended)

Add to `clusters/orders/cluster.yaml`:

```yaml
redis:
  # ... existing config ...
  
  # Anti-affinity rules
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      # Node-level: Spread across different nodes
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: redis-enterprise
          topologyKey: kubernetes.io/hostname
      
      # Zone-level: Spread across different zones
      - weight: 50
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: redis-enterprise
          topologyKey: topology.kubernetes.io/zone
```

Then sync ArgoCD:
```bash
argocd app sync redis-cluster-orders
```

---

### Method 2: Patch Existing Cluster

Use `rec-anti-affinity-patch.yaml` to patch an existing cluster:

```bash
oc patch rec orders-redis-cluster -n redis-orders \
  --type merge \
  --patch-file platform/high-availability/anti-affinity/rec-anti-affinity-patch.yaml
```

---

## 📊 Preferred vs Required

### Preferred (Recommended)
```yaml
preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm: ...
```

**Behavior**:
- ✅ Tries to spread pods across nodes/zones
- ✅ Allows scheduling even if constraint can't be met
- ✅ Flexible (works with 1 zone or limited nodes)

**Use when**: You want best-effort spreading without blocking deployments

---

### Required (Strict)
```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector: ...
    topologyKey: kubernetes.io/hostname
```

**Behavior**:
- ✅ Guarantees pods are on different nodes/zones
- ❌ Blocks scheduling if constraint can't be met
- ❌ Requires enough nodes/zones

**Use when**: You have guaranteed infrastructure (3+ nodes, 3+ zones)

---

## ✅ Verification

### Check Pod Distribution

```bash
# Check which nodes pods are running on
oc get pods -n redis-orders -o wide

# Expected output (3 different nodes):
# NAME                        NODE
# orders-redis-cluster-0      worker-1
# orders-redis-cluster-1      worker-2
# orders-redis-cluster-2      worker-3
```

### Check Zone Distribution

```bash
# Check which zones pods are running in
oc get pods -n redis-orders -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
ZONE:.spec.nodeSelector.'topology\.kubernetes\.io/zone'

# Expected output (3 different zones):
# NAME                        NODE       ZONE
# orders-redis-cluster-0      worker-1   us-east-1a
# orders-redis-cluster-1      worker-2   us-east-1b
# orders-redis-cluster-2      worker-3   us-east-1c
```

### Check Anti-Affinity Configuration

```bash
# Check REC spec
oc get rec orders-redis-cluster -n redis-orders -o yaml | grep -A 20 affinity
```

---

## 🎯 Best Practices

1. **Always use `preferred`** - More flexible than `required`
2. **Set appropriate weights** - Node-level (100) > Zone-level (50)
3. **Verify node/zone labels** - Ensure nodes are properly labeled
4. **Test failover** - Simulate node/zone failures
5. **Monitor distribution** - Alert if pods are co-located

---

## 📚 Topology Keys

| Topology Key | Spreads Across | Requires |
|--------------|----------------|----------|
| `kubernetes.io/hostname` | Physical nodes | Multiple nodes |
| `topology.kubernetes.io/zone` | Availability zones | Multi-zone cluster |
| `topology.kubernetes.io/region` | Regions | Multi-region cluster |

---

## 🚨 Troubleshooting

### Pods Not Spreading

**Symptom**: Multiple Redis pods on same node

**Possible causes**:
1. Not enough nodes (need 3+ nodes for 3-pod cluster)
2. Node selectors/taints preventing scheduling
3. Resource constraints (not enough CPU/memory on other nodes)

**Solution**:
```bash
# Check node count
oc get nodes

# Check node resources
oc describe nodes | grep -A 5 "Allocated resources"

# Check pod events
oc describe pod orders-redis-cluster-0 -n redis-orders
```

---

### Zone Labels Missing

**Symptom**: Zone-level anti-affinity not working

**Possible cause**: Nodes not labeled with zone information

**Solution**:
```bash
# Check if nodes have zone labels
oc get nodes --show-labels | grep topology.kubernetes.io/zone

# If missing, add labels manually (if not using cloud provider)
oc label node worker-1 topology.kubernetes.io/zone=zone-a
oc label node worker-2 topology.kubernetes.io/zone=zone-b
oc label node worker-3 topology.kubernetes.io/zone=zone-c
```

---

**Last Updated**: 2024-02-18  
**Managed by**: Platform Team

