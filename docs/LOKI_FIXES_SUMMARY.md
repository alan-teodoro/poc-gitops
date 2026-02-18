# Loki Implementation - Fixes Summary

## 📋 Overview

This document summarizes all fixes applied to the Loki logging implementation (Phase 5.5 - Option A) during testing.

---

## 🔧 Files Modified

### 1. `platform/observability/logging/loki/lokistack-instance.yaml`
**Issue**: Wrong StorageClass causing PVC creation failure  
**Fix**: Changed `storageClassName` from `gp3-csi` to `ocs-external-storagecluster-ceph-rbd` (line 43)

### 2. `platform/observability/logging/loki/loki-secret-sync-job.yaml`
**Issue**: Image pull failure for `registry.redhat.io/openshift4/ose-cli:latest`  
**Fix**: Changed image to `quay.io/openshift/origin-cli:latest` (line 69)

### 3. `platform/observability/logging/loki/clusterlogforwarder.yaml`
**Issues**:
- Wrong API version (deprecated `logging.openshift.io/v1`)
- Missing ServiceAccount
- Missing RBAC permissions

**Fixes**:
- Changed API version to `observability.openshift.io/v1`
- Added ServiceAccount resource (wave 10)
- Added ClusterRoleBinding to `collect-application-logs` ClusterRole
- Added `serviceAccount` field to ClusterLogForwarder spec
- Added `inputs` section with namespace selection
- Removed `kubernetesMetadata` filter (not supported in new API)

### 4. `platform/observability/logging/loki/grafana-datasource-loki.yaml`
**Issues**:
- Wrong URL path
- Missing authentication configuration
- TLS certificate validation issues

**Fixes**:
- Changed URL to internal service: `https://logging-loki-gateway-http.openshift-logging.svc:8080/api/logs/v1/application/`
- Added Bearer token authentication via HTTP headers
- Set `tlsSkipVerify: true` (for self-signed certificates)
- Configured `valuesFrom` to get token from Secret `grafana-loki-token`

### 5. `platform/observability/logging/loki/grafana-loki-sa.yaml` (NEW FILE)
**Issue**: Grafana needs ServiceAccount with proper RBAC to access LokiStack  
**Solution**: Created complete RBAC configuration with:
- ServiceAccount `grafana-loki-reader`
- Secret `grafana-loki-token` (ServiceAccount token)
- ClusterRole `logging-application-logs-reader` (permissions to read application logs)
- ClusterRoleBinding `grafana-loki-auth-delegator` → `system:auth-delegator` (OAuth token validation)
- ClusterRoleBinding `grafana-loki-application-logs-reader` → `logging-application-logs-reader` (log access)
- ClusterRoleBinding `grafana-loki-metrics-view` → `cluster-monitoring-view` (metrics access)

### 6. `docs/IMPLEMENTATION_ORDER.md`
**Changes**:
- Split Step 23b into Steps 23b and 23c (documentation error)
- Updated Step 23f-Loki with complete instructions including ServiceAccount creation
- Added verification steps for RBAC permissions

---

## 🎯 Key Learnings

### 1. LokiStack Authentication
- LokiStack in `openshift-logging` tenant mode uses Observatorium API for multi-tenancy
- Requires proper RBAC permissions for ServiceAccount tokens
- Three ClusterRoleBindings are required:
  - `system:auth-delegator` - OAuth token validation
  - `logging-application-logs-reader` - Log access permissions
  - `cluster-monitoring-view` - Metrics access

### 2. API Version Changes
- OpenShift Logging 6.x uses new API: `observability.openshift.io/v1`
- Old API `logging.openshift.io/v1` is deprecated
- Some fields changed (e.g., `kubernetesMetadata` filter removed)

### 3. Storage Configuration
- Must use correct StorageClass for the cluster
- ODF External Mode uses: `ocs-external-storagecluster-ceph-rbd` for block storage
- ObjectBucketClaim uses: `openshift-storage.noobaa.io` for S3 storage

### 4. Image Registry
- Red Hat registry images may require authentication
- Public Quay.io images work without authentication
- Use `quay.io/openshift/origin-cli:latest` instead of `registry.redhat.io/openshift4/ose-cli:latest`

---

## 📝 Application Order for New Cluster

Follow these steps in order:

```bash
# 1. Apply LokiStack instance (creates Loki components + OBC)
oc apply -f platform/observability/logging/loki/lokistack-instance.yaml

# 2. Wait for OBC to create bucket and secret
oc get obc -n openshift-logging
oc get secret logging-loki-s3 -n openshift-logging

# 3. Apply secret sync job (copies OBC credentials to LokiStack secret)
oc apply -f platform/observability/logging/loki/loki-secret-sync-job.yaml

# 4. Wait for job to complete
oc get job loki-secret-sync -n openshift-logging

# 5. Verify LokiStack components are running
oc get pods -n openshift-logging | grep loki

# 6. Apply ClusterLogForwarder (creates Vector collectors)
oc apply -f platform/observability/logging/loki/clusterlogforwarder.yaml

# 7. Verify Vector collectors are running
oc get pods -n openshift-logging | grep collector

# 8. Create ServiceAccount with RBAC for Grafana
oc apply -f platform/observability/logging/loki/grafana-loki-sa.yaml

# 9. Verify RBAC was created
oc get sa grafana-loki-reader -n openshift-monitoring
oc get secret grafana-loki-token -n openshift-monitoring
oc get clusterrolebinding | grep grafana-loki

# 10. Apply Grafana datasource
oc apply -f platform/observability/logging/loki/grafana-datasource-loki.yaml

# 11. Test in Grafana
# - Login to Grafana (admin/admin)
# - Go to Explore
# - Select "Loki (Redis Logs)" datasource
# - Run query: {kubernetes_namespace_name="redis"}
```

---

## ✅ Success Criteria

- 6 of 7 Loki components running (compactor may be in CrashLoopBackOff - non-critical)
- 6 Vector collector pods running
- Grafana datasource connects successfully
- Logs visible in Grafana Explore

---

## 🚀 Next Steps After Loki

1. Test Splunk implementation (Phase 5.5 - Option B)
2. Commit and push all changes to Git
3. Continue with Phase 6: Performance Testing & Validation

