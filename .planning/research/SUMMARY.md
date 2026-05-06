# Research Summary: A Journey to System Architect

**Synthesized:** 2026-05-06
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md

## Key Findings

### Stack
AWS-focused with Terraform for IaC, Docker for containers, ECS/Fargate for orchestration, GitHub Actions for CI/CD, PostgreSQL + Redis for data, CloudWatch for observability. Skip Kubernetes, serverless, and multi-cloud for now.

### Table Stakes (Must-Learn Topics)
1. Linux & server fundamentals
2. Networking (VPC, subnets, DNS, security groups)
3. Manual server deployment (EC2 + Nginx + PM2)
4. Docker & containerization
5. CI/CD pipelines (GitHub Actions)
6. Infrastructure as Code (Terraform)
7. Database management (RDS PostgreSQL)
8. Monitoring & observability (CloudWatch)

### Differentiators (What Sets You Apart)
1. Container orchestration (ECS/Fargate with auto-scaling)
2. Caching strategies (Redis + CloudFront)
3. System design reasoning (scaling, architecture patterns)
4. Message queues & async processing (SQS/SNS)
5. Security best practices (IAM, secrets management)

### Critical Pitfalls to Avoid
1. **Tutorial hell** — always rebuild from scratch after learning
2. **Skipping networking** — everything breaks without this foundation
3. **AWS bill shock** — set budget alerts immediately, terraform destroy after sessions
4. **Terraform before understanding** — create manually first, then codify
5. **Security shortcuts** — never use root, never commit credentials
6. **Over-engineering the app** — keep the app simple, make the infra interesting

## Recommended Learning Progression

```
Phase 1: Foundation (Linux + Networking + AWS Setup)
Phase 2: First Deploy (EC2 + Nginx + RDS — manual, feel the pain)
Phase 3: Containerization (Docker + Docker Compose)
Phase 4: CI/CD (GitHub Actions — automate what you did manually)
Phase 5: Infrastructure as Code (Terraform — codify what you understand)
Phase 6: Production Deploy (ECS/Fargate + ALB + Auto-scaling) ← MIDPOINT
Phase 7: Data & Caching (RDS advanced + Redis + CloudFront)
Phase 8: Observability (CloudWatch + structured logging + alerting)
Phase 9: System Design Capstone (queues, scaling, architecture exercises)
```

**Estimated timeline:** 12-20 weeks at 1-2 hrs/day

## Design Principle
**Same app, increasing sophistication.** Deploy one React/Node app through every phase. Each phase makes the deployment more production-grade. The app stays simple — the infrastructure gets interesting.

## Cost Strategy
Stick to AWS free tier where possible. Set $10/month budget alert. Always `terraform destroy` after sessions. Estimated cost: $5-15/month if disciplined.

## Confidence Assessment

| Area | Confidence | Notes |
|------|-----------|-------|
| Learning progression order | HIGH | Well-established pedagogical pattern |
| AWS service recommendations | HIGH | Standard production stack |
| Tool choices (Terraform, Docker, GH Actions) | HIGH | Industry standards |
| Time estimates | MEDIUM | Varies significantly by individual |
| Specific tool versions | LOW | Verify at install time |
