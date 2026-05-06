---
phase: 01-foundation
plan: 02
subsystem: infra
tags: [linux, ssh, filesystem, processes, permissions, systemd, nginx, env-vars]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "Monorepo skeleton, directory structure for Phase 1 topics, AWS account setup materials"
provides:
  - "Linux fundamentals study materials (SSH, filesystem, navigation, file ops, packages)"
  - "Processes and permissions study materials (ps, systemd, chmod/chown, env vars)"
  - "6 markdown files following concept-then-build pattern across 2 topics"
affects: [01-03-PLAN, phase-02]

# Tech tracking
tech-stack:
  added: []
  patterns: [concept-then-build-docs, rebuild-challenge-pattern]

key-files:
  created:
    - docs/phase-01/02-linux-fundamentals/guide.md
    - docs/phase-01/02-linux-fundamentals/exercise.md
    - docs/phase-01/02-linux-fundamentals/cheatsheet.md
    - docs/phase-01/03-processes-permissions/guide.md
    - docs/phase-01/03-processes-permissions/exercise.md
    - docs/phase-01/03-processes-permissions/cheatsheet.md
  modified: []

key-decisions:
  - "Amazon Linux 2023 with yum package manager as exercise target (per research recommendation)"
  - "Nginx as the practical systemd service example for teaching service management"

patterns-established:
  - "Exercises include troubleshooting tips for common errors (Permission denied, Connection timed out)"
  - "Each exercise ends with verification commands, clean-up steps, and rebuild challenge"
  - "Cheatsheets organized by category with tables for quick scanning"

requirements-completed: [FOUND-01, FOUND-02]

# Metrics
duration: 4min
completed: 2026-05-06
---

# Phase 1 Plan 02: Linux Fundamentals and Processes/Permissions Summary

**SSH/filesystem/navigation guide plus processes/systemd/permissions/env-vars guide with hands-on EC2 exercises and command cheatsheets**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-06T15:06:38Z
- **Completed:** 2026-05-06T15:10:35Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created comprehensive Linux fundamentals guide covering SSH key auth (with ASCII handshake diagram), filesystem hierarchy, navigation, file operations, text editing, package management, archives, and disk space
- Built hands-on EC2 exercise walking through instance launch, SSH connection, filesystem exploration, file manipulation, package installation, and SSH config setup
- Created processes/permissions guide covering ps/top output interpretation, signals, systemd service management, permission model (with ASCII diagram), chmod/chown, sudo, and environment variables
- Built hands-on exercise with Nginx installation as practical systemd service example, permission experimentation, and env var persistence patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Linux fundamentals guides (FOUND-01)** - `d837159` (feat)
2. **Task 2: Create processes and permissions guides (FOUND-02)** - `f00c266` (feat)

## Files Created/Modified
- `docs/phase-01/02-linux-fundamentals/guide.md` - Conceptual guide: SSH, filesystem, navigation, file ops, packages, archives, disk (137 lines)
- `docs/phase-01/02-linux-fundamentals/exercise.md` - Hands-on: launch EC2, SSH in, explore filesystem, create files, install packages (219 lines)
- `docs/phase-01/02-linux-fundamentals/cheatsheet.md` - Quick reference by category: navigation, files, text, packages, archives, disk, SSH, networking preview (110 lines)
- `docs/phase-01/03-processes-permissions/guide.md` - Conceptual guide: processes, systemd, permissions, env vars with ASCII diagrams (188 lines)
- `docs/phase-01/03-processes-permissions/exercise.md` - Hands-on: Nginx service management, permission manipulation, env var config, process control (347 lines)
- `docs/phase-01/03-processes-permissions/cheatsheet.md` - Quick reference: processes, systemctl, journalctl, chmod, chown, env vars (126 lines)

## Decisions Made
- Used Amazon Linux 2023 with yum as the exercise target OS (consistent with research recommendation and AWS Free Tier)
- Chose Nginx as the practical systemd service example -- it is lightweight, universally known, and demonstrates start/stop/enable/status/logs workflow clearly

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Linux fundamentals and processes/permissions materials complete
- Learner can now SSH into EC2, navigate filesystem, manage services, set permissions, and configure env vars
- Ready for Plan 03 (networking, security groups, DNS, SSL/TLS topics)
- All exercises reference the EC2 instance and AWS account from Plan 01 materials

## Self-Check: PASSED

- All 6 created files verified present on disk
- Commit d837159 (Task 1) verified in git log
- Commit f00c266 (Task 2) verified in git log

---
*Phase: 01-foundation*
*Completed: 2026-05-06*
