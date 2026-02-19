# POC 2: Network Performance Analysis

## Objective

Measure and compare latency between internal Service access (within cluster) and external Route access (from outside cluster) to quantify network overhead and validate performance characteristics.

---

## Test Scenarios

### 1. Internal Service Latency (Pod-to-Service)
### 2. External Route Latency (External-to-Route)
### 3. Performance Comparison Analysis
### 4. Network Overhead Quantification

---

## Prerequisites

- Redis Enterprise Cluster running with database deployed
- `redis-benchmark` tool available
- Access to create test pods in the cluster

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                     │
│                                                          │
│  ┌──────────────┐         ┌──────────────────────┐     │
│  │  Test Pod    │────────▶│  Redis Service       │     │
│  │              │  (1)    │  (Internal)          │     │
│  └──────────────┘         └──────────────────────┘     │
│                                     │                    │
│                                     ▼                    │
│                           ┌──────────────────────┐      │
│                           │  Redis Database      │      │
│                           │  (customers)         │      │
│                           └──────────────────────┘      │
│                                     ▲                    │
│                                     │                    │
│                           ┌──────────────────────┐      │
│                           │  OpenShift Router    │      │
│                           │  (HAProxy)           │      │
│                           └──────────────────────┘      │
│                                     ▲                    │
└─────────────────────────────────────┼────────────────────┘
                                      │
                            ┌──────────────────────┐
                            │  External Client     │
                            │  (2)                 │
                            └──────────────────────┘

(1) Internal Service Access - Low latency
(2) External Route Access - Higher latency (TLS termination, routing)
```

---

## Step 1: Get Database Connection Details

```bash
# Get internal service endpoint
INTERNAL_SERVICE=$(oc get svc -n redis-demo -l app=redis-enterprise-database,redis.io/bdb=customers -o jsonpath='{.items[0].metadata.name}')
INTERNAL_PORT=$(oc get svc $INTERNAL_SERVICE -n redis-demo -o jsonpath='{.spec.ports[0].port}')

echo "Internal Service: $INTERNAL_SERVICE:$INTERNAL_PORT"

# Get database password
DB_PASSWORD=$(oc get secret redb-customers -n redis-demo -o jsonpath='{.data.password}' | base64 -d)

echo "Database Password: $DB_PASSWORD"

# Create external route (if not exists)
oc create route passthrough customers-external \
  --service=$INTERNAL_SERVICE \
  --port=$INTERNAL_PORT \
  -n redis-demo 2>/dev/null || echo "Route already exists"

# Get external route
EXTERNAL_ROUTE=$(oc get route customers-external -n redis-demo -o jsonpath='{.spec.host}')
EXTERNAL_PORT=443

echo "External Route: $EXTERNAL_ROUTE:$EXTERNAL_PORT"
```

**Evidence**: Save output to `evidence/poc2/01-connection-details.txt`

---

## Step 2: Test Internal Service Latency

```bash
# Create test pod with redis-cli
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: redis-benchmark-pod
  namespace: redis-demo
spec:
  containers:
  - name: redis-tools
    image: redis:7-alpine
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF

# Wait for pod to be ready
oc wait --for=condition=Ready pod/redis-benchmark-pod -n redis-demo --timeout=60s

# Run internal latency test (1000 requests)
oc exec -n redis-demo redis-benchmark-pod -- \
  redis-benchmark \
  -h $INTERNAL_SERVICE \
  -p $INTERNAL_PORT \
  -a "$DB_PASSWORD" \
  -t ping,set,get \
  -n 1000 \
  -q \
  --csv > evidence/poc2/02-internal-latency.csv

# Display results
cat evidence/poc2/02-internal-latency.csv
```

**Evidence**: Save output to `evidence/poc2/02-internal-latency.csv`

---

## Step 3: Test External Route Latency

```bash
# Run external latency test (1000 requests)
# Note: Using --tls and --insecure for passthrough route
redis-benchmark \
  -h $EXTERNAL_ROUTE \
  -p $EXTERNAL_PORT \
  -a "$DB_PASSWORD" \
  --tls \
  --insecure \
  -t ping,set,get \
  -n 1000 \
  -q \
  --csv > evidence/poc2/03-external-latency.csv

# Display results
cat evidence/poc2/03-external-latency.csv
```

**Evidence**: Save output to `evidence/poc2/03-external-latency.csv`

---

## Step 4: Detailed Latency Analysis

```bash
# Internal - Detailed percentile analysis
echo "=== INTERNAL SERVICE LATENCY ===" > evidence/poc2/04-detailed-analysis.txt

oc exec -n redis-demo redis-benchmark-pod -- \
  redis-benchmark \
  -h $INTERNAL_SERVICE \
  -p $INTERNAL_PORT \
  -a "$DB_PASSWORD" \
  -t get \
  -n 10000 \
  --latency-history >> evidence/poc2/04-detailed-analysis.txt

echo "" >> evidence/poc2/04-detailed-analysis.txt
echo "=== EXTERNAL ROUTE LATENCY ===" >> evidence/poc2/04-detailed-analysis.txt

# External - Detailed percentile analysis
redis-benchmark \
  -h $EXTERNAL_ROUTE \
  -p $EXTERNAL_PORT \
  -a "$DB_PASSWORD" \
  --tls \
  --insecure \
  -t get \
  -n 10000 \
  --latency-history >> evidence/poc2/04-detailed-analysis.txt

# Display results
cat evidence/poc2/04-detailed-analysis.txt
```

**Evidence**: Save output to `evidence/poc2/04-detailed-analysis.txt`

---

## Step 5: Generate Performance Comparison Report

```bash
# Create comparison script
cat > pocs/scripts/poc2-latency-test.sh <<'SCRIPT'
#!/bin/bash

# Parse CSV results
parse_latency() {
  local file=$1
  echo "File: $file"
  echo "----------------------------------------"
  while IFS=, read -r test rps avg_latency min_latency p50 p95 p99 max_latency; do
    if [ "$test" != "test" ]; then
      printf "%-10s | RPS: %8s | Avg: %6s ms | P50: %6s ms | P95: %6s ms | P99: %6s ms\n" \
        "$test" "$rps" "$avg_latency" "$p50" "$p95" "$p99"
    fi
  done < "$file"
  echo ""
}

echo "=========================================="
echo "  REDIS NETWORK PERFORMANCE COMPARISON"
echo "=========================================="
echo ""

echo "INTERNAL SERVICE (Pod-to-Service):"
parse_latency evidence/poc2/02-internal-latency.csv

echo "EXTERNAL ROUTE (External-to-Route):"
parse_latency evidence/poc2/03-external-latency.csv

echo "=========================================="
echo "  ANALYSIS"
echo "=========================================="
echo ""
echo "Network Overhead:"
echo "- Internal access provides lowest latency (direct service)"
echo "- External access adds overhead from:"
echo "  * TLS termination/passthrough"
echo "  * HAProxy routing"
echo "  * External network path"
echo ""
echo "Recommendation:"
echo "- Use internal Service for pod-to-database communication"
echo "- Use external Route only when external access is required"
echo ""
SCRIPT

chmod +x pocs/scripts/poc2-latency-test.sh

# Run comparison
./pocs/scripts/poc2-latency-test.sh | tee evidence/poc2/05-performance-comparison.txt
```

**Evidence**: Save output to `evidence/poc2/05-performance-comparison.txt`

---

## Expected Results

### Internal Service Latency
- **PING**: < 1ms average
- **GET**: < 1ms average
- **SET**: < 1ms average
- **P99**: < 2ms

### External Route Latency
- **PING**: 1-5ms average
- **GET**: 1-5ms average
- **SET**: 1-5ms average
- **P99**: 5-10ms

### Network Overhead
- **Additional latency**: 1-4ms (TLS + routing)
- **Overhead percentage**: 100-400% increase

---

## Cleanup

```bash
# Delete test pod
oc delete pod redis-benchmark-pod -n redis-demo

# Optionally delete external route
# oc delete route customers-external -n redis-demo
```

---

## Success Criteria

- ✅ Internal service latency measured successfully
- ✅ External route latency measured successfully
- ✅ Performance comparison documented
- ✅ Network overhead quantified
- ✅ Clear recommendation provided

---

## Conclusion

This POC quantifies the network performance difference between internal Service access and external Route access. Results demonstrate that internal access provides significantly lower latency, validating the recommendation to use internal Services for pod-to-database communication whenever possible.

---

**Test Duration**: ~20 minutes  
**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed  
**Tested By**: _________________  
**Date**: _________________

