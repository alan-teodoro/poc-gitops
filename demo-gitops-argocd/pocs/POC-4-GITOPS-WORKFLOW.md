# POC 4: GitOps Workflow Demonstration

## Objective

Demonstrate GitOps methodology using ArgoCD for infrastructure management. This validates the ability to manage Redis Enterprise infrastructure as code with automated synchronization, self-healing, and Git-driven changes.

---

## Test Scenarios

### 1. Deploy Infrastructure via ArgoCD
### 2. Demonstrate Automated Synchronization
### 3. Validate Self-Healing Capabilities
### 4. Execute Git-Driven Infrastructure Changes
### 5. Show Rollback Capabilities

---

## Prerequisites

- OpenShift cluster with ArgoCD installed
- Git repository with infrastructure code
- `oc` and `git` CLI tools configured

---

## GitOps Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      GitOps Workflow                          │
└──────────────────────────────────────────────────────────────┘

    Git Repository (Source of Truth)
           │
           │ (1) ArgoCD monitors Git
           ▼
    ┌──────────────────┐
    │     ArgoCD       │
    │   Controller     │
    └──────────────────┘
           │
           │ (2) Detects changes
           │ (3) Syncs to cluster
           ▼
    ┌──────────────────┐
    │   OpenShift      │
    │   Cluster        │
    │                  │
    │  ┌────────────┐  │
    │  │  Cluster   │  │
    │  └────────────┘  │
    │  ┌────────────┐  │
    │  │  Database  │  │
    │  └────────────┘  │
    └──────────────────┘
           │
           │ (4) Self-healing
           │     (if drift detected)
           ▼
    Desired State = Actual State
```

---

## Step 1: Verify Git Repository Structure

```bash
# Clone repository (if not already cloned)
git clone https://github.com/alan-teodoro/poc-gitops.git
cd poc-gitops/demo-gitops-argocd

# Show repository structure
tree -L 2 > ../evidence/poc4/01-repository-structure.txt

# Display key files
echo "=== ArgoCD Applications ===" >> ../evidence/poc4/01-repository-structure.txt
ls -la argocd-app-*.yaml >> ../evidence/poc4/01-repository-structure.txt

echo "" >> ../evidence/poc4/01-repository-structure.txt
echo "=== Resource Definitions ===" >> ../evidence/poc4/01-repository-structure.txt
ls -la 0*.yaml >> ../evidence/poc4/01-repository-structure.txt

cat ../evidence/poc4/01-repository-structure.txt
```

**Evidence**: Save output to `evidence/poc4/01-repository-structure.txt`

---

## Step 2: Deploy Cluster via ArgoCD

```bash
# Ensure namespace exists
oc get namespace redis-demo || oc create namespace redis-demo

# Apply ArgoCD Application for cluster
oc apply -f argocd-app-cluster.yaml

# Verify Application created
oc get application redis-demo-cluster -n openshift-gitops -o yaml > \
  ../evidence/poc4/02-argocd-application-cluster.yaml

# Watch ArgoCD sync status
oc get application redis-demo-cluster -n openshift-gitops -w
```

**Evidence**: 
- Save Application YAML to `evidence/poc4/02-argocd-application-cluster.yaml`
- Screenshot of ArgoCD UI showing sync progress

**Expected Result**: Application syncs successfully, cluster created

---

## Step 3: Monitor Automated Synchronization

```bash
# Check sync status
argocd app get redis-demo-cluster --refresh > ../evidence/poc4/03-sync-status.txt

# Show resources created by ArgoCD
oc get rec,pods,pvc -n redis-demo -o wide > ../evidence/poc4/03-resources-created.txt

# Display ArgoCD sync history
argocd app history redis-demo-cluster >> ../evidence/poc4/03-sync-status.txt

cat ../evidence/poc4/03-sync-status.txt
```

**Evidence**: Save output to `evidence/poc4/03-sync-status.txt`

**Expected Result**: All resources synced and healthy

---

## Step 4: Demonstrate Self-Healing

```bash
# Manually delete a resource (ArgoCD should recreate it)
echo "=== Testing Self-Healing ===" > ../evidence/poc4/04-self-healing-test.txt
echo "Deleting Redis Enterprise Cluster..." >> ../evidence/poc4/04-self-healing-test.txt

# Delete cluster
oc delete rec demo-cluster -n redis-demo

# Wait 10 seconds
sleep 10

# Check if ArgoCD recreated it
echo "" >> ../evidence/poc4/04-self-healing-test.txt
echo "Checking if ArgoCD recreated cluster..." >> ../evidence/poc4/04-self-healing-test.txt
oc get rec -n redis-demo >> ../evidence/poc4/04-self-healing-test.txt

# Wait for cluster to be recreated
sleep 30

# Verify cluster is back
echo "" >> ../evidence/poc4/04-self-healing-test.txt
echo "Final status:" >> ../evidence/poc4/04-self-healing-test.txt
oc get rec,pods -n redis-demo >> ../evidence/poc4/04-self-healing-test.txt

cat ../evidence/poc4/04-self-healing-test.txt
```

**Evidence**: 
- Save output to `evidence/poc4/04-self-healing-test.txt`
- Screenshot showing ArgoCD detecting drift and resyncing

**Expected Result**: ArgoCD automatically recreates deleted resource

---

## Step 5: Deploy Database via ArgoCD

```bash
# Apply ArgoCD Application for database
oc apply -f argocd-app-databases.yaml

# Verify Application created
oc get application redis-demo-databases -n openshift-gitops -o yaml > \
  ../evidence/poc4/05-argocd-application-database.yaml

# Wait for sync
sleep 30

# Check database status
oc get redb -n redis-demo -o wide > ../evidence/poc4/05-database-status.txt

cat ../evidence/poc4/05-database-status.txt
```

**Evidence**: Save output to `evidence/poc4/05-database-status.txt`

**Expected Result**: Database created and active

---

## Step 6: Git-Driven Infrastructure Change

```bash
# Make a change in Git - increase database memory
cd poc-gitops/demo-gitops-argocd

# Backup original file
cp 02-database-customers.yaml 02-database-customers.yaml.backup

# Change memory size from 100MB to 200MB
sed -i '' 's/memorySize: 100MB/memorySize: 200MB/' 02-database-customers.yaml

# Show diff
git diff 02-database-customers.yaml > ../evidence/poc4/06-git-change-diff.txt

# Commit and push
git add 02-database-customers.yaml
git commit -m "POC4: Increase customers database memory to 200MB"
git push

echo "Change pushed to Git. Waiting for ArgoCD to detect..."
sleep 60

# Check if ArgoCD detected and synced the change
oc get redb customers -n redis-demo -o jsonpath='{.spec.memorySize}' > \
  ../evidence/poc4/06-database-memory-after-change.txt

echo "" >> ../evidence/poc4/06-database-memory-after-change.txt
echo "ArgoCD sync status:" >> ../evidence/poc4/06-database-memory-after-change.txt
argocd app get redis-demo-databases >> ../evidence/poc4/06-database-memory-after-change.txt

cat ../evidence/poc4/06-database-memory-after-change.txt
```

**Evidence**: 
- Save diff to `evidence/poc4/06-git-change-diff.txt`
- Save new memory size to `evidence/poc4/06-database-memory-after-change.txt`
- Screenshot of ArgoCD UI showing automatic sync

**Expected Result**: Database memory updated automatically to 200MB

---

## Step 7: Demonstrate Rollback via Git

```bash
# Rollback the change in Git
cd poc-gitops/demo-gitops-argocd

# Restore original file
cp 02-database-customers.yaml.backup 02-database-customers.yaml

# Show diff
git diff 02-database-customers.yaml > ../evidence/poc4/07-git-rollback-diff.txt

# Commit and push rollback
git add 02-database-customers.yaml
git commit -m "POC4: Rollback database memory to 100MB"
git push

echo "Rollback pushed to Git. Waiting for ArgoCD to detect..."
sleep 60

# Verify rollback
oc get redb customers -n redis-demo -o jsonpath='{.spec.memorySize}' > \
  ../evidence/poc4/07-database-memory-after-rollback.txt

echo "" >> ../evidence/poc4/07-database-memory-after-rollback.txt
echo "ArgoCD sync status:" >> ../evidence/poc4/07-database-memory-after-rollback.txt
argocd app get redis-demo-databases >> ../evidence/poc4/07-database-memory-after-rollback.txt

cat ../evidence/poc4/07-database-memory-after-rollback.txt

# Cleanup backup file
rm 02-database-customers.yaml.backup
```

**Evidence**: Save output to `evidence/poc4/07-database-memory-after-rollback.txt`

**Expected Result**: Database memory rolled back to 100MB automatically

---

## Step 8: Show ArgoCD Application Topology

```bash
# Get application details
argocd app get redis-demo-cluster --show-operation > \
  ../evidence/poc4/08-application-topology.txt

argocd app get redis-demo-databases --show-operation >> \
  ../evidence/poc4/08-application-topology.txt

# List all resources managed by ArgoCD
echo "" >> ../evidence/poc4/08-application-topology.txt
echo "=== All Resources Managed by ArgoCD ===" >> ../evidence/poc4/08-application-topology.txt
oc get all,rec,redb,pvc -n redis-demo -l argocd.argoproj.io/instance >> \
  ../evidence/poc4/08-application-topology.txt

cat ../evidence/poc4/08-application-topology.txt
```

**Evidence**: 
- Save output to `evidence/poc4/08-application-topology.txt`
- Screenshot of ArgoCD UI showing application topology

---

## Success Criteria

- ✅ Infrastructure deployed via ArgoCD Applications
- ✅ Automated synchronization working
- ✅ Self-healing demonstrated (deleted resource recreated)
- ✅ Git-driven change applied automatically
- ✅ Rollback via Git successful
- ✅ All resources managed declaratively

---

## Key GitOps Principles Demonstrated

1. **Declarative**: Infrastructure defined as code in Git
2. **Versioned**: All changes tracked in Git history
3. **Automated**: ArgoCD automatically syncs Git to cluster
4. **Self-Healing**: Drift detection and automatic correction
5. **Auditable**: Complete audit trail in Git commits

---

## Conclusion

This POC demonstrates a complete GitOps workflow using ArgoCD to manage Redis Enterprise infrastructure. All changes are Git-driven, automatically synchronized, and self-healing, providing a robust and auditable infrastructure management approach.

---

**Test Duration**: ~30 minutes  
**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed  
**Tested By**: _________________  
**Date**: _________________

