# Phase 4: CI/CD -- Phase Gate Checklist

Complete both checkpoints before moving to Phase 5. Each checkpoint maps to a requirement and has a "Prove It" section with commands and verification steps.

---

## Checkpoint 1: CI/CD Pipeline (DEPL-06)

**Requirement:** Learner can set up a GitHub Actions pipeline that builds, tests, and deploys on merge.

### Knowledge Check

- [ ] Can you explain the 3-job pipeline structure (lint-and-test, build-images, push-and-deploy)?
- [ ] Can you describe what the `needs` keyword does and why job ordering matters?
- [ ] Can you explain what `if: github.event_name == 'push'` prevents?
- [ ] Can you describe the difference between a PR workflow run and a push workflow run?
- [ ] Can you explain why `--frozen-lockfile` is used in CI but not in local development?
- [ ] Can you describe the concurrency group pattern and why it matters for deployments?

### Prove It

```bash
# 1. Show recent pipeline runs (at least one successful)
gh run list --workflow=ci-cd.yml --limit=5
# Expected: At least one run with status "completed" and conclusion "success"

# 2. View a successful run -- all jobs should show as passed
gh run view <run-id>
# Expected: lint-and-test (pass), build-images (pass), push-and-deploy (pass)

# 3. Show a failed run where a test failure blocked deployment
gh run list --workflow=ci-cd.yml --status=failure --limit=3
# Then view the failed run:
gh run view <failed-run-id>
# Expected: lint-and-test (fail), build-images (skipped), push-and-deploy (skipped)
# This proves the pipeline catches failures before they reach any server

# 4. Verify the workflow file exists and has the correct structure
cat .github/workflows/ci-cd.yml | head -20
# Expected: Shows the workflow name, trigger configuration, and concurrency group

# 5. Verify lint and test scripts work locally
cd app
pnpm lint && echo "Lint: PASS" || echo "Lint: FAIL"
pnpm test && echo "Test: PASS" || echo "Test: FAIL"
```

### Pass Criteria

- [ ] At least one fully successful pipeline run exists (all 3 jobs green)
- [ ] At least one failed run shows build-images and push-and-deploy as SKIPPED (not failed)
- [ ] The workflow file has 3 jobs with correct `needs` dependencies
- [ ] Lint and test pass locally
- [ ] You can explain the pipeline structure and why a failing test blocks deployment

---

## Checkpoint 2: Environment-Specific Deployments (DEPL-07)

**Requirement:** Learner can configure environment-specific deployments (staging vs production).

### Knowledge Check

- [ ] Can you explain what a GitHub Environment is and how it scopes secrets?
- [ ] Can you describe how the workflow selects staging vs production (`github.ref == 'refs/heads/main' && 'production' || 'staging'`)?
- [ ] Can you explain why environment-scoped secrets are better than prefixed repo secrets (e.g., `STAGING_EC2_HOST` vs `EC2_HOST` per environment)?
- [ ] Can you describe the promotion workflow: develop -> PR -> main?
- [ ] Can you explain what would happen if you pushed directly to `main` without merging from `develop`?

### Prove It

```bash
# 1. List configured environments
gh api repos/{owner}/{repo}/environments --jq '.environments[].name'
# Expected output:
#   staging
#   production

# 2. Show a staging deployment (triggered from develop branch)
gh run list --workflow=ci-cd.yml --branch=develop --limit=3
# View one of the runs:
gh run view <staging-run-id>
# Expected: push-and-deploy job shows "environment: staging"

# 3. Show a production deployment (triggered from main branch)
gh run list --workflow=ci-cd.yml --branch=main --limit=3
# View one of the runs:
gh run view <production-run-id>
# Expected: push-and-deploy job shows "environment: production"

# 4. Verify different servers for each environment
curl -s http://<staging-ec2-ip>/health | jq .
# Expected: {"status":"ok","timestamp":"..."}

curl -s http://<production-ec2-ip>/health | jq .
# Expected: {"status":"ok","timestamp":"..."} (different server)

# 5. Verify the environment selection expression in the workflow
grep -A1 "environment:" .github/workflows/ci-cd.yml
# Expected: environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
```

### Pass Criteria

- [ ] Both `staging` and `production` environments are configured in GitHub
- [ ] A deployment to staging exists (from `develop` branch)
- [ ] A deployment to production exists (from `main` branch)
- [ ] Both staging and production servers respond to health checks (different IPs)
- [ ] The workflow uses dynamic environment selection based on branch
- [ ] You can explain the promotion workflow and why environment-scoped secrets are better

---

## Summary

When both checkpoints pass, you have demonstrated:

1. **DEPL-06:** A working CI/CD pipeline that automatically builds, tests, and deploys your application. A failing test prevents deployment -- the safety net is real.

2. **DEPL-07:** Environment-specific deployments where the same pipeline deploys to staging (from `develop`) or production (from `main`) using GitHub Environments for secret scoping.

You are ready for Phase 5: Infrastructure as Code with Terraform.
