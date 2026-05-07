# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment Variables
# =============================================================================
#
# Same variables as staging. The only difference is the default values
# in terraform.tfvars. This consistency makes it easy to reason about
# what each environment needs.
#
# Sensitive values passed via environment variables:
#   TF_VAR_db_username=produser TF_VAR_db_password=prodpass terraform plan
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used as prefix for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (staging or production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be 'staging' or 'production'."
  }
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro for learning, t3.small+ for real production)"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "EC2 key pair name -- must already exist in AWS (create via Console or aws ec2 create-key-pair)"
  type        = string
}

variable "db_name" {
  description = "Name of the PostgreSQL database to create"
  type        = string
  default     = "ecommerce"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "db_username" {
  description = "Master username for the RDS instance (passed via TF_VAR_db_username)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance (passed via TF_VAR_db_password)"
  type        = string
  sensitive   = true
}
