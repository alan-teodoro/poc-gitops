# Redis Enterprise Configuration Examples

This directory contains additional examples and use cases for Redis Enterprise on OpenShift.

## Available Examples

### Database Configurations

1. **Cache Database** - High-performance cache with LRU eviction
2. **Session Store** - Session storage with TTL-based eviction
3. **Persistent Database** - Database with AOF persistence
4. **Sharded Database** - Multi-shard database for high throughput
5. **Database with Modules** - Redis with modules (Search, TimeSeries, etc.)

### Advanced Configurations

6. **TLS-Enabled Database** - Secure database with TLS
7. **Active-Active Database** - Geo-distributed CRDB
8. **Database with Backup** - Automated backup configuration
9. **Resource-Limited Database** - Database with CPU/memory limits

## Example Files

Each example includes:
- YAML manifest
- Description of use case
- Configuration explanation
- Testing instructions

## Using Examples

### Copy an Example

```bash
# Copy example to your environment
cp examples/cache-database.yaml orders-redis-dev/redb-my-cache.yaml

# Customize as needed
# Add to kustomization.yaml
# Commit and push
```

### Combine Examples

You can combine features from multiple examples:

```yaml
# Combine persistence + TLS
spec:
  memorySize: 2GB
  persistence: aofEverySecond  # From persistent-database.yaml
  tlsMode: enabled              # From tls-database.yaml
```

## Examples Overview

### 1. Cache Database

**Use Case**: High-performance application cache

**File**: `cache-database.yaml`

**Features**:
- No persistence (in-memory only)
- LRU eviction policy
- Replication for HA

**Best For**:
- Session caching
- API response caching
- Temporary data storage

### 2. Session Store

**Use Case**: User session management

**File**: `session-store.yaml`

**Features**:
- TTL-based eviction
- Smaller memory footprint
- Fast access

**Best For**:
- Web application sessions
- Temporary tokens
- Short-lived data

### 3. Persistent Database

**Use Case**: Durable data storage

**File**: `persistent-database.yaml`

**Features**:
- AOF persistence
- Data survives restarts
- Configurable fsync policy

**Best For**:
- User data
- Application state
- Important caches

### 4. Sharded Database

**Use Case**: High-throughput workloads

**File**: `sharded-database.yaml`

**Features**:
- Multiple shards
- Distributed data
- Higher throughput

**Best For**:
- Large datasets
- High-traffic applications
- Scalable workloads

### 5. Database with Modules

**Use Case**: Advanced Redis features

**File**: `modules-database.yaml`

**Features**:
- RedisSearch for full-text search
- RedisTimeSeries for time-series data
- RedisJSON for JSON documents

**Best For**:
- Search functionality
- Time-series analytics
- Document storage

### 6. TLS-Enabled Database

**Use Case**: Secure production database

**File**: `tls-database.yaml`

**Features**:
- Encrypted connections
- Certificate-based auth
- Production-ready security

**Best For**:
- Production environments
- Compliance requirements
- Sensitive data

### 7. Active-Active Database

**Use Case**: Geo-distributed applications

**File**: `active-active-database.yaml`

**Features**:
- Multi-region replication
- Conflict resolution
- Low-latency local reads

**Best For**:
- Global applications
- Disaster recovery
- Multi-datacenter deployments

### 8. Database with Backup

**Use Case**: Automated data backup

**File**: `backup-database.yaml`

**Features**:
- Scheduled backups
- S3 storage
- Point-in-time recovery

**Best For**:
- Production databases
- Compliance requirements
- Data protection

### 9. Resource-Limited Database

**Use Case**: Resource-constrained environments

**File**: `resource-limited-database.yaml`

**Features**:
- CPU limits
- Memory limits
- Guaranteed resources

**Best For**:
- Shared clusters
- Cost optimization
- Resource quotas

## Testing Examples

### Deploy an Example

```bash
# Copy to your environment
cp examples/persistent-database.yaml orders-redis-dev/redb-test.yaml

# Update metadata
sed -i 's/name: example/name: test/' orders-redis-dev/redb-test.yaml

# Add to kustomization
echo "  - redb-test.yaml" >> orders-redis-dev/kustomization.yaml

# Validate
kustomize build orders-redis-dev

# Commit and push
git add orders-redis-dev/
git commit -m "Add test database from example"
git push
```

### Verify Deployment

```bash
# Check database status
oc get redisenterprisedatabase -n orders-redis-dev

# Get connection details
oc describe redisenterprisedatabase test -n orders-redis-dev

# Test connection
oc run redis-cli --image=redis:latest -n orders-redis-dev --rm -it -- \
  redis-cli -h test -p <PORT>
```

## Customization Tips

### Adjust Memory Size

```yaml
spec:
  memorySize: 2GB  # Change based on your needs
```

### Change Eviction Policy

```yaml
spec:
  evictionPolicy: allkeys-lru  # Options: volatile-lru, allkeys-lru, volatile-lfu, 
                                #          allkeys-lfu, volatile-random, allkeys-random,
                                #          volatile-ttl, noeviction
```

### Enable/Disable Replication

```yaml
spec:
  replication: true  # false for single-shard (no replica)
```

### Configure Persistence

```yaml
spec:
  persistence: aofEverySecond  # Options: disabled, aofEverySecond,
                                #          snapshotEvery1Hour, snapshotEvery6Hours,
                                #          snapshotEvery12Hours
```

## Best Practices

1. **Start Simple**: Begin with basic examples and add features as needed
2. **Test in Dev**: Always test new configurations in dev environment first
3. **Monitor Resources**: Watch memory and CPU usage after deployment
4. **Use Appropriate Persistence**: Balance durability vs. performance
5. **Enable TLS in Production**: Always use TLS for production databases
6. **Plan for Scale**: Consider sharding for large datasets
7. **Backup Important Data**: Configure backups for production databases

## Contributing Examples

Have a useful configuration? Contribute it!

1. Create a new example file
2. Add documentation
3. Test thoroughly
4. Submit a pull request

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for details.

## Additional Resources

- [Redis Enterprise Documentation](https://redis.io/docs/latest/operate/kubernetes/)
- [Redis Commands Reference](https://redis.io/commands/)
- [Redis Best Practices](https://redis.io/docs/latest/develop/use/patterns/)
- [OpenShift Documentation](https://docs.openshift.com/)

