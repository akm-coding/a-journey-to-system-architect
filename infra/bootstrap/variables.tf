# =============================================================================
# Variables for Bootstrap Infrastructure
# =============================================================================
#
# Bootstrap infrastructure is SHARED across all environments (staging,
# production). There is no "environment" variable here because these
# resources exist once per project, not once per environment.
#
# The S3 bucket stores state for ALL environments (separated by key path),
# the DynamoDB table locks ALL state operations, and the ECR repository
# holds images used by ALL environments.
# =============================================================================

variable "aws_region" {
  description = "AWS region where bootstrap resources will be created"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names (e.g., 'journey' produces 'journey-terraform-state')"
  type        = string

  validation {
    condition     = length(var.project_name) >= 3
    error_message = "Project name must be at least 3 characters long."
  }

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}
