# =============================================================================
# Bootstrap Infrastructure: S3 State Bucket + DynamoDB Lock Table + ECR
# =============================================================================
#
# These resources must exist BEFORE any environment directory can run
# `terraform init` with an S3 backend. Run this first:
#
#   cd infra/bootstrap
#   terraform init
#   terraform plan -var="project_name=journey"
#   terraform apply -var="project_name=journey"
#
# After this apply completes, the S3 bucket and DynamoDB table are ready
# for use in staging/providers.tf and production/providers.tf backend blocks.
# =============================================================================

# Common tags applied to every resource in this directory.
# Keeps tagging consistent and makes it easy to find Terraform-managed
# resources in the AWS Console.
locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "bootstrap"
  }
}

# =============================================================================
# S3 Bucket for Terraform State
# =============================================================================
#
# This bucket stores terraform.tfstate files for all environments.
# Each environment uses a different key path:
#   - staging/terraform.tfstate
#   - production/terraform.tfstate
#
# Versioning is enabled so you can recover from a corrupted state file
# by rolling back to a previous version in the S3 console.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state"

  # prevent_destroy is a critical safety net for the state bucket.
  # If you accidentally run `terraform destroy` in this directory,
  # Terraform will REFUSE to delete this bucket. You'd have to
  # remove the lifecycle block first, which forces you to think twice.
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-terraform-state"
  })
}

# Enable versioning on the state bucket.
# Every time Terraform writes a new state file, S3 keeps the previous
# version. If something goes wrong, you can restore a previous state
# from the S3 console under "Show versions".
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt all objects in the state bucket.
# State files contain sensitive data (database passwords, resource ARNs).
# AES256 is S3-managed encryption -- AWS handles the keys automatically.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block ALL public access to the state bucket.
# State files should never be publicly readable. These four settings
# cover every possible way S3 objects could become public.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# DynamoDB Table for State Locking
# =============================================================================
#
# When `terraform apply` runs, it writes a lock record to this table.
# If another person (or CI job) tries to run `terraform apply` at the
# same time, they get a "state locked" error instead of corrupting state.
#
# The table has a single attribute: LockID (string). Terraform manages
# the lock records automatically -- you never write to this table directly.
#
# PAY_PER_REQUEST billing means you pay per lock/unlock operation.
# For a learning project, this is essentially free (fractions of a cent).

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S" # S = String
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-terraform-locks"
  })
}

# =============================================================================
# ECR Repository
# =============================================================================
#
# ECR (Elastic Container Registry) stores Docker images for the app.
# It's in the bootstrap directory because:
#   1. ECR repos are shared across environments (staging and production
#      pull from the same repo, using different image tags)
#   2. The CI/CD pipeline pushes images here before any environment exists
#   3. Like the state bucket, it's project-level infrastructure, not
#      environment-specific
#
# FORCE_DELETE allows `terraform destroy` to delete the repo even if it
# contains images. Without this, destroy would fail because ECR won't
# delete a non-empty repository by default.

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  # Scan images for known vulnerabilities on push.
  # Free with ECR -- no reason not to enable it.
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-app"
  })
}

# ECR Lifecycle Policy
#
# Without a lifecycle policy, old images accumulate forever and storage
# costs grow. This policy enforces two rules:
#
# Rule 1 (priority 10): Expire untagged images after 7 days.
#   Untagged images are usually leftover build artifacts or replaced
#   "latest" tags. No reason to keep them.
#
# Rule 2 (priority 20): Keep only the last 10 tagged images.
#   This matches the Phase 3 decision. The CI pipeline tags images with
#   commit SHAs, so this keeps the 10 most recent deployable versions.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 10
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 20
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["*"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
