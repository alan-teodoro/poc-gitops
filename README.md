# Redis Enterprise on OpenShift - GitOps Reference Architecture

**Production-grade GitOps-based deployment and management of Redis Enterprise on Red Hat OpenShift**

[![OpenShift](https://img.shields.io/badge/OpenShift-4.x-red)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![Redis Enterprise](https://img.shields.io/badge/Redis%20Enterprise-8.0.10-DC382D)](https://redis.io/enterprise/)
[![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-orange)](https://argo-cd.readthedocs.io/)
[![Gatekeeper](https://img.shields.io/badge/OPA%20Gatekeeper-Policy-blue)](https://open-policy-agent.github.io/gatekeeper/)

---

## 📋 Overview

This repository provides a **complete enterprise reference architecture** for deploying and managing Redis Enterprise at scale using GitOps principles on Red Hat OpenShift.

**Designed for**:
- ✅ Enterprise customers (including regulated industries like banking)
- ✅ Multi-team environments (10-100+ databases)
- ✅ Professional Services engagements
- ✅ Database-as-a-Service (DBaaS) foundations

---

## 🎯 Quick Start

### Prerequisites
- Red Hat OpenShift 4.x cluster
- Redis Enterprise Operator installed
- Red Hat OpenShift GitOps (Argo CD) installed
- `oc` CLI configured and logged in

### Get Started in 5 Minutes

```bash
# Clone repository
git clone https://github.com/alan-teodoro/poc-gitops.git
cd poc-gitops

# Follow step-by-step guide
cat docs/IMPLEMENTATION_ORDER.md
```

**📚 Complete implementation guide**: [`docs/IMPLEMENTATION_ORDER.md`](docs/IMPLEMENTATION_ORDER.md)

---

## ✨ Key Features

### 🔐 Multi-Tenant Governance
- **Argo CD AppProjects** for team isolation
- **Namespace-based** resource segregation
- **RBAC** for fine-grained access control

### 📊 Resource Management
- **ResourceQuotas** per namespace (CPU, memory, storage)
- **LimitRanges** for container limits
- **Different profiles** for dev/prod environments

### 🛡️ Policy Enforcement
- **OPA Gatekeeper** for admission control
- **Automated validation** of Redis configurations
- **Prevent data loss** (immutable shardCount)
- **Enforce standards** (mandatory labels, memory limits)

### 🚀 GitOps Automation
- **Declarative** infrastructure as code
- **Auto-sync** from Git to cluster
- **Self-healing** capabilities
- **Audit trail** via Git history

### 🔧 Multi-Namespace Support
- **Operator** in dedicated namespace
- **Cluster** in operator namespace
- **Databases** in separate namespaces (dev/prod isolation)

---

## 🏗️ Architecture

### Repository Structure

```
.
├── README.md                           # This file
├── docs/                               # Documentation
│   ├── IMPLEMENTATION_ORDER.md         # 🎯 START HERE - Step-by-step guide
│   ├── TROUBLESHOOTING.md              # Common issues and solutions
│   ├── HELM_ARCHITECTURE.md            # Helm charts explanation
│   ├── MULTI_NAMESPACE.md              # Multi-namespace architecture
│   └── architecture/
│       └── ADR-001-gitops-governance.md
│
├── platform/                           # Platform-level resources
│   ├── argocd/projects/                # AppProjects (multi-tenancy)
│   ├── quotas/                         # ResourceQuota & LimitRange
│   ├── policies/                       # OPA Gatekeeper policies
│   └── operators/                      # Operator configurations
│
├── helm-charts/                        # Helm charts
│   ├── redis-enterprise-cluster/       # REC chart
│   ├── redis-enterprise-database/      # REDB chart
│   └── redis-multi-namespace-rbac/     # Multi-namespace RBAC
│
└── clusters/                           # Cluster configurations
    └── orders/                         # Example: Orders cluster
        ├── cluster.yaml                # Cluster configuration
        ├── rbac.yaml                   # RBAC configuration
        ├── argocd-cluster.yaml         # Argo CD Application (cluster)
        ├── argocd-rbac.yaml            # Argo CD Application (RBAC)
        ├── namespaces/                 # Namespace definitions
        └── databases/                  # Database configurations
            ├── cache/                  # Cache database (dev/prod)
            └── session/                # Session database (dev/prod)
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Container Platform** | Red Hat OpenShift 4.x | Kubernetes distribution |
| **Database** | Redis Enterprise 8.0.10 | In-memory database |
| **GitOps** | Red Hat OpenShift GitOps (Argo CD) | Continuous delivery |
| **Templating** | Helm 3.x | Package management |
| **Policy Engine** | OPA Gatekeeper | Admission control |
| **Operator** | Redis Enterprise Operator | Lifecycle management |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[IMPLEMENTATION_ORDER.md](docs/IMPLEMENTATION_ORDER.md)** | 🎯 **START HERE** - Complete step-by-step implementation guide |
| **[OBSERVABILITY.md](docs/OBSERVABILITY.md)** | 📊 Monitoring with Prometheus and Grafana |
| **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | Common production issues and solutions |
| **[HELM_ARCHITECTURE.md](docs/HELM_ARCHITECTURE.md)** | Helm charts architecture and usage |
| **[MULTI_NAMESPACE.md](docs/MULTI_NAMESPACE.md)** | Multi-namespace support explanation |
| **[ADR-001](docs/architecture/ADR-001-gitops-governance.md)** | Architectural decision: GitOps governance |

---

## 🚀 What You'll Deploy

Following the implementation guide, you'll deploy:

### Phase 0: Governance
- ✅ Argo CD AppProjects (platform-team, team-orders)

### Phase 1: Namespaces
- ✅ Database namespaces (redis-orders-dev, redis-orders-prod)

### Phase 2: Resource Management
- ✅ ResourceQuotas (dev: 4 CPU/8Gi RAM, prod: 16 CPU/32Gi RAM)
- ✅ LimitRanges (container limits)

### Phase 3: Policy Enforcement
- ✅ Gatekeeper Operator & Instance
- ✅ Policy Templates (mandatory labels, memory limits, immutable fields)
- ✅ Constraints (enforcement rules)

### Phase 4: Redis Enterprise
- ✅ Multi-namespace RBAC
- ✅ Redis Enterprise Cluster (3 nodes)
- ✅ Redis Databases (cache, session - dev/prod)
- ✅ Routes for external access

---

## 🎯 Use Cases

### 1. Development Teams
- Self-service database provisioning
- Isolated dev/prod environments
- Automated compliance validation

### 2. Platform Teams
- Centralized governance
- Resource quota management
- Policy enforcement
- Audit trail via Git

### 3. DBaaS (Database-as-a-Service)
- Multi-tenant database platform
- Automated provisioning
- Standardized configurations
- Cost allocation (chargeback)

---

## 🔧 Adding New Resources

### Add a New Cluster
```bash
# Copy orders cluster as template
cp -r clusters/orders clusters/payments

# Edit configuration
vim clusters/payments/cluster.yaml
vim clusters/payments/argocd-cluster.yaml

# Apply
oc apply -f clusters/payments/argocd-cluster.yaml
```

### Add a New Database
```bash
# Copy existing database as template
cp clusters/orders/databases/cache/dev.yaml \
   clusters/orders/databases/analytics/dev.yaml

# Edit configuration
vim clusters/orders/databases/analytics/dev.yaml

# Create Argo CD Application
cp clusters/orders/databases/cache/argocd-dev.yaml \
   clusters/orders/databases/analytics/argocd-dev.yaml

# Apply
oc apply -f clusters/orders/databases/analytics/argocd-dev.yaml
```

---

## 🛡️ Security & Compliance

### Implemented Controls
- ✅ **Namespace isolation** (multi-tenancy)
- ✅ **RBAC** (role-based access control)
- ✅ **Resource quotas** (prevent resource exhaustion)
- ✅ **Policy enforcement** (automated validation)
- ✅ **Audit trail** (Git history)
- ✅ **Immutability** (prevent data loss)

### Compliance Features
- ✅ **Segregation of duties** (AppProjects)
- ✅ **Change tracking** (Git commits)
- ✅ **Approval workflow** (Git pull requests)
- ✅ **Automated validation** (Gatekeeper policies)

---

## 📊 Monitoring & Observability

### Production-Grade Implementation ⭐
- ✅ **40+ Production-Tested Alerts** - Based on official Redis Enterprise best practices
- ✅ **Official Grafana Dashboards** - Cluster, Database, Node, Shard monitoring
- ✅ **v2 Prometheus Metrics** - Latest metrics from Redis Enterprise 8.0.10
- ✅ **Predictive Alerts** - "Database will be full in 2 hours"
- ✅ **Certificate & License Monitoring** - Prevent unexpected expirations
- ✅ **Cluster Quorum Monitoring** - Detect split-brain scenarios
- ✅ **ServiceMonitor** - Automatic Prometheus scraping
- ✅ **Runbook Links** - Every alert links to official Redis documentation

### Alert Categories (40+ Alerts)
- **Latency** (2) - Warning > 2ms, Critical > 5ms
- **Connections** (2) - No connections, excessive connections
- **Throughput** (2) - No requests, excessive requests
- **Capacity** (2) - Database full, predictive capacity
- **Utilization** (2) - Low hit ratio, unexpected evictions
- **Synchronization** (4) - Replica/CRDT sync and lag
- **Nodes** (5) - Health, storage, memory, CPU
- **Shards** (5) - Health, CPU, hot shards, proxy
- **Certificates & License** (6) - Expiration warnings, shard limits
- **Cluster Health** (3) - Quorum, primary status, cluster down

### Official Dashboards Available
- **Cluster Dashboard** - Overall health and status
- **Database Dashboard** - Performance and metrics
- **Node Dashboard** - Resource monitoring
- **Shard Dashboard** - Shard-level details
- **Active-Active** - CRDB replication (optional)
- **Synchronization** - Replication monitoring (optional)

**📖 Documentation**:
- [OBSERVABILITY.md](docs/OBSERVABILITY.md) - Complete observability guide
- [OBSERVABILITY_PRODUCTION_UPGRADE.md](docs/OBSERVABILITY_PRODUCTION_UPGRADE.md) - Production upgrade details
- [GRAFANA_DASHBOARDS.md](docs/GRAFANA_DASHBOARDS.md) - Official dashboard guide
- [AUTOMATED_DASHBOARDS.md](docs/AUTOMATED_DASHBOARDS.md) - Automated dashboard deployment

---

## 🤝 Contributing

This is a reference architecture. To adapt for your environment:

1. Fork the repository
2. Modify configurations for your needs
3. Test in non-production environment
4. Document changes
5. Deploy to production

---

## 📝 License

This project is provided as-is for educational and reference purposes.

---

## 🆘 Support

- **Documentation**: See [`docs/`](docs/) directory
- **Issues**: Check [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)
- **Questions**: Open a GitHub issue

---

## 🙏 Acknowledgments

- Red Hat OpenShift team
- Redis Enterprise team
- Argo CD community
- Open Policy Agent community

---

**Built with ❤️ for Enterprise Redis deployments on OpenShift**

