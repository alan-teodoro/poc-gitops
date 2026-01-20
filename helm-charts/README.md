# Redis Enterprise Helm Charts

This directory contains Helm charts for deploying Redis Enterprise on OpenShift.

## Charts

### redis-enterprise-cluster
Deploys a Redis Enterprise Cluster (REC) with:
- Namespace
- RedisEnterpriseCluster resource
- Route for UI access

**Usage**:
```bash
helm template my-cluster redis-enterprise-cluster \
  -f environments/clusters/orders/values.yaml
```

### redis-enterprise-database
Deploys a Redis Enterprise Database (REDB) with:
- RedisEnterpriseDatabase resource
- Route for database access

**Usage**:
```bash
helm template my-db redis-enterprise-database \
  -f redis-enterprise-database/values-cache.yaml \
  -f environments/databases/orders/dev/cache.yaml
```

## Presets

### values-cache.yaml
For caching workloads:
- No persistence
- volatile-lru eviction
- High throughput

### values-session.yaml
For session storage:
- No persistence
- volatile-ttl eviction
- TTL-based expiration

### values-persistent.yaml
For durable data:
- AOF persistence
- noeviction policy
- TLS enabled
- Multiple shards

## Testing Charts Locally

```bash
# Test cluster chart
helm template test-cluster redis-enterprise-cluster \
  -f environments/clusters/orders/values.yaml \
  --debug

# Test database chart
helm template test-db redis-enterprise-database \
  -f redis-enterprise-database/values-cache.yaml \
  -f environments/databases/orders/dev/cache.yaml \
  --debug

# Validate YAML
helm template test-cluster redis-enterprise-cluster \
  -f environments/clusters/orders/values.yaml | \
  kubectl apply --dry-run=client -f -
```

## Documentation

- [Architecture Overview](../docs/HELM_ARCHITECTURE.md)
- [Onboarding Guide](../docs/ONBOARDING_GUIDE.md)
- [Repository Connection](../docs/REPOSITORY_CONNECTION.md)

## Chart Versioning

- **Chart Version**: Semantic versioning (1.0.0)
- **App Version**: Redis Enterprise version (8.0.6-54)

## Contributing

When modifying charts:
1. Update Chart.yaml version
2. Test with `helm template`
3. Validate with `kubectl apply --dry-run`
4. Update documentation
5. Commit and push

