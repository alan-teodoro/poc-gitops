# Redis Enterprise Performance Testing

This directory contains **production-grade performance testing resources** for Redis Enterprise using `memtier_benchmark`.

---

## 🎯 Purpose

Performance testing is **critical** after deploying a Redis Enterprise cluster to:

1. ✅ **Validate Infrastructure** - Ensure cluster is configured correctly
2. ✅ **Establish Baselines** - Document expected performance metrics
3. ✅ **Validate Observability** - Confirm metrics, dashboards, and alerts work under load
4. ✅ **Identify Bottlenecks** - Find resource constraints before production
5. ✅ **Create Runbooks** - Document repeatable testing procedures

---

## 📊 Test Scenarios

### **1. Baseline Test** (`baseline-test.yaml`)
- **Purpose**: Quick validation that cluster is functional
- **Duration**: ~2 minutes
- **Load**: Light (50 clients, 4 threads)
- **Use Case**: Smoke test after deployment

### **2. High Throughput Test** (`high-throughput-test.yaml`)
- **Purpose**: Find maximum operations per second
- **Duration**: 5 minutes
- **Load**: Heavy (200 clients, 16 threads, pipeline=10)
- **Use Case**: Capacity planning

### **3. Latency Test** (`latency-test.yaml`)
- **Purpose**: Measure P50, P95, P99 latency
- **Duration**: 10 minutes
- **Load**: Moderate (no pipelining for accurate latency)
- **Use Case**: SLA validation

### **4. Sustained Load Test** (`sustained-load-test.yaml`)
- **Purpose**: Verify stability under continuous load
- **Duration**: 30 minutes
- **Load**: Moderate sustained
- **Use Case**: Endurance testing, memory leak detection

---

## 🚀 Quick Start

### **Step 1: Run Baseline Test**

```bash
# Apply the baseline test Job
oc apply -f platform/testing/test-scenarios/baseline-test.yaml

# Monitor Job status
oc get jobs -n redis-team1-dev -w

# Wait for completion
oc wait --for=condition=complete job/memtier-baseline -n redis-team1-dev --timeout=5m
```

### **Step 2: Monitor in Grafana**

While test is running:

1. Open Grafana: `oc get route grafana-redis-monitoring -n openshift-monitoring`
2. Navigate to **Dashboards** → **Redis Enterprise** → **Database Status Dashboard**
3. Select `cluster = demo`, `database = team1-cache-dev`
4. Observe real-time metrics:
   - **Latency** (should be < 2ms)
   - **Throughput** (ops/sec)
   - **Connections** (active clients)
   - **CPU/Memory** usage

### **Step 3: Collect Results**

```bash
# View test output
oc logs job/memtier-baseline -n redis-team1-dev

# Save results
oc logs job/memtier-baseline -n redis-team1-dev > results/baseline-$(date +%Y%m%d-%H%M%S).txt
```

### **Step 4: Cleanup**

```bash
# Delete the Job
oc delete job memtier-baseline -n redis-team1-dev
```

---

## 📋 Test Parameters Explained

### **Common memtier_benchmark Options**

| Parameter | Description | Typical Values |
|-----------|-------------|----------------|
| `--server` | Redis server hostname | `team1-cache-dev` |
| `--port` | Redis port | `12000` (default for REDB) |
| `--clients` | Concurrent clients per thread | 10-200 |
| `--threads` | Worker threads | 1-16 |
| `--ratio` | SET:GET ratio | `1:10` (read-heavy), `1:1` (balanced) |
| `--data-size` | Value size in bytes | `32`, `1024`, `10240` |
| `--requests` | Total requests per client | `10000`, `100000` |
| `--pipeline` | Pipeline depth | `1` (no pipeline), `10`, `20` |
| `--run-count` | Number of test iterations | `3`, `5` |
| `--test-time` | Test duration (alternative to requests) | `60`, `300`, `1800` (seconds) |

---

## 📖 Documentation

- **[PERFORMANCE_TESTING.md](../../docs/PERFORMANCE_TESTING.md)** - Complete testing guide
- **[PERFORMANCE_BASELINES.md](../../docs/PERFORMANCE_BASELINES.md)** - Expected results and SLOs
- **[ARGOCD_IMPLEMENTATION_GUIDE.md](../../docs/ARGOCD_IMPLEMENTATION_GUIDE.md)** - Step-by-step implementation
- **[TEST_RUNBOOK.md](./TEST_RUNBOOK.md)** - End-to-end test-day checklist

---

## 🎓 Best Practices

1. ✅ **Always test in dev first** before running in production
2. ✅ **Monitor Grafana dashboards** during tests
3. ✅ **Run multiple iterations** (3-5) for consistent results
4. ✅ **Document baselines** for future comparison
5. ✅ **Test different scenarios** (read-heavy, write-heavy, mixed)
6. ✅ **Cleanup Jobs** after completion to avoid clutter
7. ✅ **Save results** with timestamps for historical tracking

---

## 🔍 Troubleshooting

### **Job doesn't complete**
```bash
# Check Job status
oc describe job memtier-baseline -n redis-team1-dev

# Check Pod logs
oc logs -l job-name=memtier-baseline -n redis-team1-dev
```

### **Connection refused errors**
- Verify database is running: `oc get redb -n redis-team1-dev`
- Check service exists: `oc get svc team1-cache-dev -n redis-team1-dev`
- Verify port number matches database port

### **Low performance**
- Check ResourceQuotas: `oc describe quota -n redis-team1-dev`
- Check LimitRanges: `oc describe limitrange -n redis-team1-dev`
- Review Grafana dashboards for bottlenecks (CPU, memory, network)

---

## 📚 References

- [memtier_benchmark GitHub](https://github.com/redis/memtier_benchmark)
- [Redis Benchmarking Guide](https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/benchmarks/)
- [Redis Enterprise Performance Best Practices](https://redis.io/docs/latest/operate/rs/references/memtier-benchmark/)
