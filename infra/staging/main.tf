# =============================================================================
# Staging Environment: VPC Module Call
# =============================================================================
#
# This is the ONLY place where the VPC module is configured for staging.
# All network resources (VPC, subnets, IGW, route tables, security groups)
# are created by the module. We just pass in staging-specific values.
#
# The production environment calls the SAME module with different CIDRs.
# This is the power of Terraform modules: one source, multiple deployments.
# =============================================================================

module "vpc" {
  source = "../modules/vpc"

  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"

  # Public subnets: EC2 instances live here (internet-accessible)
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

  # Private subnets: RDS lives here (no internet access)
  # Two subnets in different AZs required for RDS subnet group
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # Two AZs for high availability subnet placement
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
}
