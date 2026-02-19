# POC 1: Non-CRD Database Management

## Objective

Prove that Redis databases created via Console or REST API can be managed independently without Kubernetes operator interference. This validates that the operator does not interfere with databases not created via CRD (Custom Resource Definition).

---

## Test Scenarios

### 1. Database Creation via REST API
### 2. Database Failover Operation
### 3. Database Migration Between Nodes
### 4. Database Configuration Changes (Memory Resize)
### 5. Operator Non-Interference Validation

---

## Prerequisites

- Redis Enterprise Cluster running in `redis-demo` namespace
- Cluster API credentials
- `curl` and `jq` tools installed

---

## Step 1: Get Cluster API Credentials

```bash
# Get cluster API endpoint
CLUSTER_API=$(oc get route demo-cluster-api -n redis-demo -o jsonpath='{.spec.host}')
echo "Cluster API: https://$CLUSTER_API"

# Get admin credentials
ADMIN_USER=$(oc get secret demo-cluster -n redis-demo -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(oc get secret demo-cluster -n redis-demo -o jsonpath='{.data.password}' | base64 -d)

echo "Admin User: $ADMIN_USER"
echo "Admin Password: $ADMIN_PASS"
```

**Evidence**: Save output to `evidence/poc1/01-cluster-credentials.txt`

---

## Step 2: Create Database via REST API

```bash
# Create database using REST API
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -X POST https://$CLUSTER_API/v1/bdbs \
  -d '{
    "name": "api-created-db",
    "type": "redis",
    "memory_size": 104857600,
    "port": 12000,
    "replication": true,
    "persistence": "aof",
    "aof_policy": "appendfsync-every-sec"
  }' | jq .

# Verify database was created
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs | jq '.[] | select(.name=="api-created-db")'
```

**Evidence**: 
- Save API response to `evidence/poc1/02-database-creation-api.json`
- Screenshot of database in Redis Enterprise Console

**Expected Result**: Database created successfully with UID returned

---

## Step 3: Verify Database is NOT Managed by Kubernetes

```bash
# Check if database exists as CRD
oc get redisenterprisedatabase -n redis-demo

# Should NOT show "api-created-db"
```

**Evidence**: Save output to `evidence/poc1/03-no-crd-found.txt`

**Expected Result**: Only CRD-created databases appear (e.g., `customers`), NOT `api-created-db`

---

## Step 4: Test Database Failover

```bash
# Get database UID
DB_UID=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs | \
  jq -r '.[] | select(.name=="api-created-db") | .uid')

echo "Database UID: $DB_UID"

# Get current master node
CURRENT_NODE=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.shards[0].node_uid')

echo "Current master node: $CURRENT_NODE"

# Trigger failover
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  -X POST https://$CLUSTER_API/v1/bdbs/$DB_UID/actions/failover | jq .

# Wait 10 seconds
sleep 10

# Verify new master node
NEW_NODE=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.shards[0].node_uid')

echo "New master node: $NEW_NODE"

# Verify failover occurred
if [ "$CURRENT_NODE" != "$NEW_NODE" ]; then
  echo "✅ Failover successful!"
else
  echo "⚠️ Failover did not change node"
fi
```

**Evidence**: Save output to `evidence/poc1/04-failover-test.txt`

**Expected Result**: Master node changes after failover

---

## Step 5: Test Database Migration

```bash
# Get all nodes
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/nodes | jq -r '.[] | "\(.uid): \(.addr)"'

# Migrate database to specific node
TARGET_NODE=<node_uid>  # Choose different node

curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -X PUT https://$CLUSTER_API/v1/bdbs/$DB_UID \
  -d "{\"shards_placement\": \"dense\", \"shards_placement_policy\": \"node:$TARGET_NODE\"}" | jq .

# Verify migration
sleep 10
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.shards[0].node_uid'
```

**Evidence**: Save output to `evidence/poc1/05-migration-test.txt`

**Expected Result**: Database migrated to target node

---

## Step 6: Test Memory Resize

```bash
# Get current memory size
CURRENT_MEM=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.memory_size')

echo "Current memory: $CURRENT_MEM bytes"

# Resize to 200MB
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -X PUT https://$CLUSTER_API/v1/bdbs/$DB_UID \
  -d '{"memory_size": 209715200}' | jq .

# Verify new size
sleep 5
NEW_MEM=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.memory_size')

echo "New memory: $NEW_MEM bytes"
```

**Evidence**: Save output to `evidence/poc1/06-memory-resize.txt`

**Expected Result**: Memory size changed from 100MB to 200MB

---

## Step 7: Verify Operator Non-Interference

```bash
# Check operator logs for any reconciliation attempts
oc logs -n redis-demo deployment/redis-enterprise-operator --tail=50 | grep -i "api-created-db"

# Should show NO reconciliation attempts for this database
```

**Evidence**: Save output to `evidence/poc1/07-operator-logs.txt`

**Expected Result**: No operator activity related to `api-created-db`

---

## Step 8: Test Database Connectivity

```bash
# Get database endpoint
DB_ENDPOINT=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.dns_address_master')

echo "Database endpoint: $DB_ENDPOINT"

# Get database password
DB_PASS=$(curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs/$DB_UID | \
  jq -r '.authentication_redis_pass')

# Test connection
redis-cli -h $DB_ENDPOINT -p 12000 -a "$DB_PASS" PING

# Write test data
redis-cli -h $DB_ENDPOINT -p 12000 -a "$DB_PASS" SET test:key "POC1-Success"

# Read test data
redis-cli -h $DB_ENDPOINT -p 12000 -a "$DB_PASS" GET test:key
```

**Evidence**: Save output to `evidence/poc1/08-connectivity-test.txt`

**Expected Result**: PONG response and successful data read/write

---

## Cleanup

```bash
# Delete database via API
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  -X DELETE https://$CLUSTER_API/v1/bdbs/$DB_UID

# Verify deletion
curl -k -u "$ADMIN_USER:$ADMIN_PASS" \
  https://$CLUSTER_API/v1/bdbs | jq '.[] | select(.name=="api-created-db")'
```

---

## Success Criteria

- ✅ Database created successfully via REST API
- ✅ Database does NOT appear as Kubernetes CRD
- ✅ Failover operation successful
- ✅ Migration between nodes successful
- ✅ Memory resize successful
- ✅ Operator shows NO interference in logs
- ✅ Database connectivity working

---

## Conclusion

This POC demonstrates that Redis Enterprise databases created via REST API or Console are fully manageable independently of the Kubernetes operator. All operations (failover, migration, resize) work without operator interference, proving that the operator only manages CRD-created databases.

---

**Test Duration**: ~30 minutes  
**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed  
**Tested By**: _________________  
**Date**: _________________

