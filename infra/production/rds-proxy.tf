# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: RDS Proxy
# =============================================================================
#
# Same configuration as staging. In a real production environment, you might
# tune the connection pool settings differently:
#   - Lower max_connections_percent to reserve connections for admin tasks
#   - Shorter connection_borrow_timeout for faster failure detection
#
# For this learning project, we keep the same settings as staging.
# =============================================================================

resource "aws_db_proxy" "main" {
  name                   = "${var.environment}-rds-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [module.vpc.rds_proxy_sg_id]
  vpc_subnet_ids         = module.vpc.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }

  tags = {
    Name        = "${var.environment}-rds-proxy"
    Environment = var.environment
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    max_connections_percent      = 100
    connection_borrow_timeout    = 120
  }
}

resource "aws_db_proxy_target" "main" {
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
  db_instance_identifier = aws_db_instance.main.identifier
}
