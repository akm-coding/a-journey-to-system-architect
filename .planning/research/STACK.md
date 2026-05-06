# Stack Research: Infrastructure/DevOps/System Design Learning

**Research date:** 2026-05-06
**Domain:** Infrastructure, DevOps, and System Design for React/Node developers
**Confidence note:** Tool versions may drift — verify at install time

## Recommended Stack

### Core Infrastructure Tools

| Tool | Purpose | Confidence |
|------|---------|------------|
| **AWS CLI v2** | AWS resource management from terminal | HIGH |
| **Terraform ~1.8+** | Infrastructure as Code — industry standard, cloud-agnostic skill | HIGH |
| **Docker Desktop / Docker Engine** | Containerization — universal skill | HIGH |
| **Docker Compose** | Multi-container local development | HIGH |

### AWS Services (Learning Order)

| Service | Purpose | Free Tier? | Confidence |
|---------|---------|------------|------------|
| **EC2** (t2.micro/t3.micro) | Virtual servers — understand compute fundamentals | Yes | HIGH |
| **S3** | Object storage, static site hosting | Yes (5GB) | HIGH |
| **RDS** (PostgreSQL) | Managed relational database | Yes (t3.micro) | HIGH |
| **CloudFront** | CDN — content delivery and caching | Yes (1TB/mo) | HIGH |
| **Route 53** | DNS management | No (~$0.50/zone) | HIGH |
| **ECS + Fargate** | Container orchestration without managing servers | Partial | HIGH |
| **ECR** | Docker image registry | Yes (500MB) | HIGH |
| **ALB** | Application Load Balancer | No | HIGH |
| **ElastiCache (Redis)** | Managed caching | Partial | HIGH |
| **SQS / SNS** | Message queues and pub/sub | Yes (1M requests) | HIGH |
| **CloudWatch** | Monitoring, logging, alerting | Yes (basic) | HIGH |
| **VPC** | Virtual networking | Free | HIGH |
| **IAM** | Access management | Free | HIGH |

### CI/CD

| Tool | Purpose | Confidence |
|------|---------|------------|
| **GitHub Actions** | CI/CD pipelines — most familiar for JS devs, free tier generous | HIGH |
| **AWS CodePipeline** | AWS-native CI/CD (learn after GitHub Actions) | MEDIUM |

### Monitoring & Observability

| Tool | Purpose | Confidence |
|------|---------|------------|
| **CloudWatch** | AWS-native monitoring/logging/alerting | HIGH |
| **Prometheus + Grafana** | Industry-standard metrics (optional, advanced) | MEDIUM |

### Development Tools

| Tool | Purpose | Confidence |
|------|---------|------------|
| **Node.js 20+ LTS** | Already known — runtime for backend | HIGH |
| **PostgreSQL** | Production-grade relational DB (better learning than MySQL for system design) | HIGH |
| **Redis** | Caching, sessions, pub/sub | HIGH |
| **Nginx** | Reverse proxy, load balancing concepts | HIGH |

## What NOT to Use (and Why)

| Tool | Why Skip |
|------|----------|
| **Kubernetes** | Too complex for initial learning. ECS/Fargate teaches container orchestration with far less overhead. K8s is a future milestone. |
| **AWS CDK / CloudFormation** | Terraform is more portable and industry-standard. CDK adds abstraction that hides what you need to learn. |
| **Pulumi** | Good tool but smaller community. Terraform has more learning resources. |
| **Ansible/Chef/Puppet** | Configuration management is less relevant with containers. Focus on Docker + Terraform instead. |
| **AWS SAM / Serverless Framework** | Lambda-focused. Learn traditional compute first (EC2, ECS) to understand what serverless abstracts away. |
| **Datadog / New Relic** | Expensive. CloudWatch + free Grafana covers learning needs. |
| **Multi-region setups** | Adds cost and complexity. Single-region is sufficient for learning. |

## Cost Management Strategy

- **AWS Free Tier**: New accounts get 12 months of free tier. Use t2.micro/t3.micro instances.
- **Budget Alerts**: Set up AWS Budgets immediately ($10/month alert)
- **Tear Down**: Always `terraform destroy` after learning sessions
- **Spot Instances**: Use for non-critical experimentation (up to 90% cheaper)
- **Estimated monthly cost**: $5-15 if disciplined about teardown

## Key Rationale

1. **PostgreSQL over MySQL**: Better for system design learning (JSONB, CTEs, window functions, EXPLAIN ANALYZE)
2. **Terraform over CloudFormation**: Portable skill, declarative, huge community, works beyond AWS
3. **GitHub Actions over Jenkins**: Modern, YAML-based, free, integrates with existing workflow
4. **ECS/Fargate over EKS**: 80% of container orchestration learning at 20% of the complexity
5. **Nginx**: Understanding reverse proxies is fundamental — even if ALB handles it in prod, you need the mental model
