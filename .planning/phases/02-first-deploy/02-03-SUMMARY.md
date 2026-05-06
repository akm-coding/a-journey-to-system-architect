---
phase: 02-first-deploy
plan: 03
subsystem: infra
tags: [rds, postgresql, security-groups, sg-referencing, db-subnet-group, drizzle, teardown, rebuild, aws-free-tier]

# Dependency graph
requires:
  - phase: 02-first-deploy
    provides: "Full-stack e-commerce app with Drizzle schema, seed script, and PM2 config (02-01)"
  - phase: 02-first-deploy
    provides: "EC2 running with Nginx + PM2, VPC with 2 public + 2 private subnets (02-02)"
provides:
  - "RDS PostgreSQL setup runbook with SG referencing, DB subnet group, free-tier settings, and full-stack connectivity"
  - "RDS and database command cheatsheet"
  - "Phase 2 teardown script (ordered resource deletion)"
  - "Phase 2 rebuild script (guided ~20 minute recreation checklist)"
affects: [03-containerization, 05-terraform]

# Tech tracking
tech-stack:
  added: [rds-postgresql, psql-client]
  patterns: [sg-referencing-for-rds, db-subnet-group-2az, private-subnet-rds, ordered-teardown]

key-files:
  created:
    - docs/phase-02/02-rds-database/runbook.md
    - docs/phase-02/02-rds-database/cheatsheet.md
    - scripts/teardown-phase2.sh
    - scripts/rebuild-phase2.sh
  modified: []

key-decisions:
  - "Teardown script fully automates resource deletion with confirmation prompt and dependency-ordered steps"
  - "Rebuild script is a guided checklist (not blind automation) so learner practices from memory"

patterns-established:
  - "SG referencing for RDS: RDS SG allows port 5432 only from EC2 SG (never an IP)"
  - "DB subnet group requires 2 AZs even for single-AZ RDS deployment"
  - "Ordered teardown: RDS -> DB subnet group -> EC2 -> EIP -> SGs -> VPC"

requirements-completed: [DEPL-02]

# Metrics
duration: 5min
completed: 2026-05-06
---

# Phase 2 Plan 3: RDS Database Setup and Teardown/Rebuild Scripts Summary

**RDS PostgreSQL runbook with SG referencing pattern, DB subnet group setup, Drizzle migration/seed workflow, plus ordered teardown and guided rebuild scripts for cost control**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-06T16:38:30Z
- **Completed:** 2026-05-06T16:43:05Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created comprehensive RDS runbook (581 lines) with 6 sections covering security group creation with SG referencing, DB subnet group (2 AZ requirement), RDS instance creation with free-tier settings, EC2-to-RDS connectivity, Drizzle migrations and seeding, and full-stack architecture recap
- Built RDS cheatsheet (160 lines) with CLI commands, psql connection reference, DATABASE_URL format, Drizzle commands, and troubleshooting table
- Created teardown script (214 lines) that deletes all Phase 2 resources in correct dependency order with VPC cleanup (IGW, subnets, route tables)
- Created rebuild script (180 lines) as a guided checklist with time estimates totaling ~20 minutes

## Task Commits

Each task was committed atomically:

1. **Task 1: Create RDS database setup and connectivity runbook** - `0dc6059` (feat)
2. **Task 2: Create teardown and rebuild scripts** - `91a91fe` (feat)

## Files Created/Modified

- `docs/phase-02/02-rds-database/runbook.md` - Step-by-step RDS setup: SG creation, DB subnet group, RDS launch, EC2 connectivity, Drizzle migrations, full-stack recap (581 lines)
- `docs/phase-02/02-rds-database/cheatsheet.md` - Quick reference for RDS CLI, SG commands, psql, DATABASE_URL, Drizzle, and troubleshooting (160 lines)
- `scripts/teardown-phase2.sh` - Ordered teardown of all Phase 2 AWS resources with confirmation and VPC cleanup (214 lines)
- `scripts/rebuild-phase2.sh` - Guided rebuild checklist with commands and time estimates (180 lines)

## Decisions Made

- **Teardown script is fully automated (with confirmation):** Prompts for resource IDs at the start, then executes deletion in dependency order without further interaction. Handles VPC sub-resources (IGW, subnets, route tables) explicitly since `aws ec2 delete-vpc` alone doesn't clean everything.
- **Rebuild script is a guided checklist, not automation:** The learner should recreate the environment from memory, using the script only as a reference. This reinforces learning rather than encouraging copy-paste.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - scripts and documentation only. AWS account and CLI access are prerequisites from the EC2 deployment runbook (Plan 02).

## Next Phase Readiness

- Phase 2 documentation is complete: app built (Plan 01), EC2 deployment runbook (Plan 02), RDS database runbook (Plan 03)
- Teardown and rebuild scripts enable cost-efficient study sessions
- All research pitfalls (1: DB subnet group 2 AZs, 2: SG referencing not IP, 7: free-tier settings) addressed with GOTCHA callouts
- Ready for Phase 3 containerization of the same app

## Self-Check: PASSED

- docs/phase-02/02-rds-database/runbook.md: FOUND (581 lines, exceeds 200 minimum)
- docs/phase-02/02-rds-database/cheatsheet.md: FOUND (160 lines, exceeds 30 minimum)
- scripts/teardown-phase2.sh: FOUND (214 lines, executable)
- scripts/rebuild-phase2.sh: FOUND (180 lines, executable)
- Commit 0dc6059 (Task 1): verified in git log
- Commit 91a91fe (Task 2): verified in git log

---
*Phase: 02-first-deploy*
*Completed: 2026-05-06*
