# Argo CD AppProjects

## Overview

AppProjects provide **multi-tenancy** and **governance** in Argo CD by:

1. **Namespace Isolation**: Teams can only deploy to their designated namespaces
2. **Resource Type Restrictions**: Control which Kubernetes resources teams can create
3. **RBAC Integration**: Map to LDAP/OAuth groups for access control
4. **Source Repository Control**: Restrict which Git repos can be used

## Project Structure

### Platform Team (`platform-team`)

**Purpose**: Manages cluster-wide infrastructure and policies

**Permissions**:
- ✅ Deploy to any namespace
- ✅ Create cluster-scoped resources
- ✅ Manage policies, quotas, monitoring

**Who Uses It**:
- Platform Engineering team
- SRE team
- Cluster administrators

**Applications**:
- Gatekeeper policies
- ResourceQuotas
- Logging configuration
- Monitoring dashboards
- Secret infrastructure (Vault, ESO)

### Team Projects (`team-orders`, `team-payments`, etc.)

**Purpose**: Manages team-specific Redis resources

**Permissions**:
- ✅ Deploy to team namespaces only (e.g., `redis-orders*`)
- ✅ Create Redis databases and clusters
- ✅ Create Routes, Services, Secrets
- ❌ Cannot create ResourceQuotas or LimitRanges
- ❌ Cannot create policies
- ❌ Cannot deploy to other teams' namespaces

**Who Uses It**:
- Application teams
- Database administrators (team-level)

**Applications**:
- RedisEnterpriseCluster
- RedisEnterpriseDatabase
- Routes for external access

## Deployment

### Apply AppProjects

```bash
# Apply platform team project
oc apply -f platform/argocd/projects/platform-team.yaml

# Apply team projects
oc apply -f platform/argocd/projects/team-orders.yaml
# oc apply -f platform/argocd/projects/team-payments.yaml
# oc apply -f platform/argocd/projects/team-inventory.yaml
```

### Verify

```bash
# List all projects
oc get appprojects -n openshift-gitops

# View project details
oc describe appproject team-orders -n openshift-gitops
```

### Migrate Existing Applications

```bash
# Update existing Applications to use correct project
oc patch application redis-cluster-orders \
  -n openshift-gitops \
  --type merge \
  -p '{"spec":{"project":"team-orders"}}'

# Verify
oc get applications -n openshift-gitops \
  -o custom-columns=NAME:.metadata.name,PROJECT:.spec.project
```

## RBAC Integration

AppProjects integrate with OpenShift OAuth/LDAP groups:

```yaml
roles:
  - name: admin
    groups:
      - orders-team-admins  # LDAP/OAuth group
```

### Setting Up Groups

1. **OpenShift OAuth**: Configure in `oauth` cluster resource
2. **LDAP**: Configure LDAP identity provider
3. **Manual Groups**: Create OpenShift groups manually

```bash
# Create OpenShift group (for testing)
oc adm groups new orders-team-admins user1 user2

# Add users to group
oc adm groups add-users orders-team-admins user3
```

## Security Model

### Principle of Least Privilege

Each team gets **minimum necessary permissions**:

| Resource Type | Platform Team | Application Team |
|---------------|---------------|------------------|
| Namespace | ✅ Create | ❌ No |
| ResourceQuota | ✅ Manage | ❌ No |
| Gatekeeper Policy | ✅ Manage | ❌ No |
| RedisEnterpriseCluster | ✅ Manage | ✅ Manage (own namespaces) |
| RedisEnterpriseDatabase | ✅ Manage | ✅ Manage (own namespaces) |
| Route | ✅ Manage | ✅ Manage (own namespaces) |

### Blast Radius Control

If a team's Application is compromised:
- ✅ Damage limited to team's namespaces
- ✅ Cannot affect other teams
- ✅ Cannot modify platform policies
- ✅ Cannot escalate privileges

## Best Practices

### 1. One Project Per Team

```
team-orders     → redis-orders, redis-orders-dev, redis-orders-prod
team-payments   → redis-payments, redis-payments-dev, redis-payments-prod
team-inventory  → redis-inventory, redis-inventory-dev, redis-inventory-prod
```

### 2. Separate Dev/Prod Projects (Optional)

For stricter control:

```
team-orders-dev   → redis-orders-dev
team-orders-prod  → redis-orders-prod (with sync windows)
```

### 3. Use Sync Windows for Production

```yaml
syncWindows:
  - kind: allow
    schedule: '0 9-17 * * 1-5'  # Mon-Fri 9am-5pm
    duration: 8h
    applications:
      - '*-prod'
    manualSync: true  # Require manual approval
```

### 4. Monitor Orphaned Resources

```yaml
orphanedResources:
  warn: true  # Alert on resources not in Git
```

## Troubleshooting

### Application Stuck in "Unknown" State

**Cause**: Application references a project that doesn't exist

**Solution**:
```bash
# Check if project exists
oc get appproject team-orders -n openshift-gitops

# If missing, apply it
oc apply -f platform/argocd/projects/team-orders.yaml
```

### Permission Denied Errors

**Cause**: AppProject doesn't allow the resource type or namespace

**Solution**:
```bash
# Check project permissions
oc get appproject team-orders -n openshift-gitops -o yaml

# Add missing resource to namespaceResourceWhitelist
```

### User Cannot See Applications

**Cause**: User not in correct LDAP/OAuth group

**Solution**:
```bash
# Check user's groups
oc get groups | grep orders

# Add user to group
oc adm groups add-users orders-team-developers username
```

## References

- [Argo CD Projects Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [RBAC Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [Sync Windows](https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/)

