# Roadmap: A Journey to System Architect

## Overview

A progressive, hands-on learning program that takes a React/Node developer from near-zero infrastructure knowledge to independently provisioning, deploying, and scaling production systems on AWS. Each phase deploys the same app with increasing sophistication -- the app stays simple, the infrastructure gets interesting. Eight phases build from Linux fundamentals through system design, each producing a real deployed artifact.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Linux, networking, AWS account setup, and core concepts
- [ ] **Phase 2: First Deploy** - Manual EC2 deployment with Nginx, PM2, and RDS
- [ ] **Phase 3: Containerization** - Docker, Docker Compose, and ECR
- [ ] **Phase 4: CI/CD** - GitHub Actions pipelines with staging and production
- [ ] **Phase 5: Infrastructure as Code and Database** - Terraform for all resources plus RDS production patterns
- [ ] **Phase 6: Container Orchestration** - ECS/Fargate with ALB and auto-scaling
- [ ] **Phase 7: Caching and Observability** - Redis, CloudFront, structured logging, and alerting
- [ ] **Phase 8: System Design Capstone** - Message queues, scaling patterns, and architecture reasoning

## Phase Details

### Phase 1: Foundation
**Goal**: Learner can navigate a Linux server, understand AWS networking, and has a secure AWS environment ready for deployments
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06
**Success Criteria** (what must be TRUE):
  1. Learner can SSH into an EC2 instance and perform basic Linux operations (files, processes, permissions, env vars)
  2. Learner can diagram a VPC with public/private subnets, explain security group rules, and trace a request through route tables
  3. Learner can point a domain to an EC2 instance via DNS and access it over HTTPS with a valid certificate
  4. Learner has a non-root IAM user with CLI access and a budget alert configured
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Monorepo skeleton, AWS account setup guides, and phase tracking templates
- [x] 01-02-PLAN.md — Linux fundamentals and processes/permissions study materials
- [x] 01-03-PLAN.md — Networking (VPC/SGs), DNS, and SSL/TLS study materials

### Phase 2: First Deploy
**Goal**: Learner can deploy a full-stack React/Node app to EC2 manually, understanding every step of what managed platforms abstract away
**Depends on**: Phase 1
**Requirements**: DEPL-01, DEPL-02
**Success Criteria** (what must be TRUE):
  1. A React frontend and Node API are running on EC2 behind Nginx reverse proxy, accessible via a public URL
  2. The app reads and writes data to an RDS PostgreSQL database in a private subnet
  3. Learner can explain each component in the deployment (Nginx config, PM2 process, RDS connection, security group rules)
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Build the e-commerce app (React/Vite frontend + Express API + Drizzle ORM)
- [ ] 02-02-PLAN.md — EC2 deployment runbook (Nginx, PM2, HTTPS with Certbot)
- [ ] 02-03-PLAN.md — RDS database setup runbook, teardown and rebuild scripts

### Phase 3: Containerization
**Goal**: Learner can containerize applications with Docker and manage multi-service stacks, ready for cloud container deployment
**Depends on**: Phase 2
**Requirements**: DEPL-03, DEPL-04, DEPL-05
**Success Criteria** (what must be TRUE):
  1. The React app builds via a multi-stage Dockerfile producing a small production image
  2. The full stack (app + database + Redis) runs locally via Docker Compose with a single command
  3. Docker images are pushed to ECR and can be pulled from another machine or service
**Plans**: 3 plans

Plans:
- [ ] 03-01-PLAN.md — Docker study materials, Dockerfiles, nginx.conf, and .dockerignore
- [ ] 03-02-PLAN.md — Docker Compose study materials, dev/prod compose files, and .env pattern
- [ ] 03-03-PLAN.md — ECR study materials, teardown script, phase overview, and gate checklist

### Phase 4: CI/CD
**Goal**: Learner can automate the build-test-deploy cycle so code merged to main reaches production without manual steps
**Depends on**: Phase 3
**Requirements**: DEPL-06, DEPL-07
**Success Criteria** (what must be TRUE):
  1. A push to the main branch triggers a GitHub Actions workflow that builds, tests, and deploys the app
  2. Staging and production environments exist with separate configurations, and the pipeline deploys to the correct one based on branch
  3. A failing test prevents deployment (the pipeline catches it and stops)
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Infrastructure as Code and Database
**Goal**: Learner can define all AWS infrastructure in Terraform and manage databases with production-grade patterns
**Depends on**: Phase 4
**Requirements**: IAC-01, IAC-02, IAC-03, IAC-04, DATA-01, DATA-02, DATA-03, DATA-04
**Success Criteria** (what must be TRUE):
  1. Running `terraform apply` provisions a complete environment (VPC, EC2/ECS, RDS, S3) from scratch
  2. Terraform state is stored in S3 with DynamoDB locking, and the learner can explain why this matters
  3. At least one reusable Terraform module exists (e.g., a VPC module used by both staging and production)
  4. The database uses connection pooling, has automated backups configured, and the learner can run migrations as part of deployment
  5. Running `terraform destroy` tears down the environment cleanly (cost control)
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD
- [ ] 05-03: TBD

### Phase 6: Container Orchestration
**Goal**: Learner can run production containers on ECS/Fargate with load balancing and auto-scaling -- no more managing EC2 instances directly
**Depends on**: Phase 5
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04
**Success Criteria** (what must be TRUE):
  1. The app runs on ECS/Fargate with a task definition, accessible through an Application Load Balancer
  2. Auto-scaling adjusts the number of running tasks based on CPU/memory thresholds
  3. Learner can perform a rolling deployment (new version goes live with zero downtime)
  4. Learner can explain ECS concepts: clusters, services, tasks, and how they map to the container lifecycle
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD
- [ ] 06-03: TBD

### Phase 7: Caching and Observability
**Goal**: Learner can make the app fast with caching and keep it healthy with monitoring, logging, and alerting
**Depends on**: Phase 6
**Requirements**: CACH-01, CACH-02, CACH-03, OBSV-01, OBSV-02, OBSV-03, OBSV-04
**Success Criteria** (what must be TRUE):
  1. API responses are cached in Redis, and the learner can demonstrate cache hit vs miss behavior
  2. Static assets are served through CloudFront CDN, and the learner can invalidate the cache after a deploy
  3. Application logs are structured JSON flowing to CloudWatch, queryable with Logs Insights
  4. A CloudWatch dashboard shows key metrics (request rate, error rate, latency, CPU/memory)
  5. An alarm fires and sends an SNS notification when error rate exceeds a threshold
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD
- [ ] 07-03: TBD

### Phase 8: System Design Capstone
**Goal**: Learner can reason about and implement distributed system patterns, and can design architectures for real-world problems
**Depends on**: Phase 7
**Requirements**: SYDE-01, SYDE-02, SYDE-03, SYDE-04, SYDE-05, SYDE-06, SYDE-07
**Success Criteria** (what must be TRUE):
  1. An SQS-based async worker processes background tasks (e.g., email sending), with dead letter queues handling failures
  2. An SNS topic publishes events that multiple subscribers consume (event-driven pattern working end-to-end)
  3. Learner can whiteboard a system design for a given problem, identifying load balancers, caches, queues, databases, and service boundaries
  4. Learner can articulate scaling strategies (horizontal vs vertical), CAP theorem tradeoffs, and when to split a monolith
**Plans**: TBD

Plans:
- [ ] 08-01: TBD
- [ ] 08-02: TBD
- [ ] 08-03: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2026-05-06 |
| 2. First Deploy | 0/3 | Not started | - |
| 3. Containerization | 0/3 | Not started | - |
| 4. CI/CD | 0/2 | Not started | - |
| 5. Infrastructure as Code and Database | 0/3 | Not started | - |
| 6. Container Orchestration | 0/3 | Not started | - |
| 7. Caching and Observability | 0/3 | Not started | - |
| 8. System Design Capstone | 0/3 | Not started | - |
