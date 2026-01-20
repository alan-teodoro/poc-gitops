# Redis Enterprise GitOps Demo on OpenShift

This repository demonstrates how to manage Redis Enterprise on Red Hat OpenShift Container Platform (OCP) using GitOps principles with Argo CD.

## 📋 Overview

This demo shows how to:

- Define Redis Enterprise clusters and databases as Kubernetes custom resources
- Use Git as the source of truth for Redis configuration
- Use Argo CD to reconcile Git-based configuration into OpenShift
- Apply a repeatable workflow that can be extended to production environments

## 🏗️ Repository Structure

```
.
├── README.md                           # This file
├── docs/                               # Documentation
│   ├── PREREQUISITES.md                # Prerequisites and assumptions
│   ├── DEPLOYMENT.md                   # Deployment guide
│   ├── OPERATIONS.md                   # Operational workflows
│   ├── ARCHITECTURE.md                 # Architecture overview
│   ├── OPENSHIFT_GITOPS_SETUP.md       # OpenShift GitOps setup guide
│   ├── HELM_ARCHITECTURE.md            # Helm-based architecture (NEW)
│   └── ONBOARDING_GUIDE.md             # Guide for adding clusters/databases (NEW)
│
├── helm-charts/                        # Helm charts (NEW - Scalable approach)
│   ├── redis-enterprise-cluster/       # Chart for Redis Enterprise Cluster
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── namespace.yaml
│   │       ├── rec.yaml
│   │       └── route-ui.yaml
│   └── redis-enterprise-database/      # Chart for Redis Enterprise Database
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-cache.yaml           # Preset for cache databases
│       ├── values-session.yaml         # Preset for session databases
│       ├── values-persistent.yaml      # Preset for persistent databases
│       └── templates/
│           ├── redb.yaml
│           └── route.yaml
│
├── environments/                       # Environment configurations (NEW)
│   ├── clusters/                       # Cluster-specific configs
│   │   └── orders/
│   │       └── values.yaml
│   └── databases/                      # Database-specific configs
│       └── orders/
│           ├── dev/
│           │   ├── cache.yaml
│           │   └── session.yaml
│           └── prod/
│               ├── cache.yaml
│               └── session.yaml
│
├── argocd/                             # Argo CD Application definitions
│   ├── infrastructure/                 # Cluster Applications (NEW)
│   │   └── redis-cluster-orders.yaml
│   ├── databases/                      # Database Applications (NEW)
│   │   ├── orders-cache-dev.yaml
│   │   └── session-store-dev.yaml
│   ├── orders-redis-dev-app.yaml       # Legacy - Dev environment app
│   └── orders-redis-prod-app.yaml      # Legacy - Prod environment app
│
├── orders-redis/                       # Legacy Kustomize approach (kept for reference)
│   ├── base/
│   └── overlays/
│
├── examples/                           # Configuration examples
│   ├── cache-database.yaml
│   ├── persistent-database.yaml
│   ├── sharded-database.yaml
│   └── tls-database.yaml
└── ci/                                 # CI validation
    ├── validate.sh
    ├── yamllint-config.yaml
    └── .gitlab-ci.yml.example
```

## 🚀 Quick Start

### Prerequisites

Before using this demo, ensure you have:

1. **OpenShift 4.x cluster** with:
   - Working DNS and default CNI
   - Storage class for persistent volumes
   
2. **Redis Enterprise Operator** installed via OperatorHub

3. **OpenShift GitOps (Argo CD)** installed and running

4. **CLI tools**:
   - `oc` CLI configured for your cluster
   - `git` client
   - `kustomize` (optional, for local validation)

See [docs/PREREQUISITES.md](docs/PREREQUISITES.md) for detailed requirements.

### Deploy the Demo

1. **Fork or clone this repository**

2. **Update the Argo CD Application manifest** with your Git repository URL:
   ```bash
   # Edit argocd/orders-redis-dev-app.yaml
   # Update spec.source.repoURL to your repository
   ```

3. **Update storage class** in the base REC manifest:
   ```bash
   # Edit orders-redis/base/rec.yaml
   # Update spec.storageClassName to match your cluster
   ```

4. **Grant Argo CD permissions**:
   ```bash
   # Cluster namespace
   oc adm policy add-role-to-user admin \
     system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
     -n redis-enterprise

   # Application namespaces
   oc adm policy add-role-to-user admin \
     system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
     -n orders-redis-dev

   oc adm policy add-role-to-user admin \
     system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
     -n orders-redis-prod
   ```

5. **Apply the Argo CD Application**:
   ```bash
   oc apply -f argocd/orders-redis-dev-app.yaml
   ```

6. **Verify deployment**:
   ```bash
   # Check cluster
   oc get redisenterprisecluster -n redis-enterprise

   # Check databases
   oc get redisenterprisedatabase -n orders-redis-dev

   # Check pods
   oc get pods -n redis-enterprise
   oc get pods -n orders-redis-dev
   ```

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

## 📚 Documentation

### Getting Started
- [Prerequisites](docs/PREREQUISITES.md) - Platform and tooling requirements
- [Repository Connection](docs/REPOSITORY_CONNECTION.md) - How to connect Git repo to Argo CD
- [OpenShift GitOps Setup](docs/OPENSHIFT_GITOPS_SETUP.md) - Complete GitOps setup guide

### Architecture & Design
- [Helm Architecture](docs/HELM_ARCHITECTURE.md) - **NEW** Helm-based scalable architecture
- [Architecture Overview](docs/ARCHITECTURE.md) - Original Kustomize-based architecture
- [Onboarding Guide](docs/ONBOARDING_GUIDE.md) - **NEW** How to add clusters and databases

### Operations
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Operations Guide](docs/OPERATIONS.md) - Day-2 operations and workflows

## 🔄 GitOps Workflow Examples

### Adding a New Database

1. Create a new REDB manifest (e.g., `redb-session-store-dev.yaml`)
2. Add it to `kustomization.yaml`
3. Commit and push to Git
4. Argo CD automatically reconciles the change

### Modifying Database Configuration

1. Edit the REDB manifest (e.g., change `memorySize`)
2. Commit and push to Git
3. Argo CD detects and applies the change

See [docs/OPERATIONS.md](docs/OPERATIONS.md) for detailed workflows.

## 🎯 What This Demonstrates

This repository demonstrates **two approaches** for managing Redis Enterprise at scale:

### 🆕 Helm-based Architecture (Recommended for Scale)

**Design for enterprise scale**: Dozens of clusters, hundreds of databases, multiple datacenters

**Key Features**:
- ✅ **One operator per cluster**: Each cluster has dedicated operator in its own namespace
- ✅ **Separate Applications**: 1 Application for cluster, 1 per database (blast radius control)
- ✅ **Helm + Values**: Templating with environment-specific configurations
- ✅ **Presets**: Common patterns (cache, session, persistent)
- ✅ **Self-service ready**: Easy to add new clusters/databases via Git

**Structure**:
- **Namespace**: `redis-{cluster-name}-enterprise` (e.g., `redis-orders-enterprise`)
- **Operator**: Installed via OperatorHub per cluster
- **Cluster**: Deployed via Helm chart with values file
- **Databases**: Each deployed as separate Application with preset + custom values

**Example**:
```bash
# Deploy cluster
oc apply -f argocd/infrastructure/redis-cluster-orders.yaml

# Deploy databases independently
oc apply -f argocd/databases/orders-cache-dev.yaml
oc apply -f argocd/databases/session-store-dev.yaml
```

See [docs/HELM_ARCHITECTURE.md](docs/HELM_ARCHITECTURE.md) for details.

### 📦 Kustomize-based Architecture (Legacy)

**Original approach**: Single Application managing cluster + databases

**Structure**:
- **Base** (`orders-redis/base/`): Shared cluster configuration
- **Overlays** (`orders-redis/overlays/`): Environment-specific databases
- **Single Application**: Manages all resources together

**Limitations**:
- Changes to one database trigger sync of all resources
- Not suitable for hundreds of databases
- Harder to delegate to multiple teams

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

---

### GitOps Benefits (Both Approaches)

- ✅ **Git as source of truth**: All configuration in version control
- ✅ **Automated reconciliation**: Argo CD keeps cluster in sync with Git
- ✅ **Audit trail**: All changes tracked via Git commits
- ✅ **Rollback capability**: Git revert to undo changes
- ✅ **Multi-environment**: Dev, prod, and beyond

## 🔗 References

### Internal Documentation
- [OpenShift GitOps Setup Guide](docs/OPENSHIFT_GITOPS_SETUP.md) - Complete guide to installing and configuring OpenShift GitOps
- [Architecture Overview](docs/ARCHITECTURE.md) - Detailed architecture diagrams and explanations
- [Prerequisites](docs/PREREQUISITES.md) - Platform and tooling requirements
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Operations Guide](docs/OPERATIONS.md) - Day-2 operations and workflows

### External Resources
- [Redis Enterprise for Kubernetes - Architecture](https://redis.io/docs/latest/operate/kubernetes/architecture/)
- [Deploy Redis Enterprise with OpenShift](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)
- [OpenShift GitOps Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)

## 📝 License

This is a demonstration project for educational purposes.

