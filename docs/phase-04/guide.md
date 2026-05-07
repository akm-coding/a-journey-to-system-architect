# Phase 4: CI/CD with GitHub Actions

In Phases 2 and 3, you deployed manually. You SSH'd into EC2, ran `docker compose pull`, restarted services, and hoped everything worked. It did work -- but every deploy required you to be at a keyboard, running commands in the right order, remembering each step.

CI/CD eliminates that. Every time code is merged, the pipeline runs the same steps you ran by hand -- automatically, consistently, and with built-in checks that prevent broken code from reaching production.

This guide covers the concepts behind the pipeline you're about to use: what CI/CD is, how GitHub Actions works, how environments and secrets are managed, and how the pipeline architecture maps to what you already know from Phases 2-3.

---

## What Is CI/CD?

CI/CD is three related ideas on a spectrum from manual to fully automated:

### Continuous Integration (CI)

Every code change is automatically built and tested when pushed. The goal: catch bugs early, before they compound.

Without CI, a developer might break something on Monday, and nobody notices until Friday when another developer pulls their changes and everything explodes. With CI, the breakage is caught within minutes of the push.

**What CI does for this project:**
- Runs ESLint (catches code quality issues)
- Runs Prettier check (catches formatting inconsistencies)
- Runs unit tests (catches broken logic)
- Builds Docker images (catches Dockerfile or dependency issues)

### Continuous Delivery (CD - Delivery)

Code that passes CI is automatically prepared for deployment, but a human clicks the "deploy" button. The artifact (Docker image, compiled binary, etc.) is ready to go at any time.

**What delivery looks like for this project:**
- Docker images are built and pushed to ECR after merge
- A human could choose when to deploy them to EC2

### Continuous Deployment (CD - Deployment)

Code that passes CI is automatically deployed to production with no human intervention. This is the full automation endpoint.

**What deployment looks like for this project:**
- Merge to `main` triggers the full pipeline
- If lint, tests, and Docker build all pass, the pipeline SSHs into EC2 and deploys
- No human clicks needed after the merge

```
Manual Deploy          CI Only           Continuous Delivery    Continuous Deployment
     |                    |                      |                       |
  Developer           Automated              Automated              Automated
  runs every         build + test          build + test           build + test
  step by hand      (catch bugs)          + artifact ready       + auto deploy
                                          (human deploys)        (no human needed)

  Phase 2-3          Most teams            Many teams             This project
  approach           start here            land here              (after Phase 4)
```

Our pipeline implements Continuous Deployment: merge triggers deploy. This is aggressive for a real production app (most teams add manual approval gates), but perfect for a learning project where you're the only developer.

---

## GitHub Actions Fundamentals

GitHub Actions is GitHub's built-in CI/CD platform. Your pipeline is defined in YAML files inside `.github/workflows/`. When an event happens (push, PR, schedule), GitHub spins up a virtual machine (runner), clones your repo, and executes the steps you defined.

### Core Concepts

```
WORKFLOW (ci-cd.yml)
  |
  |-- triggered by EVENTS (push, pull_request)
  |
  |-- contains JOBS (lint-and-test, build-images, push-and-deploy)
        |
        |-- each job runs on a RUNNER (ubuntu-latest VM)
        |
        |-- each job contains STEPS
              |
              |-- steps use ACTIONS (checkout, setup-node)
              |   or run SHELL COMMANDS (pnpm lint, docker build)
```

### Workflows

A workflow is a YAML file in `.github/workflows/`. One repo can have multiple workflows. Each workflow is triggered by specific events and contains one or more jobs.

```yaml
# This is a workflow file
name: CI/CD Pipeline
on: [push, pull_request]  # Triggered by these events
jobs:
  my-job:                  # Contains this job
    runs-on: ubuntu-latest
    steps: [...]
```

### Events and Triggers

Events tell GitHub Actions WHEN to run a workflow. The most common triggers:

| Event | When It Fires | Typical Use |
|-------|---------------|-------------|
| `push` | Code is pushed to a branch | Deploy after merge |
| `pull_request` | PR is opened, updated, or synced | Run checks before merge |
| `workflow_dispatch` | Manual trigger via GitHub UI | Emergency deploys, one-off tasks |
| `schedule` | Cron schedule (e.g., nightly) | Nightly builds, cleanup jobs |

You can filter events by branch:

```yaml
on:
  push:
    branches: [main, develop]      # Only these branches
  pull_request:
    branches: [main, develop]      # Only PRs targeting these branches
```

**Key insight:** `push` to `main` fires when a PR is merged to main (merge creates a push event). It also fires on direct pushes. For our pipeline, both trigger a deploy -- which is fine because `main` should be protected (requiring PR reviews).

### Jobs

Jobs are independent units of work. Each job runs on its own fresh virtual machine. Jobs run in parallel by default, but you can create dependencies:

```yaml
jobs:
  lint-and-test:           # Runs first (no dependencies)
    runs-on: ubuntu-latest

  build-images:
    needs: lint-and-test   # Waits for lint-and-test to pass

  push-and-deploy:
    needs: build-images    # Waits for build-images to pass
    if: github.event_name == 'push'  # Only on merge, not PR
```

The `needs` keyword creates a dependency chain. If `lint-and-test` fails, `build-images` is skipped. If `build-images` fails, `push-and-deploy` is skipped. This is "fail fast" -- don't waste time on later steps if early checks failed.

The `if` condition adds further control. `push-and-deploy` only runs on push events (merges), never on pull requests.

### Steps

Steps are individual commands within a job. They run sequentially in the order defined. There are two types:

**Action steps** use pre-built actions from the GitHub marketplace:
```yaml
- uses: actions/checkout@v4          # Clone the repo
- uses: actions/setup-node@v4       # Install Node.js
  with:
    node-version: 20                 # Configure the action
```

**Run steps** execute shell commands:
```yaml
- run: pnpm install --frozen-lockfile
- run: pnpm lint
- name: Build server           # Optional name for readability
  run: pnpm build:server
```

### Runners

Runners are the virtual machines where jobs execute. GitHub provides hosted runners (free for public repos):

| Runner | OS | Common Use |
|--------|----|------------|
| `ubuntu-latest` | Ubuntu Linux | Most CI/CD jobs |
| `macos-latest` | macOS | iOS/macOS builds |
| `windows-latest` | Windows | Windows-specific builds |

Each job starts with a clean VM. Nothing persists between jobs unless you explicitly pass artifacts or use caching.

---

## Secrets and Environments

Your pipeline needs sensitive values: AWS credentials, SSH keys, EC2 IP addresses. These must never be in your code. GitHub provides two mechanisms for managing them.

### Repository Secrets

Secrets stored at the repository level, available to all workflows. You set them in Settings > Secrets and variables > Actions.

```yaml
# Referencing a repository secret
- run: echo "Deploying to ${{ secrets.EC2_HOST }}"
```

Secrets are masked in logs. If the value appears in output, GitHub replaces it with `***`.

### GitHub Environments

Environments group secrets by deployment target. Instead of `STAGING_EC2_HOST` and `PROD_EC2_HOST`, you create two environments -- each with an `EC2_HOST` secret that has a different value.

```
Repository
  |
  |-- Environment: staging
  |     EC2_HOST = 54.123.45.67
  |     SSH_PRIVATE_KEY = (staging key)
  |     AWS_ACCESS_KEY_ID = AKIA...
  |
  |-- Environment: production
        EC2_HOST = 13.234.56.78
        SSH_PRIVATE_KEY = (production key)
        AWS_ACCESS_KEY_ID = AKIA...
```

In the workflow, you select the environment dynamically:

```yaml
push-and-deploy:
  environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
```

This expression evaluates to `"production"` when the push is to `main`, and `"staging"` for any other branch (i.e., `develop`). The same workflow YAML, the same secret names, but different values depending on which branch triggered it.

### Secrets Needed Per Environment

| Secret / Variable | Description | Same or Different? |
|--------------------|-------------|-------------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key | Could be shared or separate |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key | Could be shared or separate |
| `EC2_HOST` | EC2 instance public IP or DNS | Different (separate instances) |
| `EC2_USERNAME` | SSH username (e.g., `ec2-user`) | Usually same |
| `SSH_PRIVATE_KEY` | SSH private key for EC2 access | Different (separate keys) |
| `AWS_REGION` (variable) | AWS region (e.g., `ap-southeast-1`) | Usually same |

**Setup steps:**
1. Go to Repository Settings > Environments > New Environment
2. Create "staging" and "production"
3. Add secrets to each environment
4. Optionally restrict branches (production: only `main`, staging: only `develop`)

### Why Environments Are Better Than Prefixed Secrets

Without environments:
```yaml
# Messy -- secret names leak environment info into the workflow
- run: |
    if [ "${{ github.ref }}" = "refs/heads/main" ]; then
      HOST="${{ secrets.PROD_EC2_HOST }}"
    else
      HOST="${{ secrets.STAGING_EC2_HOST }}"
    fi
```

With environments:
```yaml
# Clean -- same secret name, different value per environment
environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
steps:
  - run: echo "Deploying to ${{ secrets.EC2_HOST }}"
```

The workflow code is simpler, and adding a new environment (e.g., "qa") only requires creating the environment and its secrets -- no workflow YAML changes.

---

## The Pipeline Architecture

Our pipeline has three jobs that run in sequence:

```
                    +-----------------+
  push/PR -------->| lint-and-test   |
                    | (ESLint,        |
                    |  Prettier,      |
                    |  unit tests)    |
                    +--------+--------+
                             |
                             | passes
                             v
                    +--------+--------+
                    | build-images    |
                    | (Docker build   |
                    |  frontend + API)|
                    +--------+--------+
                             |
                             | passes
                             v
                    +--------+--------+
             +----->| push-and-deploy |<-- Only on push (merge)
             |      | (ECR push,      |    Skipped on PRs
             |      |  SSH deploy,    |
             |      |  health check)  |
             |      +-----------------+
             |
   if: github.event_name == 'push'
```

### Job 1: lint-and-test

**Purpose:** Fast feedback on code quality. Runs in ~30-60 seconds.

Steps:
1. Checkout code
2. Install pnpm and Node.js (with cache)
3. `pnpm install --frozen-lockfile` (deterministic install)
4. `pnpm lint` (ESLint)
5. `pnpm format` (Prettier check)
6. `pnpm test` (unit tests)

If any step fails, the entire pipeline stops. The developer sees which check failed in the PR.

### Job 2: build-images

**Purpose:** Verify Docker images build successfully. Catches Dockerfile issues, missing files, broken multi-stage builds.

**Why this matters:** You might change a file path in your code, and the Dockerfile's `COPY` command breaks. Without this job, you'd only discover it when trying to deploy.

**The API pre-build quirk:** The API Dockerfile (`Dockerfile.api`) expects `dist/server/` to already exist (pre-compiled TypeScript). So the CI job must run `pnpm build:server` before `docker build`. This is a design choice from Phase 3 -- it keeps the Docker image smaller but adds a CI step.

### Job 3: push-and-deploy

**Purpose:** Get the new code running on the server. Only runs on merge (push events).

**The `if` condition:** `if: github.event_name == 'push'` ensures this job is skipped entirely on pull requests. PRs should only verify -- never deploy.

**Dual tagging:** Images are tagged with both the commit SHA (for traceability) and `latest` (for convenience):
```
ecommerce-frontend:a1b2c3d    # Which commit produced this image?
ecommerce-frontend:latest      # docker compose pull gets this by default
```

**SSH deploy sequence:** The same steps you ran manually in Phase 2-3:
1. Authenticate Docker to ECR on the EC2 instance
2. `git pull` to sync the compose file and configs
3. `docker compose pull` to download new images
4. `docker compose run --rm api pnpm db:push` to run database migrations
5. `docker compose up -d --force-recreate --remove-orphans` to restart services

**Why `git pull`?** The EC2 instance already has the repo cloned from Phase 2. Pulling ensures the compose file and any config changes are current. Without it, you might push a new Docker image but the EC2 still has an old compose file that references different service names or ports.

---

## Caching in CI

Without caching, every pipeline run downloads all dependencies from scratch. For this project, that means ~200MB of npm packages every single time. Caching stores those packages between runs.

### pnpm Store Cache

The `actions/setup-node` action has built-in pnpm cache support:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'pnpm'
    cache-dependency-path: pnpm-lock.yaml
```

How it works:
1. On first run: no cache exists. pnpm downloads everything. After the job, the pnpm store is saved to GitHub's cache.
2. On subsequent runs: the cache is restored before `pnpm install`. pnpm links packages from the store instead of downloading them. Install takes seconds instead of minutes.
3. When the lockfile changes: the cache key changes (it's based on the lockfile hash), so a fresh download happens. This ensures you never use stale packages.

### Docker Layer Cache

Docker images are built in layers. If a layer hasn't changed, Docker reuses the cached version. In CI, each job starts with a clean VM, so there's no local Docker cache.

For this project, we don't implement Docker layer caching in CI. The builds are fast enough (~1-2 minutes) that the complexity isn't worth it. For large projects, you'd use `docker/build-push-action` with `cache-from` and `cache-to` to persist layers between runs.

---

## Deploy Strategy: SSH Pull

Our deploy strategy is "SSH pull" -- the CI runner SSHs into EC2 and tells it to pull new images and restart.

```
GitHub Actions Runner                     EC2 Instance
      |                                        |
      |-- SSH connect -----------------------> |
      |                                        |
      |   "docker compose pull"                |
      |                                        |-- pulls images from ECR
      |                                        |
      |   "docker compose up -d"               |
      |                                        |-- restarts containers
      |                                        |
      |<-- exit ----------------------------- |
      |                                        |
      |-- curl /health ----------------------> |
      |<-- 200 OK  <------------------------- |
```

### Why SSH for This Phase

The SSH approach builds directly on what you learned in Phases 2-3. You already:
- Have an EC2 instance with SSH access
- Have Docker and Docker Compose installed
- Have the app repo cloned on the instance
- Know how to SSH in and run commands

The pipeline simply automates those same SSH commands. It's the most natural evolution from manual deploy.

### What Comes Next (Phase 6: ECS)

In Phase 6, you'll replace the SSH deploy with ECS (Elastic Container Service). Instead of managing an EC2 instance yourself, you'll tell AWS "run this container image" and ECS handles the rest:
- No SSH needed
- No `docker compose` on a server
- AWS manages container health, restarts, and scaling
- The pipeline just updates the ECS task definition and triggers a deployment

The SSH approach is a stepping stone. Understanding it makes ECS's value proposition clear: "Why am I managing Docker on a server when AWS can do it for me?"

---

## Health Checks

A health check verifies that your application is actually running after deployment. It's the difference between "the deploy command succeeded" and "the app is serving traffic."

### Why Health Checks Matter

Without a health check:
```
1. Pipeline pushes new Docker image
2. Pipeline SSHs in, runs docker compose up
3. Containers start (exit code 0 -- "success!")
4. App crashes 2 seconds later (bad config, missing env var)
5. Pipeline reports: "Deploy successful"
6. Users see: 502 Bad Gateway
7. Nobody knows until a user complains
```

With a health check:
```
1. Pipeline pushes new Docker image
2. Pipeline SSHs in, runs docker compose up
3. Containers start
4. App crashes 2 seconds later
5. Health check: /health returns 503... retrying...
6. After 10 retries: "Health check FAILED"
7. Pipeline reports: "Deploy failed"
8. Team is alerted immediately
```

### The /health Endpoint

Our API exposes a simple health endpoint:

```typescript
router.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
  });
});
```

This is a "shallow" health check -- it confirms the Express server is running and can respond to HTTP requests. A "deep" health check would also verify database connectivity, Redis connection, etc. Shallow is sufficient for our needs.

### Retry Logic

The health check in the pipeline retries 10 times, 10 seconds apart, after an initial 15-second wait:

```
t=0s    Deploy completes
t=15s   First health check attempt
t=25s   Second attempt (if first failed)
...
t=105s  Tenth attempt (if all failed)
t=105s  Pipeline fails
```

This gives the application up to ~2 minutes to start. If it's not healthy by then, something is wrong.

---

## CI/CD Tool Comparison

GitHub Actions isn't the only CI/CD tool. Here's how it compares:

| Feature | GitHub Actions | Jenkins | GitLab CI | CircleCI |
|---------|---------------|---------|-----------|----------|
| **Hosting** | Cloud (GitHub) | Self-hosted (typically) | Cloud or self-hosted | Cloud |
| **Config** | YAML in `.github/workflows/` | Groovy Jenkinsfile | YAML in `.gitlab-ci.yml` | YAML in `.circleci/config.yml` |
| **Marketplace** | 15,000+ actions | 1,800+ plugins | Templates + includes | Orbs marketplace |
| **Free tier** | 2,000 min/month (public: unlimited) | Free (self-hosted) | 400 min/month | 6,000 min/month |
| **Learning curve** | Low | High | Medium | Low |
| **GitHub integration** | Native (same platform) | Plugin-based | Separate platform | OAuth integration |
| **Strengths** | Native GitHub integration, huge marketplace, easy setup | Extremely flexible, any environment | Built-in container registry, security scanning | Fast execution, good caching |
| **Weaknesses** | Vendor lock-in to GitHub, YAML complexity at scale | Complex setup, maintenance burden | Tied to GitLab platform | Less marketplace variety |

### Why GitHub Actions for This Project

1. **Native integration:** Our code is on GitHub. No external service to set up, no webhooks to configure, no OAuth to manage.
2. **Free for public repos:** Unlimited minutes for public repositories. Even private repos get 2,000 free minutes/month.
3. **Official AWS actions:** `aws-actions/configure-aws-credentials` and `aws-actions/amazon-ecr-login` are maintained by AWS. They handle edge cases (credential masking, cleanup) that you'd miss writing raw shell commands.
4. **Industry standard:** GitHub Actions is the most popular CI/CD tool for open-source projects. Understanding it transfers to most development teams.

---

## Production Best Practices

These are things to know for real projects. We don't implement them in this learning project, but understanding them is important for interviews and production work.

### OIDC Instead of Access Keys

Our pipeline uses IAM access keys (`AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`) stored as GitHub secrets. These are long-lived credentials -- if leaked, an attacker has AWS access until you rotate them.

The production alternative is OIDC (OpenID Connect):
```yaml
# Production approach (not used in this project)
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    aws-region: us-east-1
```

With OIDC, GitHub Actions gets temporary credentials (valid for ~1 hour) by assuming an IAM role. No secrets stored in GitHub at all. AWS trusts GitHub as an identity provider and issues short-lived tokens.

**Why we don't use it here:** Setting up the IAM identity provider and role requires more AWS configuration. Access keys are simpler to learn and sufficient for a learning project.

### Branch Protection Rules

In a real project, you'd protect `main` and `develop`:
- Require pull request reviews before merge
- Require status checks to pass (lint-and-test, build-images)
- Prevent direct pushes to protected branches
- Require linear history (no merge commits)

This ensures that no code reaches `main` without being reviewed and passing CI.

### Required Status Checks

You can require specific workflow jobs to pass before a PR can be merged:

```
Settings > Branches > Branch protection rule > Require status checks
  [x] lint-and-test
  [x] build-images
```

With this enabled, the "Merge" button is disabled until both jobs pass. This is the enforcement mechanism for CI -- it's not just informational, it actually prevents broken code from being merged.

### Deployment Approvals

For the production environment, you can require manual approval:

```
Settings > Environments > production > Protection rules
  [x] Required reviewers: @team-lead
```

With this enabled, the pipeline runs lint-and-test and build-images automatically, but pauses before push-and-deploy. A designated reviewer must click "Approve" in the GitHub UI before the deploy proceeds. This turns Continuous Deployment back into Continuous Delivery for production, while keeping staging fully automated.

### Rollback Strategy

Our current pipeline has no rollback mechanism. If a bad deploy goes out, you'd need to:
1. Revert the commit (creates a new commit that undoes the changes)
2. Push the revert (triggers the pipeline again)
3. Wait for the pipeline to redeploy

A more sophisticated approach would keep the previous Docker image tags and have a rollback workflow that redeploys the previous tag. This is something ECS handles more gracefully in Phase 6.

---

## Key Takeaways

1. **CI/CD is automation of what you already know.** Every step in the pipeline maps to something you did manually in Phases 2-3.

2. **Fail fast.** Lint and test before building. Build before deploying. Each gate prevents wasting time on later steps if earlier ones fail.

3. **Environments are the key to multi-target deployment.** Same workflow, same secret names, different values. Branch determines environment.

4. **Health checks close the feedback loop.** Without them, "deploy succeeded" just means "the script ran" -- not "the app works."

5. **Start simple, evolve.** SSH deploy is good enough for now. It builds understanding that makes ECS (Phase 6) intuitive rather than magical.
