# Phase 5: Terraform and Database Cheatsheet

Quick reference for Terraform CLI commands, AWS CLI database commands, connection strings, and common troubleshooting.

---

## Terraform Lifecycle Commands

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `terraform init` | Downloads providers, configures backend | First time in a directory, or after changing backend config |
| `terraform plan` | Shows what will change (dry run) | Before every apply -- always review the plan |
| `terraform apply` | Creates/updates resources to match config | After reviewing the plan output |
| `terraform destroy` | Removes all managed resources | When tearing down an environment |
| `terraform validate` | Checks HCL syntax without accessing AWS | Quick syntax check during development |
| `terraform fmt` | Formats `.tf` files to canonical style | Before committing `.tf` files |

### Common Flags

| Flag | Works With | What It Does |
|------|-----------|-------------|
| `-auto-approve` | apply, destroy | Skips the "yes" confirmation (use in scripts, never manually) |
| `-target=RESOURCE` | plan, apply, destroy | Acts on a single resource only |
| `-var="key=value"` | plan, apply | Passes a variable value inline |
| `-var-file=FILE` | plan, apply | Uses a specific variables file |
| `-out=FILE` | plan | Saves the plan to a file for later `apply` |
| `-destroy` | plan | Shows what `destroy` would do without destroying |

---

## Terraform State Commands

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `terraform state list` | Lists all managed resources | See what Terraform is tracking |
| `terraform state show RESOURCE` | Shows all attributes of a resource | Inspect a specific resource's current state |
| `terraform output` | Shows all output values | Get endpoints, IPs, IDs |
| `terraform output -raw NAME` | Shows a single output (no quotes) | Use in scripts or copy-paste |

> **NEVER** use `terraform state rm`, `terraform state mv`, or `terraform state push` unless you fully understand the consequences. These modify state directly and can cause Terraform to lose track of resources.

---

## AWS CLI: RDS Commands

### Instance Management

```bash
# Describe an RDS instance
aws rds describe-db-instances --db-instance-identifier staging-postgres

# Get just the status
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].DBInstanceStatus' --output text

# Get the endpoint
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].Endpoint.Address' --output text
```

### Snapshots

```bash
# Create a manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier staging-postgres \
  --db-snapshot-identifier my-snapshot-name

# Wait for snapshot to complete
aws rds wait db-snapshot-available --db-snapshot-identifier my-snapshot-name

# List manual snapshots
aws rds describe-db-snapshots --snapshot-type manual \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status,SnapshotCreateTime]' \
  --output table

# List automated snapshots for an instance
aws rds describe-db-snapshots \
  --db-instance-identifier staging-postgres \
  --snapshot-type automated \
  --output table

# Delete a manual snapshot
aws rds delete-db-snapshot --db-snapshot-identifier my-snapshot-name
```

### Backup Info

```bash
# Check backup configuration
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].{
    Retention: BackupRetentionPeriod,
    Window: PreferredBackupWindow,
    LatestRestore: LatestRestorableTime
  }' --output table

# Check PITR window (earliest and latest restorable times)
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].{
    Earliest: EarliestRestorableTime,
    Latest: LatestRestorableTime
  }' --output table
```

### RDS Proxy

```bash
# Check proxy status
aws rds describe-db-proxies --db-proxy-name staging-rds-proxy \
  --query 'DBProxies[0].Status' --output text

# Get proxy endpoint
aws rds describe-db-proxies --db-proxy-name staging-rds-proxy \
  --query 'DBProxies[0].Endpoint' --output text
```

---

## Database Connection Strings

### Proxy Endpoint (Application Traffic)

```
postgresql://<username>:<password>@<rds-proxy-endpoint>:5432/<dbname>
```

Use for: Application `DATABASE_URL`, normal read/write operations

### Direct Endpoint (Admin/Migrations)

```
postgresql://<username>:<password>@<rds-direct-endpoint>:5432/<dbname>
```

Use for: `drizzle-kit push`, `psql` admin sessions, schema changes

### Getting Endpoints from Terraform

```bash
# Proxy endpoint (for app)
terraform output -raw rds_proxy_endpoint

# Direct endpoint (for migrations)
terraform output -raw rds_direct_endpoint
```

---

## Environment Variables

### Terraform Variables (TF_VAR_*)

```bash
# Sensitive values -- set these before terraform plan/apply
export TF_VAR_db_username="ecomadmin"
export TF_VAR_db_password="YourSecurePassword123!"
export TF_VAR_key_pair_name="your-aws-keypair-name"

# Non-sensitive values are in terraform.tfvars (committed to git)
# project_name, aws_region, instance_type, db_name, environment
```

### Application Variables

```bash
# On the EC2 instance, for app runtime:
export DATABASE_URL="postgresql://user:pass@<proxy-endpoint>:5432/ecommerce"

# For migrations only (use direct endpoint):
export DATABASE_URL="postgresql://user:pass@<direct-endpoint>:5432/ecommerce"
```

---

## Common Troubleshooting

### State Lock Stuck

**Symptom:** `Error: Error acquiring the state lock`

**Cause:** A previous `terraform apply` crashed or was killed before releasing the lock.

**Fix:**
```bash
# Get the lock ID from the error message, then:
terraform force-unlock LOCK_ID
# Only use this if you are CERTAIN no other apply is running
```

### Provider Version Mismatch

**Symptom:** `Error: Incompatible provider version` or `provider registry.terraform.io/hashicorp/aws v6.x does not match ~> 5.0`

**Cause:** The `.terraform.lock.hcl` file pins a different version than `providers.tf` requires.

**Fix:**
```bash
# Update the lock file to match the version constraint
terraform init -upgrade
```

### Subnet AZ Error

**Symptom:** `DBSubnetGroupDoesNotCoverEnoughAZs`

**Cause:** RDS subnet group requires subnets in at least 2 different Availability Zones.

**Fix:** Ensure your VPC module creates private subnets in 2+ AZs. Check `availability_zones` variable in the module call.

### S3 Backend Not Found

**Symptom:** `Error: Failed to get existing workspaces` during `terraform init`

**Cause:** The S3 bucket or DynamoDB table from bootstrap doesn't exist yet.

**Fix:** Run `terraform apply` in `infra/bootstrap/` first.

### RDS Proxy Stuck Creating

**Symptom:** RDS Proxy stays in "creating" status for 15+ minutes, then fails.

**Cause:** Usually an IAM role trust policy issue -- the proxy cannot read Secrets Manager credentials.

**Fix:** Verify the IAM role has:
1. Trust policy allowing `rds.amazonaws.com` to assume the role
2. Permission policy granting `secretsmanager:GetSecretValue` on the correct secret ARN

### Cannot Connect to RDS from EC2

**Symptom:** `psql` connection times out or is refused.

**Cause:** Security group rules not allowing traffic from EC2 to RDS (or to RDS Proxy).

**Fix:** Verify the security group chain:
```
App SG -> RDS Proxy SG (port 5432) -> RDS SG (port 5432)
```

Check in the AWS console: EC2 > Security Groups > verify inbound rules reference the correct source SG.

### Terraform Destroy Hangs on RDS

**Symptom:** `terraform destroy` takes 15+ minutes on the RDS instance.

**Cause:** RDS is creating a final snapshot (default behavior if `skip_final_snapshot = false`).

**Fix:** For learning environments, set `skip_final_snapshot = true` in `rds.tf`. For production, this is expected -- the final snapshot is a safety net.

---

## Quick Reference: Project Directory Structure

```
infra/
├── bootstrap/          # State backend (local state)
│   ├── providers.tf    # Terraform + AWS versions (no backend block)
│   ├── variables.tf    # region, project_name
│   ├── main.tf         # S3 bucket, DynamoDB, ECR
│   └── outputs.tf      # Bucket name, table name, ECR URL
├── modules/
│   └── vpc/            # Reusable VPC module
│       ├── main.tf     # VPC, subnets, IGW, routes, SGs
│       ├── variables.tf # CIDRs, AZs, environment
│       └── outputs.tf  # IDs for all created resources
├── staging/            # Staging environment (S3 backend)
│   ├── providers.tf    # Backend config (staging state key)
│   ├── variables.tf    # All input variables
│   ├── terraform.tfvars # Non-sensitive values
│   ├── main.tf         # VPC module call
│   ├── ec2.tf          # EC2 with Docker user_data
│   ├── rds.tf          # RDS PostgreSQL
│   ├── rds-proxy.tf    # RDS Proxy + target group
│   ├── secrets.tf      # Secrets Manager + IAM role
│   └── outputs.tf      # Endpoints and IDs
└── production/         # Production (same structure, different values)
    └── ...
```
