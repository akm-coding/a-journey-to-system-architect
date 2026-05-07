# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: Provider and Backend Configuration
# =============================================================================
#
# Same structure as staging/providers.tf but with a DIFFERENT state key.
# This ensures staging and production state are completely isolated.
# You can destroy staging without affecting production, and vice versa.
#
# PREREQUISITE: Run infra/bootstrap first (same as staging).
# =============================================================================

terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Production state is stored at a DIFFERENT key path than staging.
  # Same bucket, different key -- this is the environment separation pattern.
  backend "s3" {
    bucket         = "journey-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "journey-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
