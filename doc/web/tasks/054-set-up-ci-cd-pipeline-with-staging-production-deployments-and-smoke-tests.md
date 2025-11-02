# Set up CI/CD pipeline with staging/production deployments and smoke tests.

**Parent Section:** 10. Deployment & Maintenance
**Task ID:** #054

## Goal
Build CI/CD pipeline for staging and production.

## Implementation Steps
1. Create pipeline with lint/test/build steps and deploy to staging.
2. Gate production deploy with approval and run smoke tests.
3. Provide rollback commands and documentation.

## Completion Notes (2025-02-14)
- Added `.github/workflows/web.yml` with `checks`, `deploy-staging`, and `deploy-production` jobs (GitHub Actions).
- Staging deploy runs automatically on `main`, production deploy is gated by the GitHub `production` environment, and both hit `/healthz` smoke probes.
- Deployment artifacts capture previous revisions for rollback; operational handbook documented in `doc/web/ci_cd.md`.
