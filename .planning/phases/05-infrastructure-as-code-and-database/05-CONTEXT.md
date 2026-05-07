# Phase 5: Infrastructure as Code and Database - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Define all AWS infrastructure in Terraform and manage databases with production-grade patterns. Covers VPC, EC2, RDS, S3, ECR, and RDS Proxy. Everything provisioned from scratch (no importing existing resources). Terraform commands run manually — CI/CD integration for Terraform is out of scope.

</domain>

<decisions>
## Implementation Decisions

### Terraform structure
- Directory per environment: `infra/staging/` and `infra/production/` with shared modules in `infra/modules/`
- Each environment has its own state file (no workspaces)
- VPC + Security Groups module as the reusable module (used by both staging and production)
- State stored in S3 bucket with DynamoDB table for locking (bootstrapped manually first)
- Variables include type constraints, validation blocks, and descriptions
- Outputs documented with descriptions

### Resource scope
- All resources defined fresh from scratch — no terraform import of existing Phase 2-4 infra
- Compute: EC2 instances (ECS/Fargate deferred to Phase 6)
- Include ECR repos and S3/DynamoDB state backend as "bootstrap" infrastructure, separate from app infra
- Terraform plan/apply run manually (no CI/CD pipeline integration for Terraform)
- Full resource set: VPC, subnets, security groups, EC2, RDS, S3 (state), DynamoDB (lock), ECR

### Database patterns
- Connection pooling via RDS Proxy (AWS-managed, ~$15/mo)
- Automated daily backups with 7-day retention + manual snapshot exercise
- Pre-deploy migration step: SSH in, run drizzle-kit push (same as Phase 4 pattern, now documented in runbook)
- Study both Multi-AZ and single-AZ patterns; deploy single-AZ to keep costs low
- Show Multi-AZ configuration for reference

### Study materials
- Concept guide covering HCL syntax, state management, providers, resources, modules, plan/apply lifecycle
- Annotated .tf files with inline explanations (same pattern as Phase 3 Dockerfiles, Phase 4 workflow YAML)
- Cost estimation section showing monthly cost per resource
- Brief comparison: Terraform vs CloudFormation vs Pulumi vs CDK
- Destroy and rebuild exercise as final exercise (proves IaC reproducibility, matches success criteria #5)

### Claude's Discretion
- Exact variable names and output structure
- Terraform provider version pinning strategy
- Security group rule granularity
- RDS instance class selection (cost vs performance)
- Exercise ordering and difficulty progression

</decisions>

<specifics>
## Specific Ideas

- Bootstrap vs app infrastructure separation teaches a real production pattern (state backend can't manage itself)
- The destroy+rebuild exercise directly proves the core IaC value proposition
- Cost breakdown serves double duty: learning material and practical cost awareness for the learner's AWS bill

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-infrastructure-as-code-and-database*
*Context gathered: 2026-05-07*
