# Demo Commands - Quick Reference

## 🚀 Deploy the Demo

```bash
# 1. Create the ArgoCD Application
oc apply -f demo-gitops-argocd/argocd-application.yaml

# 2. Watch the application sync
oc get application redis-demo -n openshift-gitops -w

# 3. Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```

## 👀 Monitor Progress

```bash
# Watch namespace creation
oc get namespace redis-demo

# Watch operator installation
oc get pods -n redis-demo -w

# Watch cluster creation
oc get rec -n redis-demo -w

# Watch database creation
oc get redb -n redis-demo -w
```

## 📊 Show Resources

```bash
# Show all resources in the namespace
oc get all -n redis-demo

# Show Redis Enterprise Cluster
oc get rec demo-cluster -n redis-demo -o yaml

# Show databases
oc get redb -n redis-demo

# Show database details
oc describe redb customers -n redis-demo
oc describe redb orders -n redis-demo
```

## 🔐 Get Database Credentials

```bash
# Get customers database password
oc get secret redb-customers -n redis-demo -o jsonpath='{.data.password}' | base64 -d
echo ""

# Get orders database password
oc get secret redb-orders -n redis-demo -o jsonpath='{.data.password}' | base64 -d
echo ""

# Get database service endpoints
oc get svc -n redis-demo | grep redb
```

## 🔌 Connect to Database

```bash
# Get cluster pod name
CLUSTER_POD=$(oc get pods -n redis-demo -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}')

# Get password
CUSTOMERS_PASSWORD=$(oc get secret redb-customers -n redis-demo -o jsonpath='{.data.password}' | base64 -d)

# Connect to customers database
oc exec -it $CLUSTER_POD -n redis-demo -- redis-cli -h redb-customers -a $CUSTOMERS_PASSWORD

# Test commands in redis-cli:
# > SET customer:1 "John Doe"
# > GET customer:1
# > KEYS *
# > INFO
# > exit
```

## 🎯 Demo GitOps - Make a Change

```bash
# 1. Edit the orders database to increase memory
# Change memorySize from 100MB to 200MB in 04-database-orders.yaml

# 2. Commit and push
git add demo-gitops-argocd/04-database-orders.yaml
git commit -m "demo: Increase orders database memory to 200MB"
git push

# 3. Watch ArgoCD detect and sync the change
oc get application redis-demo -n openshift-gitops -w

# 4. Verify the change
oc get redb orders -n redis-demo -o jsonpath='{.spec.memorySize}'
```

## 🔄 Sync Manually (if needed)

```bash
# Trigger manual sync
oc patch application redis-demo -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'

# Or use ArgoCD CLI
argocd app sync redis-demo
```

## 📈 Show ArgoCD Application Status

```bash
# Get application status
oc get application redis-demo -n openshift-gitops -o jsonpath='{.status.sync.status}'
echo ""

# Get health status
oc get application redis-demo -n openshift-gitops -o jsonpath='{.status.health.status}'
echo ""

# Get detailed status
oc describe application redis-demo -n openshift-gitops
```

## 🧪 Test Database Functionality

```bash
# Get cluster pod and password
CLUSTER_POD=$(oc get pods -n redis-demo -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}')
CUSTOMERS_PASSWORD=$(oc get secret redb-customers -n redis-demo -o jsonpath='{.data.password}' | base64 -d)

# Write some test data
oc exec -it $CLUSTER_POD -n redis-demo -- redis-cli -h redb-customers -a $CUSTOMERS_PASSWORD SET customer:1 "John Doe"
oc exec -it $CLUSTER_POD -n redis-demo -- redis-cli -h redb-customers -a $CUSTOMERS_PASSWORD SET customer:2 "Jane Smith"

# Read the data
oc exec -it $CLUSTER_POD -n redis-demo -- redis-cli -h redb-customers -a $CUSTOMERS_PASSWORD GET customer:1
oc exec -it $CLUSTER_POD -n redis-demo -- redis-cli -h redb-customers -a $CUSTOMERS_PASSWORD KEYS "customer:*"
```

## 🧹 Cleanup

```bash
# Option 1: Delete via ArgoCD (recommended)
oc delete application redis-demo -n openshift-gitops

# Option 2: Delete manually
oc delete -f demo-gitops-argocd/04-database-orders.yaml
oc delete -f demo-gitops-argocd/03-database-customers.yaml
oc delete -f demo-gitops-argocd/02-redis-cluster.yaml
oc delete -f demo-gitops-argocd/01-operator-subscription.yaml
oc delete -f demo-gitops-argocd/00-namespace.yaml

# Option 3: Delete namespace (deletes everything)
oc delete namespace redis-demo
```

## 🎓 Key Points to Highlight During Demo

1. **GitOps Principles:**
   - Git is the single source of truth
   - Declarative configuration
   - Automated deployment

2. **Sync Waves:**
   - Wave 0: Namespace (must exist first)
   - Wave 1: Operator (must be installed before cluster)
   - Wave 2: Cluster (must be ready before databases)
   - Wave 3: Databases (created last)

3. **Self-Healing:**
   - If someone manually changes a resource, ArgoCD will revert it
   - Demo: Manually change database memory, watch ArgoCD fix it

4. **Automated Sync:**
   - Changes in Git automatically deploy
   - No manual kubectl/oc commands needed

5. **Visibility:**
   - ArgoCD UI shows the entire application state
   - Easy to see what's deployed and what's out of sync

