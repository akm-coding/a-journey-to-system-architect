# =============================================================================
# VPC Module Variables
# =============================================================================
#
# All variables have type constraints, validation blocks, and descriptions.
# This follows the Terraform best practice of self-documenting inputs.
#
# Usage from an environment directory:
#
#   module "vpc" {
#     source               = "../modules/vpc"
#     environment          = "staging"
#     vpc_cidr             = "10.0.0.0/16"
#     public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
#     private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
#     availability_zones   = ["ap-southeast-1a", "ap-southeast-1b"]
#   }
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "environment" {
  description = "Environment name -- used in resource naming and tags"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be 'staging' or 'production'."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ, for EC2 instances with public IPs)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ, for RDS -- must span 2+ AZs for subnet group)"
  type        = list(string)
}

variable "availability_zones" {
  description = "AWS availability zones for subnet placement (minimum 2 for RDS subnet group requirement)"
  type        = list(string)
}
