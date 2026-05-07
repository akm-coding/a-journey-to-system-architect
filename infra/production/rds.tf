# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: RDS PostgreSQL Instance
# =============================================================================
#
# Key differences from staging:
#   - skip_final_snapshot = false: Production keeps a final snapshot on destroy
#   - final_snapshot_identifier set: Names the snapshot for easy identification
#   - Multi-AZ shown as reference config (commented out)
#
# Everything else matches staging. The database engine, storage, and backup
# settings are identical because consistency between environments reduces
# surprises during promotion.
# =============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.environment}-postgres"

  # Engine configuration (same as staging for consistency)
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.micro"

  # Storage configuration (same as staging)
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [module.vpc.rds_sg_id]

  # Availability configuration
  # Single-AZ for the learning environment to keep costs low.
  multi_az            = false
  publicly_accessible = false

  # ----- Multi-AZ reference configuration -----
  # Uncomment for production high availability (~2x RDS cost, ~$28/month):
  #
  # multi_az = true
  #
  # With Multi-AZ enabled, AWS maintains a synchronous standby replica
  # in a different AZ. If the primary fails, AWS automatically fails over
  # to the standby (typically 60-120 seconds of downtime).
  #
  # For a real production workload, Multi-AZ is strongly recommended.
  # The cost increase (~$14/month extra) is justified by the automatic
  # failover capability.
  # -----------------------------------------------

  # Backup configuration (same as staging -- 7-day retention)
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Snapshot configuration
  # Production keeps a final snapshot on destroy, unlike staging.
  # This is a safety net: if you accidentally destroy the database,
  # you can restore from the final snapshot.
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-final-snapshot"

  tags = {
    Name        = "${var.environment}-postgres"
    Environment = var.environment
  }
}
