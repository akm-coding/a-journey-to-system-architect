# A Journey to System Architect

## What This Is

A structured, hands-on learning program for a React/Node full-stack developer to build deep competence in infrastructure, DevOps, and system design — from near-zero to full independence. Each phase pairs conceptual study with real AWS deployments, so knowledge is earned through building, not just reading.

## Core Value

By the end, you can independently provision, deploy, scale, and reason about production systems on AWS — no hand-holding needed.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Understand how apps actually run in production (servers, networking, DNS, load balancers)
- [ ] Deploy a React/Node app to AWS from scratch (not Vercel/Netlify)
- [ ] Containerize applications with Docker and manage them in production
- [ ] Set up CI/CD pipelines that build, test, and deploy automatically
- [ ] Use Infrastructure as Code (Terraform) to provision AWS resources reproducibly
- [ ] Understand and implement caching strategies (Redis, CDN, application-level)
- [ ] Design and scale databases (RDS, read replicas, connection pooling, migrations)
- [ ] Implement monitoring, logging, and alerting for production systems
- [ ] Reason about system design: load balancing, message queues, microservices, service boundaries
- [ ] Design systems that handle scale (horizontal scaling, auto-scaling, stateless services)
- [ ] Understand networking fundamentals (VPC, subnets, security groups, DNS routing)
- [ ] Work with message queues and async processing (SQS, SNS, event-driven patterns)

### Out of Scope

- Kubernetes (K8s) — too complex for initial learning; focus on ECS/Fargate first, K8s is a future milestone
- Multi-cloud — AWS-only focus to build depth before breadth
- AWS certifications — this is about practical skills, not exam prep
- Frontend architecture — already strong here, no need to revisit
- Machine learning / data engineering — separate domain, not the gap to close

## Context

- You're a working full-stack developer (React + Node) with solid frontend and backend code skills
- Your product owner flagged infrastructure and system design as a growth area
- Current deployment experience is limited to managed platforms (Vercel/Netlify)
- You can dedicate 1-2 hours per day alongside your day job
- Each phase should produce a real deployed project on AWS you can demonstrate
- Learning should build progressively — each phase uses skills from previous phases

## Constraints

- **Time**: 1-2 hours/day alongside a day job — phases must be scoped accordingly
- **Cost**: AWS free tier where possible; be mindful of costs for real deployments
- **Stack**: AWS-focused (EC2, ECS, RDS, S3, CloudFront, SQS, Terraform)
- **Approach**: Hands-on first — every concept must be paired with a real deployment
- **Foundation**: Assume near-zero infra knowledge; start from fundamentals

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AWS over cloud-agnostic | Most job-relevant, biggest ecosystem, depth over breadth | — Pending |
| ECS/Fargate over Kubernetes | Lower complexity ceiling for initial learning, still production-grade | — Pending |
| Real deploys over local-only | Hands-on with real cloud services builds genuine confidence | — Pending |
| Terraform for IaC | Industry standard, cloud-agnostic skill even within AWS focus | — Pending |

---
*Last updated: 2026-05-06 after initialization*
