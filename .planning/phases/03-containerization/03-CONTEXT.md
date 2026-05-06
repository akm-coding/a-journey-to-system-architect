# Phase 3: Containerization - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Teach Docker fundamentals using the existing e-commerce app from Phase 2. Learner writes Dockerfiles, runs a multi-service stack with Docker Compose, and pushes images to ECR. No new app features, no orchestration (Phase 6), no CI/CD automation (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Study material depth
- Practical builder depth — cover what's needed to write good Dockerfiles and Compose files (layers, caching, .dockerignore)
- Skip kernel internals (cgroups, namespaces, union filesystems)
- Include essential Docker security: non-root users in containers, avoiding secrets in images, basic scanning
- Dedicated troubleshooting/debugging section covering common errors (port conflicts, build cache issues, volume permissions) and debugging tools (docker logs, exec, inspect)
- Same format as Phase 1-2: study docs with concept explanations, then separate runbook/cheatsheet for hands-on

### Dockerfile strategy
- Incremental build-up approach: start with a simple single-stage Dockerfile, see the problems (large image, dev deps in prod), then refactor to multi-stage
- Learner writes the React multi-stage Dockerfile (build stage + nginx serve stage); Node API Dockerfile is provided pre-written
- Alpine-based images (node:alpine, nginx:alpine) — teach image size awareness from the start
- Layer caching optimization with hands-on demo: build a bad Dockerfile, time it, reorder for caching, time again — concrete proof of why order matters

### Compose stack design
- Full stack: React frontend, Node API, PostgreSQL, Redis (4 services)
- Two configurations: docker-compose.yml for dev (volume mounts, hot reload) + docker-compose.prod.yml override for production-like builds
- Environment variables via .env file pattern with .env.example checked into version control
- Health checks with depends_on service_healthy conditions for DB and Redis — solves the real "API starts before DB is ready" problem

### ECR workflow
- CLI-first approach: create repo, authenticate, tag, push all via AWS CLI. Console shown for verification only
- Tagging strategy: git commit SHA for traceability + "latest" for convenience
- Basic lifecycle policy to keep last N images and expire untagged ones (cost awareness)
- Full teardown script including ECR repo deletion, consistent with Phase 2's teardown pattern

### Claude's Discretion
- .env file pattern: what goes in .env vs .env.example
- Exact number of images to retain in lifecycle policy
- Troubleshooting section organization and specific error scenarios
- Docker network configuration details in Compose
- Specific nginx configuration for the React multi-stage build

</decisions>

<specifics>
## Specific Ideas

- Incremental Dockerfile teaching mirrors the "see the problem, then fix it" pattern — learner should feel the pain of a 1GB image before learning multi-stage
- Redis is included in Compose even though caching isn't taught until Phase 7 — it prepares the stack and satisfies the success criteria (DEPL-04)
- Dev vs prod Compose configs teach the override pattern which is widely used in real projects

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-containerization*
*Context gathered: 2026-05-07*
