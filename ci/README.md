# CI Validation

This directory contains CI/CD pipeline configurations and validation scripts for the Redis Enterprise GitOps repository.

## Overview

The CI validation ensures that:

1. **YAML syntax is valid** - All YAML files are properly formatted
2. **Kustomize renders successfully** - All overlays can be built without errors
3. **Policy compliance** - Configuration meets security and operational standards
4. **No placeholder values** - Repository URLs and other critical values are configured

## Files

- **`validate.sh`**: Main validation script that runs all checks
- **`yamllint-config.yaml`**: Configuration for YAML linting
- **`.gitlab-ci.yml.example`**: Example GitLab CI/CD pipeline
- **`.github-workflows-ci.yml.example`**: Example GitHub Actions workflow

## Running Validation Locally

### Prerequisites

Install required tools:

```bash
# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Install yamllint (optional)
pip install yamllint
```

### Run Validation

```bash
# Make script executable
chmod +x ci/validate.sh

# Run validation
./ci/validate.sh
```

## CI/CD Integration

### GitLab CI/CD

1. Copy the example pipeline:
   ```bash
   cp ci/.gitlab-ci.yml.example .gitlab-ci.yml
   ```

2. Customize as needed for your environment

3. Commit and push:
   ```bash
   git add .gitlab-ci.yml
   git commit -m "Add GitLab CI pipeline"
   git push
   ```

The pipeline will run automatically on:
- Merge requests
- Commits to main branch

### GitHub Actions

1. Create the workflows directory:
   ```bash
   mkdir -p .github/workflows
   ```

2. Copy the example workflow:
   ```bash
   cp ci/.github-workflows-ci.yml.example .github/workflows/ci.yml
   ```

3. Commit and push:
   ```bash
   git add .github/workflows/ci.yml
   git commit -m "Add GitHub Actions workflow"
   git push
   ```

The workflow will run automatically on:
- Pull requests to main/develop
- Commits to main branch

## Validation Checks

### 1. YAML Linting

Validates YAML syntax and formatting:

```bash
yamllint -c ci/yamllint-config.yaml .
```

**Rules**:
- 2-space indentation
- Max line length: 120 characters
- No trailing spaces
- Newline at end of file

### 2. Kustomize Rendering

Ensures all configurations can be rendered:

```bash
# Single-environment demo
kustomize build orders-redis-dev

# Multi-environment overlays
kustomize build orders-redis/overlays/dev
kustomize build orders-redis/overlays/nonprod
kustomize build orders-redis/overlays/prod
```

### 3. Policy Checks

Validates configuration against policies:

- **Production TLS**: Production databases must have TLS enabled
- **Production Persistence**: Production databases must have persistence enabled
- **Repository URLs**: No placeholder URLs in Argo CD Applications

### 4. Security Scanning (Optional)

Uses tools like `kubesec` to scan for security issues:

```bash
kustomize build orders-redis/overlays/prod | kubesec scan -
```

## Customizing Validation

### Adding Custom Checks

Edit `ci/validate.sh` and add your checks in the appropriate section:

```bash
section "Custom Policy Checks"

# Example: Check for resource limits
if kustomize build orders-redis/overlays/prod | grep -q "limits:"; then
    success "Resource limits are defined"
else
    error "Resource limits must be defined for production"
fi
```

### Adjusting YAML Linting Rules

Edit `ci/yamllint-config.yaml`:

```yaml
rules:
  line-length:
    max: 150  # Increase max line length
```

### Adding OPA/Conftest Policies

1. Create a `policies/` directory
2. Add Rego policy files
3. Update CI pipeline to run conftest

Example policy (`policies/redis.rego`):

```rego
package main

deny[msg] {
  input.kind == "RedisEnterpriseDatabase"
  input.metadata.namespace == "orders-redis-prod"
  input.spec.tlsMode != "enabled"
  msg = "Production databases must have TLS enabled"
}
```

Run with:
```bash
conftest test -p policies/ orders-redis/overlays/prod/
```

## Best Practices

1. **Run validation locally** before pushing changes
2. **Fix all errors** before creating pull requests
3. **Review warnings** - they may indicate configuration issues
4. **Keep validation fast** - CI should complete in < 5 minutes
5. **Use branch protection** - require CI to pass before merging

## Troubleshooting

### Kustomize Build Fails

**Error**: `Error: accumulating resources: accumulation err='accumulating resources from '../../base': ...`

**Solution**: Check that:
- Base path is correct in overlay kustomization.yaml
- All referenced files exist
- YAML syntax is valid

### YAML Linting Fails

**Error**: `line too long (150 > 120 characters)`

**Solution**: Either:
- Break the line into multiple lines
- Adjust the line-length rule in yamllint-config.yaml

### Policy Check Fails

**Error**: `Production databases should have TLS enabled`

**Solution**: Update the production overlay to enable TLS:

```yaml
spec:
  tlsMode: enabled
```

## Integration with Argo CD

The validation script checks for common issues that would prevent Argo CD from syncing:

- Invalid YAML syntax
- Kustomize rendering errors
- Missing required fields
- Placeholder values

**Note**: CI validation does NOT apply changes to the cluster. It only validates that the configuration is correct.

## Next Steps

- Set up branch protection rules requiring CI to pass
- Configure notifications for CI failures
- Add custom policies for your organization
- Integrate with security scanning tools
- Set up automated testing of deployed resources

