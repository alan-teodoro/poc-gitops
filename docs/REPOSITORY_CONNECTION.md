# Connecting Git Repository to Argo CD

This guide explains how to connect this Git repository to Argo CD on OpenShift.

## Prerequisites

- OpenShift GitOps (Argo CD) installed and running
- Access to Argo CD UI or CLI
- Git repository URL: `https://github.com/alan-teodoro/poc-gitops.git`

## Method 1: Via Argo CD UI (Recommended)

This is the easiest method for beginners.

### Steps

1. **Get Argo CD URL**:
   ```bash
   oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
   ```

2. **Get Admin Password**:
   ```bash
   oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
   ```

3. **Login to Argo CD UI**:
   - Open the URL from step 1 in your browser
   - Username: `admin`
   - Password: from step 2

4. **Connect Repository**:
   - Click **Settings** (⚙️ gear icon in left sidebar)
   - Click **Repositories**
   - Click **+ Connect Repo** button
   - Fill in the form:
     - **Choose your connection method**: `VIA HTTPS`
     - **Type**: `git`
     - **Project**: `default`
     - **Repository URL**: `https://github.com/alan-teodoro/poc-gitops.git`
     - **Username**: (leave empty for public repository)
     - **Password**: (leave empty for public repository)
   - Click **Connect**

5. **Verify Connection**:
   - The repository should appear in the list with status "Successful"
   - Connection status should show a green checkmark ✓

## Method 2: Via Argo CD CLI

For users comfortable with command-line tools.

### Steps

1. **Install Argo CD CLI** (if not already installed):
   ```bash
   # macOS
   brew install argocd
   
   # Linux
   curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
   chmod +x /usr/local/bin/argocd
   ```

2. **Login to Argo CD**:
   ```bash
   argocd login $(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}') \
     --username admin \
     --insecure
   ```
   
   Enter the admin password when prompted.

3. **Add Repository**:
   ```bash
   argocd repo add https://github.com/alan-teodoro/poc-gitops.git
   ```

4. **Verify**:
   ```bash
   argocd repo list
   ```

## Method 3: Via Kubernetes Manifest (GitOps Way)

The most "GitOps" approach - managing Argo CD configuration via Kubernetes manifests.

### Steps

1. **Create Repository Secret**:
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

2. **Verify**:
   ```bash
   oc get secret poc-gitops-repo -n openshift-gitops
   ```

3. **Check in Argo CD UI**:
   - The repository should automatically appear in Settings → Repositories

## For Private Repositories

If your repository is private, you need to provide authentication credentials.

### Option A: Using Personal Access Token (Recommended)

1. **Create GitHub Personal Access Token**:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Give it a name: `argocd-poc-gitops`
   - Select scopes: `repo` (Full control of private repositories)
   - Click "Generate token"
   - **Copy the token** (you won't see it again!)

2. **Add to Argo CD via UI**:
   - Settings → Repositories → + Connect Repo
   - Repository URL: `https://github.com/alan-teodoro/poc-gitops.git`
   - Username: `<your-github-username>`
   - Password: `<paste-your-token>`
   - Click Connect

3. **Or via Manifest**:
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
     username: <your-github-username>
     password: <your-github-token>
   EOF
   ```

### Option B: Using SSH Key

1. **Generate SSH Key**:
   ```bash
   ssh-keygen -t ed25519 -C "argocd@openshift" -f ~/.ssh/argocd_github -N ""
   ```

2. **Add Public Key to GitHub**:
   ```bash
   cat ~/.ssh/argocd_github.pub
   ```
   - Copy the output
   - Go to GitHub → Settings → SSH and GPG keys → New SSH key
   - Paste the public key
   - Click "Add SSH key"

3. **Create Secret in Argo CD**:
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

## Troubleshooting

### Repository Shows "Connection Failed"

**Check 1: Repository URL**
- Ensure the URL is correct
- For HTTPS: `https://github.com/alan-teodoro/poc-gitops.git`
- For SSH: `git@github.com:alan-teodoro/poc-gitops.git`

**Check 2: Authentication**
- For private repos, ensure credentials are correct
- For tokens, ensure they haven't expired
- For SSH keys, ensure the public key is added to GitHub

**Check 3: Network Access**
- Ensure OpenShift cluster can reach GitHub
- Check firewall rules if behind corporate proxy

### Repository Connected but Applications Can't Sync

**Check**: Ensure the repository path in Application manifest is correct:
```yaml
spec:
  source:
    repoURL: https://github.com/alan-teodoro/poc-gitops.git
    targetRevision: main
    path: orders-redis/overlays/dev  # Must match actual path in repo
```

## Next Steps

After connecting the repository:

1. **Grant RBAC Permissions**: See [argocd/README.md](../argocd/README.md#3-configure-rbac-permissions)
2. **Deploy Applications**: See [QUICKSTART.md](../QUICKSTART.md#step-4-deploy-with-argo-cd)
3. **Monitor Deployment**: See [DEPLOYMENT.md](DEPLOYMENT.md)

## References

- [Argo CD Repository Credentials](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/understanding_openshift_gitops/about-redhat-openshift-gitops.html)

