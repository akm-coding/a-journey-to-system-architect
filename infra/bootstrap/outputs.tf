# =============================================================================
# Outputs from Bootstrap Infrastructure
# =============================================================================
#
# These values are needed when configuring environment directories.
# After running `terraform apply`, view them with:
#
#   terraform output
#
# Then copy the bucket name and table name into your environment's
# backend "s3" block in providers.tf.
# =============================================================================

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state -- use in environment backend config"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket -- for IAM policies if needed"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking -- use in environment backend config"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes (used by CI/CD pipeline and manual deploys)"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name (without registry prefix)"
  value       = aws_ecr_repository.app.name
}
