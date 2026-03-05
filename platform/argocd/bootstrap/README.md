# Argo CD App-of-Apps Bootstrap

This directory provides a single root `Application` to bootstrap the full Redis platform stack with configurable component toggles.

## Single Apply

```bash
oc apply -f platform/argocd/bootstrap/root-application.yaml
```

This creates `redis-platform-root`, which renders child `Application` objects from the Helm chart at `platform/argocd/bootstrap/chart`.

## Enable/Disable Components

Edit:
- `platform/argocd/bootstrap/chart/values.yaml`

Each component has:
- `enabled: true` to include it
- `enabled: false` to skip it

Example:
```yaml
- id: redis-logging
  name: redis-logging
  enabled: false
```

## Important Bootstrap Order

Core bootstrap components are included with earlier sync waves:
1. `argocd-appprojects` (wave `-2`)
2. `argocd-platform-rbac` (wave `-1`)
3. Remaining platform and cluster/database apps

This avoids manual pre-apply for AppProjects and Argo CD RBAC.

## Notes

- Root app runs in Argo CD `default` project by design (bootstraps AppProjects first).
- Child app repo/revision defaults are set in `chart/values.yaml`.
- Existing standalone app manifests remain available in `platform/argocd/apps/`.
