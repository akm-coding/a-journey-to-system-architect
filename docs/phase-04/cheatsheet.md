# Phase 4: CI/CD -- GitHub Actions Cheatsheet

Quick reference for GitHub Actions workflow syntax, secrets, and common patterns used in this phase.

---

## Workflow Triggers

```yaml
on:
  # Run on pushes to specific branches
  push:
    branches: [main, develop]

  # Run on PRs targeting specific branches
  pull_request:
    branches: [main, develop]

  # Manual trigger from GitHub UI
  workflow_dispatch:

  # Scheduled (cron syntax)
  schedule:
    - cron: '0 6 * * 1'   # Every Monday at 6:00 UTC
```

---

## Job Structure Template

```yaml
jobs:
  job-name:
    runs-on: ubuntu-latest           # Runner OS
    needs: [other-job]               # Run after these jobs pass
    if: github.event_name == 'push'  # Conditional execution
    environment: production          # GitHub Environment (scopes secrets)
    defaults:
      run:
        working-directory: ./app     # Default working dir for run steps
    steps:
      - uses: actions/checkout@v4   # Use an action
      - name: Run a command
        run: echo "Hello"           # Run a shell command
      - name: Multi-line command
        run: |
          echo "Line 1"
          echo "Line 2"
      - name: With environment variables
        env:
          MY_VAR: some-value
        run: echo $MY_VAR
```

---

## Common Actions (Version-Pinned)

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | `@v4` | Clone the repository |
| `actions/setup-node` | `@v4` | Install Node.js with caching |
| `pnpm/action-setup` | `@v4` | Install pnpm |
| `aws-actions/configure-aws-credentials` | `@v4` | Set AWS credentials in runner |
| `aws-actions/amazon-ecr-login` | `@v2` | Authenticate Docker to ECR |
| `appleboy/ssh-action` | `@v1` | Execute commands on remote server via SSH |
| `docker/setup-buildx-action` | `@v3` | Enable Docker BuildKit |
| `actions/cache` | `@v4` | Cache files between runs |

---

## Secrets vs Variables

```yaml
# Secrets: masked in logs, encrypted at rest
${{ secrets.AWS_SECRET_ACCESS_KEY }}
${{ secrets.SSH_PRIVATE_KEY }}

# Variables: visible in logs, plain text
${{ vars.AWS_REGION }}
${{ vars.APP_URL }}
${{ vars.NODE_ENV }}
```

**When to use which:**
- Secrets: passwords, API keys, SSH keys, access tokens -- anything sensitive
- Variables: region names, URLs, feature flags, environment names -- non-sensitive config

---

## Useful Context Variables

```yaml
${{ github.sha }}              # Full commit SHA (e.g., a1b2c3d4e5f6...)
${{ github.ref }}              # Full ref (e.g., refs/heads/main)
${{ github.ref_name }}         # Short ref (e.g., main, develop)
${{ github.event_name }}       # Trigger type: push, pull_request, workflow_dispatch
${{ github.repository }}       # owner/repo (e.g., user/ecommerce-app)
${{ github.actor }}            # Username who triggered the run
${{ github.run_id }}           # Unique ID for this workflow run
${{ github.run_number }}       # Sequential run number for this workflow
${{ github.workspace }}        # Path to repo checkout on runner
```

---

## Common `if` Conditions

```yaml
# Only on push events (not PRs)
if: github.event_name == 'push'

# Only on main branch
if: github.ref == 'refs/heads/main'

# Only on PRs
if: github.event_name == 'pull_request'

# Only when previous job succeeded
if: success()

# Run even if previous job failed
if: always()

# Only if previous job failed
if: failure()

# Combine conditions
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

---

## Concurrency Control

```yaml
# Cancel in-progress runs for the same branch/PR
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This prevents two simultaneous deploys when you push twice in quick succession.

---

## Environment Selection Expression

```yaml
# Dynamically select environment based on branch
environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
```

This is a ternary-style expression: if the branch is `main`, use `production`; otherwise use `staging`.

---

## Docker Build and Push in CI

```yaml
# Build with multiple tags
- name: Build and tag image
  env:
    REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    IMAGE_TAG: ${{ github.sha }}
  run: |
    docker build \
      -t $REGISTRY/ecommerce-frontend:$IMAGE_TAG \
      -t $REGISTRY/ecommerce-frontend:latest \
      ./app

# Push all tags at once
    docker push $REGISTRY/ecommerce-frontend --all-tags
```

---

## Node.js + pnpm Setup

```yaml
- uses: pnpm/action-setup@v4
  with:
    version: 10

- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'pnpm'
    cache-dependency-path: pnpm-lock.yaml   # Root lockfile for monorepo

- run: pnpm install --frozen-lockfile       # Fail if lockfile is outdated
```

---

## SSH Deploy Pattern

```yaml
- name: Deploy via SSH
  uses: appleboy/ssh-action@v1
  with:
    host: ${{ secrets.EC2_HOST }}
    username: ${{ secrets.EC2_USERNAME }}
    key: ${{ secrets.SSH_PRIVATE_KEY }}
    script: |
      cd ~/app
      git pull origin ${{ github.ref_name }}
      docker compose pull
      docker compose up -d --force-recreate --remove-orphans
```

---

## gh CLI Commands for Workflow Management

```bash
# List recent workflow runs
gh run list --workflow=ci-cd.yml --limit=10

# View a specific run (shows jobs and status)
gh run view <run-id>

# Watch a running workflow in real time
gh run watch <run-id>

# Re-run a failed workflow
gh run rerun <run-id>

# Re-run only failed jobs
gh run rerun <run-id> --failed

# View workflow run logs
gh run view <run-id> --log

# List environments
gh api repos/{owner}/{repo}/environments

# Trigger a manual workflow dispatch
gh workflow run ci-cd.yml --ref main
```

---

## Step Outputs (Passing Data Between Steps)

```yaml
- name: Login to ECR
  id: login-ecr                              # Give the step an ID
  uses: aws-actions/amazon-ecr-login@v2

- name: Use the output
  run: echo ${{ steps.login-ecr.outputs.registry }}
  #                ^^^^^^^^^ step ID  ^^^^^^^^ output name
```

---

## Quick Debugging Tips

```yaml
# Print all GitHub context (useful for debugging)
- name: Debug context
  run: echo '${{ toJSON(github) }}'

# Print all environment variables
- name: Debug env
  run: env | sort

# Print secret length (secrets are masked, but you can check they exist)
- name: Check secret exists
  run: |
    if [ -z "${{ secrets.SSH_PRIVATE_KEY }}" ]; then
      echo "SECRET IS EMPTY"
      exit 1
    fi
    echo "Secret is set (length: ${#SSH_KEY})"
  env:
    SSH_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```
