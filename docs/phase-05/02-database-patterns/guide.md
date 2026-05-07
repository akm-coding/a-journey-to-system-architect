# Database Production Patterns

This guide covers the patterns you need to run PostgreSQL in production on AWS. Each section explains WHY the pattern exists, WHAT it does, and the specific configuration used in this project's Terraform infrastructure.

**Prerequisites:** You should have read the Terraform concepts guide (`docs/phase-05/01-terraform-concepts/guide.md`) and reviewed the `.tf` files in `infra/staging/` before reading this guide.

---

## 1. Database Migrations in Production

### WHY Migrations Matter

When you develop locally, you might change your database schema by dropping and recreating tables. In production, you cannot do that -- the tables have real data. Database migrations solve this by applying incremental, reproducible schema changes.

Without migrations:
- **Schema drift:** Your local database has columns that production doesn't (or vice versa)
- **No reproducibility:** Nobody knows what SQL was run to get the production schema to its current state
- **No rollback path:** If a schema change breaks something, you have no record of what changed

### The drizzle-kit push Workflow

This project uses `drizzle-kit push` for migrations. It compares your Drizzle schema definitions (in TypeScript) against the actual database and applies the differences.

**The migration workflow:**

```
1. SSH into the EC2 instance
2. Set DATABASE_URL to the DIRECT RDS endpoint (not the proxy)
3. Run: npx drizzle-kit push
4. Verify: tables created/updated as expected
5. Update app to use the RDS Proxy endpoint for normal traffic
```

> **GOTCHA:** Migrations must use the direct RDS endpoint, NOT the RDS Proxy endpoint. RDS Proxy can interfere with DDL (schema-changing) statements because it manages connection pooling. The proxy is for application traffic; the direct endpoint is for admin/migration operations.

**Step-by-step commands:**

```bash
# 1. Get the EC2 IP and RDS direct endpoint from Terraform
cd infra/staging
terraform output ec2_public_ip
terraform output rds_direct_endpoint

# 2. SSH into the EC2 instance
ssh -i ~/.ssh/your-key.pem ec2-user@<ec2-public-ip>

# 3. Navigate to the app directory and set the direct endpoint
cd /path/to/app
export DATABASE_URL="postgresql://username:password@<rds-direct-endpoint>:5432/ecommerce"

# 4. Run the migration
npx drizzle-kit push

# 5. Verify tables exist
# You can use drizzle-kit studio or connect with psql
```

### Where Migrations Fit in the Deployment Workflow

```
Code pushed to GitHub
        |
        v
CI/CD builds and pushes Docker images to ECR
        |
        v
SSH into EC2, pull new images
        |
        v
Run migrations BEFORE starting the new app version   <-- HERE
        |
        v
Start the new containers (app connects via RDS Proxy)
```

> **WHY this order:** If you start the new app before migrating, the app might reference columns or tables that don't exist yet, causing crashes. Always migrate first, then deploy the new code.

### Idempotency

`drizzle-kit push` is idempotent -- running it twice on the same schema produces no changes the second time. This means it is safe to run migrations as part of every deployment, even if no schema changes were made. If the database already matches the schema, drizzle-kit does nothing.

---

## 2. Connection Pooling with RDS Proxy

### WHY Connection Pooling Matters

Every database connection consumes memory and CPU on the database server. PostgreSQL creates a new process for each connection, and a typical `db.t4g.micro` instance supports roughly 80-100 connections before running out of resources.

Without pooling, problems arise when:
- **Multiple app instances** each open their own connections (2 instances x 10 connections = 20; 10 instances = 100, already at the limit)
- **Lambda cold starts** create new connections on every invocation (hundreds of concurrent Lambdas = hundreds of connections)
- **Connection churn** from app restarts or deployments creates/destroys connections rapidly, stressing the database

### How RDS Proxy Works

RDS Proxy sits between your application and the RDS instance. It maintains a pool of persistent connections to the database and multiplexes your application's connections through them.

```
+-------------+     +-------------+     +-------------+
|  App        |     |  RDS Proxy  |     |  RDS        |
|  Instance 1 |---->|             |     |  PostgreSQL |
+-------------+     |  Maintains  |---->|             |
                    |  a pool of  |     |  ~80 max    |
+-------------+     |  connections|     |  connections |
|  App        |---->|  to RDS     |     +-------------+
|  Instance 2 |     |             |
+-------------+     +-------------+
       |                  |
  App opens 50       Proxy uses 10
  connections        actual DB
  (25 per instance)  connections
```

> **WHY RDS Proxy over application-level pooling (like pg-pool):** Application-level pools only manage connections within a single process. RDS Proxy manages connections across ALL your application instances. When you scale from 1 to 10 instances, pg-pool would create 10 separate pools (one per instance). RDS Proxy keeps a single, shared pool.

### RDS Proxy Architecture in Terraform

RDS Proxy requires three components:

1. **Secrets Manager secret** -- Stores the database credentials (username, password, host, port). RDS Proxy reads credentials from Secrets Manager, not from environment variables.

2. **IAM role** -- Allows the RDS Proxy service to access the Secrets Manager secret. This role has a trust policy letting `rds.amazonaws.com` assume it, and a permissions policy granting `secretsmanager:GetSecretValue`.

3. **The proxy itself** -- Placed in private subnets, attached to a security group that allows traffic from the application security group.

See `infra/staging/rds-proxy.tf` and `infra/staging/secrets.tf` for the full configuration.

### Cost Consideration

RDS Proxy pricing is based on the vCPUs of the underlying RDS instance:
- **db.t4g.micro** (2 vCPUs): ~$22/month
- This is the most expensive single component in the learning environment

> **GOTCHA:** RDS Proxy costs money even when your app is not running. If you are not actively studying, destroy the infrastructure with `terraform destroy` to avoid ongoing charges. The destroy+rebuild exercise (Exercise 6) proves you can recreate everything from code.

### Verifying Connection Pooling Works

After deployment, you can verify pooling is active:

```bash
# From the EC2 instance, check RDS connection count
# Connect to RDS directly (for admin monitoring)
psql "postgresql://username:password@<rds-direct-endpoint>:5432/ecommerce"

# Check active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

# If pooling works: connection count should be MUCH lower than
# the number of app-level connections. Example:
# - App reports 50 open connections
# - RDS shows 5-10 actual connections
# - The proxy is multiplexing 50 app connections through 5-10 DB connections
```

---

## 3. Automated Backups

### How RDS Automated Backups Work

RDS automatically takes a daily snapshot of your database during a configurable backup window. It also continuously captures transaction logs, which allows point-in-time recovery to any second within the retention period.

**Configuration in this project:**

| Setting | Value | Why |
|---------|-------|-----|
| `backup_retention_period` | 7 days | Keeps a week of backups; AWS default is 0 (disabled) |
| `backup_window` | `03:00-04:00` UTC | Low-traffic window to minimize performance impact |
| `maintenance_window` | `Mon:04:00-Mon:05:00` | After backup window; patches and minor version updates |

> **WHY 7 days:** This gives you a full week to discover a problem and recover. If data corruption happened last Tuesday and you notice on Friday, you can restore to Monday's state. The maximum retention is 35 days, but 7 is sufficient for learning.

### Point-in-Time Recovery (PITR)

PITR lets you restore your database to any specific second within the retention period. RDS achieves this by:

1. Taking a daily full snapshot (during the backup window)
2. Continuously recording transaction logs (every 5 minutes)
3. When you request a restore, RDS replays the snapshot + transaction logs up to your specified timestamp

**Important:** PITR creates a NEW RDS instance. It does not overwrite the existing one. You will need to:
1. Create the new instance from the point-in-time restore
2. Verify the data is correct
3. Update your application to point to the new instance
4. Delete the old instance (or keep it as reference)

> **WHY a new instance:** This is a safety feature. If the restore is not what you expected, your original database is still intact. You can inspect both and choose which to keep.

### Backup Storage Costs

RDS provides free backup storage equal to the size of your provisioned database. For a 20 GB database with 7-day retention, backups are free as long as total backup storage stays under 20 GB (which it will for a learning project).

---

## 4. Manual Snapshots

### When to Take Manual Snapshots

Automated backups are deleted after the retention period (7 days). Manual snapshots persist until you explicitly delete them. Take manual snapshots:

- **Before major schema changes** -- If a migration goes wrong, you have a known-good state to restore from
- **Before `terraform destroy`** -- If you want to preserve data across infrastructure teardown/rebuild cycles
- **Before experimenting** -- If you are testing destructive queries or load testing

### Creating a Manual Snapshot

```bash
# Create a manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier staging-postgres \
  --db-snapshot-identifier staging-pre-migration-$(date +%Y%m%d)

# Check snapshot status (wait for "available")
aws rds describe-db-snapshots \
  --db-snapshot-identifier staging-pre-migration-20260507

# List all manual snapshots
aws rds describe-db-snapshots \
  --snapshot-type manual \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status,SnapshotCreateTime]' \
  --output table
```

### Difference from Automated Backups

| Feature | Automated Backups | Manual Snapshots |
|---------|-------------------|------------------|
| Created by | RDS (daily, during backup window) | You (on demand) |
| Retention | Deleted after retention period (7 days) | Persist until you delete them |
| PITR support | Yes (restored from snapshot + transaction logs) | No (snapshot only, exact point in time) |
| Cost | Free up to 1x DB size | Charged per GB/month after free tier |
| Deleted on instance termination | Yes (if `skip_final_snapshot = true`) | No (always persists) |

> **GOTCHA:** If you `terraform destroy` an RDS instance with `skip_final_snapshot = true` (as in the staging config), all automated backups are deleted. If you need to preserve data, either create a manual snapshot first or set `skip_final_snapshot = false` with a `final_snapshot_identifier` (as in the production config).

---

## 5. Multi-AZ vs Single-AZ

### What Multi-AZ Does

In a Multi-AZ deployment, RDS maintains a synchronous standby replica in a different Availability Zone. If the primary instance fails (hardware failure, AZ outage), RDS automatically fails over to the standby -- typically within 60-120 seconds.

```
                     Region: ap-southeast-1
   +--------------------+     +--------------------+
   |  AZ: ap-se-1a      |     |  AZ: ap-se-1b      |
   |                    |     |                    |
   |  +-------------+  |     |  +-------------+  |
   |  | RDS Primary |  |---->|  | RDS Standby |  |
   |  | (read/write)|  | sync|  | (no traffic) |  |
   |  +-------------+  | repl|  +-------------+  |
   |                    |     |                    |
   +--------------------+     +--------------------+

   Normal: All traffic goes to Primary
   Failover: DNS flips to Standby (60-120 seconds)
```

### When to Use Multi-AZ

- **Production with uptime SLAs:** If your application needs to be available 99.95%+ of the time
- **Critical data:** When the cost of downtime exceeds the cost of the standby instance
- **Compliance:** Some regulations require multi-AZ for disaster recovery

### This Project's Approach

Per the project decisions: **Deploy single-AZ to keep costs low; study Multi-AZ as a reference.**

The Terraform configuration difference is minimal -- just one parameter:

```hcl
# Single-AZ (what we deploy)
resource "aws_db_instance" "main" {
  # ... all other config ...
  multi_az = false  # ~$14/month for db.t4g.micro
}

# Multi-AZ (reference configuration)
resource "aws_db_instance" "main" {
  # ... all other config ...
  multi_az = true   # ~$28/month for db.t4g.micro (roughly 2x)
}
```

### Cost Impact

| Configuration | Est. Monthly Cost | Use Case |
|---------------|-------------------|----------|
| Single-AZ (db.t4g.micro) | ~$14 | Learning, development, non-critical |
| Multi-AZ (db.t4g.micro) | ~$28 | Production with uptime requirements |

> **WHY this matters for learning:** Understanding Multi-AZ is important even if you don't deploy it. In job interviews and production discussions, you need to know: what it does, when to use it, and the cost tradeoff. The fact that it is a single-parameter change in Terraform demonstrates the power of IaC -- you can switch between single-AZ and Multi-AZ with one line change and a `terraform apply`.

---

## 6. Security Patterns

### Private Subnet Placement

The RDS instance is placed in private subnets with no public accessibility:

```hcl
resource "aws_db_instance" "main" {
  db_subnet_group_name = aws_db_subnet_group.main.name  # Private subnets
  publicly_accessible  = false                           # No public IP
}
```

> **WHY:** A database should never be directly accessible from the internet. Even with strong passwords, public exposure increases the attack surface dramatically (port scanning, brute force, zero-day exploits). The only path to the database is through the application or through SSH on the EC2 instance.

### Security Group Referencing

Instead of allowing traffic from CIDR blocks (IP ranges), the security groups reference each other:

```
App SG  --(allows traffic to)-->  RDS Proxy SG  --(allows traffic to)-->  RDS SG
```

This is configured in `infra/modules/vpc/main.tf` using separate `aws_security_group_rule` resources:

```hcl
# RDS Proxy SG: allow inbound from App SG on port 5432
resource "aws_security_group_rule" "rds_proxy_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_proxy.id
  source_security_group_id = aws_security_group.app.id
}

# RDS SG: allow inbound from RDS Proxy SG on port 5432
resource "aws_security_group_rule" "rds_from_proxy" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.rds_proxy.id
}
```

> **WHY SG referencing over CIDR blocks:** When you reference a security group, AWS dynamically resolves the rule to include all instances in that group. If you add more EC2 instances to the App SG, they automatically get access to the proxy. With CIDRs, you would need to update the rules manually every time an IP changes.

### Encrypted Storage

RDS storage encryption is enabled by default in the Terraform configuration:

```hcl
resource "aws_db_instance" "main" {
  storage_encrypted = true
}
```

This uses AWS-managed keys (KMS) at no additional cost. All data at rest, automated backups, read replicas, and snapshots are encrypted.

### Secrets Manager for Credentials

Database credentials are stored in AWS Secrets Manager, not in plaintext `.tfvars` files:

```hcl
# Credentials passed via environment variables (TF_VAR_db_username, TF_VAR_db_password)
# Then stored in Secrets Manager for RDS Proxy to access
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    # ...
  })
}
```

> **WHY Secrets Manager:** (1) RDS Proxy requires it -- the proxy reads credentials from Secrets Manager, not from environment variables. (2) It is a security best practice -- Secrets Manager supports automatic rotation, audit logging, and fine-grained IAM access control. (3) It keeps secrets out of Terraform state where possible -- though note that Terraform state still contains the secret values as an attribute of the resource.

> **GOTCHA:** Even with Secrets Manager, the Terraform state file (`terraform.tfstate`) contains the secret values in plaintext. This is why state files must be stored in encrypted S3 buckets with restricted access, never committed to git, and never shared over insecure channels.

---

## Summary: Production Database Checklist

Use this checklist when setting up a new production database on RDS:

- [ ] **Migrations:** Automated, idempotent, run before app deployment
- [ ] **Connection pooling:** RDS Proxy (or application-level pool for simple setups)
- [ ] **Automated backups:** Enabled with appropriate retention (7+ days for production)
- [ ] **Manual snapshots:** Taken before major changes and before destroy operations
- [ ] **Multi-AZ:** Enabled for production workloads with uptime requirements
- [ ] **Private subnets:** No public access to the database
- [ ] **Security group referencing:** Allow traffic only from known services, not CIDR blocks
- [ ] **Encrypted storage:** Enabled (free with AWS-managed KMS keys)
- [ ] **Credentials in Secrets Manager:** Not in plaintext config files
- [ ] **State file security:** Encrypted S3 bucket, restricted access, never in git
