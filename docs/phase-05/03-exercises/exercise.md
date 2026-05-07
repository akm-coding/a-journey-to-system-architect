# Phase 5: Infrastructure as Code and Database -- Hands-On Exercises

These exercises walk you through the complete Terraform lifecycle: bootstrapping state infrastructure, deploying a full environment, exploring state, running migrations, managing backups, and proving IaC reproducibility through destroy and rebuild.

**Prerequisites for all exercises:**
- Terraform CLI installed (`terraform --version` shows 1.15+)
- AWS CLI configured with valid credentials (`aws sts get-caller-identity`)
- SSH key pair created in your AWS region
- The `infra/` directory from this project with all `.tf` files

**Estimated time:** 60-90 minutes for all 6 exercises (most time is waiting for RDS to provision, ~10-15 minutes)

---

## Exercise 1: Bootstrap the State Backend

**Objective:** Provision the S3 bucket, DynamoDB lock table, and ECR repository that all other Terraform configs depend on.

**Why this matters:** The state backend is a chicken-and-egg problem -- you need infrastructure to store Terraform state, but that infrastructure itself is managed by Terraform. The bootstrap directory solves this by using local state (stored on your machine) to create the remote state backend that everything else uses.

### Steps

1. **Navigate to the bootstrap directory**
   ```bash
   cd infra/bootstrap
   ```

2. **Review the configuration before applying**
   ```bash
   # Read each file to understand what will be created
   cat providers.tf    # Terraform version, AWS provider, NO backend block (local state)
   cat variables.tf    # Inputs: region, project_name with validation
   cat main.tf         # S3 bucket, DynamoDB table, ECR repository
   cat outputs.tf      # Values needed by staging/production configs
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   # Expected: "Terraform has been successfully initialized!"
   # Note: This downloads the AWS provider plugin (~300MB)
   ```

4. **Run terraform plan to preview what will be created**
   ```bash
   terraform plan
   # Expected output:
   # Plan: 7 to add, 0 to change, 0 to destroy.
   # Resources include: S3 bucket, versioning, public access block,
   #   DynamoDB table, ECR repository, ECR lifecycle policy
   ```

   > **WHY plan first:** Always run `terraform plan` before `terraform apply`. The plan shows you exactly what Terraform will create, modify, or destroy. Read the plan output carefully -- this is your safety net against unexpected changes.

5. **Apply the configuration**
   ```bash
   terraform apply
   # Review the plan one more time, then type "yes" to confirm
   # Expected: "Apply complete! Resources: 7 added, 0 changed, 0 destroyed."
   ```

6. **Record the output values**
   ```bash
   terraform output
   # Expected output includes:
   #   state_bucket_name = "journey-sysarch-terraform-state"
   #   lock_table_name   = "journey-sysarch-terraform-locks"
   #   ecr_repository_url = "123456789.dkr.ecr.ap-southeast-1.amazonaws.com/journey-sysarch-app"
   ```

### Verification

```bash
# Verify S3 bucket exists
aws s3 ls | grep terraform-state
# Expected: Shows the bucket with creation date

# Verify DynamoDB table exists
aws dynamodb describe-table --table-name journey-sysarch-terraform-locks \
  --query 'Table.TableStatus' --output text
# Expected: ACTIVE

# Verify ECR repository exists
aws ecr describe-repositories --repository-names journey-sysarch-app \
  --query 'repositories[0].repositoryUri' --output text
# Expected: Shows the ECR URI

# Verify local state file was created (NOT remote -- bootstrap uses local state)
ls -la terraform.tfstate
# Expected: File exists (this is the bootstrap's local state)
```

### What You Learned

- The bootstrap pattern solves the state backend chicken-and-egg problem
- `terraform init` downloads providers; `terraform plan` previews changes; `terraform apply` executes them
- Output values from one Terraform config feed into another (bootstrap outputs -> environment backend config)
- Local state is fine for bootstrap; remote state is for everything else

---

## Exercise 2: Deploy Staging Infrastructure

**Objective:** Deploy a complete staging environment (VPC, EC2, RDS, RDS Proxy) using remote state stored in the S3 bucket from Exercise 1.

**Why this matters:** This is the core IaC experience -- describing your entire production-like environment in code and creating it with a single command. Everything that would take hours of clicking in the AWS console happens automatically, in the right order, with the right dependencies.

### Steps

1. **Navigate to the staging directory**
   ```bash
   cd infra/staging
   ```

2. **Set sensitive variables as environment variables**
   ```bash
   # NEVER put passwords in .tfvars files or commit them to git
   export TF_VAR_db_username="ecomadmin"
   export TF_VAR_db_password="YourSecurePassword123!"
   export TF_VAR_key_pair_name="your-aws-keypair-name"
   ```

   > **WHY environment variables for secrets:** The `terraform.tfvars` file is committed to git and should contain only non-sensitive values (project name, region, instance type). Sensitive values like passwords are passed via `TF_VAR_` environment variables, which are never written to disk.

3. **Initialize Terraform with remote backend**
   ```bash
   terraform init
   # Expected: "Successfully configured the backend "s3"!"
   # This connects to the S3 bucket created in Exercise 1
   # State will be stored remotely, not locally
   ```

4. **Run terraform plan and study the output**
   ```bash
   terraform plan
   # Expected: Plan shows ~20+ resources to create, including:
   # - VPC, subnets (2 public, 2 private), internet gateway, route tables
   # - Security groups (app, rds, rds_proxy) with rules
   # - EC2 instance with user_data script
   # - RDS PostgreSQL instance (db.t4g.micro)
   # - RDS Proxy with Secrets Manager integration
   # - IAM role and policy for RDS Proxy
   #
   # Take time to read each resource in the plan output.
   # Notice how Terraform resolves dependencies automatically.
   ```

5. **Apply the configuration**
   ```bash
   terraform apply
   # Type "yes" to confirm
   # This will take 10-15 minutes (RDS and RDS Proxy are slow to provision)
   # Watch the creation order -- Terraform handles dependencies automatically:
   #   VPC -> Subnets -> Security Groups -> RDS -> Secrets -> RDS Proxy
   ```

   > **GOTCHA:** The RDS instance takes ~8-10 minutes to become available. The RDS Proxy takes another ~5 minutes after that. Be patient -- do not cancel the apply.

6. **Review the outputs**
   ```bash
   terraform output
   # Key outputs:
   #   ec2_public_ip       = "x.x.x.x"
   #   rds_proxy_endpoint  = "staging-rds-proxy.proxy-xxx.ap-southeast-1.rds.amazonaws.com"
   #   rds_direct_endpoint = "staging-postgres.xxx.ap-southeast-1.rds.amazonaws.com"
   ```

### Verification

```bash
# Verify VPC exists
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=staging" \
  --query 'Vpcs[0].CidrBlock' --output text
# Expected: 10.0.0.0/16

# Verify EC2 is running
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=staging" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
# Expected: Shows the public IP

# Verify RDS is available
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].DBInstanceStatus' --output text
# Expected: available

# Verify RDS Proxy is available
aws rds describe-db-proxies --db-proxy-name staging-rds-proxy \
  --query 'DBProxies[0].Status' --output text
# Expected: available

# Verify state is stored remotely in S3
aws s3 ls s3://journey-sysarch-terraform-state/staging/
# Expected: Shows terraform.tfstate file
```

### What You Learned

- A complete cloud environment can be created from code with a single `terraform apply`
- Terraform automatically resolves resource dependencies and creates them in the right order
- Remote state in S3 means the state is shared and persistent (not tied to your laptop)
- Sensitive variables are passed via environment variables, not committed to git

---

## Exercise 3: Explore Terraform State

**Objective:** Inspect the Terraform state to understand what resources are managed and how Terraform tracks them.

**Why this matters:** Terraform state is the single source of truth for what exists in your cloud. Understanding state helps you debug issues, understand resource relationships, and know what happens when you change your `.tf` files.

### Steps

1. **List all managed resources**
   ```bash
   cd infra/staging
   terraform state list
   # Expected: Shows every resource Terraform manages, e.g.:
   #   module.vpc.aws_vpc.main
   #   module.vpc.aws_subnet.public[0]
   #   module.vpc.aws_subnet.public[1]
   #   module.vpc.aws_subnet.private[0]
   #   module.vpc.aws_subnet.private[1]
   #   aws_db_instance.main
   #   aws_db_proxy.main
   #   aws_instance.app
   #   ...
   ```

2. **Inspect a specific resource in detail**
   ```bash
   terraform state show aws_db_instance.main
   # Expected: Shows ALL attributes of the RDS instance, including:
   #   - identifier, engine, engine_version
   #   - endpoint, address, port
   #   - backup_retention_period, backup_window
   #   - multi_az, storage_encrypted
   #   - vpc_security_group_ids
   ```

3. **View all outputs**
   ```bash
   terraform output
   # Shows the values defined in outputs.tf
   # These are the "public interface" of this Terraform config

   # Get a single output value (useful in scripts)
   terraform output -raw ec2_public_ip
   terraform output -raw rds_proxy_endpoint
   ```

4. **Check where state is stored**
   ```bash
   # The state is in S3, not on your local machine
   aws s3 ls s3://journey-sysarch-terraform-state/staging/
   # Expected: terraform.tfstate

   # Check if the DynamoDB lock table has entries
   aws dynamodb scan --table-name journey-sysarch-terraform-locks \
     --select COUNT
   # Expected: Count: 0 (lock is released after apply completes)
   # During a terraform apply, there would be 1 lock entry
   ```

5. **Understand what happens if you modify state directly**

   > **GOTCHA:** NEVER edit the state file manually. If you delete a resource from state without destroying it in AWS, Terraform "forgets" about it but the resource still exists (and costs money). If you add a resource to state that does not exist, Terraform will fail on the next plan. The only safe way to change infrastructure is through `.tf` files and `terraform apply`.

   ```bash
   # Safe way to see what Terraform would do if you changed something:
   # (Don't actually change anything -- just observe)
   terraform plan
   # Expected: "No changes. Your infrastructure matches the configuration."
   # This confirms state matches reality
   ```

### What You Learned

- `terraform state list` shows all managed resources
- `terraform state show` reveals every attribute of a resource (including computed values like endpoints)
- State is stored remotely in S3 with DynamoDB locking to prevent concurrent modifications
- Never edit state manually -- always use `terraform apply` to make changes

---

## Exercise 4: Run Database Migration

**Objective:** SSH into the EC2 instance and run `drizzle-kit push` against the RDS direct endpoint to create the database tables.

**Why this matters:** Infrastructure provisioning (Terraform) creates the database server, but the database is empty. Migrations create the schema (tables, columns, indexes) that your application needs. This is the bridge between infrastructure and application.

### Steps

1. **Get the connection details from Terraform**
   ```bash
   cd infra/staging

   # Get EC2 public IP for SSH
   EC2_IP=$(terraform output -raw ec2_public_ip)
   echo "EC2 IP: $EC2_IP"

   # Get RDS direct endpoint for migrations (NOT the proxy endpoint)
   RDS_DIRECT=$(terraform output -raw rds_direct_endpoint)
   echo "RDS Direct: $RDS_DIRECT"
   ```

2. **SSH into the EC2 instance**
   ```bash
   ssh -i ~/.ssh/your-key.pem ec2-user@$EC2_IP
   ```

3. **Verify database connectivity from EC2**
   ```bash
   # On the EC2 instance:
   # Install PostgreSQL client if not already available
   sudo yum install -y postgresql16

   # Test connection to RDS (use the direct endpoint)
   psql "postgresql://ecomadmin:YourSecurePassword123!@<rds-direct-endpoint>:5432/ecommerce" \
     -c "SELECT version();"
   # Expected: Shows PostgreSQL 16.x version string
   ```

4. **Run the database migration**
   ```bash
   # On the EC2 instance, navigate to the app directory
   cd /path/to/app

   # Set DATABASE_URL to the DIRECT RDS endpoint (not proxy!)
   export DATABASE_URL="postgresql://ecomadmin:YourSecurePassword123!@<rds-direct-endpoint>:5432/ecommerce"

   # Run drizzle-kit push
   npx drizzle-kit push
   # Expected: Shows table creation statements
   # "Changes applied" or similar success message
   ```

   > **GOTCHA:** Use the DIRECT RDS endpoint for migrations, not the proxy endpoint. DDL statements (CREATE TABLE, ALTER TABLE) should bypass the connection pool.

5. **Verify the tables were created**
   ```bash
   # Still on EC2, connect to the database
   psql "postgresql://ecomadmin:YourSecurePassword123!@<rds-direct-endpoint>:5432/ecommerce"

   # List all tables
   \dt
   # Expected: Shows tables created by your Drizzle schema (products, orders, etc.)

   # Check a table structure
   \d products
   # Expected: Shows columns, types, constraints

   # Exit psql
   \q
   ```

6. **Verify the app can connect via the proxy endpoint**
   ```bash
   # Now test connectivity through RDS Proxy (this is what the app uses)
   RDS_PROXY=$(terraform output -raw rds_proxy_endpoint)

   psql "postgresql://ecomadmin:YourSecurePassword123!@<rds-proxy-endpoint>:5432/ecommerce" \
     -c "\dt"
   # Expected: Same tables visible through the proxy
   ```

### Verification

```bash
# From your local machine (after exiting SSH):
# Verify by checking RDS connection count
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].DBInstanceStatus' --output text
# Expected: available (unchanged after migration)
```

### What You Learned

- Terraform provisions infrastructure; migrations set up the application schema
- Migrations use the direct RDS endpoint, not the proxy endpoint
- The same database is accessible through both direct and proxy endpoints
- `drizzle-kit push` is idempotent -- running it again makes no changes if the schema matches

---

## Exercise 5: Create Manual Snapshot and Test Backup

**Objective:** Create a manual RDS snapshot and verify that automated backups are configured.

**Why this matters:** Backups are your safety net. Before making changes (migrations, experiments, or destroying infrastructure), you should know how to create a snapshot and verify that automated backups are running.

### Steps

1. **Check automated backup configuration**
   ```bash
   aws rds describe-db-instances --db-instance-identifier staging-postgres \
     --query 'DBInstances[0].{
       BackupRetention: BackupRetentionPeriod,
       BackupWindow: PreferredBackupWindow,
       LatestRestore: LatestRestorableTime,
       MultiAZ: MultiAZ,
       Encrypted: StorageEncrypted
     }' --output table
   # Expected:
   # BackupRetention: 7
   # BackupWindow: 03:00-04:00
   # LatestRestore: (a recent timestamp, proving PITR is available)
   # MultiAZ: False
   # Encrypted: True
   ```

2. **Create a manual snapshot**
   ```bash
   # Create a snapshot (takes 1-3 minutes)
   SNAPSHOT_ID="staging-pre-exercise-$(date +%Y%m%d-%H%M)"
   aws rds create-db-snapshot \
     --db-instance-identifier staging-postgres \
     --db-snapshot-identifier $SNAPSHOT_ID

   echo "Created snapshot: $SNAPSHOT_ID"
   ```

3. **Wait for the snapshot to complete**
   ```bash
   # Check status (wait for "available")
   aws rds describe-db-snapshots \
     --db-snapshot-identifier $SNAPSHOT_ID \
     --query 'DBSnapshots[0].Status' --output text
   # Expected: creating -> available (refresh until "available")

   # Or wait with a loop:
   aws rds wait db-snapshot-available \
     --db-snapshot-identifier $SNAPSHOT_ID
   echo "Snapshot is available!"
   ```

4. **Inspect the snapshot details**
   ```bash
   aws rds describe-db-snapshots \
     --db-snapshot-identifier $SNAPSHOT_ID \
     --query 'DBSnapshots[0].{
       ID: DBSnapshotIdentifier,
       Status: Status,
       Created: SnapshotCreateTime,
       Engine: Engine,
       Size: AllocatedStorage,
       Encrypted: Encrypted
     }' --output table
   ```

5. **List all snapshots (automated and manual)**
   ```bash
   # Manual snapshots
   aws rds describe-db-snapshots \
     --db-instance-identifier staging-postgres \
     --snapshot-type manual \
     --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status,SnapshotCreateTime]' \
     --output table

   # Automated snapshots
   aws rds describe-db-snapshots \
     --db-instance-identifier staging-postgres \
     --snapshot-type automated \
     --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status,SnapshotCreateTime]' \
     --output table
   # Note: Automated snapshots may not exist yet if the daily backup window hasn't occurred
   ```

6. **Understand point-in-time recovery options**
   ```bash
   # Check the earliest and latest restorable times
   aws rds describe-db-instances --db-instance-identifier staging-postgres \
     --query 'DBInstances[0].{
       Earliest: EarliestRestorableTime,
       Latest: LatestRestorableTime
     }' --output table
   # These define the PITR window -- you can restore to any second between these two timestamps
   ```

   > **WHY this matters:** If you discover data corruption, you can restore to a point just before it happened. The restore creates a NEW RDS instance (it does not overwrite the current one), giving you a safe way to verify the restored data before switching over.

### Verification

```bash
# Confirm manual snapshot exists and is available
aws rds describe-db-snapshots \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --query 'DBSnapshots[0].Status' --output text
# Expected: available

# Confirm backup retention is set
aws rds describe-db-instances --db-instance-identifier staging-postgres \
  --query 'DBInstances[0].BackupRetentionPeriod' --output text
# Expected: 7
```

### What You Learned

- Automated backups happen daily during the backup window with configurable retention
- Manual snapshots persist until you delete them (unlike automated backups which expire)
- Point-in-time recovery lets you restore to any second within the retention period
- Restoring always creates a NEW instance, preserving the original as a safety net

---

## Exercise 6: Destroy and Rebuild

**Objective:** Destroy the entire staging environment with `terraform destroy`, then recreate it with `terraform apply` to prove IaC reproducibility.

**Why this matters:** This is the capstone exercise that proves the core value proposition of Infrastructure as Code. If you can destroy everything and rebuild it identically from code, you know that: (1) your infrastructure is fully defined in code, (2) nothing was configured manually, and (3) you can recover from any disaster by running `terraform apply`.

### Steps

1. **Create a manual snapshot first (safety net)**
   ```bash
   # If you have data you want to preserve:
   aws rds create-db-snapshot \
     --db-instance-identifier staging-postgres \
     --db-snapshot-identifier staging-pre-destroy-$(date +%Y%m%d)

   # Wait for it to complete
   aws rds wait db-snapshot-available \
     --db-snapshot-identifier staging-pre-destroy-$(date +%Y%m%d)
   ```

2. **Review what will be destroyed**
   ```bash
   cd infra/staging
   terraform plan -destroy
   # Expected: Shows ALL resources marked for destruction
   # Read the list carefully -- this is everything Terraform manages in staging
   ```

3. **Destroy the staging environment**
   ```bash
   terraform destroy
   # Type "yes" to confirm
   # Watch the destruction order -- Terraform destroys in reverse dependency order:
   #   RDS Proxy -> Secrets -> RDS -> EC2 -> Security Groups -> Subnets -> VPC
   # This takes 5-10 minutes (RDS Proxy and RDS instance deletion are slow)
   ```

   > **WHY reverse dependency order:** You cannot delete a VPC while subnets exist in it. You cannot delete subnets while instances are running in them. Terraform handles this automatically -- it destroys resources in the correct order based on their dependency graph.

4. **Verify everything is gone**
   ```bash
   # Check VPC
   aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=staging" \
     --query 'Vpcs[*].VpcId' --output text
   # Expected: (empty -- no VPC)

   # Check EC2
   aws ec2 describe-instances \
     --filters "Name=tag:Environment,Values=staging" "Name=instance-state-name,Values=running" \
     --query 'Reservations[*].Instances[*].InstanceId' --output text
   # Expected: (empty -- no running instances)

   # Check RDS
   aws rds describe-db-instances --db-instance-identifier staging-postgres 2>&1
   # Expected: "DBInstanceNotFound" error

   # Check state shows no resources
   terraform state list
   # Expected: (empty -- no managed resources)
   ```

5. **Rebuild from code**
   ```bash
   # Set the sensitive variables again
   export TF_VAR_db_username="ecomadmin"
   export TF_VAR_db_password="YourSecurePassword123!"
   export TF_VAR_key_pair_name="your-aws-keypair-name"

   # Apply -- recreate everything from scratch
   terraform apply
   # Type "yes" to confirm
   # Watch the creation -- same resources, same order as Exercise 2
   # Takes 10-15 minutes
   ```

6. **Verify everything works again**
   ```bash
   # Same verification as Exercise 2:
   terraform output
   # Expected: New IPs and endpoints (different from before, but same structure)

   # Verify EC2
   EC2_IP=$(terraform output -raw ec2_public_ip)
   ssh -i ~/.ssh/your-key.pem ec2-user@$EC2_IP "echo 'SSH works!'"
   # Expected: "SSH works!"

   # Verify RDS
   aws rds describe-db-instances --db-instance-identifier staging-postgres \
     --query 'DBInstances[0].DBInstanceStatus' --output text
   # Expected: available

   # Verify RDS Proxy
   aws rds describe-db-proxies --db-proxy-name staging-rds-proxy \
     --query 'DBProxies[0].Status' --output text
   # Expected: available
   ```

7. **Run migrations again on the fresh database**
   ```bash
   # The new RDS instance has an empty database -- run migrations
   # (Follow Exercise 4 steps again)
   # This proves: code -> infrastructure -> schema is fully reproducible
   ```

### What You Learned

- `terraform destroy` removes all managed resources in reverse dependency order
- `terraform apply` recreates everything identically from the same `.tf` files
- IPs and endpoints change (they are dynamic), but the infrastructure topology is identical
- The database is empty after rebuild -- you need to run migrations again
- Your manual snapshot from step 1 is preserved (manual snapshots survive instance deletion)
- This is disaster recovery in action: if your entire environment is compromised, you can rebuild it from code

> **WHY this is the most important exercise:** In a production incident, the ability to destroy and rebuild an environment is invaluable. Instead of debugging a corrupted system, you can spin up a fresh one and restore data from backups. Infrastructure as Code makes this possible -- without it, you would need to manually recreate every resource, which is error-prone and slow.

---

## Next Steps

After completing all 6 exercises:

1. **Review the phase gate checklist** (`docs/phase-05/phase-gate-checklist.md`) to verify you can prove every requirement
2. **Destroy the staging environment** (`terraform destroy` in `infra/staging/`) to stop incurring costs
3. **Keep the bootstrap infrastructure** if you plan to continue studying -- it costs nearly nothing (~$0.05/month)
4. **Move to Phase 6** when ready to learn container orchestration with ECS/Fargate
