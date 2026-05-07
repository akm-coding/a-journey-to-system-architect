# Phase 4: CI/CD -- Overview

## What You Learned

Phase 4 automates the entire build-test-deploy cycle using GitHub Actions. Everything you did manually in Phases 2 and 3 -- SSHing into an EC2 instance, building Docker images, pushing to ECR, running `docker compose up` -- is now triggered automatically when you push code or merge a pull request.

You learned:
- How GitHub Actions workflows are structured (triggers, jobs, steps)
- How to lint, test, and build in CI before any deployment happens
- How to push Docker images to ECR from a pipeline
- How to deploy to EC2 via SSH from a GitHub Actions runner
- How to use GitHub Environments for staging vs production deployments
- How a failing test prevents broken code from reaching any server

---

## Architecture

```
                        GitHub Repository
                              |
                    push / pull_request
                              |
                              v
                    +-------------------+
                    |  GitHub Actions   |
                    |  CI/CD Pipeline   |
                    +-------------------+
                              |
              +---------------+---------------+
              |               |               |
              v               v               v
       +-----------+   +-----------+   +----------------+
       | Job 1:    |   | Job 2:    |   | Job 3:         |
       | Lint &    |-->| Build     |-->| Push to ECR &  |
       | Test      |   | Images    |   | Deploy via SSH |
       +-----------+   +-----------+   +----------------+
                                              |
                                    +---------+---------+
                                    |                   |
                                    v                   v
                            +-------------+     +-------------+
                            |   Staging   |     | Production  |
                            |   EC2       |     | EC2         |
                            | (develop)   |     | (main)      |
                            +-------------+     +-------------+
                                    |                   |
                                    v                   v
                            +-------------+     +-------------+
                            |  ECR Images |     |  ECR Images |
                            |  (latest)   |     |  (latest)   |
                            +-------------+     +-------------+
```

### Pipeline Flow

**On Pull Request (lint + test + build verification only):**

```
PR opened/updated
    |
    v
lint-and-test -----> build-images -----> push-and-deploy
  (runs)              (runs)              (SKIPPED)
  pnpm lint           docker build        Not triggered
  pnpm format         (verify only)       because event is
  pnpm test                               pull_request
```

**On Push/Merge (full pipeline with deployment):**

```
Push to develop or main
    |
    v
lint-and-test -----> build-images -----> push-and-deploy
  (runs)              (runs)              (runs)
  pnpm lint           docker build        ECR login
  pnpm format                             docker push
  pnpm test                               SSH deploy
                                          health check
                                              |
                                    Branch == main?
                                    Yes: production env
                                    No:  staging env
```

---

## Study Order

Work through the Phase 4 materials in this order:

| # | Document | Purpose | Time |
|---|----------|---------|------|
| 1 | `guide.md` | Understand GitHub Actions concepts (triggers, jobs, secrets, environments) | 30 min |
| 2 | `.github/workflows/ci-cd.yml` | Read the annotated workflow file line by line | 20 min |
| 3 | `exercises.md` | Hands-on practice: set up environments, trigger runs, break tests, deploy | 2-3 hours |
| 4 | `troubleshooting.md` | Reference when something goes wrong (8 common pitfalls) | As needed |
| 5 | `cheatsheet.md` | Quick-reference while writing or modifying workflows | As needed |

The guide teaches the concepts, the workflow file shows a real implementation, and the exercises have you interact with the running pipeline. The troubleshooting guide and cheatsheet are reference materials you return to.

---

## Connection to Previous Phases

### Phase 2: First Deploy (Manual)
In Phase 2, you deployed by SSHing into an EC2 instance, cloning the repo, installing dependencies, and starting the app with PM2. Every deployment required manual SSH access and running commands by hand.

**Phase 4 automates this:** The pipeline SSHs into EC2 for you, pulls the latest code and images, and restarts services. You never touch the server directly for routine deployments.

### Phase 3: Containerization (Docker + ECR)
In Phase 3, you containerized the app with Docker, composed the multi-service stack with Docker Compose, and manually pushed images to ECR using shell commands.

**Phase 4 automates this:** The pipeline builds Docker images, tags them with the commit SHA, pushes them to ECR, and runs `docker compose up` on the target server. The manual `aws ecr get-login-password | docker login` and `docker push` commands are now workflow steps.

### The Evolution

```
Phase 2: You SSH in, you install, you start         (fully manual)
Phase 3: You build images, you push to ECR           (manual with containers)
Phase 4: Pipeline builds, pushes, deploys for you    (automated)
Phase 5: Terraform creates the infrastructure itself  (infrastructure as code)
```

---

## What Phase 5 Builds On Top of This

Phase 5 introduces Terraform for infrastructure as code. While Phase 4 automated the deployment of your application, the infrastructure (EC2 instances, security groups, ECR repositories, RDS databases) was still created manually through the AWS Console.

In Phase 5, you will:
- Define EC2 instances, security groups, and other resources in Terraform configuration files
- Version-control your infrastructure alongside your application code
- Create and destroy environments with a single command (`terraform apply` / `terraform destroy`)
- Eventually integrate Terraform into the CI/CD pipeline so infrastructure changes are also automated

The CI/CD pipeline from Phase 4 continues to be used -- Phase 5 adds the infrastructure layer underneath it.

---

## Key Files from This Phase

| File | Purpose |
|------|---------|
| `.github/workflows/ci-cd.yml` | The CI/CD pipeline (heavily annotated) |
| `app/eslint.config.js` | ESLint v9 flat config for TypeScript |
| `app/.prettierrc` | Prettier formatting configuration |
| `app/src/server/routes/health.ts` | Health check endpoint used by the pipeline |
| `docs/phase-04/guide.md` | Concept guide for GitHub Actions |
| `docs/phase-04/exercises.md` | 6 hands-on exercises |
| `docs/phase-04/troubleshooting.md` | 8 common pitfalls with fixes |
| `docs/phase-04/cheatsheet.md` | Quick reference for workflow syntax |
| `docs/phase-04/phase-gate-checklist.md` | Requirement verification (DEPL-06, DEPL-07) |
