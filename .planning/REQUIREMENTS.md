# Requirements: A Journey to System Architect

**Defined:** 2026-05-06
**Core Value:** Independently provision, deploy, scale, and reason about production systems on AWS

## v1 Requirements

Requirements for the full learning program. Each maps to roadmap phases.

### Foundation

- [x] **FOUND-01**: Learner can SSH into an EC2 instance and navigate the Linux filesystem
- [x] **FOUND-02**: Learner can manage processes, permissions, and environment variables on a Linux server
- [x] **FOUND-03**: Learner can explain VPC, subnets (public/private), security groups, and route tables
- [x] **FOUND-04**: Learner can configure DNS records (A, CNAME) and understand DNS resolution
- [x] **FOUND-05**: Learner can set up SSL/TLS certificates using AWS Certificate Manager
- [x] **FOUND-06**: Learner has IAM user configured (not root), AWS CLI working, and budget alerts set

### Deployment

- [x] **DEPL-01**: Learner can deploy a React/Node app to EC2 manually (Nginx reverse proxy + PM2)
- [x] **DEPL-02**: Learner can connect the deployed app to an RDS PostgreSQL database
- [x] **DEPL-03**: Learner can write Dockerfiles for React (multi-stage build) and Node apps
- [x] **DEPL-04**: Learner can use Docker Compose to run a multi-service stack locally (app + db + redis)
- [x] **DEPL-05**: Learner can push Docker images to AWS ECR
- [x] **DEPL-06**: Learner can set up a GitHub Actions pipeline that builds, tests, and deploys on merge
- [x] **DEPL-07**: Learner can configure environment-specific deployments (staging vs production)

### Infrastructure as Code

- [x] **IAC-01**: Learner can write Terraform HCL to provision EC2, RDS, S3, and VPC resources
- [x] **IAC-02**: Learner can manage Terraform state with S3 backend and DynamoDB locking
- [x] **IAC-03**: Learner can create reusable Terraform modules
- [x] **IAC-04**: Learner can execute the full Terraform lifecycle (init, plan, apply, destroy)

### Database

- [x] **DATA-01**: Learner can provision and configure RDS PostgreSQL via Terraform
- [ ] **DATA-02**: Learner can implement database migrations in a production workflow
- [x] **DATA-03**: Learner can set up connection pooling for Node.js apps
- [x] **DATA-04**: Learner can configure automated backups and understand point-in-time recovery

### Container Orchestration

- [ ] **ORCH-01**: Learner can deploy a containerized app to ECS/Fargate with task definitions
- [ ] **ORCH-02**: Learner can configure an Application Load Balancer (ALB) in front of ECS services
- [ ] **ORCH-03**: Learner can set up auto-scaling based on CPU/memory metrics
- [ ] **ORCH-04**: Learner can perform rolling and blue/green deployments on ECS

### Caching

- [ ] **CACH-01**: Learner can set up ElastiCache (Redis) for API response and session caching
- [ ] **CACH-02**: Learner can configure CloudFront CDN for static assets with cache invalidation
- [ ] **CACH-03**: Learner can implement application-level caching patterns in Node.js

### Observability

- [ ] **OBSV-01**: Learner can implement structured JSON logging in a Node.js app
- [ ] **OBSV-02**: Learner can create CloudWatch dashboards with key application metrics
- [ ] **OBSV-03**: Learner can set up CloudWatch alarms and SNS notifications for alerts
- [ ] **OBSV-04**: Learner can use CloudWatch Logs Insights to query and debug production issues

### System Design

- [ ] **SYDE-01**: Learner can design and implement SQS-based async task processing (e.g., email queue)
- [ ] **SYDE-02**: Learner can set up SNS pub/sub for event-driven notifications
- [ ] **SYDE-03**: Learner can configure dead letter queues and retry strategies
- [ ] **SYDE-04**: Learner can reason about horizontal vs vertical scaling and explain tradeoffs
- [ ] **SYDE-05**: Learner can design a system architecture diagram for a given problem (whiteboard-style)
- [ ] **SYDE-06**: Learner can explain CAP theorem, eventual consistency, and when to use each pattern
- [ ] **SYDE-07**: Learner can articulate service boundary decisions (when to split a monolith)

## v2 Requirements

Deferred to future milestones.

### Kubernetes
- **K8S-01**: Deploy apps to EKS with Helm charts
- **K8S-02**: Understand pods, services, deployments, ingress
- **K8S-03**: Set up horizontal pod autoscaling

### Serverless
- **SRVL-01**: Build and deploy Lambda functions
- **SRVL-02**: API Gateway + Lambda integration
- **SRVL-03**: Step Functions for orchestration

### Advanced Database
- **ADVD-01**: DynamoDB for NoSQL use cases
- **ADVD-02**: Aurora for high-availability PostgreSQL
- **ADVD-03**: Read replicas and database sharding

## Out of Scope

| Feature | Reason |
|---------|--------|
| Kubernetes (EKS) | Too complex for initial learning; ECS teaches same concepts simpler |
| Multi-cloud (GCP, Azure) | Depth over breadth -- AWS mastery first |
| AWS Certifications | Practical skills, not exam prep |
| Serverless (Lambda) | Learn traditional compute first to understand what serverless abstracts |
| Service mesh (Istio) | K8s-adjacent, too advanced for v1 |
| Multi-region / DR | Expensive, complex; single-region sufficient for learning |
| Frontend architecture | Already strong -- not the gap to close |
| ML / Data Engineering | Separate domain |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| FOUND-06 | Phase 1 | Complete |
| DEPL-01 | Phase 2 | Complete |
| DEPL-02 | Phase 2 | Complete |
| DEPL-03 | Phase 3 | Complete |
| DEPL-04 | Phase 3 | Complete |
| DEPL-05 | Phase 3 | Complete |
| DEPL-06 | Phase 4 | Complete |
| DEPL-07 | Phase 4 | Complete |
| IAC-01 | Phase 5 | Complete |
| IAC-02 | Phase 5 | Complete |
| IAC-03 | Phase 5 | Complete |
| IAC-04 | Phase 5 | Complete |
| DATA-01 | Phase 5 | Complete |
| DATA-02 | Phase 5 | Pending |
| DATA-03 | Phase 5 | Complete |
| DATA-04 | Phase 5 | Complete |
| ORCH-01 | Phase 6 | Pending |
| ORCH-02 | Phase 6 | Pending |
| ORCH-03 | Phase 6 | Pending |
| ORCH-04 | Phase 6 | Pending |
| CACH-01 | Phase 7 | Pending |
| CACH-02 | Phase 7 | Pending |
| CACH-03 | Phase 7 | Pending |
| OBSV-01 | Phase 7 | Pending |
| OBSV-02 | Phase 7 | Pending |
| OBSV-03 | Phase 7 | Pending |
| OBSV-04 | Phase 7 | Pending |
| SYDE-01 | Phase 8 | Pending |
| SYDE-02 | Phase 8 | Pending |
| SYDE-03 | Phase 8 | Pending |
| SYDE-04 | Phase 8 | Pending |
| SYDE-05 | Phase 8 | Pending |
| SYDE-06 | Phase 8 | Pending |
| SYDE-07 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 39 total
- Mapped to phases: 39
- Unmapped: 0

---
*Requirements defined: 2026-05-06*
*Last updated: 2026-05-06 after roadmap creation*
