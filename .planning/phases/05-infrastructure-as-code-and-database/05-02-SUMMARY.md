---
phase: 05-infrastructure-as-code-and-database
plan: 02
subsystem: infra
tags: [terraform, vpc, ec2, rds, rds-proxy, secrets-manager, iam, security-groups]

requires:
  - phase: 05-infrastructure-as-code-and-database
    plan: 01
    provides: Bootstrap S3 state bucket, DynamoDB lock table, ECR repo, Terraform concepts
provides:
  - Reusable VPC module with parameterized CIDRs, subnets, IGW, route tables, 3 security groups
  - Complete staging environment Terraform configs (VPC, EC2, RDS, RDS Proxy, Secrets Manager)
  - Complete production environment Terraform configs mirroring staging with production values
  - Foundation for Plan 03 exercises and study materials
affects: [05-03, 06-container-orchestration]

tech-stack:
  added: []
  patterns: [reusable-vpc-module, sg-referencing-pattern, environment-separation, dynamic-ami-lookup, secrets-manager-for-rds-proxy]

key-files:
  created:
    - infra/modules/vpc/main.tf
    - infra/modules/vpc/variables.tf
    - infra/modules/vpc/outputs.tf
    - infra/staging/providers.tf
    - infra/staging/variables.tf
    - infra/staging/terraform.tfvars
    - infra/staging/main.tf
    - infra/staging/ec2.tf
    - infra/staging/rds.tf
    - infra/staging/rds-proxy.tf
    - infra/staging/secrets.tf
    - infra/staging/outputs.tf
    - infra/production/providers.tf
    - infra/production/variables.tf
    - infra/production/terraform.tfvars
    - infra/production/main.tf
    - infra/production/ec2.tf
    - infra/production/rds.tf
    - infra/production/rds-proxy.tf
    - infra/production/secrets.tf
    - infra/production/outputs.tf
  modified: []

key-decisions:
  - "SG referencing pattern: RDS allows traffic from RDS Proxy SG, Proxy allows from App SG (not CIDR-based)"
  - "Separate aws_security_group_rule resources to avoid circular dependency errors"
  - "Production CIDR 10.1.0.0/16 avoids overlap with staging 10.0.0.0/16 for potential VPC peering"
  - "Production keeps final snapshot on destroy; staging skips it for clean teardown"
  - "Force-added terraform.tfvars to git despite .gitignore since they contain only non-sensitive values"

patterns-established:
  - "Reusable VPC module called from both environments with different parameters"
  - "SG referencing pattern: security groups reference other SGs instead of CIDR blocks"
  - "Dynamic AMI lookup via data source instead of hardcoded AMI IDs"
  - "Secrets Manager + IAM role pattern for RDS Proxy credential access"
  - "Environment separation via directory structure with shared module source"

requirements-completed: [IAC-01, IAC-03, DATA-01, DATA-03, DATA-04]

duration: 5min
completed: 2026-05-07
---

# Phase 5 Plan 02: VPC Module and Environment Terraform Configurations Summary

**Reusable VPC module with 3 security groups, plus complete staging and production Terraform configs covering EC2, RDS PostgreSQL with 7-day backups, RDS Proxy with Secrets Manager auth, and IAM roles**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-07T11:10:14Z
- **Completed:** 2026-05-07T11:15:13Z
- **Tasks:** 3
- **Files modified:** 21

## Accomplishments
- Reusable VPC module with VPC, public+private subnets across 2 AZs, IGW, route tables, and 3 security groups using SG referencing pattern
- Complete staging environment (9 .tf files) with EC2, RDS PostgreSQL 16.4, RDS Proxy, Secrets Manager, and S3 remote backend
- Complete production environment mirroring staging with different CIDR range, final snapshot enabled, and separate state key
- All .tf files annotated with inline comment blocks explaining what each resource does and why

## Task Commits

Each task was committed atomically:

1. **Task 1: Reusable VPC module** - `7cd1ec8` (feat)
2. **Task 2: Staging environment Terraform configuration** - `edaea69` (feat)
3. **Task 3: Production environment Terraform configuration** - `588bbf5` (feat)

## Files Created/Modified
- `infra/modules/vpc/main.tf` - VPC, subnets, IGW, route tables, 3 security groups (app, rds, rds_proxy) with SG referencing
- `infra/modules/vpc/variables.tf` - Parameterized inputs with type constraints and validation blocks
- `infra/modules/vpc/outputs.tf` - vpc_id, subnet IDs, security group IDs with descriptions
- `infra/staging/providers.tf` - Terraform >= 1.15.0, AWS ~> 6.0, S3 backend with staging state key
- `infra/staging/variables.tf` - Region, project name, instance type, DB credentials (sensitive marked)
- `infra/staging/terraform.tfvars` - Non-sensitive values only (project_name, region, instance_type, db_name)
- `infra/staging/main.tf` - VPC module call with staging CIDRs (10.0.0.0/16)
- `infra/staging/ec2.tf` - EC2 with dynamic AMI lookup and Docker user_data
- `infra/staging/rds.tf` - RDS PostgreSQL 16.4, db.t4g.micro, 7-day backups, skip_final_snapshot = true
- `infra/staging/rds-proxy.tf` - RDS Proxy with Secrets Manager auth, connection pool config
- `infra/staging/secrets.tf` - Secrets Manager secret + IAM role for RDS Proxy
- `infra/staging/outputs.tf` - Proxy endpoint, direct RDS endpoint, EC2 IP, instance ID, VPC ID
- `infra/production/providers.tf` - Same as staging but with production state key
- `infra/production/variables.tf` - Same variables, default environment = production
- `infra/production/terraform.tfvars` - Production values with same instance types
- `infra/production/main.tf` - VPC module call with production CIDRs (10.1.0.0/16)
- `infra/production/ec2.tf` - Same EC2 setup as staging
- `infra/production/rds.tf` - Same RDS but skip_final_snapshot = false, final_snapshot_identifier set
- `infra/production/rds-proxy.tf` - Same RDS Proxy configuration
- `infra/production/secrets.tf` - Same Secrets Manager + IAM role pattern
- `infra/production/outputs.tf` - Same outputs as staging

## Decisions Made
- Used SG referencing pattern (source_security_group_id) instead of CIDR blocks for inter-service communication -- more secure and scales with instances
- Separate aws_security_group_rule resources instead of inline blocks to avoid circular dependency errors (RESEARCH.md pitfall #4)
- Production uses CIDR 10.1.0.0/16 while staging uses 10.0.0.0/16 to avoid overlap in case VPC peering is ever needed
- Production sets skip_final_snapshot = false with a named final_snapshot_identifier as a safety net
- Force-added terraform.tfvars to git despite *.tfvars in .gitignore because these files contain only non-sensitive configuration values; sensitive values are passed via TF_VAR_ environment variables

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- terraform.tfvars files were ignored by .gitignore (*.tfvars pattern). Resolved by using `git add -f` since the plan explicitly requires committing these files and they contain only non-sensitive values (project name, region, instance type, db name).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All Terraform configurations are ready for `terraform init && terraform plan` after bootstrap
- VPC module demonstrates reusability across staging and production
- Plan 03 can use these configs for exercises (init, plan, apply, destroy lifecycle)
- The annotated .tf files serve as study material for understanding each resource

## Self-Check: PASSED

All 21 created files verified. All 3 task commits (7cd1ec8, edaea69, 588bbf5) confirmed in git log.

---
*Phase: 05-infrastructure-as-code-and-database*
*Completed: 2026-05-07*
