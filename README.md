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
│   └── OPENSHIFT_GITOPS_SETUP.md       # OpenShift GitOps setup guide
├── orders-redis/                       # Kustomize base + overlays pattern
│   ├── base/                           # Base configuration (shared)
│   │   ├── namespace.yaml              # redis-enterprise namespace
│   │   ├── rec.yaml                    # Redis Enterprise Cluster
│   │   └── kustomization.yaml          # Base kustomization
│   └── overlays/                       # Environment-specific overlays
│       ├── dev/                        # Development environment
│       │   ├── namespace-patch.yaml    # orders-redis-dev namespace
│       │   ├── redb-dev.yaml           # Dev databases
│       │   └── kustomization.yaml
│       └── prod/                       # Production environment
│           ├── namespace-patch.yaml    # orders-redis-prod namespace
│           ├── rec-patch.yaml          # Prod cluster overrides
│           ├── redb-prod.yaml          # Prod databases
│           └── kustomization.yaml
├── argocd/                             # Argo CD Application definitions
│   ├── orders-redis-dev-app.yaml       # Dev environment app
│   └── orders-redis-prod-app.yaml      # Prod environment app
├── examples/                           # Configuration examples
│   ├── cache-database.yaml
│   ├── persistent-database.yaml
│   ├── sharded-database.yaml
│   └── tls-database.yaml
└── ci/                                 # CI validation
    ├── validate.sh                     # Validation script
    ├── yamllint-config.yaml
    └── .gitlab-ci.yml.example          # Example CI pipeline
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

- [Prerequisites](docs/PREREQUISITES.md) - Platform and tooling requirements
- [Repository Connection](docs/REPOSITORY_CONNECTION.md) - How to connect Git repo to Argo CD
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Operations Guide](docs/OPERATIONS.md) - Day-2 operations and workflows
- [Architecture](docs/ARCHITECTURE.md) - Detailed architecture overview
- [OpenShift GitOps Setup](docs/OPENSHIFT_GITOPS_SETUP.md) - Complete GitOps setup guide

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

This repository demonstrates the **Kustomize base + overlays pattern** for managing multiple environments:

### Architecture

- **Cluster**: Deployed in `redis-enterprise` namespace (shared across environments)
- **Databases**: Deployed in environment-specific namespaces
  - `orders-redis-dev`: Development databases
  - `orders-redis-prod`: Production databases

### Environment Configuration

- **Base** (`orders-redis/base/`): Redis Enterprise Cluster in `redis-enterprise` namespace
  - 3 nodes, 2Gi memory per node, 50Gi storage

- **Dev overlay** (`orders-redis/overlays/dev/`):
  - Namespace: `orders-redis-dev`
  - 2 databases: cache (1GB) + session (512MB)
  - No TLS, no persistence (fast iteration)

- **Prod overlay** (`orders-redis/overlays/prod/`):
  - Namespace: `orders-redis-prod`
  - Cluster override: 5 nodes, 4Gi memory, 100Gi storage
  - 2 databases: cache (4GB, sharded) + session (2GB)
  - TLS enabled, AOF persistence (production-ready)

### GitOps Benefits

- ✅ **DRY principle**: Cluster defined once, databases reference it
- ✅ **Namespace isolation**: Each environment has its own namespace
- ✅ **Shared cluster**: One cluster serves multiple environments
- ✅ **GitOps workflow**: All changes via Git commits
- ✅ **Progressive complexity**: Dev is simple, prod has all features

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

