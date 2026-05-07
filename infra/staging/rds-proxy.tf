# =============================================================================
# Staging Environment: RDS Proxy
# =============================================================================
#
# RDS Proxy sits between the application and the database, providing:
#   - Connection pooling: Multiple app instances share a pool of DB connections
#   - Failover handling: Automatically routes to standby in Multi-AZ setups
#   - TLS enforcement: All connections between proxy and RDS are encrypted
#
# The app connects to the PROXY endpoint, not directly to RDS.
# This is critical -- if the app uses the RDS endpoint directly,
# it bypasses the proxy and gets no pooling benefit.
# (See RESEARCH.md pitfall #7)
#
# Cost: ~$22/month (most expensive component after RDS itself).
# Destroy when not studying to avoid ongoing charges.
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

  # Auth block tells the proxy where to find database credentials.
  # SECRETS auth scheme means "read credentials from Secrets Manager".
  # IAM auth is disabled -- the proxy authenticates with username/password.
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

# The target group configures connection pool behavior.
# max_connections_percent = 100 means the proxy can use up to 100% of
# the RDS instance's max connections. For db.t4g.micro, that's ~80 connections.
# connection_borrow_timeout = 120 means if all connections are in use,
# a new request will wait up to 120 seconds before timing out.
resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    max_connections_percent      = 100
    connection_borrow_timeout    = 120
  }
}

# The target links the proxy to the actual RDS instance.
# This tells the proxy which database to forward connections to.
resource "aws_db_proxy_target" "main" {
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
  db_instance_identifier = aws_db_instance.main.identifier
}
