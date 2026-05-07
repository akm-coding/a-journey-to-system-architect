# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: Outputs
# =============================================================================
#
# Same outputs as staging. After `terraform apply`, view with:
#   terraform output
#
# The rds_proxy_endpoint is the most important -- it's what goes in
# the app's DATABASE_URL environment variable.
# =============================================================================

output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint -- use this as DATABASE_URL host in the app's .env"
  value       = aws_db_proxy.main.endpoint
}

output "rds_direct_endpoint" {
  description = "Direct RDS endpoint -- for admin/migration use only (bypass proxy for drizzle-kit push)"
  value       = aws_db_instance.main.address
}

output "ec2_public_ip" {
  description = "Public IP of the app server -- use for SSH access and browser testing"
  value       = aws_instance.app.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID -- needed for aws ec2 commands and console lookup"
  value       = aws_instance.app.id
}

output "vpc_id" {
  description = "VPC ID -- useful for verifying resources are in the correct network"
  value       = module.vpc.vpc_id
}
