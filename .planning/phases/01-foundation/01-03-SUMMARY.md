---
phase: 01-foundation
plan: 03
subsystem: infra
tags: [vpc, subnets, security-groups, dns, ssl, tls, certbot, cloudflare, nginx, networking]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "Monorepo skeleton with docs directory structure (01-01)"
provides:
  - "VPC/subnets/route tables/IGW/NAT conceptual guide with ASCII architecture diagrams"
  - "Security groups guide covering stateful rules, SG referencing, lockout experiment"
  - "DNS guide covering resolution flow, record types, TTL, Cloudflare setup"
  - "SSL/TLS guide covering TLS handshake, certificate chain, ACM limitation, Let's Encrypt/Certbot"
  - "12 markdown files: guide + exercise + cheatsheet for 4 networking topics"
affects: [02-deploy, 05-terraform, 06-load-balancing]

# Tech tracking
tech-stack:
  added: [certbot, nginx-ssl, cloudflare-dns]
  patterns: [vpc-public-private-subnet, sg-referencing, lets-encrypt-on-ec2, concept-then-build-docs]

key-files:
  created:
    - docs/phase-01/04-networking-vpc/guide.md
    - docs/phase-01/04-networking-vpc/exercise.md
    - docs/phase-01/04-networking-vpc/cheatsheet.md
    - docs/phase-01/05-security-groups/guide.md
    - docs/phase-01/05-security-groups/exercise.md
    - docs/phase-01/05-security-groups/cheatsheet.md
    - docs/phase-01/06-dns/guide.md
    - docs/phase-01/06-dns/exercise.md
    - docs/phase-01/06-dns/cheatsheet.md
    - docs/phase-01/07-ssl-tls/guide.md
    - docs/phase-01/07-ssl-tls/exercise.md
    - docs/phase-01/07-ssl-tls/cheatsheet.md
  modified: []

key-decisions:
  - "Cloudflare free tier for DNS (zero cost), Route 53 taught conceptually for later phases"
  - "ACM limitation prominently called out: ACM certs work only with ALB/CloudFront, not standalone EC2"
  - "DNS exercise requires grey-cloud (DNS only) mode in Cloudflare for direct learning"

patterns-established:
  - "VPC standard pattern: 10.0.0.0/16 VPC, 10.0.1.0/24 public, 10.0.2.0/24 private"
  - "SG referencing pattern: web-sg allows public traffic, db-sg allows only from web-sg"
  - "Sequential exercises: VPC -> SG -> DNS -> SSL (each builds on previous)"

requirements-completed: [FOUND-03, FOUND-04, FOUND-05]

# Metrics
duration: 7min
completed: 2026-05-06
---

# Phase 1 Plan 03: Networking, DNS, and SSL/TLS Study Materials Summary

**VPC/subnet/SG guides with ASCII diagrams, DNS resolution via Cloudflare free tier, and SSL/TLS with Let's Encrypt/Certbot including ACM limitation callout**

## Performance

- **Duration:** 7 min
- **Started:** 2026-05-06T15:06:43Z
- **Completed:** 2026-05-06T15:13:52Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Created comprehensive VPC networking guide with two ASCII diagrams (architecture overview and request flow) covering VPC, subnets, IGW, NAT Gateway, and route tables with CIDR reference table
- Built security groups guide explaining stateful nature with flow diagram, SG referencing pattern (web-sg + db-sg), and deliberate lockout experiment in the exercise
- Created DNS guide with full resolution chain ASCII diagram, record type table, TTL guidance, and Cloudflare vs Route 53 comparison with rationale
- Built SSL/TLS guide with TLS handshake diagram, certificate chain explanation, and prominent ACM limitation callout per research pitfall #2

## Task Commits

Each task was committed atomically:

1. **Task 1: Create VPC networking and security groups guides** - `8ee987f` (feat)
2. **Task 2: Create DNS and SSL/TLS guides** - `4c09e32` (feat)

## Files Created/Modified
- `docs/phase-01/04-networking-vpc/guide.md` - VPC, subnets, IGW, NAT, route tables with ASCII diagrams (156 lines)
- `docs/phase-01/04-networking-vpc/exercise.md` - Create VPC from scratch with console + CLI, bastion pattern (283 lines)
- `docs/phase-01/04-networking-vpc/cheatsheet.md` - VPC CLI commands, CIDR reference, teardown order (106 lines)
- `docs/phase-01/05-security-groups/guide.md` - Stateful rules, SG referencing, best practices (106 lines)
- `docs/phase-01/05-security-groups/exercise.md` - SG config, lockout experiment, db-sg referencing web-sg (247 lines)
- `docs/phase-01/05-security-groups/cheatsheet.md` - SG CLI commands, port reference, troubleshooting (64 lines)
- `docs/phase-01/06-dns/guide.md` - DNS resolution flow, record types, TTL, Cloudflare vs Route 53 (121 lines)
- `docs/phase-01/06-dns/exercise.md` - Cloudflare setup, A/CNAME records, dig verification, TTL experiment (184 lines)
- `docs/phase-01/06-dns/cheatsheet.md` - dig/nslookup commands, propagation check (83 lines)
- `docs/phase-01/07-ssl-tls/guide.md` - TLS handshake, certificate chain, ACM limitation, Nginx SSL (133 lines)
- `docs/phase-01/07-ssl-tls/exercise.md` - Certbot install, Let's Encrypt cert, HTTPS verify, auto-renewal (269 lines)
- `docs/phase-01/07-ssl-tls/cheatsheet.md` - Certbot/openssl commands, cert file locations, ACM reminder (89 lines)

## Decisions Made
- Cloudflare free tier chosen for DNS exercises (zero cost, same learning concepts) with Route 53 explained conceptually for production use
- ACM limitation given prominent callout in SSL/TLS guide per research pitfall #2 -- learners must use Let's Encrypt for standalone EC2
- Exercises sequenced so DNS must be working before SSL (domain resolution required for Let's Encrypt certificate issuance)
- Cloudflare proxy set to "DNS only" (grey cloud) during exercises for direct learning without CDN layer

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. Domain purchase and Cloudflare signup are handled within the exercises themselves.

## Next Phase Readiness
- All 12 networking/DNS/SSL study materials complete
- Materials follow the established concept-then-build pattern (guide -> exercise -> cheatsheet -> rebuild challenge)
- Exercises are sequenced: VPC -> Security Groups -> DNS -> SSL/TLS (each builds on previous)
- Phase 1 study materials are now complete across all 7 topics (plans 01, 02, and 03)
- Phase gate checklist in `docs/phase-01/phase-gate-checklist.md` covers FOUND-01 through FOUND-06

## Self-Check: PASSED

- All 12 created files verified present on disk
- Commit 8ee987f (Task 1) verified in git log
- Commit 4c09e32 (Task 2) verified in git log

---
*Phase: 01-foundation*
*Completed: 2026-05-06*
