# Phase 5: Infrastructure as Code and Database -- Phase Gate Checklist

Complete all 8 checkpoints before moving to Phase 6. Each checkpoint maps to a requirement and has a "Prove It" section with runnable commands and verification steps.

---

## Checkpoint 1: Terraform HCL (IAC-01)

**Requirement:** Write Terraform HCL to provision EC2, RDS, S3, and VPC resources.

### Knowledge Check

- [ ] Can you explain the difference between `resource`, `data`, and `module` blocks?
- [ ] Can you describe what `variable` blocks do and why `validation` blocks matter?
- [ ] Can you explain why `output` blocks are needed (how one config feeds into another)?
- [ ] Can you explain the VPC module's inputs and outputs?
- [ ] Can you describe the security group referencing pattern (SG -> SG instead of CIDR)?

### Prove It

```bash
# 1. Show the Terraform files that define infrastructure
ls infra/staging/*.tf
# Expected: main.tf, ec2.tf, rds.tf, rds-proxy.tf, secrets.tf, outputs.tf, variables.tf, providers.tf, terraform.tfvars

# 2. Show the VPC module that creates networking resources
ls infra/modules/vpc/*.tf
# Expected: main.tf, variables.tf, outputs.tf

# 3. Show that the staging config calls the VPC module
grep -A 8 'module "vpc"' infra/staging/main.tf
# Expected: Shows module source, environment, CIDRs, AZs

# 4. Show the RDS resource definition
grep -A 15 'resource "aws_db_instance"' infra/staging/rds.tf
# Expected: Shows engine, instance_class, storage, backup settings

# 5. Show the EC2 resource with dynamic AMI lookup
grep -B 2 -A 10 'resource "aws_instance"' infra/staging/ec2.tf
# Expected: Shows ami = data.aws_ami.amazon_linux_2023.id

# 6. Explain what each .tf file does and why resources are split across files
# (Verbal: providers.tf for versions/backend, variables.tf for inputs,
#  main.tf for module call, ec2.tf/rds.tf for compute/database,
#  outputs.tf for exposing values)
```

### Pass Criteria

- [ ] Terraform configs exist for VPC, EC2, RDS, S3 (state), and ECR
- [ ] You can explain what each resource block does
- [ ] You can describe the VPC module interface (inputs/outputs)
- [ ] You understand the SG referencing pattern and why it is better than CIDRs

---

## Checkpoint 2: Remote State Management (IAC-02)

**Requirement:** Manage Terraform state with S3 backend and DynamoDB locking.

### Knowledge Check

- [ ] Can you explain the bootstrap chicken-and-egg pattern (why bootstrap uses local state)?
- [ ] Can you describe what the S3 backend stores and why versioning matters?
- [ ] Can you explain what DynamoDB locking prevents (concurrent state modifications)?
- [ ] Can you describe what `prevent_destroy` does on the state bucket?

### Prove It

```bash
# 1. Show the S3 state bucket exists
aws s3 ls | grep terraform-state
# Expected: Shows the bucket name with creation date

# 2. Show the DynamoDB lock table exists
aws dynamodb describe-table --table-name journey-sysarch-terraform-locks \
  --query 'Table.{Name:TableName,Status:TableStatus,KeySchema:KeySchema}' \
  --output table
# Expected: Shows table name, ACTIVE status, LockID hash key

# 3. Show the state file is stored remotely
aws s3 ls s3://journey-sysarch-terraform-state/staging/
# Expected: Shows terraform.tfstate file (if staging has been deployed)

# 4. Show the bootstrap config has NO backend block (local state)
grep -c "backend" infra/bootstrap/providers.tf
# Expected: 0 (no backend block -- uses local state)

# 5. Show the staging config HAS an S3 backend block
grep -A 6 'backend "s3"' infra/staging/providers.tf
# Expected: Shows bucket, key, region, dynamodb_table, encrypt

# 6. Show prevent_destroy on the state bucket
grep -A 3 "lifecycle" infra/bootstrap/main.tf | head -4
# Expected: Shows prevent_destroy = true
```

### Pass Criteria

- [ ] S3 bucket exists with versioning enabled
- [ ] DynamoDB table exists with LockID hash key
- [ ] Bootstrap uses local state (no backend block)
- [ ] Staging uses S3 backend pointing to the bootstrap bucket
- [ ] You can explain why remote state is needed (sharing, persistence, locking)

---

## Checkpoint 3: Reusable Modules (IAC-03)

**Requirement:** Create reusable Terraform modules.

### Knowledge Check

- [ ] Can you explain what a Terraform module is (directory with .tf files called via `module` block)?
- [ ] Can you describe the VPC module's interface: what inputs it takes and what outputs it provides?
- [ ] Can you explain how staging and production use the same module with different values?

### Prove It

```bash
# 1. Show the VPC module is used by both staging and production
grep 'source.*modules/vpc' infra/staging/main.tf infra/production/main.tf
# Expected: Both files reference "../modules/vpc"

# 2. Show different CIDR ranges for each environment
grep 'vpc_cidr' infra/staging/main.tf infra/production/main.tf
# Expected: staging = "10.0.0.0/16", production = "10.1.0.0/16"

# 3. Show module variables with validation
grep -A 8 'variable "vpc_cidr"' infra/modules/vpc/variables.tf
# Expected: Shows type, description, validation block

# 4. Show module outputs
grep 'output' infra/modules/vpc/outputs.tf
# Expected: vpc_id, public_subnet_ids, private_subnet_ids, app_sg_id, rds_sg_id, rds_proxy_sg_id

# 5. Show how staging references module outputs
grep 'module.vpc' infra/staging/ec2.tf infra/staging/rds.tf infra/staging/rds-proxy.tf
# Expected: module.vpc.public_subnet_ids, module.vpc.rds_sg_id, etc.
```

### Pass Criteria

- [ ] VPC module exists with variables.tf, main.tf, outputs.tf
- [ ] Both staging and production call the same module with different parameters
- [ ] Module uses validation blocks on inputs
- [ ] You can explain why modules exist (reusability, consistency, DRY principle)

---

## Checkpoint 4: Terraform Lifecycle (IAC-04)

**Requirement:** Execute the full Terraform lifecycle (init, plan, apply, destroy).

### Knowledge Check

- [ ] Can you explain what each lifecycle step does (init, plan, apply, destroy)?
- [ ] Can you describe what `terraform init` downloads and configures?
- [ ] Can you explain why you should always run `plan` before `apply`?
- [ ] Can you describe the dependency-ordered destruction that `destroy` performs?

### Prove It

```bash
# 1. Show you can init (downloads providers, configures backend)
cd infra/staging && terraform init
# Expected: "Terraform has been successfully initialized!"

# 2. Show you can plan (dry run, shows changes)
terraform plan
# Expected: Shows resource changes (or "No changes" if already applied)

# 3. Show you can apply (creates/updates resources)
terraform apply -auto-approve
# Expected: "Apply complete!" with resource count

# 4. Show you can destroy (removes all resources)
terraform destroy -auto-approve
# Expected: "Destroy complete!" with resource count

# 5. Show you can rebuild (proves reproducibility)
terraform apply -auto-approve
# Expected: Same resources recreated from code

# Note: Exercise 6 (Destroy and Rebuild) in the exercises document
# is the definitive proof of this requirement.
```

### Pass Criteria

- [ ] You have successfully run init, plan, apply, and destroy
- [ ] You have completed Exercise 6 (Destroy and Rebuild)
- [ ] You can explain the difference between plan and apply
- [ ] You understand that destroy removes resources in reverse dependency order

---

## Checkpoint 5: RDS PostgreSQL (DATA-01)

**Requirement:** Provision and configure RDS PostgreSQL via Terraform.

### Knowledge Check

- [ ] Can you explain the RDS configuration choices (instance class, storage type, engine version)?
- [ ] Can you describe why RDS is in private subnets with `publicly_accessible = false`?
- [ ] Can you explain the db_subnet_group requirement (2+ AZs even for single-AZ)?
- [ ] Can you describe the difference between `skip_final_snapshot` in staging vs production?

### Prove It

```bash
# 1. Show the RDS Terraform configuration
cat infra/staging/rds.tf
# Expected: aws_db_instance with engine, instance_class, backup settings

# 2. Show the RDS instance is running (if deployed)
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].{
    Status: DBInstanceStatus,
    Engine: Engine,
    Version: EngineVersion,
    Class: DBInstanceClass,
    MultiAZ: MultiAZ,
    Encrypted: StorageEncrypted
  }' --output table
# Expected: available, postgres, 16.4, db.t4g.micro, False, True

# 3. Show RDS is in private subnets (not publicly accessible)
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].PubliclyAccessible' --output text
# Expected: False

# 4. Show the Terraform state for the RDS instance
cd infra/staging && terraform state show aws_db_instance.main 2>/dev/null | head -20
# Expected: Shows all RDS attributes including endpoint, storage, backup config
```

### Pass Criteria

- [ ] RDS configuration exists in Terraform with appropriate settings
- [ ] RDS is in private subnets with no public access
- [ ] Storage is encrypted
- [ ] You can explain the configuration choices and their cost/security tradeoffs

---

## Checkpoint 6: Database Migrations (DATA-02)

**Requirement:** Implement database migrations in a production workflow.

### Knowledge Check

- [ ] Can you explain the migration workflow (SSH, set DATABASE_URL, drizzle-kit push)?
- [ ] Can you describe why migrations use the direct RDS endpoint (not the proxy)?
- [ ] Can you explain idempotency (running the same migration twice produces no changes)?
- [ ] Can you describe where migrations fit in the deployment workflow (before app restart)?

### Prove It

```bash
# 1. Show the migration tool is available
cd app && npx drizzle-kit --version 2>/dev/null || pnpm drizzle-kit --version
# Expected: Shows drizzle-kit version

# 2. Show the Drizzle schema defines tables
ls app/src/db/ 2>/dev/null || ls app/src/schema/ 2>/dev/null
# Expected: Shows schema files (schema.ts or similar)

# 3. Show you can get the direct endpoint from Terraform
cd infra/staging && terraform output rds_direct_endpoint 2>/dev/null
# Expected: Shows the direct RDS endpoint (not proxy)

# 4. Demonstrate the migration workflow (explain these steps):
# a. SSH into EC2: ssh -i key.pem ec2-user@$(terraform output -raw ec2_public_ip)
# b. Set DATABASE_URL to direct endpoint (not proxy)
# c. Run: npx drizzle-kit push
# d. Verify tables: psql $DATABASE_URL -c "\dt"
# e. Update app to use proxy endpoint for normal traffic

# 5. Show that Exercise 4 was completed (migration ran successfully)
# (Verbal: describe the tables created and the output from drizzle-kit push)
```

### Pass Criteria

- [ ] Migration tool (drizzle-kit) is configured in the project
- [ ] You can explain the full migration workflow step by step
- [ ] You understand why the direct endpoint is used for migrations
- [ ] You have successfully run a migration against the RDS instance (Exercise 4)

---

## Checkpoint 7: Connection Pooling (DATA-03)

**Requirement:** Set up connection pooling for Node.js apps.

### Knowledge Check

- [ ] Can you explain why connection pooling is needed (connection limits, multi-instance scaling)?
- [ ] Can you describe how RDS Proxy works (sits between app and RDS, multiplexes connections)?
- [ ] Can you explain the Secrets Manager + IAM role requirement for RDS Proxy?
- [ ] Can you describe how to verify pooling is working (connection count comparison)?

### Prove It

```bash
# 1. Show the RDS Proxy Terraform configuration
cat infra/staging/rds-proxy.tf
# Expected: aws_db_proxy, aws_db_proxy_default_target_group, aws_db_proxy_target

# 2. Show the Secrets Manager configuration
cat infra/staging/secrets.tf
# Expected: aws_secretsmanager_secret, IAM role with trust policy for rds.amazonaws.com

# 3. Show the RDS Proxy endpoint in Terraform outputs
grep 'rds_proxy_endpoint' infra/staging/outputs.tf
# Expected: Output block with proxy endpoint value

# 4. Show RDS Proxy is running (if deployed)
aws rds describe-db-proxies --db-proxy-name staging-rds-proxy \
  --query 'DBProxies[0].{
    Status: Status,
    Endpoint: Endpoint,
    EngineFamily: EngineFamily,
    RequireTLS: RequireTLS
  }' --output table
# Expected: available, endpoint URL, POSTGRESQL, true

# 5. Verify app uses proxy endpoint (not direct)
# Show that the application DATABASE_URL should point to the proxy endpoint:
cd infra/staging && echo "App should use: $(terraform output -raw rds_proxy_endpoint 2>/dev/null)"
echo "NOT the direct: $(terraform output -raw rds_direct_endpoint 2>/dev/null)"
```

### Pass Criteria

- [ ] RDS Proxy is configured in Terraform with Secrets Manager auth
- [ ] IAM role exists with correct trust policy and permissions
- [ ] Proxy endpoint is exposed as a Terraform output
- [ ] You can explain why the app uses the proxy endpoint and migrations use the direct endpoint
- [ ] You understand the cost tradeoff (~$22/month for learning)

---

## Checkpoint 8: Backups and Recovery (DATA-04)

**Requirement:** Configure automated backups and understand point-in-time recovery.

### Knowledge Check

- [ ] Can you explain the difference between automated backups and manual snapshots?
- [ ] Can you describe what point-in-time recovery is and how RDS achieves it?
- [ ] Can you explain why PITR creates a NEW instance (safety feature)?
- [ ] Can you describe when to take manual snapshots (before changes, before destroy)?

### Prove It

```bash
# 1. Show backup configuration in Terraform
grep -A 3 'backup_retention_period\|backup_window' infra/staging/rds.tf
# Expected: backup_retention_period = 7, backup_window = "03:00-04:00"

# 2. Show backup is enabled on the running instance (if deployed)
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].{
    Retention: BackupRetentionPeriod,
    Window: PreferredBackupWindow,
    LatestRestore: LatestRestorableTime
  }' --output table
# Expected: Retention=7, Window=03:00-04:00, LatestRestore=(timestamp)

# 3. Show you can create a manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier staging-postgres \
  --db-snapshot-identifier gate-check-snapshot-$(date +%Y%m%d) \
  --query 'DBSnapshot.DBSnapshotIdentifier' --output text 2>/dev/null
# Expected: Shows the snapshot identifier (or error if instance not running)

# 4. List existing snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier staging-postgres \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status,SnapshotType]' \
  --output table 2>/dev/null
# Expected: Shows manual and/or automated snapshots

# 5. Show staging skips final snapshot but production keeps it
grep 'skip_final_snapshot' infra/staging/rds.tf infra/production/rds.tf
# Expected: staging = true, production = false
# Explain WHY: staging is disposable (learning), production has real data

# 6. Show PITR window (if instance is running)
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].{
    Earliest: EarliestRestorableTime,
    Latest: LatestRestorableTime
  }' --output table 2>/dev/null
# Expected: Shows the time range you can restore to
```

### Pass Criteria

- [ ] Automated backups configured with 7-day retention
- [ ] You have created at least one manual snapshot (Exercise 5)
- [ ] You can explain PITR: what it is, how it works, and why it creates a new instance
- [ ] You understand the staging vs production snapshot behavior difference
- [ ] You can describe when to take manual snapshots in a real workflow

---

## Phase 5 Complete

When all 8 checkpoints pass, you have demonstrated:
- Writing declarative infrastructure in Terraform HCL
- Managing state remotely with S3 and DynamoDB locking
- Creating and using reusable modules across environments
- Executing the full Terraform lifecycle including destroy+rebuild
- Provisioning and configuring RDS PostgreSQL
- Running database migrations in a production workflow
- Setting up connection pooling with RDS Proxy
- Configuring and managing database backups

**Next:** Phase 6 -- Container Orchestration (ECS/Fargate)

**Cost control:** Run `scripts/phase-05-teardown.sh` or `terraform destroy` in each environment directory to stop incurring costs.
