# Operations Guide

This guide describes common day-2 operations and GitOps workflows for managing Redis Enterprise on OpenShift.

## GitOps Principles

All changes to Redis Enterprise configuration follow this workflow:

1. **Modify** configuration files in Git
2. **Commit** and push changes to the repository
3. **Argo CD** detects changes and reconciles them to the cluster
4. **Redis Enterprise Operator** applies the changes to running resources

**Never make manual changes directly in the cluster** - always use Git as the source of truth.

---

## Common Operations

### 1. Adding a New Database

**Scenario**: Add a new Redis database for session storage.

**Steps**:

1. **Create a new REDB manifest**:
   ```bash
   # Create orders-redis-dev/redb-session-store-dev.yaml
   ```

   Content:
   ```yaml
   apiVersion: app.redislabs.com/v1
   kind: RedisEnterpriseDatabase
   metadata:
     name: session-store-dev
     namespace: orders-redis-dev
   spec:
     memorySize: 512MB
     replication: true
     persistence: disabled
     databasePort: 12001
     tlsMode: disabled
   ```

2. **Update kustomization.yaml**:
   ```yaml
   # Edit orders-redis-dev/kustomization.yaml
   # Add the new resource
   resources:
     - namespace.yaml
     - rec-orders-redis-cluster.yaml
     - redb-orders-cache-dev.yaml
     - redb-session-store-dev.yaml  # New line
   ```

3. **Validate locally** (optional):
   ```bash
   kustomize build orders-redis-dev
   ```

4. **Commit and push**:
   ```bash
   git add orders-redis-dev/
   git commit -m "Add session-store-dev database"
   git push origin main
   ```

5. **Verify in Argo CD**:
   - Argo CD will detect the change (within 3 minutes by default)
   - Or manually sync: `oc patch application orders-redis-dev -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'`

6. **Verify the database**:
   ```bash
   oc get redisenterprisedatabase -n orders-redis-dev
   oc describe redisenterprisedatabase session-store-dev -n orders-redis-dev
   ```

---

### 2. Modifying Database Configuration

**Scenario**: Increase memory allocation for the cache database.

**Steps**:

1. **Edit the REDB manifest**:
   ```bash
   # Edit orders-redis-dev/redb-orders-cache-dev.yaml
   ```

   Change:
   ```yaml
   spec:
     memorySize: 2GB  # Changed from 1GB
   ```

2. **Commit and push**:
   ```bash
   git add orders-redis-dev/redb-orders-cache-dev.yaml
   git commit -m "Increase orders-cache-dev memory to 2GB"
   git push origin main
   ```

3. **Verify the change**:
   ```bash
   # Wait for Argo CD to sync
   oc get redisenterprisedatabase orders-cache-dev -n orders-redis-dev -o yaml | grep memorySize
   ```

**Note**: Some changes (like memory size) can be applied without downtime. Others may require database restart. Check Redis Enterprise documentation for specific field behaviors.

---

### 3. Scaling the Redis Enterprise Cluster

**Scenario**: Scale the cluster from 3 to 5 nodes.

**Steps**:

1. **Edit the REC manifest**:
   ```bash
   # Edit orders-redis-dev/rec-orders-redis-cluster.yaml
   ```

   Change:
   ```yaml
   spec:
     nodes: 5  # Changed from 3
   ```

2. **Commit and push**:
   ```bash
   git add orders-redis-dev/rec-orders-redis-cluster.yaml
   git commit -m "Scale cluster to 5 nodes"
   git push origin main
   ```

3. **Monitor the scaling**:
   ```bash
   oc get pods -n orders-redis-dev -w
   ```

   New pods will be created: `orders-redis-cluster-3` and `orders-redis-cluster-4`

---

### 4. Enabling Database Persistence

**Scenario**: Enable persistence for the cache database.

**Steps**:

1. **Edit the REDB manifest**:
   ```bash
   # Edit orders-redis-dev/redb-orders-cache-dev.yaml
   ```

   Change:
   ```yaml
   spec:
     persistence: aofEverySecond  # Changed from disabled
   ```

   Options:
   - `disabled` - No persistence
   - `aofEverySecond` - AOF with fsync every second
   - `snapshotEvery1Hour` - RDB snapshot every hour
   - `snapshotEvery6Hours` - RDB snapshot every 6 hours
   - `snapshotEvery12Hours` - RDB snapshot every 12 hours

2. **Commit and push**:
   ```bash
   git add orders-redis-dev/redb-orders-cache-dev.yaml
   git commit -m "Enable AOF persistence for orders-cache-dev"
   git push origin main
   ```

---

### 5. Deleting a Database

**Scenario**: Remove the session-store-dev database.

**Steps**:

1. **Remove from kustomization.yaml**:
   ```yaml
   # Edit orders-redis-dev/kustomization.yaml
   # Remove the line:
   # - redb-session-store-dev.yaml
   ```

2. **Delete the manifest file**:
   ```bash
   git rm orders-redis-dev/redb-session-store-dev.yaml
   ```

3. **Commit and push**:
   ```bash
   git commit -m "Remove session-store-dev database"
   git push origin main
   ```

4. **Verify deletion**:
   ```bash
   oc get redisenterprisedatabase -n orders-redis-dev
   ```

**Note**: With Argo CD's `prune: true` setting, the database will be automatically deleted from the cluster.

---

## Advanced Operations

### Enabling TLS

For production environments, enable TLS on databases:

```yaml
spec:
  tlsMode: enabled
  # Optional: specify custom certificates
  # tlsSecret: my-tls-secret
```

### Configuring Replication

Enable high availability with replication:

```yaml
spec:
  replication: true
  # Optional: specify replica sources
  # replicaOf: ["redis://source-db:12000"]
```

### Setting Resource Limits

Configure resource limits for the cluster:

```yaml
spec:
  redisEnterpriseNodeResources:
    requests:
      cpu: "2"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
```

---

## Monitoring and Observability

### Check Cluster Status

```bash
# Overall cluster status
oc get redisenterprisecluster -n orders-redis-dev

# Detailed cluster information
oc describe redisenterprisecluster orders-redis-cluster -n orders-redis-dev

# Cluster logs
oc logs -n orders-redis-dev orders-redis-cluster-0
```

### Check Database Status

```bash
# List all databases
oc get redisenterprisedatabase -n orders-redis-dev

# Database details
oc describe redisenterprisedatabase orders-cache-dev -n orders-redis-dev

# Database connection info
oc get redisenterprisedatabase orders-cache-dev -n orders-redis-dev -o jsonpath='{.status}'
```

### Argo CD Monitoring

```bash
# Application status
oc get application orders-redis-dev -n openshift-gitops

# Application details
oc describe application orders-redis-dev -n openshift-gitops

# Force sync
oc patch application orders-redis-dev -n openshift-gitops \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

---

## Best Practices

### 1. Use Pull Requests

For production environments:
- Never commit directly to main/production branches
- Use pull requests for all changes
- Require code review and approval
- Run CI validation before merging

### 2. Test in Lower Environments

- Test changes in dev before promoting to prod
- Use the multi-environment pattern with overlays
- Validate with `kustomize build` before committing

### 3. Document Changes

- Write clear commit messages
- Include ticket/issue references
- Document breaking changes

### 4. Monitor Argo CD

- Set up alerts for sync failures
- Review sync status regularly
- Investigate drift between Git and cluster

### 5. Backup Configuration

- Git is your backup for configuration
- Ensure Git repository is backed up
- For data backup, use Redis Enterprise backup features

---

## Troubleshooting

### Change Not Applied

1. Check Argo CD sync status
2. Verify Git commit was pushed
3. Check Argo CD application logs
4. Manually trigger sync if needed

### Database Configuration Rejected

1. Check REDB status and events
2. Verify configuration is valid
3. Check operator logs
4. Ensure cluster has sufficient resources

### Cluster Not Scaling

1. Check node resources
2. Verify storage availability
3. Check cluster events
4. Review operator logs

---

## Next Steps

- Explore the multi-environment pattern in `orders-redis/`
- Set up CI validation (see `ci/validate.sh`)
- Configure monitoring and alerting
- Plan migration to production

