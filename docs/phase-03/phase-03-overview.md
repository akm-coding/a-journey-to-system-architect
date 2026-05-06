# Phase 3: Containerization

## Learning Objectives

By the end of this phase, you will be able to:

1. **Write Dockerfiles** for React (multi-stage build) and Node.js applications
2. **Run a multi-service stack** locally with Docker Compose (frontend + API + database + cache)
3. **Push Docker images** to AWS ECR with proper tagging and lifecycle policies

## Prerequisites

- Phase 2 complete (e-commerce app with build scripts)
- Docker Desktop installed and running
- AWS CLI configured (`aws sts get-caller-identity` returns your account)
- Basic terminal proficiency

## Architecture Overview

### Local Development Stack (Docker Compose)

```
┌─────────────────────────────────────────────────────┐
│                   Docker Compose                     │
│                                                      │
│  ┌──────────────┐     ┌──────────────┐              │
│  │   frontend    │────>│     api      │              │
│  │  (nginx:80)   │     │  (node:3000) │              │
│  │  React SPA    │     │  Express     │              │
│  └──────────────┘     └──────┬───────┘              │
│                              │                       │
│                    ┌─────────┴─────────┐            │
│                    │                   │            │
│              ┌─────┴──────┐    ┌──────┴─────┐      │
│              │     db      │    │    redis    │      │
│              │ (pg:5432)   │    │  (redis:    │      │
│              │ PostgreSQL   │    │   6379)     │      │
│              └─────────────┘    └────────────┘      │
│                                                      │
└─────────────────────────────────────────────────────┘
```

- **frontend** -- Nginx serving React SPA (multi-stage Dockerfile)
- **api** -- Node.js Express server (non-root user Dockerfile)
- **db** -- PostgreSQL 16 with health checks
- **redis** -- Redis 7 Alpine with health checks

### ECR Push Flow

```
┌───────────┐    docker build     ┌───────────────┐
│  Source    │ ──────────────────> │  Local Image   │
│  Code     │                     │  ecommerce-    │
│  + Docker │                     │  frontend:     │
│  file     │                     │  latest        │
└───────────┘                     └───────┬───────┘
                                          │
                                   docker tag
                                          │
                                          v
                                  ┌───────────────┐
                                  │  Tagged Image  │
                                  │  ECR_URI/      │
                                  │  ecommerce-    │
                                  │  frontend:     │
                                  │  abc123f       │
                                  └───────┬───────┘
                                          │
                                   docker push
                                          │
                                          v
                              ┌─────────────────────┐
                              │     AWS ECR          │
                              │  ┌───────────────┐   │
                              │  │ ecommerce-    │   │
                              │  │ frontend      │   │
                              │  │  :abc123f     │   │
                              │  │  :latest      │   │
                              │  └───────────────┘   │
                              │  ┌───────────────┐   │
                              │  │ ecommerce-    │   │
                              │  │ api           │   │
                              │  │  :abc123f     │   │
                              │  │  :latest      │   │
                              │  └───────────────┘   │
                              └─────────────────────┘
```

## Study Order

Follow these materials in order. Each topic builds on the previous one.

### 1. Docker Fundamentals (DEPL-03)

| Material | Purpose | Time |
|----------|---------|------|
| [Docker Guide](./docker-guide.md) | Core concepts: images, layers, caching, multi-stage builds, security | 30-45 min read |
| [Docker Exercise](./docker-exercise.md) | Hands-on: write Dockerfiles, build images, compare sizes | 45-60 min |
| [Docker Cheatsheet](./docker-cheatsheet.md) | Quick reference for Docker commands | Reference |

### 2. Docker Compose (DEPL-04)

| Material | Purpose | Time |
|----------|---------|------|
| [Compose Guide](./compose-guide.md) | Multi-service orchestration, health checks, dev/prod configs | 30-45 min read |
| [Compose Exercise](./compose-exercise.md) | Hands-on: run the full 4-service stack locally | 30-45 min |
| [Compose Cheatsheet](./compose-cheatsheet.md) | Quick reference for Compose commands | Reference |

### 3. AWS ECR (DEPL-05)

| Material | Purpose | Time |
|----------|---------|------|
| [ECR Guide](./ecr-guide.md) | ECR concepts, auth flow, tagging strategy, lifecycle policies | 20-30 min read |
| [ECR Exercise](./ecr-exercise.md) | Hands-on: create repos, authenticate, push images, apply policies | 20-30 min |
| [ECR Cheatsheet](./ecr-cheatsheet.md) | Quick reference for ECR CLI commands | Reference |

**Total estimated time:** 3-5 hours (study + hands-on)

## Key Files

```
app/
  Dockerfile              # React frontend: multi-stage build (Node + nginx)
  Dockerfile.api          # Node API: single-stage with non-root user
  nginx.conf              # SPA routing + API reverse proxy + gzip
  .dockerignore           # Build context exclusions
  docker-compose.yml      # Dev: volume mounts, hot reload
  docker-compose.prod.yml # Prod override: built images, restart policies

scripts/
  phase-03-teardown.sh    # Delete ECR repos + local Docker artifacts

docs/phase-03/
  docker-guide.md         # Docker concepts
  docker-exercise.md      # Docker hands-on
  docker-cheatsheet.md    # Docker reference
  compose-guide.md        # Compose concepts
  compose-exercise.md     # Compose hands-on
  compose-cheatsheet.md   # Compose reference
  ecr-guide.md            # ECR concepts
  ecr-exercise.md         # ECR hands-on
  ecr-cheatsheet.md       # ECR reference
```

## Cleanup

When you're done with Phase 3 exercises:

```bash
./scripts/phase-03-teardown.sh
```

This deletes ECR repositories and local Docker Compose artifacts.

## What's Next

**Phase 4: CI/CD** -- Automate the build-test-push-deploy workflow that you've done manually in Phase 3. The Docker images you learned to build and push will be built and pushed automatically by GitHub Actions on every commit.

---

*Phase: 03-containerization*
