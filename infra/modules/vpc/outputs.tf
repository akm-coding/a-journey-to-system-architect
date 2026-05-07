# =============================================================================
# VPC Module Outputs
# =============================================================================
#
# These outputs are used by the calling environment (staging or production)
# to wire up other resources to the VPC. For example:
#
#   module "vpc" { source = "../modules/vpc" ... }
#
#   resource "aws_instance" "app" {
#     subnet_id              = module.vpc.public_subnet_ids[0]
#     vpc_security_group_ids = [module.vpc.app_sg_id]
#   }
#
# All outputs have descriptions so `terraform output` is self-documenting.
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (for EC2 instances)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (for RDS subnet group -- spans 2+ AZs)"
  value       = aws_subnet.private[*].id
}

output "app_sg_id" {
  description = "Security group ID for app EC2 instances (allows HTTP, HTTPS, SSH inbound)"
  value       = aws_security_group.app.id
}

output "rds_sg_id" {
  description = "Security group ID for RDS instances (allows PostgreSQL from RDS Proxy only)"
  value       = aws_security_group.rds.id
}

output "rds_proxy_sg_id" {
  description = "Security group ID for RDS Proxy (allows PostgreSQL from app, to RDS)"
  value       = aws_security_group.rds_proxy.id
}
