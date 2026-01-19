# Getting Started with OpenShift GitOps

**Last Updated**: May 28, 2025  
**Author**: Gerald Nunn  
**Source**: Red Hat OpenShift GitOps Documentation

## Table of Contents

- [Introduction](#introduction)
- [Installing the OpenShift GitOps Operator](#installing-the-openshift-gitops-operator)
- [Configuring the Default Argo CD Instance](#configuring-the-default-argo-cd-instance)
- [Provisioning a Sample Application](#provisioning-a-sample-application)
- [Next Steps](#next-steps)

---

## Introduction

OpenShift GitOps enables users to deploy and manage applications and cluster configuration in a reliable and consistent fashion using the GitOps methodology. It leverages standard Git workflow practices to enable teams to:

- Monitor configuration drift with optional automatic remediation
- Increase visibility and audit for changes
- Deploy applications consistently across environments

OpenShift GitOps uses an **Operator-based approach** to install and manage Argo CD instances in an OpenShift environment. The operator provides full lifecycle management with easy installation and upgrade paths as new versions of Argo CD are released.

### What This Guide Covers

1. Installing the OpenShift GitOps Operator
2. Configuring the Default Argo CD Instance
3. Provisioning a Sample Application in Argo CD

### Prerequisites

⚠️ **Important**: This guide assumes you are a **cluster-admin** and have sufficient privileges to:
- Install operators
- Create groups
- Create ClusterRoleBindings

If you do not have these privileges, contact your operations or platform team for assistance.

> **Note**: The first two steps require elevated privileges. If OpenShift GitOps has already been provisioned by your platform team, you can skip to [Provisioning a Sample Application](#provisioning-a-sample-application).

---

## Installing the OpenShift GitOps Operator

### Installation Steps

1. **Access OperatorHub**
   - In the OpenShift Console, switch to the **Administrator Perspective**
   - Open the **Operators** menu
   - Select **OperatorHub**
   
   > If you do not see the OperatorHub menu item, you do not have sufficient privileges to install the operator.

2. **Locate the Operator**
   - In OperatorHub, type `Red Hat OpenShift GitOps` in the search field
   - Select the **Red Hat OpenShift GitOps** operator tile
   
   ⚠️ **Important**: Do NOT install the community Argo CD Operator as it is not supported by Red Hat.

3. **Install the Operator**
   - Click the **Install** button
   - Use the default **Latest** channel (installs the latest version)
   - On the next screen, accept the defaults
   - Click **Install** again

4. **Wait for Installation**
   - Wait until you see: "OpenShift GitOps Operator Installed Successfully"

**Congratulations!** You have successfully installed the Red Hat OpenShift GitOps Operator.

### Exploring the Installation

After installation:

1. Click **View Operator** or navigate to **Operators** → **Installed Operators**
2. Select the **OpenShift GitOps** operator
3. Click the **Argo CD** tab to see available Argo CD instances

#### Default Argo CD Instance

The operator automatically creates an Argo CD instance in the `openshift-gitops` namespace. This instance:

- Is intended for **cluster configuration** use cases
- Has elevated privileges assigned by default
- Can be supplemented with additional instances in other namespaces for application deployments

#### Viewing the Argo CD Custom Resource

1. Click on the default instance (`openshift-gitops`)
2. Click the **YAML** tab to view the configuration
3. Note the different sections: `server`, `controller`, `rbac`, etc.

#### Accessing the Argo CD UI

1. Click the **Application Menu** (9 dots) in the top right corner of the OpenShift Console
2. Select **Cluster Argo CD**
3. Click **Log in via OpenShift**
4. Enter your OpenShift credentials

At this point, the UI will be empty as no Applications have been defined yet.

---

## Configuring the Default Argo CD Instance

The default Argo CD instance requires configuration before it can be used effectively. Two main areas need adjustment:

1. **Argo CD RBAC** - Permissions within Argo CD
2. **Kubernetes Permissions** - Permissions for Argo CD to manage cluster resources

### Configuring Argo CD RBAC

#### View Current RBAC Configuration

```bash
oc get argocd openshift-gitops -n openshift-gitops -o=jsonpath='{.spec.rbac}'
```

This returns:

```json
{
  "defaultPolicy": "",
  "policy": "g, system:cluster-admins, role:admin\ng, cluster-admins, role:admin\n",
  "scopes": "[groups]"
}
```

As YAML:

```yaml
rbac:
  defaultPolicy: ""
  policy: |
    g, system:cluster-admins, role:admin
    g, cluster-admins, role:admin
  scopes: '[groups]'
```

#### Understanding the Configuration

- **defaultPolicy**: Empty string = no role assigned automatically
- **policy**: Assigns `admin` role to two groups:
  - `system:cluster-admins` (temporary kube-admin credential)
  - `cluster-admins` (recommended group for users)

#### Grant Access to Your User

**Option 1: Create/Update the cluster-admins Group** (Recommended)

1. Check if the group exists:
   ```bash
   oc get groups
   ```

2. If the group does NOT exist, create it:
   ```bash
   oc adm groups new cluster-admins <your-username>
   ```

3. If the group exists but your user is not in it:
   ```bash
   oc adm groups add-users cluster-admins <your-username>
   ```

4. Verify the group membership:
   ```bash
   oc get groups cluster-admins
   ```
   
   Expected output:
   ```
   NAME             USERS
   cluster-admins   <your-username>
   ```

⚠️ **Important**: After creating or modifying the group, **log out of Argo CD and log back in** for the changes to take effect.

#### Validate Group Assignment in Argo CD

After logging back in:
1. Go to **User Info** in Argo CD
2. Verify that `cluster-admins` appears in your groups

**Option 2: Change defaultPolicy** (NOT Recommended)

Setting `defaultPolicy: "role:admin"` would give admin permissions to all users - this is a security risk.

### Configuring Argo CD Kubernetes Permissions

The default instance needs expanded permissions to deploy all required resources.

#### Grant Cluster-Admin Permissions

For cluster configuration use cases, grant cluster-admin permissions to the Argo CD service account:

```bash
oc adm policy add-cluster-role-to-user \
  --rolebinding-name="openshift-gitops-cluster-admin" \
  cluster-admin \
  -z openshift-gitops-argocd-application-controller \
  -n openshift-gitops
```

Expected output:
```
clusterrole.rbac.authorization.k8s.io/cluster-admin added: "openshift-gitops-argocd-application-controller"
```

#### Verify the ClusterRoleBinding

```bash
oc get clusterrolebinding openshift-gitops-cluster-admin -o yaml
```

Output:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openshift-gitops-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: openshift-gitops-argocd-application-controller
  namespace: openshift-gitops
```

> **Note**: For application teams, Red Hat recommends creating separate Argo CD instances in different namespaces with restricted permissions rather than using the default instance.

---

## Provisioning a Sample Application

Now that Argo CD is installed and configured, let's deploy a sample application.

### Deploy the BGD Application

1. **Access Argo CD UI**
   - Log in using your OpenShift credentials

2. **Create New Application**
   - Click **Create Application** (or **+ New App** if applications already exist)
   - Click **Edit as YAML** in the top right

3. **Paste Application Manifest**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bgd
spec:
  destination:
    namespace: bgd
    server: https://kubernetes.default.svc
  source:
    path: bgd/base
    repoURL: https://github.com/gitops-examples/getting-started
    targetRevision: HEAD
  project: default
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Understanding the Application Manifest

| Field | Description |
|-------|-------------|
| **destination** | Where to deploy the application |
| `namespace` | Target namespace (`bgd`) |
| `server` | Kubernetes API server (local cluster) |
| **source** | Location of application manifests |
| `repoURL` | Git repository URL |
| `path` | Path to manifests in the repository |
| `targetRevision` | Git revision (HEAD = latest) |
| **project** | Argo CD Project (grouping and RBAC) |
| **syncPolicy** | How Argo CD should sync the application |
| `automated` | Enable automatic sync |
| `selfHeal` | Automatically revert manual changes |
| `syncOptions` | Additional sync options |
| `CreateNamespace=true` | Auto-create the namespace if it doesn't exist |

4. **Create the Application**
   - Review the manifest
   - Click **Save**
   - Click **Create**

5. **Wait for Sync**
   - Wait for the application tile to show **Healthy** and **Synced**

**Congratulations!** Your first application has been deployed via GitOps.

### Verify the Deployment

#### In OpenShift Console

1. Navigate to the **Developer Perspective**
2. Switch to the **bgd** project
3. View the **Topology**
4. You should see the bgd application deployed

#### Access the Application

1. In the Topology view, click the **route icon** (small arrow) at the top right of the bgd circle
2. The application will open showing bouncing blue balloons

### What Just Happened?

1. **Argo CD** pulled the manifests from the Git repository
2. **Applied** them to the OpenShift cluster
3. **Created** the namespace, deployment, service, and route
4. **Monitors** the application for drift
5. **Self-heals** if manual changes are made (due to `selfHeal: true`)

---

## Next Steps

You have successfully:
- ✅ Installed OpenShift GitOps Operator
- ✅ Configured the default Argo CD instance
- ✅ Deployed your first application using GitOps

### Continue Your Journey

#### Documentation
- [OpenShift GitOps Official Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)

#### Free eBooks
- **GitOps Cookbook** - Practical recipes for GitOps
- **Getting GitOps: A practical platform with OpenShift, Argo CD, and Tekton**

#### Recommended Practices
- [OpenShift GitOps Recommended Practices](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)

### Apply to This Project

Now that you understand how OpenShift GitOps works, you can apply these concepts to the Redis Enterprise demo:

1. **Review the Argo CD Applications** in the `argocd/` directory
2. **Deploy the Redis Enterprise demo** using the same process
3. **Experiment with GitOps workflows** by modifying Redis configurations in Git

See the main [README.md](../README.md) and [QUICKSTART.md](../QUICKSTART.md) for Redis Enterprise-specific deployment instructions.

---

## Quick Reference Commands

### Check Operator Installation
```bash
# List installed operators
oc get csv -n openshift-operators | grep gitops

# Check GitOps pods
oc get pods -n openshift-gitops
```

### Manage Groups
```bash
# List all groups
oc get groups

# Create cluster-admins group
oc adm groups new cluster-admins <username>

# Add user to group
oc adm groups add-users cluster-admins <username>

# View group details
oc get groups cluster-admins -o yaml
```

### Manage Permissions
```bash
# Grant cluster-admin to Argo CD
oc adm policy add-cluster-role-to-user \
  --rolebinding-name="openshift-gitops-cluster-admin" \
  cluster-admin \
  -z openshift-gitops-argocd-application-controller \
  -n openshift-gitops

# View ClusterRoleBinding
oc get clusterrolebinding openshift-gitops-cluster-admin -o yaml
```

### Manage Applications
```bash
# List Argo CD Applications
oc get applications -n openshift-gitops

# View Application details
oc get application bgd -n openshift-gitops -o yaml

# Delete Application
oc delete application bgd -n openshift-gitops
```

### Access Argo CD
```bash
# Get Argo CD route
oc get route openshift-gitops-server -n openshift-gitops

# Get admin password (if needed)
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
```

---

## Troubleshooting

### Cannot See OperatorHub
**Problem**: OperatorHub menu item is not visible
**Solution**: You do not have cluster-admin privileges. Contact your cluster administrator.

### User Has No Permissions in Argo CD
**Problem**: Can log in but cannot view or create applications
**Solution**:
1. Ensure you are in the `cluster-admins` group
2. Log out and log back in to Argo CD
3. Verify group membership in User Info

### Application Not Syncing
**Problem**: Application shows "OutOfSync" status
**Solution**:
1. Check Argo CD has permissions to the target namespace
2. Verify the Git repository is accessible
3. Check the application logs in Argo CD UI

### Insufficient Permissions Error
**Problem**: Argo CD cannot create resources
**Solution**: Ensure the ClusterRoleBinding was created correctly:
```bash
oc get clusterrolebinding openshift-gitops-cluster-admin
```

---

## Best Practices

### For Production Deployments

1. **Separate Argo CD Instances**
   - Use the default instance for cluster configuration
   - Create separate instances for application teams

2. **Use Argo CD Projects**
   - Don't use the `default` project
   - Create projects with appropriate RBAC and restrictions

3. **Implement RBAC**
   - Don't give everyone admin access
   - Use groups and roles appropriately

4. **Use Git Branches**
   - Use different branches for different environments
   - Implement PR-based workflows for production changes

5. **Enable Notifications**
   - Configure Slack/email notifications for sync failures
   - Set up alerts for drift detection

6. **Backup Argo CD Configuration**
   - Regularly backup Argo CD Applications and Projects
   - Store them in Git for disaster recovery

### Security Considerations

1. **Limit cluster-admin Permissions**
   - Only grant cluster-admin when necessary
   - Use namespace-scoped permissions for application deployments

2. **Use Private Git Repositories**
   - Store sensitive configurations in private repos
   - Use SSH keys or tokens for authentication

3. **Enable TLS**
   - Use TLS for Git repository connections
   - Enable TLS for Argo CD UI access

4. **Audit and Compliance**
   - Leverage Git history for audit trails
   - Use Argo CD RBAC for access control

---

## Additional Resources

### Related Documentation in This Project
- [Prerequisites](PREREQUISITES.md) - Platform and tooling requirements
- [Deployment Guide](DEPLOYMENT.md) - Deploy Redis Enterprise with GitOps
- [Operations Guide](OPERATIONS.md) - Day-2 operations
- [Architecture](ARCHITECTURE.md) - Architecture overview

### External Resources
- [Red Hat OpenShift GitOps](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kustomize Documentation](https://kustomize.io/)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-19
**Maintained By**: Platform Team


