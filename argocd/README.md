# Argo CD Application Manifests

This directory contains Argo CD Application definitions for deploying Redis Enterprise using GitOps with Kustomize overlays.

## Available Applications

All applications use the **Kustomize base + overlays** pattern from `orders-redis/`:

- **`orders-redis-dev-app.yaml`**: Deploys dev environment from `orders-redis/overlays/dev/`
- **`orders-redis-prod-app.yaml`**: Deploys production environment from `orders-redis/overlays/prod/`

### Architecture

- **Cluster**: Deployed in `redis-enterprise` namespace (shared across environments)
- **Databases**: Deployed in environment-specific namespaces (`orders-redis-dev`, `orders-redis-prod`)

Each environment includes:
- 1 Redis Enterprise Cluster (REC)
- 2 Redis Enterprise Databases (REDB): cache and session store

## Before Deploying

### 1. Connect Repository to Argo CD

Before deploying applications, you need to connect this Git repository to Argo CD.

#### Option A: Via Argo CD UI (Recommended for Beginners)

1. **Access Argo CD UI**:
   ```bash
   oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
   ```

2. **Login** with admin credentials

3. **Connect Repository**:
   - Click **Settings** (⚙️) → **Repositories**
   - Click **+ Connect Repo**
   - Fill in:
     - **Method**: `HTTPS`
     - **Type**: `git`
     - **Repository URL**: `https://github.com/alan-teodoro/poc-gitops.git`
     - **Username**: (leave empty for public repo)
     - **Password**: (leave empty for public repo)
   - Click **Connect**

4. **Verify**: Repository should show "Successful" status

#### Option B: Via Argo CD CLI

```bash
# Login to Argo CD
argocd login $(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}') \
  --username admin \
  --insecure

# Add repository
argocd repo add https://github.com/alan-teodoro/poc-gitops.git

# Verify
argocd repo list
```

#### Option C: Via Kubernetes Manifest (GitOps Way)

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: poc-gitops-repo
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/alan-teodoro/poc-gitops.git
EOF
```

Verify the connection:
```bash
oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=repository
```

#### For Private Repositories

If your repository is private, you need authentication:

**Using Personal Access Token**:

1. Create a GitHub Personal Access Token:
   - GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token with `repo` scope
   - Copy the token

2. Add to Argo CD:
   ```bash
   cat <<EOF | oc apply -f -
   apiVersion: v1
   kind: Secret
   metadata:
     name: poc-gitops-repo
     namespace: openshift-gitops
     labels:
       argocd.argoproj.io/secret-type: repository
   stringData:
     type: git
     url: https://github.com/alan-teodoro/poc-gitops.git
     username: <YOUR_GITHUB_USERNAME>
     password: <YOUR_GITHUB_TOKEN>
   EOF
   ```

**Using SSH Key**:

1. Generate SSH key:
   ```bash
   ssh-keygen -t ed25519 -C "argocd@openshift" -f ~/.ssh/argocd_github
   ```

2. Add public key to GitHub:
   ```bash
   cat ~/.ssh/argocd_github.pub
   # Add to GitHub → Settings → SSH and GPG keys → New SSH key
   ```

3. Create secret in Argo CD:
   ```bash
   cat <<EOF | oc apply -f -
   apiVersion: v1
   kind: Secret
   metadata:
     name: poc-gitops-repo-ssh
     namespace: openshift-gitops
     labels:
       argocd.argoproj.io/secret-type: repository
   stringData:
     type: git
     url: git@github.com:alan-teodoro/poc-gitops.git
     sshPrivateKey: |
   $(cat ~/.ssh/argocd_github | sed 's/^/      /')
   EOF
   ```

### 2. Repository Configuration

The Applications are configured to use:

```yaml
spec:
  source:
    repoURL: https://github.com/alan-teodoro/poc-gitops.git
    targetRevision: main
```

If you fork this repository, update the `repoURL` in each Application manifest.

### 3. Configure RBAC Permissions

Grant Argo CD permissions to deploy into the target namespaces:

```bash
# Grant permissions for cluster namespace
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n redis-enterprise

# Grant permissions for each application environment
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n orders-redis-dev

oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n orders-redis-prod
```

## Deployment

Deploy one or more environments as needed:

```bash
# Deploy development environment
oc apply -f orders-redis-dev-app.yaml

# Deploy production environment
oc apply -f orders-redis-prod-app.yaml

# Or deploy all at once
oc apply -f .
```

## Verify Deployment

### Check Application Status

```bash
# List all applications
oc get applications -n openshift-gitops

# Get specific application status
oc get application orders-redis-dev -n openshift-gitops

# Detailed application information
oc describe application orders-redis-dev -n openshift-gitops
```

### View in Argo CD UI

1. Get the Argo CD route:
   ```bash
   oc get route openshift-gitops-server -n openshift-gitops
   ```

2. Get the admin password:
   ```bash
   oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
   ```

3. Log in to the Argo CD UI and view your applications

## Sync Policies

All applications are configured with:

- **Automated sync**: Changes in Git are automatically applied
- **Self-heal**: Manual changes in the cluster are reverted to match Git
- **Prune**: Resources removed from Git are deleted from the cluster
- **CreateNamespace**: Namespaces are created automatically

## Manual Sync

To manually trigger a sync:

```bash
# Using oc
oc patch application orders-redis-dev -n openshift-gitops \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Or use Argo CD CLI
argocd app sync orders-redis-dev
```

## Troubleshooting

### Application Not Syncing

1. **Check application status**:
   ```bash
   oc describe application orders-redis-dev -n openshift-gitops
   ```

2. **Check Argo CD logs**:
   ```bash
   oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
   ```

3. **Verify repository access**:
   - For private repositories, configure credentials in Argo CD
   - Check that the repository URL is correct

### Sync Failures

1. **Check sync status**:
   ```bash
   oc get application orders-redis-dev -n openshift-gitops -o yaml
   ```

2. **View sync errors in Argo CD UI**

3. **Check target namespace**:
   ```bash
   oc get events -n orders-redis-dev --sort-by='.lastTimestamp'
   ```

### Permission Issues

Ensure Argo CD service account has proper permissions:

```bash
oc get rolebinding -n orders-redis-dev | grep gitops
```

## Advanced Configuration

### Custom AppProject

For production, create a custom AppProject with restricted permissions:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: redis-enterprise
  namespace: openshift-gitops
spec:
  description: Redis Enterprise deployments
  sourceRepos:
    - 'https://github.com/alan-teodoro/poc-gitops.git'
  destinations:
    - namespace: 'orders-redis-*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: 'app.redislabs.com'
      kind: '*'
```

Then update the Application to use this project:

```yaml
spec:
  project: redis-enterprise
```

### Sync Waves

For complex deployments, use sync waves to control resource creation order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Lower numbers are applied first.

## Next Steps

- Monitor applications in Argo CD UI
- Set up notifications for sync failures
- Configure webhooks for faster sync detection
- Explore Argo CD ApplicationSets for managing multiple environments

