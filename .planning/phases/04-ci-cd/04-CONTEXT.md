# Phase 4: CI/CD - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Automate the build-test-deploy cycle using GitHub Actions so that code merged to main reaches production without manual steps. Staging and production environments exist with separate configurations, and the pipeline deploys to the correct one based on branch. A failing test prevents deployment.

</domain>

<decisions>
## Implementation Decisions

### Pipeline stages
- Lint (ESLint/Prettier) + unit tests for the API — no integration tests at this phase
- Build Docker images on PR (verify they build), push to ECR only on merge to deploy branches
- Single workflow file handles both frontend and API services
- Cache node_modules and Docker layers using GitHub Actions cache

### Environment strategy
- Branch-based deployment: `develop` branch deploys to staging, `main` branch deploys to production
- Use GitHub Environments feature with environment-specific secrets (not prefixed repo secrets)
- Separate AWS resources per environment (different EC2 instances and RDS databases)
- Post-deploy health check: pipeline hits /health endpoint and fails if no response

### Deployment target
- Deploy to EC2 via SSH (building on Phase 2-3 knowledge, before Phase 6 introduces ECS)
- SSH into EC2, pull latest images from ECR, run `docker compose up -d`
- SSH private key stored as a GitHub secret
- Run Drizzle database migrations via SSH before restarting containers

### Study materials
- Concept guide explaining GitHub Actions fundamentals (triggers, jobs, steps, secrets, environments)
- Heavily annotated workflow YAML file with inline explanations
- Troubleshooting section covering common CI/CD pitfalls (secret not found, Docker build failures in CI, permissions issues, cache invalidation)
- Brief comparison of GitHub Actions vs Jenkins, GitLab CI, CircleCI
- Hands-on exercises (e.g., intentionally break a test and watch pipeline fail, add a new secret, modify deploy step)

### Claude's Discretion
- Exact caching strategy implementation details
- Workflow job structure and parallelization
- Health check timeout and retry logic
- Exercise difficulty progression

</decisions>

<specifics>
## Specific Ideas

- Pipeline should feel like a natural evolution from the manual EC2 deploy in Phase 2 — "everything you did by hand, now automated"
- The annotated YAML approach mirrors how previous phases used study guides + working config files (Dockerfiles, compose files)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-ci-cd*
*Context gathered: 2026-05-07*
