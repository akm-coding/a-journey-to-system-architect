# =============================================================================
# Staging Environment: RDS PostgreSQL Instance
# =============================================================================
#
# PostgreSQL database for the e-commerce application.
# Placed in private subnets (no internet access) with security group
# allowing connections only from the RDS Proxy.
#
# Key configuration choices:
#   - db.t4g.micro: Smallest/cheapest instance (~$14/month)
#   - gp3 storage: Newer generation, better baseline performance than gp2
#   - Single-AZ: Cost savings for learning (Multi-AZ shown as reference)
#   - 7-day backup retention: Automated daily backups per CONTEXT.md
#   - skip_final_snapshot = true: Staging doesn't need a final snapshot
# =============================================================================

# The DB subnet group tells RDS which subnets it can use.
# AWS requires subnets in at least 2 different AZs, even for single-AZ
# deployments. (See RESEARCH.md pitfall #6)
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

  # Engine configuration
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.micro"

  # Storage configuration
  # Start with 20GB, auto-scale up to 50GB if the database grows.
  # gp3 provides 3000 IOPS baseline (better than gp2 for small instances).
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
  # Single-AZ to keep costs low for a learning environment.
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
  # -----------------------------------------------

  # Backup configuration
  # Automated daily backups with 7-day retention.
  # backup_window: When the daily backup snapshot is taken (UTC).
  # maintenance_window: When minor patches and maintenance can occur (UTC).
  # These windows should not overlap.
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Snapshot configuration
  # For staging: skip the final snapshot on destroy to allow clean teardown.
  # For production: set skip_final_snapshot = false (see production/rds.tf).
  skip_final_snapshot = true

  tags = {
    Name        = "${var.environment}-postgres"
    Environment = var.environment
  }
}
