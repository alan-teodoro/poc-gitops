# Prerequisites and Assumptions

## Platform Prerequisites

### OpenShift Cluster Requirements

You need an OpenShift 4.x cluster with the following:

1. **Networking**:
   - Working DNS resolution
   - Default Container Network Interface (CNI) configured
   - Network connectivity for pulling container images

2. **Storage**:
   - A storage class suitable for Redis Enterprise persistent volumes
   - Common options:
     - `ocs-storagecluster-ceph-rbd` (OpenShift Data Foundation)
     - `gp3-csi` (AWS EBS)
     - `managed-premium` (Azure Disk)
     - `pd-ssd` (GCP Persistent Disk)
   
   To list available storage classes:
   ```bash
   oc get storageclass
   ```

3. **Cluster Permissions**:
   - Cluster admin access (for initial operator installation)
   - Namespace admin access (for deploying Redis resources)

### Redis Enterprise Operator

The Redis Enterprise Operator must be installed before deploying this demo.

**Installation via OperatorHub**:

1. Log in to the OpenShift web console
2. Navigate to **Operators** → **OperatorHub**
3. Search for "Redis Enterprise"
4. Click **Install**
5. Choose installation mode:
   - **All namespaces** (recommended for multi-tenant scenarios)
   - **Specific namespace** (for isolated deployments)
6. Click **Install** and wait for the operator to be ready

**Verify installation**:
```bash
oc get csv -n openshift-operators | grep redis
oc get crd | grep redis
```

You should see:
- `RedisEnterpriseCluster` CRD
- `RedisEnterpriseDatabase` CRD
- `RedisEnterpriseActiveActiveDatabase` CRD (for Active-Active)

**Required Configuration**:

The operator requires:
- Service accounts with appropriate permissions
- Security Context Constraints (SCCs) - typically configured automatically
- Redis Enterprise license (for production; trial licenses available)

### OpenShift GitOps (Argo CD)

OpenShift GitOps must be installed and configured.

**Installation**:

1. Log in to the OpenShift web console
2. Navigate to **Operators** → **OperatorHub**
3. Search for "Red Hat OpenShift GitOps"
4. Click **Install**
5. Accept defaults and click **Install**

**Verify installation**:
```bash
oc get pods -n openshift-gitops
oc get route -n openshift-gitops
```

**Configure Argo CD permissions**:

Argo CD needs permissions to deploy into target namespaces. For this demo:

```bash
# Grant Argo CD permissions to manage the orders-redis-dev namespace
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n orders-redis-dev
```

For production, use more granular RBAC policies.

**Access Argo CD UI**:
```bash
# Get the route
oc get route openshift-gitops-server -n openshift-gitops

# Get admin password
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
```

## Tooling Prerequisites

### Required CLI Tools

1. **oc CLI**:
   - Download from OpenShift web console: **?** → **Command Line Tools**
   - Or from [Red Hat](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
   
   Verify:
   ```bash
   oc version
   oc whoami
   ```

2. **git**:
   - Install from [git-scm.com](https://git-scm.com/)
   
   Verify:
   ```bash
   git --version
   ```

3. **kustomize** (optional, for local validation):
   - Install from [kustomize.io](https://kubectl.docs.kubernetes.io/installation/kustomize/)
   
   Verify:
   ```bash
   kustomize version
   ```

### Git Repository

You need a Git repository to store the configuration. Options include:

- GitHub
- GitLab
- Bitbucket
- Gitea
- Internal Git server

**Requirements**:
- Argo CD must have read access to the repository
- For private repositories, configure SSH keys or access tokens in Argo CD

## Network and Security Considerations

### For Development/Demo Environments

This demo uses simplified settings suitable for development:

- TLS disabled on Redis databases
- No authentication required
- No network policies
- Simplified resource limits

### For Production Environments

Production deployments should include:

1. **TLS/SSL**:
   - Enable `tlsMode: enabled` on databases
   - Configure certificates (self-signed or CA-signed)

2. **Authentication**:
   - Enable password authentication
   - Use secrets management (e.g., HashiCorp Vault)

3. **Network Policies**:
   - Restrict traffic between namespaces
   - Limit ingress/egress

4. **Resource Quotas**:
   - Set namespace quotas
   - Define resource limits and requests

5. **Monitoring**:
   - Prometheus metrics
   - Grafana dashboards
   - Alerting rules

## Validation Checklist

Before proceeding with the demo, verify:

- [ ] OpenShift cluster is accessible via `oc` CLI
- [ ] Redis Enterprise Operator is installed and running
- [ ] OpenShift GitOps is installed and Argo CD is accessible
- [ ] You have identified the storage class to use
- [ ] You have a Git repository ready for configuration
- [ ] Argo CD has permissions to deploy into target namespaces

## Next Steps

Once all prerequisites are met, proceed to [DEPLOYMENT.md](DEPLOYMENT.md) for deployment instructions.

