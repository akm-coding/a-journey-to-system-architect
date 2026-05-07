# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: Secrets Manager + IAM Role for RDS Proxy
# =============================================================================
#
# Same structure as staging. The secret stores production DB credentials,
# and the IAM role allows RDS Proxy to read them.
#
# In a real production setup, you might also:
#   - Enable automatic secret rotation (Secrets Manager supports this)
#   - Use separate IAM roles per service (principle of least privilege)
# =============================================================================

# -----------------------------------------------------------------------------
# Secrets Manager Secret
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}-db-credentials"

  tags = {
    Name        = "${var.environment}-db-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

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

resource "aws_iam_role" "rds_proxy" {
  name = "${var.environment}-rds-proxy-role"

  # Trust policy: allows RDS service to assume this role
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

# Permissions policy: grants access to the production secret only
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
