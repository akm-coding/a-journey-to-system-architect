# Phase 5: Infrastructure as Code and Database -- Overview

## What You Learned

Phase 5 transitions from manually-provisioned AWS resources to fully declarative infrastructure using Terraform. Everything you did by clicking through the AWS console in previous phases -- creating VPCs, launching EC2 instances, configuring security groups -- is now defined in `.tf` files and created with `terraform apply`.

You learned:
- How to write Terraform HCL to define AWS resources (VPC, EC2, RDS, S3, ECR)
- How to manage Terraform state with an S3 backend and DynamoDB locking
- How to create reusable modules (VPC module shared by staging and production)
- How to execute the full Terraform lifecycle: init, plan, apply, destroy
- How to provision and configure RDS PostgreSQL with automated backups
- How to run database migrations using drizzle-kit push in a production workflow
- How to set up connection pooling with RDS Proxy
- How to create and manage database backups (automated and manual snapshots)

---

## Architecture

```
                    infra/bootstrap/ (local state)
                    ┌─────────────────────────────────┐
                    │  S3 Bucket (terraform state)     │
                    │  DynamoDB Table (state locking)  │
                    │  ECR Repository (Docker images)  │
                    └──────────────┬──────────────────┘
                                   │
                         state stored in S3
                                   │
              ┌────────────────────┼────────────────────┐
              │                                         │
   infra/staging/                            infra/production/
   ┌──────────────────────┐                  ┌──────────────────────┐
   │  VPC (10.0.0.0/16)   │                  │  VPC (10.1.0.0/16)   │
   │  ┌────────────────┐  │                  │  ┌────────────────┐  │
   │  │ Public Subnets  │  │                  │  │ Public Subnets  │  │
   │  │  ┌──────────┐  │  │                  │  │  ┌──────────┐  │  │
   │  │  │   EC2    │  │  │                  │  │  │   EC2    │  │  │
   │  │  └──────────┘  │  │                  │  │  └──────────┘  │  │
   │  └────────────────┘  │                  │  └────────────────┘  │
   │  ┌────────────────┐  │                  │  ┌────────────────┐  │
   │  │ Private Subnets │  │                  │  │ Private Subnets │  │
   │  │  ┌──────────┐  │  │                  │  │  ┌──────────┐  │  │
   │  │  │RDS Proxy │  │  │                  │  │  │RDS Proxy │  │  │
   │  │  └─────┬────┘  │  │                  │  │  └─────┬────┘  │  │
   │  │  ┌─────▼────┐  │  │                  │  │  ┌─────▼────┐  │  │
   │  │  │   RDS    │  │  │                  │  │  │   RDS    │  │  │
   │  │  │PostgreSQL│  │  │                  │  │  │PostgreSQL│  │  │
   │  │  └──────────┘  │  │                  │  │  └──────────┘  │  │
   │  └────────────────┘  │                  │  └────────────────┘  │
   └──────────────────────┘                  └──────────────────────┘

   Both environments use the same VPC module (infra/modules/vpc/)
   with different CIDR ranges and configuration values.
```

---

## Study Order

Follow this order for the best learning experience:

| Step | What | Where | Time |
|------|------|-------|------|
| 1 | Terraform concepts guide | `docs/phase-05/01-terraform-concepts/guide.md` | 30 min |
| 2 | Review bootstrap `.tf` files | `infra/bootstrap/` (4 files) | 15 min |
| 3 | Review VPC module | `infra/modules/vpc/` (3 files) | 15 min |
| 4 | Review staging `.tf` files | `infra/staging/` (9 files) | 20 min |
| 5 | Database patterns guide | `docs/phase-05/02-database-patterns/guide.md` | 20 min |
| 6 | Hands-on exercises 1-6 | `docs/phase-05/03-exercises/exercise.md` | 60-90 min |
| 7 | Phase gate checklist | `docs/phase-05/phase-gate-checklist.md` | 15 min |

**Total estimated time:** 3-4 hours

---

## Key Concepts

### Infrastructure as Code (IaC)
Define cloud resources in declarative configuration files instead of clicking through a console. Benefits: version control, reproducibility, peer review, automated provisioning.

### Terraform State
A JSON file tracking what resources Terraform manages and their current attributes. Stored remotely in S3 with DynamoDB locking to prevent concurrent modifications.

### Modules
Reusable Terraform configurations. The VPC module in this project is used by both staging and production with different input variables (CIDRs, environment names).

### Bootstrap Pattern
The state backend (S3 bucket + DynamoDB table) is created first with local state, since it cannot store its own state. All other environments use remote state stored in this backend.

### Connection Pooling
RDS Proxy manages a pool of database connections, multiplexing many application connections through fewer actual database connections. Essential when scaling beyond a single app instance.

### Backup Strategy
Automated daily backups with 7-day retention for continuous protection. Manual snapshots before major changes or destroys. Point-in-time recovery for precise restoration.

---

## Phase Documents

### Study Materials
- [Terraform Concepts Guide](01-terraform-concepts/guide.md) -- HCL syntax, state, providers, modules, lifecycle
- [Terraform Cheatsheet](01-terraform-concepts/cheatsheet.md) -- CLI commands, HCL syntax, flags
- [Database Patterns Guide](02-database-patterns/guide.md) -- Migrations, pooling, backups, security
- [Exercises](03-exercises/exercise.md) -- 6 progressive hands-on exercises
- [Exercise Cheatsheet](03-exercises/cheatsheet.md) -- Combined Terraform + database quick reference

### Infrastructure Code
- `infra/bootstrap/` -- S3 state bucket, DynamoDB lock table, ECR repository
- `infra/modules/vpc/` -- Reusable VPC with subnets, IGW, route tables, security groups
- `infra/staging/` -- Complete staging environment (VPC, EC2, RDS, RDS Proxy)
- `infra/production/` -- Production environment mirroring staging with different values

### Phase Completion
- [Phase Gate Checklist](phase-gate-checklist.md) -- Prove every requirement with runnable commands

---

## Cost Summary

| Resource | Monthly Cost | Notes |
|----------|-------------|-------|
| EC2 (t3.micro) | ~$8.50 | On-demand pricing |
| RDS (db.t4g.micro) | ~$14.00 | Single-AZ, 20GB gp3 |
| RDS Proxy | ~$21.90 | Based on RDS instance vCPUs |
| S3 (state) | ~$0.05 | Minimal storage |
| DynamoDB (locks) | ~$0.00 | PAY_PER_REQUEST, nearly zero usage |
| ECR | ~$0.50 | Minimal image storage |
| Secrets Manager | ~$0.40 | 1 secret |
| **Total (staging)** | **~$45/month** | Destroy when not studying |

**Cost control:** Use `terraform destroy` in `infra/staging/` when you are done studying. The bootstrap infrastructure (~$0.55/month) can stay running. See `scripts/phase-05-teardown.sh` for automated cleanup.
