# Phase 5: Infrastructure as Code and Database - Research

**Researched:** 2026-05-07
**Domain:** Terraform (HCL), AWS infrastructure provisioning, RDS PostgreSQL, connection pooling
**Confidence:** HIGH

## Summary

Phase 5 transitions from manually-provisioned AWS resources to fully declarative infrastructure using Terraform. The learner will define VPC, EC2, RDS, S3, ECR, and supporting resources in HCL, store state remotely in S3, and implement production database patterns (connection pooling via RDS Proxy, automated backups, migrations).

The Terraform ecosystem is mature and well-documented. The AWS provider is at v6.x (GA since early 2026), and Terraform CLI is at v1.15.x. A significant development: S3 native state locking (`use_lockfile`) replaces DynamoDB locking as of Terraform 1.10+. However, the CONTEXT.md decision specifies DynamoDB locking, which is still supported and teaches a valuable pattern -- the research covers both approaches so the planner can include the DynamoDB approach as decided while noting the newer alternative.

**Primary recommendation:** Use Terraform ~1.15 with AWS provider ~6.x. Structure as `infra/bootstrap/` (state backend), `infra/modules/` (reusable), `infra/staging/` and `infra/production/` (environments). Use DynamoDB locking as decided, but mention S3 native locking as a study note.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Directory per environment: `infra/staging/` and `infra/production/` with shared modules in `infra/modules/`
- Each environment has its own state file (no workspaces)
- VPC + Security Groups module as the reusable module (used by both staging and production)
- State stored in S3 bucket with DynamoDB table for locking (bootstrapped manually first)
- Variables include type constraints, validation blocks, and descriptions
- Outputs documented with descriptions
- All resources defined fresh from scratch -- no terraform import of existing Phase 2-4 infra
- Compute: EC2 instances (ECS/Fargate deferred to Phase 6)
- Include ECR repos and S3/DynamoDB state backend as "bootstrap" infrastructure
- Terraform plan/apply run manually (no CI/CD pipeline integration for Terraform)
- Full resource set: VPC, subnets, security groups, EC2, RDS, S3 (state), DynamoDB (lock), ECR
- Connection pooling via RDS Proxy (AWS-managed)
- Automated daily backups with 7-day retention + manual snapshot exercise
- Pre-deploy migration step: SSH in, run drizzle-kit push
- Deploy single-AZ to keep costs low; show Multi-AZ configuration for reference
- Concept guide, annotated .tf files, cost estimation section, IaC comparison, destroy+rebuild exercise
- Bootstrap vs app infrastructure separation

### Claude's Discretion
- Exact variable names and output structure
- Terraform provider version pinning strategy
- Security group rule granularity
- RDS instance class selection (cost vs performance)
- Exercise ordering and difficulty progression

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IAC-01 | Write Terraform HCL to provision EC2, RDS, S3, and VPC resources | Standard Stack (Terraform + AWS provider), Architecture Patterns (module structure, resource definitions), Code Examples |
| IAC-02 | Manage Terraform state with S3 backend and DynamoDB locking | Architecture Patterns (bootstrap config), State Management section, Code Examples |
| IAC-03 | Create reusable Terraform modules | Architecture Patterns (VPC module structure), Code Examples (module source/variable patterns) |
| IAC-04 | Execute the full Terraform lifecycle (init, plan, apply, destroy) | Architecture Patterns (lifecycle flow), Common Pitfalls (state issues, dependency ordering) |
| DATA-01 | Provision and configure RDS PostgreSQL via Terraform | Code Examples (aws_db_instance, aws_db_subnet_group), Cost analysis (instance selection) |
| DATA-02 | Implement database migrations in a production workflow | Architecture Patterns (drizzle-kit push via SSH), existing app db setup |
| DATA-03 | Set up connection pooling for Node.js apps | RDS Proxy section, Code Examples (aws_db_proxy), Cost analysis |
| DATA-04 | Configure automated backups and understand point-in-time recovery | Code Examples (backup_retention_period, snapshot), Common Pitfalls (final snapshot) |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Terraform CLI | ~1.15.x | Infrastructure provisioning engine | Industry standard IaC tool, BSL-licensed but free for individual use |
| AWS Provider | ~6.x | Terraform provider for AWS resources | Official HashiCorp provider, GA since April 2026 |
| HCL | 2.0 | Terraform configuration language | Native Terraform language, declarative |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| drizzle-kit | ^0.30.0 | Database schema migrations | Already in project -- `drizzle-kit push` for migration |
| pg (node-postgres) | ^8.13.0 | PostgreSQL client for Node.js | Already in project -- connects through RDS Proxy endpoint |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Terraform | CloudFormation | AWS-native, no state management needed, but vendor lock-in and verbose YAML/JSON |
| Terraform | Pulumi/CDK | Real programming languages, but adds complexity for learning IaC concepts |
| DynamoDB locking | S3 native locking (`use_lockfile`) | Newer (Terraform 1.10+), simpler setup, but DynamoDB approach teaches more infrastructure concepts |
| RDS Proxy | Application-level pooling (pg-pool) | Free, simpler, but doesn't handle connection management across multiple app instances |

**Installation:**
```bash
# Terraform CLI (macOS)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify
terraform --version
```

## Architecture Patterns

### Recommended Project Structure
```
infra/
├── bootstrap/              # State backend (S3 bucket + DynamoDB table)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── modules/
│   └── vpc/                # Reusable VPC + security groups module
│       ├── main.tf         # VPC, subnets, IGW, route tables, SGs
│       ├── variables.tf    # CIDR blocks, AZ config, tag inputs
│       └── outputs.tf      # vpc_id, subnet_ids, sg_ids
├── staging/
│   ├── main.tf             # Calls modules, defines env-specific resources
│   ├── variables.tf        # Environment-specific variables
│   ├── outputs.tf          # Endpoints, IDs for reference
│   ├── providers.tf        # AWS provider + backend config
│   ├── terraform.tfvars    # Actual values for staging
│   ├── ec2.tf              # EC2 instance(s)
│   ├── rds.tf              # RDS instance + subnet group
│   ├── rds-proxy.tf        # RDS Proxy + target group
│   ├── ecr.tf              # ECR repositories (or in bootstrap)
│   └── secrets.tf          # Secrets Manager for RDS credentials
└── production/
    ├── (same structure as staging)
    └── terraform.tfvars    # Production values (larger instances, Multi-AZ ref)
```

### Pattern 1: Bootstrap-Then-App Separation
**What:** State backend resources (S3 bucket, DynamoDB table) are provisioned separately with local state, before the main infrastructure that uses remote state.
**When to use:** Always -- the state backend cannot manage its own state.
**Example:**
```hcl
# infra/bootstrap/main.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = "myproject-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

### Pattern 2: Environment-Specific Backend Config
**What:** Each environment directory has its own backend block pointing to a different state key.
**When to use:** Every environment directory.
**Example:**
```hcl
# infra/staging/providers.tf
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "myproject-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
```

### Pattern 3: Reusable Module with Variable Validation
**What:** VPC module accepts parameterized inputs with type constraints and validation.
**When to use:** The VPC + Security Groups module.
**Example:**
```hcl
# infra/modules/vpc/variables.tf
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "environment" {
  description = "Environment name (staging or production)"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be 'staging' or 'production'."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (for RDS)"
  type        = list(string)
}
```

### Pattern 4: RDS Proxy with Secrets Manager
**What:** RDS Proxy requires credentials stored in Secrets Manager and an IAM role to access them.
**When to use:** When setting up connection pooling for RDS.
**Example:**
```hcl
# Secrets Manager secret for RDS credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

# RDS Proxy
resource "aws_db_proxy" "main" {
  name                   = "${var.environment}-rds-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [module.vpc.rds_proxy_sg_id]
  vpc_subnet_ids         = module.vpc.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    max_connections_percent      = 100
    connection_borrow_timeout    = 120
  }
}

resource "aws_db_proxy_target" "main" {
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
  db_instance_identifier = aws_db_instance.main.identifier
}
```

### Anti-Patterns to Avoid
- **Hardcoded values in .tf files:** Use variables.tf + terraform.tfvars; never embed IPs, passwords, or region strings directly
- **Single monolithic main.tf:** Split by resource type (ec2.tf, rds.tf, etc.) for readability
- **terraform.tfvars in git with secrets:** Use environment variables or Secrets Manager for passwords; .tfvars for non-sensitive config only
- **Importing existing Phase 2-4 resources:** Per decision, start fresh -- do not `terraform import` old infra

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connection pooling | Custom pg-pool config per instance | RDS Proxy | Handles failover, connection draining, IAM auth natively |
| VPC networking | Manual subnet math, route tables | VPC module with parameterized CIDRs | Subnet/CIDR mistakes cause hard-to-debug connectivity issues |
| State locking | File-based locking, scripts | S3 + DynamoDB backend | Race conditions corrupt state; built-in locking prevents this |
| Credential management | Plaintext in tfvars | AWS Secrets Manager | Required by RDS Proxy; also best practice for rotation |
| AMI lookup | Hardcoded AMI IDs | `aws_ami` data source with filters | AMI IDs differ by region and update frequently |

**Key insight:** Terraform's declarative model means the provider handles dependency ordering, retry logic, and API pagination. Manual scripts doing the same work are 10x more code and miss edge cases.

## Common Pitfalls

### Pitfall 1: Bootstrap Chicken-and-Egg
**What goes wrong:** Trying to use S3 backend before the S3 bucket exists, or trying to manage the state bucket with the same state it stores.
**Why it happens:** Circular dependency -- state backend must exist before `terraform init`.
**How to avoid:** Separate `infra/bootstrap/` directory with local state. Run it first, then configure backend in environment directories.
**Warning signs:** "Error: Failed to get existing workspaces" during `terraform init`.

### Pitfall 2: Forgetting `prevent_destroy` on State Bucket
**What goes wrong:** Accidental `terraform destroy` deletes the state bucket, losing all state files.
**Why it happens:** Bootstrap resources look like any other resource.
**How to avoid:** Add `lifecycle { prevent_destroy = true }` to the S3 bucket and enable versioning.
**Warning signs:** State bucket appears in `terraform plan -destroy` output.

### Pitfall 3: RDS Final Snapshot Blocking Destroy
**What goes wrong:** `terraform destroy` hangs or fails because RDS wants to create a final snapshot.
**Why it happens:** `skip_final_snapshot` defaults to `false`.
**How to avoid:** Set `skip_final_snapshot = true` for learning/staging environments. Set `final_snapshot_identifier` for production.
**Warning signs:** Destroy takes 10+ minutes on the RDS step.

### Pitfall 4: Security Group Circular Dependencies
**What goes wrong:** Two security groups referencing each other cause Terraform dependency cycles.
**Why it happens:** SG A allows traffic from SG B, and SG B allows traffic from SG A.
**How to avoid:** Use `aws_security_group_rule` as separate resources instead of inline `ingress`/`egress` blocks.
**Warning signs:** "Error: Cycle" in terraform plan.

### Pitfall 5: RDS Proxy IAM Role Trust Policy
**What goes wrong:** RDS Proxy cannot read Secrets Manager credentials.
**Why it happens:** Missing trust policy allowing `rds.amazonaws.com` to assume the IAM role, or missing policy granting `secretsmanager:GetSecretValue`.
**How to avoid:** Always define both the trust policy (assume role) and the permissions policy (secrets access).
**Warning signs:** RDS Proxy stuck in "creating" state for 10+ minutes, then fails.

### Pitfall 6: Subnet Group Requires Multiple AZs
**What goes wrong:** RDS subnet group creation fails.
**Why it happens:** `aws_db_subnet_group` requires subnets in at least 2 different AZs, even for single-AZ deployments.
**How to avoid:** Always create private subnets in 2+ AZs. Single-AZ just means the instance runs in one, but the subnet group must span multiple.
**Warning signs:** "DBSubnetGroupDoesNotCoverEnoughAZs" error.

### Pitfall 7: Application DATABASE_URL Must Point to Proxy
**What goes wrong:** App connects directly to RDS, bypassing the proxy.
**Why it happens:** DATABASE_URL still uses the RDS endpoint instead of the RDS Proxy endpoint.
**How to avoid:** Output the proxy endpoint from Terraform and use it in the app's .env. The proxy endpoint replaces the direct RDS endpoint.
**Warning signs:** Connection count on RDS matches app instances (no pooling benefit).

## Code Examples

### RDS PostgreSQL Instance
```hcl
# Source: HashiCorp AWS Provider docs + Terraform Registry
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [module.vpc.rds_sg_id]

  multi_az            = false  # Single-AZ for cost savings
  publicly_accessible = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  skip_final_snapshot       = true  # For learning; use false in real production
  final_snapshot_identifier = "${var.environment}-final-snapshot"

  tags = {
    Name        = "${var.environment}-postgres"
    Environment = var.environment
  }
}
```

### EC2 Instance with Latest Amazon Linux 2023 AMI
```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [module.vpc.app_sg_id]
  key_name               = var.key_pair_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name        = "${var.environment}-app"
    Environment = var.environment
  }
}
```

### VPC Module Call from Environment
```hcl
# infra/staging/main.tf
module "vpc" {
  source = "../modules/vpc"

  environment          = "staging"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["ap-southeast-1a", "ap-southeast-1b"]
}
```

### Terraform Outputs for Application Config
```hcl
# infra/staging/outputs.tf
output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint -- use this as DATABASE_URL host"
  value       = aws_db_proxy.main.endpoint
}

output "rds_direct_endpoint" {
  description = "Direct RDS endpoint -- for admin/migration use only"
  value       = aws_db_instance.main.address
}

output "ec2_public_ip" {
  description = "Public IP of the app server"
  value       = aws_instance.app.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes"
  value       = aws_ecr_repository.app.repository_url
}
```

## Cost Estimation (Learning Environment)

| Resource | Instance/Config | Est. Monthly Cost |
|----------|----------------|-------------------|
| EC2 (t3.micro) | 1 instance, on-demand | ~$8.50 |
| RDS (db.t4g.micro) | Single-AZ, 20GB gp3 | ~$14.00 |
| RDS Proxy | 2 vCPUs (db.t4g.micro) | ~$21.90 |
| S3 (state) | Minimal storage | ~$0.05 |
| DynamoDB (locks) | PAY_PER_REQUEST | ~$0.00 |
| ECR | Minimal storage | ~$0.50 |
| Secrets Manager | 1 secret | ~$0.40 |
| **Total (staging only)** | | **~$45/month** |

**Cost note:** RDS Proxy at ~$22/month is the most expensive component for a learning environment. The CONTEXT.md decision includes it, and it teaches a real production pattern. The destroy+rebuild exercise is critical for cost control -- destroy when not studying.

**Multi-AZ reference cost:** Adding Multi-AZ to RDS roughly doubles the RDS cost (~$28 instead of ~$14). This is why the decision is single-AZ deploy with Multi-AZ shown as reference config.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DynamoDB state locking | S3 native locking (`use_lockfile`) | Terraform 1.10 (late 2024) | DynamoDB still works but is deprecated; S3 native is simpler |
| AWS Provider v5 | AWS Provider v6 | April 2026 | Multi-region improvements, S3 encryption defaults changed |
| Inline SG rules | Separate `aws_security_group_rule` | Long-standing best practice | Avoids circular dependencies, easier to read |
| `terraform workspace` for envs | Directory-per-environment | Community consensus | Clearer separation, independent state, no workspace confusion |

**Important note on DynamoDB locking:** The CONTEXT.md decision uses DynamoDB locking, which is the well-established pattern and still fully supported. It also teaches the learner about DynamoDB as a service. The study materials should mention that S3 native locking (`use_lockfile = true`) is the newer alternative, available since Terraform 1.10.

## Open Questions

1. **AWS Region**
   - What we know: Previous phases likely used a specific region (project memory doesn't specify)
   - What's unclear: Which region the learner has been using
   - Recommendation: Planner should use a variable for region; examples can default to `ap-southeast-1` or whichever the learner prefers

2. **RDS Proxy Cost Justification**
   - What we know: ~$22/month is significant for learning
   - What's unclear: Whether learner wants to keep it running long-term
   - Recommendation: Include in Terraform but document how to comment out/skip RDS Proxy resources. The destroy+rebuild exercise mitigates ongoing cost.

3. **ECR Placement (Bootstrap vs App)**
   - What we know: CONTEXT.md says ECR is "bootstrap" infrastructure
   - What's unclear: Whether ECR repos should be in `infra/bootstrap/` or in environment directories
   - Recommendation: Put ECR in bootstrap (repos are shared across environments, not env-specific)

## Sources

### Primary (HIGH confidence)
- [HashiCorp Terraform S3 Backend docs](https://developer.hashicorp.com/terraform/language/backend/s3) - Backend configuration, locking options
- [HashiCorp AWS Provider Registry](https://registry.terraform.io/providers/hashicorp/aws/latest) - Provider v6.x, resource documentation
- [AWS RDS Proxy pricing](https://aws.amazon.com/rds/proxy/pricing/) - $0.015/vCPU/hour pricing
- [Terraform AWS Provider 6.0 announcement](https://www.hashicorp.com/en/blog/terraform-aws-provider-6-0-now-generally-available) - v6 GA features

### Secondary (MEDIUM confidence)
- [S3 native state locking overview](https://www.bschaatsbergen.com/s3-native-state-locking) - Detailed explanation of `use_lockfile` feature
- [Terraform module best practices](https://oneuptime.com/blog/post/2026-02-23-how-to-use-terraform-module-best-practices-for-large-organizations/view) - Directory structure, naming conventions
- [RDS Proxy Terraform patterns](https://oneuptime.com/blog/post/2026-02-23-how-to-create-rds-proxy-with-terraform/view) - Configuration examples

### Tertiary (LOW confidence)
- RDS Proxy monthly cost estimate (~$22 for db.t4g.micro) - calculated from per-vCPU pricing; actual billing depends on region

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Terraform and AWS provider are mature, well-documented, versions verified
- Architecture: HIGH - Directory-per-environment and module patterns are well-established community consensus
- Pitfalls: HIGH - Common issues well-documented across multiple sources (subnet AZ requirements, final snapshot, bootstrap chicken-and-egg)
- Cost estimates: MEDIUM - Based on published pricing but actual costs vary by region and usage
- RDS Proxy config: MEDIUM - Configuration patterns verified but IAM role setup has many moving parts

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (stable domain, 30 days)
