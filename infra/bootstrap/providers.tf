# =============================================================================
# Terraform and Provider Configuration (Bootstrap)
# =============================================================================
#
# This is the bootstrap directory -- it creates the S3 bucket and DynamoDB
# table that all OTHER Terraform directories use for remote state storage.
#
# IMPORTANT: There is NO backend block here. This is intentional.
# The bootstrap directory uses LOCAL state (a terraform.tfstate file on disk)
# because it creates the very infrastructure that remote state depends on.
# This is the "chicken-and-egg" pattern:
#   - Environment directories (staging/, production/) need an S3 bucket for state
#   - This directory creates that S3 bucket
#   - Therefore, this directory cannot use S3 for its own state
#
# The terraform.tfstate file in this directory is the ONE exception to the
# "always use remote state" rule. Keep it safe -- if you lose it, Terraform
# loses track of the state bucket and lock table.
# =============================================================================

terraform {
  # Minimum Terraform version required
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # ~> 6.0 means: accept 6.x versions (patches and minor updates)
      # but block 7.0+ (potential breaking changes)
    }
  }

  # No backend block = local state (terraform.tfstate file in this directory)
}

provider "aws" {
  region = var.aws_region

  # The provider reads credentials from your AWS CLI configuration
  # (set up in Phase 1). No credentials are hardcoded here.
}
