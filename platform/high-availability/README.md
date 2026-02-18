# High Availability - Redis Enterprise on OpenShift

## 🎯 Overview

This directory contains **High Availability (HA)** configurations for Redis Enterprise to ensure maximum uptime and resilience.

**Goal**: Prevent downtime during node maintenance, failures, and cluster operations.

---

## 📊 Components

### 1. PodDisruptionBudgets (PDBs)
Prevent too many pods from being evicted simultaneously during:
- Node maintenance (drain/cordon)
- Cluster upgrades
- Autoscaling events

### 2. Anti-Affinity Rules
Spread Redis pods across:
- Different physical nodes (avoid single point of failure)
- Different availability zones (zone-level fault tolerance)

---

## 🗂️ Directory Structure

```
platform/high-availability/
├── README.md                           # This file
├── pdb/
│   ├── rec-pdb.yaml                   # Redis Enterprise Cluster PDB
│   └── redb-pdb-template.yaml         # Redis Database PDB template
└── anti-affinity/
    ├── rec-anti-affinity-patch.yaml   # Cluster anti-affinity
    └── README.md                      # Anti-affinity guide
```

---

## 🔧 PodDisruptionBudgets (PDBs)

### Redis Enterprise Cluster PDB

**Purpose**: Ensure cluster quorum is maintained (minimum 2 nodes running)

**File**: `pdb/rec-pdb.yaml`

**Configuration**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: redis-cluster-pdb
  namespace: redis-orders
spec:
  minAvailable: 2  # Always keep 2 nodes running (quorum)
  selector:
    matchLabels:
      app: redis-enterprise
      redis.io/cluster: orders-redis-cluster
```

**Why `minAvailable: 2`?**
- Redis Enterprise Cluster requires quorum (majority of nodes)
- 3-node cluster: quorum = 2 nodes
- 5-node cluster: quorum = 3 nodes
- Formula: `minAvailable = ceil(nodes / 2)`

**What it prevents**:
- ❌ Draining 2+ nodes simultaneously (would break quorum)
- ❌ Cluster becoming unavailable during maintenance
- ❌ Split-brain scenarios

---

### Redis Database PDB

**Purpose**: Ensure database availability during pod evictions

**File**: `pdb/redb-pdb-template.yaml`

**Configuration**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: redis-database-pdb
  namespace: redis-orders-prod
spec:
  maxUnavailable: 1  # Only 1 shard can be down at a time
  selector:
    matchLabels:
      app: redis-enterprise-database
      redis.io/database: orders-cache-prod
```

**Why `maxUnavailable: 1`?**
- Allows rolling updates (1 shard at a time)
- Ensures at least 1 replica is always available
- Prevents complete database outage

**What it prevents**:
- ❌ All database shards being evicted simultaneously
- ❌ Database downtime during node maintenance
- ❌ Data unavailability during rolling updates

---

## 🌐 Anti-Affinity Rules

### Node-Level Anti-Affinity

**Purpose**: Spread Redis pods across different physical nodes

**Configuration**:
```yaml
spec:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: redis-enterprise
          topologyKey: kubernetes.io/hostname
```

**Behavior**:
- **Preferred** (not required) - allows scheduling even if constraint can't be met
- **Weight 100** - high priority
- **topologyKey: kubernetes.io/hostname** - spread across nodes

**Benefits**:
- ✅ Node failure affects only 1 Redis pod
- ✅ Better resource distribution
- ✅ Improved fault tolerance

---

### Zone-Level Anti-Affinity

**Purpose**: Spread Redis pods across different availability zones

**Configuration**:
```yaml
spec:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: redis-enterprise
          topologyKey: topology.kubernetes.io/zone
```

**Behavior**:
- **Preferred** (not required) - allows scheduling even if only 1 zone available
- **Weight 50** - medium priority (lower than node-level)
- **topologyKey: topology.kubernetes.io/zone** - spread across zones

**Benefits**:
- ✅ Zone failure affects only 1 Redis pod
- ✅ Geographic distribution
- ✅ Maximum fault tolerance

**Requirements**:
- OpenShift cluster must have multiple availability zones
- Nodes must be labeled with `topology.kubernetes.io/zone`

---

## 🚀 How to Apply

### Step 1: Apply PDBs

```bash
# Apply Redis Enterprise Cluster PDB
oc apply -f platform/high-availability/pdb/rec-pdb.yaml

# Apply Redis Database PDB (for each database)
oc apply -f platform/high-availability/pdb/redb-pdb-template.yaml
```

### Step 2: Configure Anti-Affinity

Anti-affinity is configured in the Helm chart values:

```yaml
# clusters/orders/cluster.yaml
redis:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: redis-enterprise
          topologyKey: kubernetes.io/hostname
      - weight: 50
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: redis-enterprise
          topologyKey: topology.kubernetes.io/zone
```

Then sync the ArgoCD Application:
```bash
argocd app sync redis-cluster-orders
```

---

## ✅ Verification

### Check PDB Status

```bash
# List all PDBs
oc get pdb -A

# Check specific PDB
oc describe pdb redis-cluster-pdb -n redis-orders

# Expected output:
# Min Available: 2
# Current: 3
# Allowed Disruptions: 1
```

### Test PDB (Node Drain)

```bash
# Try to drain a node
oc adm drain <node-name> --ignore-daemonsets --delete-emptydir-data

# PDB should prevent draining if it would violate minAvailable
# Expected: "Cannot evict pod as it would violate the pod's disruption budget"

# Uncordon node
oc adm uncordon <node-name>
```

### Check Anti-Affinity

```bash
# Check pod distribution across nodes
oc get pods -n redis-orders -o wide

# Expected: Each Redis pod on a different node
# NAME                                    NODE
# orders-redis-cluster-0                  worker-1
# orders-redis-cluster-1                  worker-2
# orders-redis-cluster-2                  worker-3
```

---

## 📊 Impact on Availability

### Before HA Configuration
- **Node failure**: Cluster may lose quorum → downtime
- **Node maintenance**: Manual coordination required
- **Zone failure**: Multiple pods affected

### After HA Configuration
- **Node failure**: Only 1 pod affected, cluster maintains quorum ✅
- **Node maintenance**: Automatic protection via PDB ✅
- **Zone failure**: Only 1 pod affected (if multi-zone) ✅

**Availability Improvement**:
- **Before**: 99.9% (single node failure = downtime)
- **After**: 99.99%+ (resilient to node and zone failures)

---

## 🎯 Best Practices

1. **Always use PDBs in production** - Prevents accidental outages
2. **Use `preferredDuringScheduling`** - Allows flexibility when constraints can't be met
3. **Set appropriate weights** - Node-level (100) > Zone-level (50)
4. **Test PDBs regularly** - Simulate node drains to verify protection
5. **Monitor PDB violations** - Alert when PDB blocks operations

---

## 📚 References

- [Kubernetes PodDisruptionBudget](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
- [Pod Affinity and Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Redis Enterprise High Availability](https://redis.io/docs/latest/operate/rs/clusters/configure/cluster-settings/)

---

**Last Updated**: 2024-02-18  
**Managed by**: Platform Team

