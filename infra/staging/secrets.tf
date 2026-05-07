# =============================================================================
# Staging Environment: Secrets Manager + IAM Role for RDS Proxy
# =============================================================================
#
# RDS Proxy requires database credentials stored in AWS Secrets Manager.
# It cannot read them from Terraform variables or environment variables.
#
# The setup has two parts:
#   1. Secret: Stores DB credentials as a JSON object
#   2. IAM Role: Allows RDS Proxy to read the secret
#
# Without both, RDS Proxy will get stuck in "creating" state and
# eventually fail. (See RESEARCH.md pitfall #5)
# =============================================================================

# -----------------------------------------------------------------------------
# Secrets Manager Secret
# -----------------------------------------------------------------------------
#
# The secret stores database credentials in the format RDS Proxy expects:
# { username, password, engine, host, port, dbname }
#
# The host is set to the RDS instance address (resolved after RDS is created).

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}-db-credentials"

  tags = {
    Name        = "${var.environment}-db-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # RDS Proxy reads this JSON to authenticate with the database.
  # The "engine" and "port" fields are required by the RDS Proxy auth format.
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

# -----------------------------------------------------------------------------
# IAM Role for RDS Proxy
# -----------------------------------------------------------------------------
#
# RDS Proxy needs an IAM role with two things:
#   1. Trust policy: Allows rds.amazonaws.com to assume this role
#   2. Permissions policy: Grants secretsmanager:GetSecretValue
#
# This is a common AWS pattern: a service (RDS Proxy) assumes a role
# to access another service (Secrets Manager) on your behalf.

resource "aws_iam_role" "rds_proxy" {
  name = "${var.environment}-rds-proxy-role"

  # Trust policy: WHO can assume this role.
  # Only the RDS service (rds.amazonaws.com) can assume it.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-rds-proxy-role"
    Environment = var.environment
  }
}

# Permissions policy: WHAT the role can do.
# Grants read access to the specific secret containing DB credentials.
# The resource ARN is scoped to just this one secret, not all secrets.
resource "aws_iam_role_policy" "rds_proxy_secrets" {
  name = "${var.environment}-rds-proxy-secrets-policy"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}
