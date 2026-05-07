# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: VPC Module Call
# =============================================================================
#
# Same module as staging, but with a DIFFERENT CIDR range (10.1.0.0/16).
# This avoids CIDR overlap in case you ever need to peer the VPCs.
#
# This is the power of Terraform modules: write the VPC module once,
# deploy it with different parameters for each environment.
# =============================================================================

module "vpc" {
  source = "../modules/vpc"

  environment = var.environment

  # Production uses 10.1.0.0/16 to avoid overlap with staging (10.0.0.0/16).
  # CIDR overlap would prevent VPC peering if ever needed.
  vpc_cidr = "10.1.0.0/16"

  # Public subnets: EC2 instances live here
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]

  # Private subnets: RDS lives here (2 AZs required for subnet group)
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]

  # Same AZs as staging -- region availability zones don't change
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
}
