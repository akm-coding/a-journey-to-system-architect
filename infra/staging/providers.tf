# =============================================================================
# Staging Environment: Provider and Backend Configuration
# =============================================================================
#
# This file configures:
#   1. Terraform version constraints
#   2. Remote state storage in S3 (created by bootstrap)
#   3. AWS provider with region from variable
#
# PREREQUISITE: Run infra/bootstrap first to create the S3 bucket and
# DynamoDB table referenced in the backend block below.
#
#   cd infra/bootstrap
#   terraform init
#   terraform apply -var="project_name=journey"
#
# Then come back here:
#   cd infra/staging
#   terraform init
#   terraform plan
# =============================================================================

terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state stored in S3 with DynamoDB locking.
  # These values come from bootstrap outputs -- run bootstrap first.
  # The "key" path separates staging state from production state
  # in the same S3 bucket.
  backend "s3" {
    bucket         = "journey-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "journey-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
