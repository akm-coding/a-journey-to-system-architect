# Architecture Research: Learning Program Structure

**Research date:** 2026-05-06
**Domain:** Optimal learning progression for infra/DevOps/system design

## Learning Components

### Component 1: Foundation Layer (Linux + Networking + AWS Basics)
**Boundary:** Raw server skills — SSH, command line, how the internet works, AWS account setup
**Builds on:** Nothing (entry point)
**Feeds into:** Everything else — this is the bedrock

**Why first:** Every other topic assumes you can navigate a Linux server and understand networking. Skipping this creates a shaky foundation that collapses under more advanced topics.

### Component 2: Traditional Deployment (EC2 + Nginx + PM2 + RDS)
**Boundary:** Deploy a React/Node app the "old school" way — manually on a server
**Builds on:** Foundation Layer
**Feeds into:** Docker (understand what Docker replaces), CI/CD (automate what you did manually)

**Why before Docker:** You need to feel the pain of manual deployment to appreciate what containers solve. Deploy manually once, then never again.

### Component 3: Containerization (Docker + Docker Compose)
**Boundary:** Package apps into containers, run multi-service stacks locally
**Builds on:** Traditional Deployment (understand what you're containerizing)
**Feeds into:** CI/CD (build images in pipeline), Container Orchestration (run containers at scale)

**Why before CI/CD:** CI/CD pipelines build and push Docker images. You need to understand Docker first.

### Component 4: CI/CD & Automation (GitHub Actions)
**Boundary:** Automate build, test, and deploy. No more manual deployments.
**Builds on:** Docker (building images), Traditional Deployment (deployment targets)
**Feeds into:** IaC (automate infrastructure too), Container Orchestration (deploy to ECS)

### Component 5: Infrastructure as Code (Terraform)
**Boundary:** Define all AWS resources as code. Reproducible, version-controlled infrastructure.
**Builds on:** All AWS knowledge from Components 1-4 (you need to know what you're codifying)
**Feeds into:** Container Orchestration (provision ECS clusters), Advanced architectures

**Why here (not earlier):** Terraform codifies what you already understand. If you Terraform before understanding the resources, you're copy-pasting config without comprehension.

### Component 6: Production-Grade Deployment (ECS/Fargate + ALB + Auto-scaling)
**Boundary:** Container orchestration, load balancing, auto-scaling, blue/green deploys
**Builds on:** Docker, Terraform, Networking, CI/CD
**Feeds into:** System Design (real scaling patterns), Monitoring (production observability)

**Why this is the midpoint milestone:** After this component, you have a production-ready deployment pipeline. Everything after is about making it better.

### Component 7: Data & Persistence (RDS Advanced + Redis + Caching)
**Boundary:** Database scaling, caching layers, data management in production
**Builds on:** Database basics from Component 2, Production deployment from Component 6
**Feeds into:** System Design (data-tier scaling), Message Queues (async processing)

### Component 8: Observability (Monitoring + Logging + Alerting)
**Boundary:** Know what's happening in production. CloudWatch, structured logging, dashboards.
**Builds on:** Running production system (Component 6)
**Feeds into:** System Design (understanding bottlenecks requires observability)

**Can run parallel with:** Component 7 — both layer onto the production system

### Component 9: System Design & Advanced Patterns (Queues + Event-driven + Architecture)
**Boundary:** High-level system reasoning — scaling strategies, service boundaries, async patterns
**Builds on:** Everything — this is the capstone that synthesizes all knowledge
**Feeds into:** Real-world architecture decisions, system design discussions

## Knowledge Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    FOUNDATION LAYER                          │
│         Linux + Networking + AWS Basics                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              TRADITIONAL DEPLOYMENT                          │
│         EC2 + Nginx + PM2 + RDS basics                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              CONTAINERIZATION                                │
│         Docker + Docker Compose                              │
└──────────┬───────────────────────────────┬──────────────────┘
           │                               │
┌──────────▼──────────┐    ┌──────────────▼───────────────────┐
│    CI/CD PIPELINES  │    │   INFRASTRUCTURE AS CODE          │
│    GitHub Actions    │    │   Terraform                      │
└──────────┬──────────┘    └──────────────┬───────────────────┘
           │                               │
           └───────────┬───────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│           PRODUCTION DEPLOYMENT                              │
│      ECS/Fargate + ALB + Auto-scaling                        │
│                ═══ MIDPOINT MILESTONE ═══                     │
└──────────┬───────────────────────────────┬──────────────────┘
           │                               │
┌──────────▼──────────┐    ┌──────────────▼───────────────────┐
│  DATA & CACHING     │    │   OBSERVABILITY                   │
│  RDS + Redis        │    │   Monitoring + Logging            │
└──────────┬──────────┘    └──────────────┬───────────────────┘
           │                               │
           └───────────┬───────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              SYSTEM DESIGN CAPSTONE                          │
│    Queues + Scaling + Architecture + Design Exercises         │
└─────────────────────────────────────────────────────────────┘
```

## Suggested Build Order & Rationale

1. **Foundation → Traditional Deploy → Docker** (sequential, each builds directly on previous)
2. **CI/CD ↔ Terraform** (can partially overlap — CI/CD for app deploy, Terraform for infra)
3. **Production Deployment** (combines Docker + CI/CD + Terraform)
4. **Data/Caching ↔ Observability** (parallel — both layer onto production system)
5. **System Design Capstone** (must come last — requires all other knowledge)

## Time Estimation (at 1-2 hrs/day)

| Component | Estimated Duration |
|-----------|-------------------|
| Foundation Layer | 1-2 weeks |
| Traditional Deployment | 1-2 weeks |
| Containerization | 1-2 weeks |
| CI/CD Pipelines | 1-2 weeks |
| Infrastructure as Code | 2-3 weeks |
| Production Deployment | 2-3 weeks |
| Data & Caching | 1-2 weeks |
| Observability | 1-2 weeks |
| System Design Capstone | 2-3 weeks |
| **Total** | **~12-20 weeks** |

## Key Architectural Principles

1. **Build before you abstract** — manual deployment before Docker, Docker before ECS, console before Terraform
2. **Same app, increasing sophistication** — deploy the same React/Node app through each phase, making the deployment more production-grade each time
3. **Tear down and rebuild** — repetition builds muscle memory. `terraform destroy` then rebuild.
4. **Real deploys, real costs** — AWS free tier keeps costs minimal, but real cloud interaction is non-negotiable for genuine learning
