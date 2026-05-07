# Phase 4: CI/CD - Research

**Researched:** 2026-05-07
**Domain:** GitHub Actions, CI/CD pipelines, EC2 SSH deployment
**Confidence:** HIGH

## Summary

Phase 4 automates the manual deploy workflow from Phases 2-3 using GitHub Actions. The pipeline lints, tests, builds Docker images, pushes to ECR, and deploys to EC2 via SSH. Two environments (staging and production) are deployed from different branches (`develop` and `main` respectively). The learner already has Docker images, Compose files, and ECR repos from Phase 3 -- this phase wires them into an automated pipeline.

The GitHub Actions ecosystem provides official actions for all needed integrations: `aws-actions/configure-aws-credentials@v4` and `aws-actions/amazon-ecr-login@v2` for AWS/ECR auth, `appleboy/ssh-action@v1` for SSH deployment, and `pnpm/action-setup@v4` with `actions/setup-node@v4` for the Node.js build environment. The pipeline will need to add ESLint, Prettier, and a basic test suite to the app (these do not exist yet in `app/package.json`).

**Primary recommendation:** Build a single workflow file with reusable job structure. Use GitHub Environments for environment-specific secrets. The workflow should feel like a direct automation of the manual steps from Phase 3 -- authenticate to ECR, build/push images, SSH in, pull images, run compose up.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Lint (ESLint/Prettier) + unit tests for the API -- no integration tests at this phase
- Build Docker images on PR (verify they build), push to ECR only on merge to deploy branches
- Single workflow file handles both frontend and API services
- Cache node_modules and Docker layers using GitHub Actions cache
- Branch-based deployment: `develop` branch deploys to staging, `main` branch deploys to production
- Use GitHub Environments feature with environment-specific secrets (not prefixed repo secrets)
- Separate AWS resources per environment (different EC2 instances and RDS databases)
- Post-deploy health check: pipeline hits /health endpoint and fails if no response
- Deploy to EC2 via SSH (building on Phase 2-3 knowledge, before Phase 6 introduces ECS)
- SSH into EC2, pull latest images from ECR, run `docker compose up -d`
- SSH private key stored as a GitHub secret
- Run Drizzle database migrations via SSH before restarting containers
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

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEPL-06 | Learner can set up a GitHub Actions pipeline that builds, tests, and deploys on merge | GitHub Actions workflow syntax, official actions for ECR/SSH, pnpm CI setup, lint/test step patterns, Docker build-push patterns |
| DEPL-07 | Learner can configure environment-specific deployments (staging vs production) | GitHub Environments feature, branch-based triggers, environment-scoped secrets, separate AWS resource configs |
</phase_requirements>

## Standard Stack

### Core
| Tool/Action | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| GitHub Actions | N/A (platform) | CI/CD platform | Native to GitHub, zero setup, free for public repos |
| `actions/checkout` | v4 | Clone repo in runner | Official GitHub action |
| `pnpm/action-setup` | v4 | Install pnpm in runner | Official pnpm action, version 10 |
| `actions/setup-node` | v4 | Install Node.js + cache pnpm store | Official, built-in pnpm cache support |
| `aws-actions/configure-aws-credentials` | v4 | Set AWS creds in runner env | Official AWS action |
| `aws-actions/amazon-ecr-login` | v2 | Authenticate Docker to ECR | Official AWS action, v2 masks passwords by default |
| `appleboy/ssh-action` | v1 | Execute commands on EC2 via SSH | Most popular SSH action (10k+ stars), stable |
| ESLint | ^9.0 | JavaScript/TypeScript linting | Industry standard linter |
| Prettier | ^3.0 | Code formatting | Industry standard formatter |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `docker/setup-buildx-action` | Enable BuildKit for layer caching | When using Docker layer caching in CI |
| `actions/cache` | Cache Docker layers between runs | Speeds up image builds on subsequent runs |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `appleboy/ssh-action` | AWS SSM Run Command | SSM avoids opening SSH port but requires SSM agent setup and IAM roles -- overkill for a learning project where SSH is already set up |
| Access key secrets | OIDC with `role-to-assume` | OIDC is more secure (no long-lived credentials) but requires IAM identity provider setup -- can note as production best practice |
| Single workflow file | Reusable workflows / composite actions | Over-engineered for this project's needs, but worth mentioning conceptually |

**Installation (new dev dependencies in app/):**
```bash
cd app
pnpm add -D eslint @eslint/js typescript-eslint prettier eslint-config-prettier
```

## Architecture Patterns

### Project Structure for CI/CD Files
```
.github/
  workflows/
    ci-cd.yml              # Single workflow file (heavily annotated)
app/
  eslint.config.js         # ESLint flat config (v9+)
  .prettierrc              # Prettier configuration
  package.json             # Updated with lint/test/format scripts
docs/
  04-ci-cd/
    guide.md               # Concept guide (triggers, jobs, secrets, environments)
    exercises.md           # Hands-on exercises
    troubleshooting.md     # Common CI/CD pitfalls and fixes
    cheatsheet.md          # Quick reference
```

### Pattern 1: Single Workflow with Branch-Conditional Jobs
**What:** One workflow file triggered on both PR and push events, with jobs that conditionally run based on event type and branch.
**When to use:** Projects with a small number of services where a single file keeps things understandable.

```yaml
name: CI/CD Pipeline

on:
  pull_request:
    branches: [develop, main]
  push:
    branches: [develop, main]

# Cancel in-progress runs for the same branch/PR
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./app
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
          cache-dependency-path: app/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm test

  build-images:
    runs-on: ubuntu-latest
    needs: lint-and-test
    steps:
      - uses: actions/checkout@v4
      - name: Build frontend image
        run: docker build -t ecommerce-frontend ./app
      - name: Build API image
        run: docker build -t ecommerce-api -f ./app/Dockerfile.api ./app

  push-and-deploy:
    if: github.event_name == 'push'  # Only on merge, not PR
    runs-on: ubuntu-latest
    needs: build-images
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
    steps:
      # ... ECR push + SSH deploy steps
```

**Key insight:** The `environment` field dynamically selects staging or production based on branch. Each environment has its own secrets (EC2_HOST, SSH_KEY, etc.).

### Pattern 2: ECR Push with Dual Tagging
**What:** Push Docker images to ECR with both commit SHA and `latest` tags.

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ vars.AWS_REGION }}

- name: Login to Amazon ECR
  id: login-ecr
  uses: aws-actions/amazon-ecr-login@v2

- name: Build, tag, and push images
  env:
    REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    IMAGE_TAG: ${{ github.sha }}
  run: |
    # Frontend
    docker build -t $REGISTRY/ecommerce-frontend:$IMAGE_TAG -t $REGISTRY/ecommerce-frontend:latest ./app
    docker push $REGISTRY/ecommerce-frontend:$IMAGE_TAG
    docker push $REGISTRY/ecommerce-frontend:latest

    # API
    docker build -t $REGISTRY/ecommerce-api:$IMAGE_TAG -t $REGISTRY/ecommerce-api:latest -f ./app/Dockerfile.api ./app
    docker push $REGISTRY/ecommerce-api:$IMAGE_TAG
    docker push $REGISTRY/ecommerce-api:latest
```

### Pattern 3: SSH Deploy with Migration
**What:** SSH into EC2, pull images, run migrations, restart services.

```yaml
- name: Deploy to EC2
  uses: appleboy/ssh-action@v1
  with:
    host: ${{ secrets.EC2_HOST }}
    username: ${{ secrets.EC2_USERNAME }}
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    script: |
      # Authenticate Docker to ECR
      aws ecr get-login-password --region ${{ vars.AWS_REGION }} | \
        docker login --username AWS --password-stdin ${{ steps.login-ecr.outputs.registry }}

      # Pull latest images
      docker pull ${{ steps.login-ecr.outputs.registry }}/ecommerce-frontend:latest
      docker pull ${{ steps.login-ecr.outputs.registry }}/ecommerce-api:latest

      # Run database migrations
      cd /home/${{ secrets.EC2_USERNAME }}/app
      docker compose run --rm api node dist/server/db/migrate.js

      # Restart services with new images
      docker compose up -d --force-recreate

- name: Health check
  run: |
    for i in {1..10}; do
      status=$(curl -s -o /dev/null -w "%{http_code}" http://${{ secrets.EC2_HOST }}/health || true)
      if [ "$status" = "200" ]; then
        echo "Health check passed"
        exit 0
      fi
      echo "Attempt $i: status=$status, retrying in 10s..."
      sleep 10
    done
    echo "Health check failed after 10 attempts"
    exit 1
```

### Pattern 4: GitHub Environments Configuration
**What:** Separate environment-scoped secrets for staging and production.

**Secrets per environment:**
| Secret | Staging | Production |
|--------|---------|------------|
| `EC2_HOST` | Staging EC2 public IP | Prod EC2 public IP |
| `EC2_USERNAME` | ec2-user | ec2-user |
| `SSH_PRIVATE_KEY` | Staging SSH key | Prod SSH key |
| `AWS_ACCESS_KEY_ID` | Shared or separate IAM | Shared or separate IAM |
| `AWS_SECRET_ACCESS_KEY` | Shared or separate IAM | Shared or separate IAM |

**Variables per environment:**
| Variable | Staging | Production |
|----------|---------|------------|
| `AWS_REGION` | ap-southeast-1 | ap-southeast-1 |
| `APP_URL` | staging.example.com | example.com |

**Setup:** Repository Settings > Environments > New Environment. For each environment, add secrets and optionally restrict branches (production: `main` only, staging: `develop` only).

### Anti-Patterns to Avoid
- **Prefixed repo secrets (e.g., STAGING_EC2_HOST, PROD_EC2_HOST):** Use GitHub Environments instead -- same secret name, different values per environment. Cleaner workflow YAML, no `if` conditions for secret selection.
- **Running deploy on PRs:** PRs should only lint, test, and verify builds. Deploy only on push (merge) to deploy branches.
- **Storing docker-compose.yml only in the repo:** The EC2 instance needs the compose file. Either git clone on the server or SCP the file as part of deploy. Since the server already has the app from Phase 2, git pull is the simplest approach.
- **Hardcoding AWS account IDs in workflow:** Use the ECR login action's `registry` output instead.
- **Skipping concurrency control:** Without `concurrency` groups, two rapid merges create parallel deploys that race. Always cancel in-progress runs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AWS credential management in CI | Manual export of env vars | `aws-actions/configure-aws-credentials@v4` | Handles credential masking, expiration, cleanup |
| ECR Docker authentication | Manual `aws ecr get-login-password` in workflow | `aws-actions/amazon-ecr-login@v2` | Masks password by default (v2), outputs registry URL |
| SSH into server | Raw `ssh` command with key file setup | `appleboy/ssh-action@v1` | Handles key formatting, host key verification, timeouts |
| pnpm caching in CI | Manual `actions/cache` with store path | `actions/setup-node@v4` with `cache: 'pnpm'` | Built-in, handles cache key generation from lockfile |
| Node.js version management | Manual nvm install | `actions/setup-node@v4` | Official, handles PATH, caching, version resolution |

**Key insight:** GitHub Actions has a mature ecosystem of official and community actions. Using raw shell commands where actions exist wastes time and misses edge cases (credential masking, proper cleanup, error handling).

## Common Pitfalls

### Pitfall 1: Secrets Not Available in PRs from Forks
**What goes wrong:** Workflow fails with empty secret values when a forked PR triggers it.
**Why it happens:** GitHub does not expose secrets to workflows from forked repos (security measure).
**How to avoid:** For this learning project (single contributor), this is informational only. Document it in the study guide as a real-world consideration.
**Warning signs:** Steps that use `${{ secrets.X }}` silently get empty strings.

### Pitfall 2: pnpm Lockfile Cache Miss in Monorepo
**What goes wrong:** `actions/setup-node` can't find the pnpm lockfile for cache key generation.
**Why it happens:** The project is a monorepo with `pnpm-lock.yaml` at root, but the app code is in `app/`. The `cache-dependency-path` must point to the correct lockfile.
**How to avoid:** Set `cache-dependency-path: app/pnpm-lock.yaml` in the `setup-node` step. However, this project has a root `pnpm-lock.yaml` (pnpm workspaces), so use `pnpm-lock.yaml` (root).
**Warning signs:** Cache restore says "cache not found" on every run.

### Pitfall 3: Docker Build Context in CI
**What goes wrong:** `docker build` fails because the Dockerfile expects files relative to `app/` but the build context is wrong.
**Why it happens:** CI runs from repo root, not `app/`. The build context must be explicitly set.
**How to avoid:** Use `docker build -f ./app/Dockerfile ./app` or `docker build ./app` (if Dockerfile is in app/).
**Warning signs:** `COPY failed: file not found in build context`.

### Pitfall 4: SSH Key Formatting in Secrets
**What goes wrong:** SSH connection fails with "invalid format" or "load key: error".
**Why it happens:** When pasting a private key into GitHub Secrets, trailing newlines or whitespace can be added/removed.
**How to avoid:** Ensure the secret includes the full key including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----` with a trailing newline. Use `cat ~/.ssh/key_name | pbcopy` to copy cleanly.
**Warning signs:** `appleboy/ssh-action` errors mentioning key parsing.

### Pitfall 5: EC2 Security Group Blocks CI Runner
**What goes wrong:** Health check step times out, even though deploy succeeded.
**Why it happens:** The health check runs from the GitHub Actions runner (a GitHub-hosted VM), not from inside the EC2. The security group may only allow specific IPs.
**How to avoid:** Ensure the EC2 security group allows HTTP (port 80) from `0.0.0.0/0`, or use the SSH action to run the health check from within the EC2 itself.
**Warning signs:** Health check always times out but site works when accessed from browser.

### Pitfall 6: docker compose File Not on EC2
**What goes wrong:** SSH deploy step fails because `docker-compose.yml` doesn't exist on the EC2 instance.
**Why it happens:** The compose file is in the git repo but was never transferred to the server.
**How to avoid:** Either (a) git clone/pull the repo on the server as part of deploy, or (b) SCP the compose file. Option (a) is simpler since the server already has the repo from Phase 2.
**Warning signs:** `docker compose` errors about missing file.

### Pitfall 7: Drizzle Migration Fails in CI Deploy
**What goes wrong:** Migration step fails because the migration script can't connect to the database.
**Why it happens:** The migration runs inside a Docker container that needs DATABASE_URL. If running via `docker compose run`, it inherits the compose environment. If running as a bare command, it needs the env var explicitly.
**How to avoid:** Run migrations via `docker compose run --rm api` so the container gets DATABASE_URL from compose's environment config.
**Warning signs:** "connection refused" or "ECONNREFUSED" during migration step.

### Pitfall 8: GitHub Environments Require GitHub Pro for Private Repos
**What goes wrong:** Environment protection rules (required reviewers, branch restrictions) are unavailable.
**Why it happens:** GitHub Environments with protection rules require GitHub Team or GitHub Pro for private repositories. For public repos, all features are free.
**How to avoid:** If the repo is public, no issue. If private, environments still work for grouping secrets -- just without protection rules. For this learning project, environment secrets are the main value, and those work on all plans.
**Warning signs:** Settings > Environments shows limitations or missing options.

## Code Examples

### ESLint Flat Config (eslint.config.js)
```javascript
// eslint.config.js -- ESLint v9 "flat config" format
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ['dist/', 'node_modules/'],
  },
  {
    files: ['src/**/*.ts', 'src/**/*.tsx'],
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
];
```

### Prettier Config (.prettierrc)
```json
{
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "semi": true
}
```

### Updated package.json Scripts (app/package.json additions)
```json
{
  "scripts": {
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix",
    "format": "prettier --check src/",
    "format:fix": "prettier --write src/",
    "test": "echo \"No tests yet\" && exit 0"
  }
}
```

**Note on tests:** The CONTEXT.md says "unit tests for the API." A minimal test setup (e.g., testing a utility function or an API route handler) is sufficient to demonstrate the pipeline catching failures. The `test` script should initially pass (placeholder), then a real test is added as part of the exercises.

### Complete Workflow File Structure (annotated)
```yaml
# .github/workflows/ci-cd.yml
#
# This workflow automates the full build-test-deploy cycle.
# - On PRs: lint, test, and verify Docker images build
# - On push to develop/main: lint, test, build, push to ECR, deploy via SSH
#
name: CI/CD Pipeline

on:
  pull_request:
    branches: [develop, main]
  push:
    branches: [develop, main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ────────────────────────────────────────────
  # Job 1: Lint and test the application code
  # ────────────────────────────────────────────
  lint-and-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./app
    steps:
      - uses: actions/checkout@v4

      - name: Install pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 10

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
          cache-dependency-path: pnpm-lock.yaml

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Format check
        run: pnpm format

      - name: Run tests
        run: pnpm test

  # ────────────────────────────────────────────
  # Job 2: Build Docker images (verify they build)
  # ────────────────────────────────────────────
  build-images:
    runs-on: ubuntu-latest
    needs: lint-and-test
    steps:
      - uses: actions/checkout@v4

      - name: Build frontend image
        run: docker build -t ecommerce-frontend ./app

      - name: Build API image
        run: |
          cd app
          pnpm install --frozen-lockfile
          pnpm build:server
          docker build -t ecommerce-api -f Dockerfile.api .

  # ────────────────────────────────────────────
  # Job 3: Push to ECR and deploy (only on merge)
  # ────────────────────────────────────────────
  push-and-deploy:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    needs: build-images
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push images
        env:
          REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $REGISTRY/ecommerce-frontend:$IMAGE_TAG \
                        -t $REGISTRY/ecommerce-frontend:latest ./app
          docker push $REGISTRY/ecommerce-frontend --all-tags

          cd app && pnpm install --frozen-lockfile && pnpm build:server && cd ..
          docker build -t $REGISTRY/ecommerce-api:$IMAGE_TAG \
                        -t $REGISTRY/ecommerce-api:latest -f ./app/Dockerfile.api ./app
          docker push $REGISTRY/ecommerce-api --all-tags

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USERNAME }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            # Authenticate Docker to ECR on the EC2 instance
            aws ecr get-login-password --region ${{ vars.AWS_REGION }} | \
              docker login --username AWS --password-stdin ${{ steps.login-ecr.outputs.registry }}

            cd ~/app

            # Pull latest images
            docker compose pull

            # Run database migrations
            docker compose run --rm api pnpm db:push

            # Restart with new images
            docker compose up -d --force-recreate --remove-orphans

      - name: Health check
        run: |
          echo "Waiting for deployment to stabilize..."
          sleep 15
          for i in {1..10}; do
            status=$(curl -s -o /dev/null -w "%{http_code}" \
              http://${{ secrets.EC2_HOST }}/health 2>/dev/null || echo "000")
            if [ "$status" = "200" ]; then
              echo "Health check passed (attempt $i)"
              exit 0
            fi
            echo "Attempt $i/10: HTTP $status -- retrying in 10s..."
            sleep 10
          done
          echo "Health check FAILED after 10 attempts"
          exit 1
```

### Health Endpoint (to add to Express API)
```typescript
// src/server/routes/health.ts
import { Router } from 'express';

const router = Router();

router.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

export default router;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Long-lived IAM access keys | OIDC identity provider (no secrets) | 2022+ | AWS recommends OIDC for GitHub Actions; access keys still work and are simpler to learn |
| `docker-compose` v1 in CI | `docker compose` v2 (built-in) | 2023 | CI runners ship with Docker Compose v2 |
| `actions/setup-node` without cache | `cache: 'pnpm'` built-in | 2021+ | Eliminates manual cache setup |
| ESLint `.eslintrc.*` | `eslint.config.js` (flat config) | ESLint v9 (2024) | Old config format is deprecated |
| `pnpm/action-setup` needing version file | `pnpm/action-setup@v4` reads `packageManager` field | 2024 | Can auto-detect pnpm version from package.json |

**Deprecated/outdated:**
- ESLint legacy config (`.eslintrc.js`, `.eslintrc.json`): Deprecated in v9, flat config is the standard
- `aws ecr get-login` (without `-password`): Removed in AWS CLI v2
- `docker-compose` (hyphen): EOL, use `docker compose`

## Open Questions

1. **API Dockerfile needs pre-built `dist/server/`**
   - What we know: From Phase 3 research, the API Dockerfile copies pre-built `dist/server/`. In CI, we need to build TypeScript before Docker build.
   - What's unclear: Whether to add a build step in CI before Docker build, or convert to a multi-stage Dockerfile that builds inside Docker.
   - Recommendation: Add `pnpm build:server` in CI before the Docker build step. Keeps the Dockerfile simple and consistent with Phase 3. The annotated workflow should explain why this extra step is needed.

2. **Compose file on EC2 -- git pull vs SCP**
   - What we know: EC2 already has the app from Phase 2 manual deploy. The compose file needs to be current.
   - What's unclear: Whether to `git pull` on the server or SCP just the compose file.
   - Recommendation: `git pull` on the server. Simpler, ensures all configs are in sync, and the server already has a git clone from Phase 2. Add this as the first SSH step.

3. **Test framework choice**
   - What we know: Need "unit tests for the API" per CONTEXT.md. No test framework exists yet.
   - What's unclear: Which test runner to use.
   - Recommendation: Use Node.js built-in test runner (`node --test`) since Node 20 supports it natively -- no additional dependency. Alternatively, Vitest if learner prefers. Keep it minimal: 1-2 tests that exercise a utility or route handler, enough to demonstrate pipeline failure.

## Sources

### Primary (HIGH confidence)
- [GitHub Actions - Using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) - Environment configuration, secrets, branch restrictions
- [GitHub Actions - Building and testing Node.js](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-nodejs) - Official Node.js CI patterns
- [pnpm - Continuous Integration](https://pnpm.io/continuous-integration) - Official pnpm CI workflow with GitHub Actions
- [aws-actions/amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login) - v2 action, IAM permissions, workflow examples
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) - v4 action, access key and OIDC patterns
- [appleboy/ssh-action](https://github.com/appleboy/ssh-action) - v1 action, input parameters, usage examples

### Secondary (MEDIUM confidence)
- [GitHub Actions pricing and environments for free plan](https://docs.github.com/en/actions/concepts/billing-and-usage) - Environment feature availability on different plans
- [GitHub Actions dependency caching](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) - Cache behavior with pnpm
- [Docker build-push-action](https://github.com/docker/build-push-action) - Docker layer caching patterns in CI

### Tertiary (LOW confidence)
- None -- all findings verified with official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All actions are official (AWS, GitHub, pnpm) or well-established community (appleboy/ssh-action). Versions verified from repos.
- Architecture: HIGH - Single workflow with branch-conditional deploy is a well-documented GitHub Actions pattern. ECR push workflow mirrors Phase 3 manual steps.
- Pitfalls: HIGH - Common CI/CD issues are extensively documented. Project-specific issues (monorepo lockfile path, API pre-build, compose file on EC2) identified from actual project structure.

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (GitHub Actions is stable; action versions rarely break)
