# Terraform Cheatsheet

Quick reference for Terraform CLI commands, HCL syntax patterns, and common configurations.

---

## CLI Commands

### Core Lifecycle

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `terraform init` | Downloads providers, initializes backend | First time in a directory, or after adding providers/modules |
| `terraform plan` | Shows what would change (dry run) | Before every apply -- always review the plan |
| `terraform apply` | Creates/updates/destroys resources | After reviewing the plan output |
| `terraform destroy` | Removes all managed resources | End of study session (cost control) |

### Formatting and Validation

| Command | What It Does |
|---------|-------------|
| `terraform fmt` | Auto-formats `.tf` files to canonical style |
| `terraform fmt -check` | Checks formatting without changing files (CI use) |
| `terraform validate` | Checks config syntax and internal consistency |

### Inspecting State

| Command | What It Does |
|---------|-------------|
| `terraform output` | Shows all outputs from last apply |
| `terraform output <name>` | Shows a specific output value |
| `terraform state list` | Lists all resources in state |
| `terraform state show <resource>` | Shows details of a specific resource |

### State Management (Use with Caution)

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `terraform state rm <resource>` | Removes a resource from state (does NOT delete it from AWS) | When you want Terraform to "forget" a resource |
| `terraform force-unlock <ID>` | Releases a stuck state lock | After a crash during apply (verify no one else is running first) |
| `terraform import <resource> <id>` | Imports existing AWS resource into state | Adopting manually-created resources (not used in this project) |

---

## Common Flags

| Flag | Command | What It Does |
|------|---------|-------------|
| `-auto-approve` | apply, destroy | Skips the confirmation prompt (use in scripts, never interactively) |
| `-target=<resource>` | plan, apply | Only plan/apply a specific resource |
| `-var="key=value"` | plan, apply | Sets a variable value |
| `-var-file="file.tfvars"` | plan, apply | Loads variables from a file |
| `-out=plan.tfplan` | plan | Saves plan to a file for exact replay |
| `-input=false` | apply | Fails if any variable is missing (CI use) |

---

## HCL Syntax Patterns

### Resource Block

```hcl
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = local.common_tags
}
```

### Data Source Block

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

### Variable Block

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Must be t3.micro, t3.small, or t3.medium."
  }
}
```

### Output Block

```hcl
output "public_ip" {
  description = "Public IP of the app server"
  value       = aws_instance.app.public_ip
}
```

### Locals Block

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

### Module Call

```hcl
module "vpc" {
  source = "../modules/vpc"

  vpc_cidr    = "10.0.0.0/16"
  environment = "staging"
}
```

### Lifecycle Rules

```hcl
resource "aws_s3_bucket" "state" {
  bucket = "my-state-bucket"

  lifecycle {
    prevent_destroy = true   # Terraform refuses to destroy this resource
  }
}
```

---

## Backend Configuration

### S3 Backend (for environment directories)

```hcl
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

### Local Backend (for bootstrap -- the default)

No backend block needed. Terraform uses local state by default.

---

## Variable Precedence (Highest to Lowest)

1. `-var` flag on command line
2. `-var-file` flag on command line
3. `*.auto.tfvars` files (alphabetical order)
4. `terraform.tfvars` file
5. `TF_VAR_<name>` environment variables
6. Variable `default` value
7. Interactive prompt (if no default and no value provided)

---

## Reference Syntax

| What | Syntax | Example |
|------|--------|---------|
| Resource attribute | `<type>.<name>.<attr>` | `aws_instance.app.public_ip` |
| Data source attribute | `data.<type>.<name>.<attr>` | `data.aws_ami.al2023.id` |
| Variable | `var.<name>` | `var.aws_region` |
| Local value | `local.<name>` | `local.common_tags` |
| Module output | `module.<name>.<output>` | `module.vpc.vpc_id` |

---

## Plan Output Symbols

| Symbol | Meaning |
|--------|---------|
| `+` | Resource will be created |
| `-` | Resource will be destroyed |
| `~` | Resource will be updated in-place |
| `-/+` | Resource will be destroyed and recreated |
| `<=` | Data source will be read |

---

## Common Patterns

### Tagging All Resources

```hcl
locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_instance" "app" {
  # ...
  tags = merge(local.common_tags, { Name = "${var.project_name}-app" })
}
```

### Sensitive Variables

```bash
# Set via environment variable (never in .tfvars)
export TF_VAR_db_password="your-secret-password"
terraform apply
```

### Targeted Operations

```bash
# Only apply changes to one resource
terraform apply -target=aws_instance.app

# Only destroy one resource
terraform destroy -target=aws_instance.app
```

---

## File Naming Convention

| File | Purpose |
|------|---------|
| `main.tf` | Primary resources |
| `variables.tf` | Input variable declarations |
| `outputs.tf` | Output declarations |
| `providers.tf` | Provider and backend configuration |
| `terraform.tfvars` | Variable values (non-sensitive) |
| `*.tf` | Additional resources by type (e.g., `ec2.tf`, `rds.tf`) |
