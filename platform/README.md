# Platform Modules

This directory contains platform-level modules managed by Argo CD.

Canonical deployment flow: `docs/ARGOCD_IMPLEMENTATION_GUIDE.md`

## Modules

- `argocd/`: AppProjects, Application manifests, bootstrap components
- `quotas/`: ResourceQuota and LimitRange templates
- `security/network-policies/`: Optional network policy baseline
- `observability/`: Prometheus rules, Grafana, logging integrations
- `high-availability/`: PodDisruptionBudgets and anti-affinity helpers
- `testing/`: memtier test scenarios for validation and baselines

## Suggested Test-Day Order

1. Deploy/validate platform apps from `platform/argocd/apps/`.
2. Validate policies/quotas/network controls.
3. Validate observability/logging modules that are enabled.
4. Run performance smoke tests from `platform/testing/test-scenarios/`.

Use: `platform/testing/TEST_RUNBOOK.md` for the complete command sequence.
