# Phase 5: Terraform and Infrastructure as Code

In every previous phase, you built infrastructure by clicking through the AWS Console or running CLI commands one at a time. You created a VPC here, an EC2 instance there, an RDS database somewhere else. It worked -- but the knowledge of *what you built* lived in your head and in scattered console screens. If you needed to rebuild it, you'd have to remember every step.

Infrastructure as Code changes that. Instead of clicking buttons, you write configuration files that describe what you want. A tool reads those files and creates the infrastructure for you. Delete everything and run it again -- you get the exact same setup. That's the core promise.

This guide covers Terraform, the most widely-used IaC tool, and the concepts you need before writing your first `.tf` files.

---

## What Is Infrastructure as Code?

Infrastructure as Code (IaC) means defining your infrastructure -- servers, databases, networks, DNS records, everything -- in text files that are version-controlled, reviewable, and repeatable.

### Declarative vs Imperative

There are two approaches to IaC:

**Imperative** (step-by-step instructions):
```
1. Create a VPC with CIDR 10.0.0.0/16
2. Create a subnet in that VPC
3. Create an internet gateway
4. Attach the gateway to the VPC
5. Create a route table...
```

**Declarative** (describe the end state):
```
I want:
- A VPC with CIDR 10.0.0.0/16
- A subnet in that VPC
- An internet gateway attached to the VPC
- A route table with a default route to the gateway
```

Terraform is declarative. You describe *what you want*, and Terraform figures out the steps to get there. If you change the description, Terraform figures out what needs to change, what needs to be created, and what needs to be destroyed.

> **WHY declarative?** Imperative scripts break when you run them twice (creating a VPC that already exists throws an error). Declarative configs are idempotent -- run them ten times and you get the same result. This matters when things go wrong mid-deploy and you need to retry.

### Why Not Just Use the Console?

The AWS Console is great for exploration, but terrible for:

- **Reproducibility**: Can you rebuild your entire environment from scratch in 10 minutes? With IaC, yes.
- **Collaboration**: How do you tell your teammate what you changed? With IaC, it's a git diff.
- **Auditability**: Who changed what, when? With IaC, it's git log.
- **Cost control**: How do you tear down everything at the end of a study session? With IaC, one command: `terraform destroy`.
- **Consistency**: Are staging and production actually the same? With IaC, they share the same modules with different variables.

---

## Terraform vs Alternatives

Terraform is not the only IaC tool. Here's how the major options compare:

| Feature | Terraform | CloudFormation | Pulumi | CDK |
|---------|-----------|---------------|--------|-----|
| **Language** | HCL (domain-specific) | YAML/JSON | TypeScript/Python/Go | TypeScript/Python/Go |
| **Cloud support** | Multi-cloud (AWS, GCP, Azure, etc.) | AWS only | Multi-cloud | AWS only (generates CloudFormation) |
| **State management** | You manage it (S3 + DynamoDB) | AWS manages it | You manage it | AWS manages it |
| **Learning curve** | Moderate (new language, but simple) | Low for AWS users | Low if you know the language | Low if you know the language |
| **Community** | Largest, most examples | Good for AWS | Growing | Growing |
| **Maturity** | Very mature | Very mature | Mature | Mature |
| **License** | BSL (free for individual use) | Free (AWS service) | Open source | Open source |

> **WHY Terraform for this project?** Three reasons: (1) industry standard -- most job postings that mention IaC mention Terraform, (2) multi-cloud knowledge transfers even if you only use AWS now, (3) managing your own state teaches you more about how infrastructure tooling works under the hood. CloudFormation hides state management, which is convenient but means you learn less.

**Tradeoffs to be honest about:**
- Terraform's HCL is a new language to learn (Pulumi/CDK let you use TypeScript, which you already know)
- Managing state is your responsibility (CloudFormation handles this automatically)
- BSL license means HashiCorp controls the direction (OpenTofu exists as a community fork)

---

## HCL Syntax Fundamentals

HCL (HashiCorp Configuration Language) is Terraform's configuration language. It's designed to be human-readable while being machine-parseable.

### Blocks

Everything in HCL is organized into blocks. A block has a type, zero or more labels, and a body:

```hcl
block_type "label_1" "label_2" {
  attribute = "value"
}
```

The main block types you'll use:

#### resource -- Creates Infrastructure

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "my-app-server"
  }
}
```

The first label (`aws_instance`) is the resource type. The second label (`app`) is the local name you choose. Together, `aws_instance.app` is how you reference this resource elsewhere.

#### data -- Reads Existing Infrastructure

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

Data sources don't create anything. They look up existing resources and make their attributes available. Use `data.aws_ami.amazon_linux.id` to reference the result.

#### variable -- Accepts Input

```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}
```

#### output -- Exposes Values

```hcl
output "instance_public_ip" {
  description = "Public IP of the app server"
  value       = aws_instance.app.public_ip
}
```

#### locals -- Computed Constants

```hcl
locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
```

Use `local.common_tags` to reference. Locals are like constants computed from variables -- they reduce repetition.

#### module -- Reusable Group of Resources

```hcl
module "vpc" {
  source = "../modules/vpc"

  vpc_cidr    = "10.0.0.0/16"
  environment = "staging"
}
```

### Attributes and Expressions

Attributes use `=` for assignment:

```hcl
instance_type = "t3.micro"           # String
count         = 2                     # Number
enabled       = true                  # Boolean
tags          = { Name = "app" }      # Map
subnet_ids    = ["subnet-a", "sub-b"] # List
```

### String Interpolation

Embed expressions inside strings with `${}`:

```hcl
name = "${var.project_name}-${var.environment}-app"
# Result: "myproject-staging-app"
```

### References

Resources reference each other by their address:

```hcl
# Reference another resource's attribute
subnet_id = aws_subnet.public.id

# Reference a variable
region = var.aws_region

# Reference a data source
ami = data.aws_ami.amazon_linux.id

# Reference a module output
vpc_id = module.vpc.vpc_id

# Reference a local value
tags = local.common_tags
```

> **GOTCHA:** References create implicit dependencies. Terraform knows that an EC2 instance referencing `aws_subnet.public.id` must wait for the subnet to be created first. You rarely need to declare dependencies explicitly.

### Type System

HCL has a simple type system:

| Type | Example | Usage |
|------|---------|-------|
| `string` | `"hello"` | Names, IDs, ARNs |
| `number` | `42` | Counts, port numbers |
| `bool` | `true` | Feature flags |
| `list(type)` | `["a", "b"]` | Subnet CIDRs, AZ lists |
| `map(type)` | `{ key = "val" }` | Tags, labels |
| `object({...})` | `{ name = string, port = number }` | Structured configs |

---

## Providers

Providers are plugins that let Terraform talk to cloud platforms, SaaS tools, and other APIs. The AWS provider translates your HCL into AWS API calls.

### Configuring the AWS Provider

```hcl
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

### Version Pinning

The `~>` operator means "compatible with":
- `~> 6.0` allows `6.0`, `6.1`, `6.99` -- but NOT `7.0`
- `~> 6.0.0` allows `6.0.0`, `6.0.1` -- but NOT `6.1.0`

> **WHY pin versions?** Without pinning, `terraform init` downloads the latest provider version. A major version bump (v5 to v6) can break your configs. Pinning to `~> 6.0` accepts patches and minor updates (safe) but blocks breaking changes (unsafe).

### Provider Authentication

The AWS provider reads credentials from the standard locations (in priority order):
1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. IAM instance profile (on EC2)

You configured AWS CLI credentials in Phase 1 -- Terraform uses the same credentials automatically.

---

## Resources and Data Sources

### Resources Create Infrastructure

A resource block tells Terraform to create and manage a piece of infrastructure:

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "myproject-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}
```

Every resource has:
- A **type** (`aws_s3_bucket`) -- determines what the provider creates
- A **local name** (`terraform_state`) -- how you refer to it in your config
- **Arguments** (`bucket = "..."`) -- configuration for the resource
- **Attributes** (computed after creation) -- like `id`, `arn`, `region`

### Data Sources Read Existing Infrastructure

Data sources query the cloud for resources that already exist:

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

# Use it in a resource
resource "aws_instance" "app" {
  ami = data.aws_ami.amazon_linux_2023.id
  # ...
}
```

> **WHY use a data source for AMIs?** AMI IDs are different in every AWS region and change when Amazon releases updates. Hardcoding `ami-0c55b159cbfafe1f0` works in us-east-1 today but breaks in ap-southeast-1 or next month. The data source always finds the latest matching AMI.

---

## Variables and Outputs

### Variable Declarations

Variables make your configs reusable. Declare them in `variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string

  validation {
    condition     = length(var.project_name) >= 3
    error_message = "Project name must be at least 3 characters."
  }
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true  # Hidden in plan/apply output
}
```

### Setting Variable Values

Variables get their values from multiple sources (in priority order, highest wins):

| Method | When to Use | Example |
|--------|-------------|---------|
| `terraform.tfvars` | Default values for an environment | `aws_region = "ap-southeast-1"` |
| `-var-file` flag | Alternate variable files | `terraform apply -var-file="prod.tfvars"` |
| `-var` flag | One-off overrides | `terraform apply -var="instance_type=t3.small"` |
| `TF_VAR_` env vars | Secrets (never commit to git) | `export TF_VAR_db_password="secret123"` |

> **GOTCHA:** Never put passwords or secrets in `.tfvars` files that are committed to git. Use `TF_VAR_` environment variables or AWS Secrets Manager for sensitive values. Mark the variable as `sensitive = true` so Terraform redacts it from output.

### Outputs

Outputs expose values after `terraform apply`. They're essential for connecting infrastructure:

```hcl
output "state_bucket_name" {
  description = "S3 bucket name for Terraform state storage"
  value       = aws_s3_bucket.terraform_state.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes"
  value       = aws_ecr_repository.app.repository_url
}
```

After apply, view outputs with `terraform output` or `terraform output state_bucket_name`.

---

## State Management

State is the most important concept to understand about Terraform. Get this wrong and you'll lose infrastructure or corrupt your setup.

### What Is State?

Terraform state is a JSON file that maps your configuration to real AWS resources:

```
Your Config (HCL)          State File              AWS (Real World)
-------------------    -------------------    -------------------
aws_instance.app  -->  i-0abc123def456    -->  EC2 instance running
aws_s3_bucket.state -> myproject-state    -->  S3 bucket existing
```

When you run `terraform plan`, Terraform:
1. Reads your `.tf` files (desired state)
2. Reads the state file (last known state)
3. Queries AWS (actual state)
4. Computes the diff

Without state, Terraform wouldn't know which AWS resources correspond to which config blocks. It would try to create everything from scratch every time.

### Local vs Remote State

**Local state** (`terraform.tfstate` file on your machine):
- Simple, works immediately
- Only one person can use it
- Lost if your laptop dies
- No locking (concurrent runs can corrupt it)

**Remote state** (S3 bucket):
- Shared across team members
- Backed up with versioning
- Locked during operations (prevents concurrent corruption)
- Required for any real project

### S3 Backend with DynamoDB Locking

The standard remote state setup for AWS:

```
                         terraform plan/apply
                                |
                    +-----------+-----------+
                    |                       |
              Read/Write State        Lock/Unlock
                    |                       |
              +-----v-----+         +------v------+
              |  S3 Bucket |         |  DynamoDB   |
              | (state.json)|        | (lock table) |
              +-----+-----+         +------+------+
                    |                       |
              Versioning               Prevents
              (rollback)              concurrent
                                      operations
```

**S3 stores the state file** with versioning enabled. If something goes wrong, you can roll back to a previous state version.

**DynamoDB provides locking.** When you run `terraform apply`, Terraform writes a lock record to DynamoDB. If someone else tries to run `terraform apply` at the same time, they get a "state locked" error. This prevents two people from modifying infrastructure simultaneously, which would corrupt the state.

```hcl
# In your environment's providers.tf
terraform {
  backend "s3" {
    bucket         = "myproject-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

> **WHY DynamoDB for locking?** You might wonder why not just use S3 locking. Actually, Terraform 1.10+ supports S3 native locking (`use_lockfile = true`) which eliminates the DynamoDB table entirely. It's simpler and cheaper. We use DynamoDB in this project because (1) it's the well-established pattern you'll encounter in most existing codebases, and (2) it teaches you about DynamoDB as a service. Know that the newer S3-native approach exists for greenfield projects.

### State Contains Secrets

The state file contains every attribute of every resource -- including database passwords, access keys, and other secrets. This is another reason state must be stored securely (encrypted S3 bucket, not committed to git).

> **GOTCHA:** Never commit `terraform.tfstate` to git. Add it to `.gitignore`. The S3 backend handles state storage; you don't need the local file.

---

## Modules

Modules are reusable groups of Terraform resources. Think of them like functions -- they accept inputs (variables), create resources, and return outputs.

### Why Modules?

Without modules, your staging and production environments would duplicate every resource definition. When you need to change a security group rule, you'd change it in two places. Modules solve this:

```
infra/
├── modules/
│   └── vpc/              # Define once
│       ├── main.tf       # VPC, subnets, IGW, route tables, SGs
│       ├── variables.tf  # CIDR blocks, AZ config
│       └── outputs.tf    # vpc_id, subnet_ids, sg_ids
├── staging/
│   └── main.tf           # module "vpc" { source = "../modules/vpc" ... }
└── production/
    └── main.tf           # module "vpc" { source = "../modules/vpc" ... }
```

Both environments use the same VPC module but with different variable values. Change the module, and both environments get the update.

### Module Structure

A module is just a directory with `.tf` files:

```hcl
# modules/vpc/variables.tf -- Module inputs
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# modules/vpc/main.tf -- Module resources
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${var.environment}-vpc" }
}

# modules/vpc/outputs.tf -- Module outputs
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}
```

### Calling a Module

```hcl
# staging/main.tf
module "vpc" {
  source = "../modules/vpc"

  environment          = "staging"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

# Use module outputs
resource "aws_instance" "app" {
  subnet_id = module.vpc.public_subnet_ids[0]
}
```

> **WHY not start with modules everywhere?** For this project, we build the VPC module in Plan 02 because it's used by both staging and production. Bootstrap infrastructure (Plan 01) is a one-off -- it doesn't need a module because there's only one state bucket. Extract modules when you see duplication, not preemptively.

### Preview: The VPC Module

In Plan 02, you'll build a VPC module that creates:
- VPC with configurable CIDR block
- Public subnets (for EC2, load balancers)
- Private subnets (for RDS, in 2+ AZs)
- Internet gateway and route tables
- Security groups (app, RDS, RDS Proxy)

Both staging and production will call this module with different CIDR blocks and settings.

---

## The Terraform Lifecycle

Terraform has four core commands that form a development loop:

```
    terraform init          terraform plan          terraform apply         terraform destroy
         |                       |                       |                        |
    Download providers      Compare config           Execute changes         Remove everything
    Initialize backend      to actual state          Create/update/delete    Reverse of apply
    Set up modules          Show what WOULD          resources               Clean teardown
                            change (dry run)
         |                       |                       |                        |
    Run ONCE per             Run EVERY time           Run after reviewing      Run when done
    new directory            before apply             the plan output          (cost control!)
```

### terraform init

The first command you run in any Terraform directory. It:
1. Downloads the providers specified in `required_providers`
2. Initializes the backend (local or S3)
3. Downloads modules from their sources

```bash
$ terraform init

Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.0.1...

Terraform has been successfully initialized!
```

You run this once when you first set up a directory, and again when you add new providers or modules.

### terraform plan

Shows what Terraform *would do* without actually doing it:

```bash
$ terraform plan

Terraform will perform the following actions:

  # aws_instance.app will be created
  + resource "aws_instance" "app" {
      + ami           = "ami-0c55b159cbfafe1f0"
      + instance_type = "t3.micro"
      + id            = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

The symbols mean:
- `+` = will be created
- `~` = will be modified in-place
- `-` = will be destroyed
- `-/+` = will be destroyed and recreated (replacement)

> **WHY always plan before apply?** `terraform plan` is your safety net. It shows you exactly what will happen. A plan that says "0 to destroy" when you expected changes means something is wrong with your config. Catching this before apply prevents accidental destruction.

### terraform apply

Executes the plan. Creates, modifies, or destroys resources:

```bash
$ terraform apply

# Shows the plan first, then asks:
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_instance.app: Creating...
aws_instance.app: Creation complete after 32s [id=i-0abc123def456]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### terraform destroy

Removes everything managed by the current configuration:

```bash
$ terraform destroy

# Shows what will be destroyed, asks for confirmation
Plan: 0 to add, 0 to change, 5 to destroy.

Do you really want to destroy all resources?
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

> **WHY destroy matters for learning:** AWS charges by the hour/second. When you're done studying for the day, `terraform destroy` tears down everything. Next session, `terraform apply` rebuilds it. This is the IaC superpower -- infrastructure is disposable and reproducible.

### State Locking During Operations

When `terraform apply` runs:
1. Terraform acquires a lock (DynamoDB write)
2. Reads current state from S3
3. Executes changes against AWS
4. Writes updated state to S3
5. Releases the lock (DynamoDB delete)

If the process crashes mid-apply, the lock remains. You can force-unlock with `terraform force-unlock <LOCK_ID>` -- but investigate first, because a stuck lock might mean a partially-applied change.

> **GOTCHA:** If you see "Error acquiring the state lock" and you're the only user, it usually means a previous `terraform apply` crashed or was interrupted. Verify no one else is running Terraform, then use `terraform force-unlock`.

---

## Bootstrap Pattern

Here's the problem: Terraform state needs to be stored in S3, but the S3 bucket is itself infrastructure that needs to be created by Terraform. If the state backend doesn't exist yet, how do you run `terraform init` with an S3 backend?

### The Chicken-and-Egg Problem

```
You want:  terraform init (with S3 backend)
     But:  S3 bucket doesn't exist yet
     And:  You need Terraform to create the S3 bucket
     But:  Terraform needs a backend to store state
     And:  The backend IS the S3 bucket you're trying to create
```

### The Solution: Bootstrap with Local State

Create the state backend resources (S3 bucket + DynamoDB table) in a separate directory that uses local state:

```
infra/
├── bootstrap/          <-- Uses LOCAL state (terraform.tfstate file)
│   ├── main.tf         <-- Creates S3 bucket + DynamoDB table
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf    <-- NO backend block (local state by default)
│
├── staging/            <-- Uses REMOTE state (S3 backend)
│   ├── providers.tf    <-- backend "s3" { bucket = "..." }
│   └── ...
│
└── production/         <-- Uses REMOTE state (S3 backend)
    ├── providers.tf    <-- backend "s3" { bucket = "..." }
    └── ...
```

**Order of operations:**
1. `cd infra/bootstrap && terraform init && terraform apply` -- creates S3 bucket and DynamoDB table (state stored locally)
2. `cd infra/staging && terraform init` -- now the S3 backend exists, init succeeds
3. `cd infra/staging && terraform apply` -- creates staging infrastructure (state stored in S3)

The bootstrap directory's `terraform.tfstate` file stays local. It's the one exception to the "always use remote state" rule -- because it defines the remote state infrastructure itself.

> **GOTCHA:** The bootstrap state file (`infra/bootstrap/terraform.tfstate`) is critical. If you lose it, Terraform loses track of the S3 bucket and DynamoDB table. Don't delete it. The `prevent_destroy` lifecycle rule on the S3 bucket is a safety net, but keep the state file safe too.

This plan (Plan 01) creates the bootstrap directory. Plan 02 creates the environment directories that use the S3 backend.

---

## Cost Estimation

Before running `terraform apply` on anything, you should know what it'll cost. Here's the monthly breakdown for a complete Phase 5 learning environment:

| Resource | Config | Est. Monthly Cost | Notes |
|----------|--------|-------------------|-------|
| EC2 | t3.micro, on-demand | ~$8.50 | Runs the app |
| RDS PostgreSQL | db.t4g.micro, single-AZ, 20GB gp3 | ~$14.00 | Database |
| RDS Proxy | 2 vCPUs (matches db.t4g.micro) | ~$21.90 | Connection pooling |
| S3 (state bucket) | Minimal storage | ~$0.05 | Terraform state files |
| DynamoDB (lock table) | PAY_PER_REQUEST | ~$0.00 | Only charges per request |
| ECR | Minimal image storage | ~$0.50 | Docker images |
| Secrets Manager | 1 secret | ~$0.40 | RDS credentials |
| **Staging total** | | **~$45/month** | |
| **Production total** | Similar | **~$45/month** | If you deploy both |

### Cost Control Strategy

The key to managing costs while learning:

1. **Destroy when not studying**: `terraform destroy` tears down everything. Next time, `terraform apply` rebuilds it in minutes. You only pay for hours resources exist.
2. **Start with staging only**: Don't deploy production until you're testing the full workflow.
3. **RDS Proxy is the expensive one**: At ~$22/month, it's nearly half the cost. The learning value is real (production pattern), but be aware.
4. **Multi-AZ doubles RDS cost**: We deploy single-AZ (~$14) and show Multi-AZ config as reference only (~$28).

> **WHY show the full cost up front?** No surprises. You should know that leaving staging running for a month costs about $45. Destroy+rebuild is how you keep it under $10/month while still learning everything.

---

## Directory Structure

Here's the complete `infra/` directory layout for this phase:

```
infra/
├── bootstrap/                  # Plan 01 (this plan)
│   ├── main.tf                 # S3 state bucket, DynamoDB lock table, ECR repo
│   ├── variables.tf            # Region, project name
│   ├── outputs.tf              # Bucket name, table name, ECR URL
│   └── providers.tf            # Terraform + AWS versions, local backend
│
├── modules/                    # Plan 02
│   └── vpc/                    # Reusable VPC + Security Groups
│       ├── main.tf             # VPC, subnets, IGW, route tables, SGs
│       ├── variables.tf        # CIDR blocks, AZ config, environment name
│       └── outputs.tf          # vpc_id, subnet_ids, security_group_ids
│
├── staging/                    # Plan 02
│   ├── main.tf                 # Module calls, data sources
│   ├── variables.tf            # Environment-specific variables
│   ├── outputs.tf              # Endpoints, IPs, URLs
│   ├── providers.tf            # AWS provider + S3 backend config
│   ├── terraform.tfvars        # Actual staging values
│   ├── ec2.tf                  # App server instance
│   ├── rds.tf                  # PostgreSQL instance + subnet group
│   ├── rds-proxy.tf            # RDS Proxy + IAM + target group
│   └── secrets.tf              # Secrets Manager for DB credentials
│
└── production/                 # Plan 02 (reference config)
    ├── (same structure)
    └── terraform.tfvars        # Production values (larger instances, Multi-AZ ref)
```

**Key principle:** Each directory is an independent Terraform workspace. You run `terraform init` and `terraform apply` separately in each one. Bootstrap first, then environments.

> **WHY split by directory instead of workspaces?** Terraform has a "workspace" feature for managing multiple environments, but the community consensus is that directory-per-environment is clearer. Each directory has its own state file, its own backend key, and you can see exactly what's different between environments by comparing files. Workspaces hide that complexity behind a CLI switch, which makes accidents more likely.

---

## Summary

You now understand the core concepts needed to write Terraform configurations:

| Concept | One-liner |
|---------|-----------|
| IaC | Infrastructure defined in version-controlled text files |
| HCL | Terraform's declarative configuration language |
| Providers | Plugins that connect Terraform to cloud APIs |
| Resources | Blocks that create infrastructure |
| Data sources | Blocks that read existing infrastructure |
| Variables | Parameterized inputs for reusability |
| Outputs | Exposed values for cross-config references |
| State | JSON mapping of config to real resources |
| Remote state | S3 + DynamoDB for shared, locked, versioned state |
| Modules | Reusable groups of resources (like functions) |
| Lifecycle | init -> plan -> apply -> destroy |
| Bootstrap | Local-state directory that creates the remote state backend |

Next up: you'll write the bootstrap `.tf` files and understand every line. Then in Plan 02, you'll build the VPC module and full environment configurations.
