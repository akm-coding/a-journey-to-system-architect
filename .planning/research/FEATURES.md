# Features Research: Infrastructure/DevOps/System Design Learning

**Research date:** 2026-05-06
**Domain:** What a React/Node developer must learn to achieve infrastructure independence

## Table Stakes (Must Learn — Without These You're Not Independent)

### 1. Linux & Server Fundamentals
- SSH into a server, navigate filesystem, manage processes
- File permissions, environment variables, systemd basics
- Package management (apt/yum)
- **Complexity:** Low | **Dependencies:** None — start here

### 2. Networking Fundamentals
- IP addresses, ports, DNS resolution, HTTP/HTTPS
- VPC, subnets (public/private), security groups, NACLs
- Route tables, internet gateways, NAT gateways
- SSL/TLS certificates, domain management
- **Complexity:** Medium | **Dependencies:** Linux basics

### 3. Manual Server Deployment
- Provision an EC2 instance, install Node.js, run your app
- Configure Nginx as reverse proxy
- Set up PM2 or systemd for process management
- Connect to RDS database
- **Complexity:** Medium | **Dependencies:** Linux, Networking

### 4. Docker & Containerization
- Write Dockerfiles for Node.js apps
- Multi-stage builds for React + Node
- Docker Compose for local multi-service development
- Push images to ECR
- **Complexity:** Medium | **Dependencies:** Linux basics

### 5. CI/CD Pipelines
- GitHub Actions: build, test, deploy workflows
- Automated testing in pipeline
- Deploy to EC2 or ECS on merge
- Environment-specific deployments (staging/prod)
- **Complexity:** Medium | **Dependencies:** Docker, Server deployment

### 6. Infrastructure as Code (Terraform)
- HCL basics, providers, resources, variables, outputs
- State management (S3 backend + DynamoDB locking)
- Modules for reusability
- Plan/apply/destroy lifecycle
- **Complexity:** High | **Dependencies:** Networking, AWS services understanding

### 7. Database Management
- RDS provisioning and configuration
- Connection pooling (PgBouncer or app-level)
- Database migrations strategy
- Backups, snapshots, point-in-time recovery
- **Complexity:** Medium | **Dependencies:** Networking (VPC/subnets)

### 8. Monitoring & Observability
- Application logging (structured JSON logs)
- CloudWatch metrics, dashboards, alarms
- Health checks and uptime monitoring
- Error tracking and alerting
- **Complexity:** Medium | **Dependencies:** Running production app

## Differentiators (Sets You Apart From Other Devs)

### 9. Container Orchestration (ECS/Fargate)
- Task definitions, services, clusters
- Auto-scaling based on CPU/memory/custom metrics
- Blue/green and rolling deployments
- Service discovery and load balancing
- **Complexity:** High | **Dependencies:** Docker, Networking, Terraform

### 10. Caching Strategies
- Redis for session storage and API response caching
- CloudFront CDN for static assets
- Cache invalidation strategies
- Application-level caching patterns
- **Complexity:** Medium-High | **Dependencies:** Running app, Redis

### 11. System Design Thinking
- Load balancing patterns (ALB, round-robin, sticky sessions)
- Horizontal vs vertical scaling
- Stateless service design
- Database scaling (read replicas, sharding concepts)
- CAP theorem, eventual consistency
- **Complexity:** High | **Dependencies:** All previous topics

### 12. Message Queues & Async Processing
- SQS for task queues (email sending, image processing)
- SNS for pub/sub notifications
- Dead letter queues and retry strategies
- Event-driven architecture patterns
- **Complexity:** High | **Dependencies:** System design fundamentals

### 13. Security Best Practices
- IAM roles and policies (least privilege)
- Secrets management (AWS Secrets Manager / Parameter Store)
- Security groups as firewalls
- HTTPS everywhere, CORS configuration
- **Complexity:** Medium-High | **Dependencies:** Networking, IAM

## Anti-Features (Deliberately Skip for Now)

| Topic | Why Skip | When to Revisit |
|-------|----------|-----------------|
| Kubernetes | Adds massive complexity. ECS teaches the same concepts simpler. | After mastering ECS |
| Microservices architecture | Start with well-structured monolith. Premature decomposition is worse than no decomposition. | After system design fundamentals |
| Serverless (Lambda) | Hides too much of what you need to learn. Understand servers first. | After understanding traditional compute |
| Service mesh (Istio, Envoy) | K8s-adjacent, too advanced | After Kubernetes |
| GitOps (ArgoCD, Flux) | K8s-specific workflow | After Kubernetes |
| Multi-region / disaster recovery | Expensive and complex. Single-region is fine for learning. | After production experience |
| Advanced database (DynamoDB, Aurora) | Learn relational well first | After PostgreSQL mastery |

## Feature Dependencies (Learning Order)

```
Linux Basics
    └── Networking Fundamentals
        ├── Manual Server Deployment
        │   └── CI/CD Pipelines
        │       └── Container Orchestration (ECS)
        ├── Docker & Containerization
        │   └── CI/CD Pipelines
        └── Infrastructure as Code (Terraform)
            └── Container Orchestration (ECS)

Database Management ──── (parallel with above after networking)

Monitoring ──── (layer on top of any running system)

System Design Thinking ──── (capstone, synthesizes everything)
    ├── Caching Strategies
    ├── Message Queues
    └── Security Best Practices
```
