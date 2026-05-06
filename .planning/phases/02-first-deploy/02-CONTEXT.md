# Phase 2: First Deploy - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Deploy a full-stack React/Node e-commerce app to EC2 manually, with Nginx reverse proxy, PM2 process management, and RDS PostgreSQL. The learner builds the app and deploys it, understanding every step that managed platforms abstract away. The app is an ultra-minimal e-commerce: products list, single product view, add to cart, place order (4 pages, no auth).

</domain>

<decisions>
## Implementation Decisions

### Sample app
- Build the e-commerce app as part of this phase (not separately)
- Stack: React (Vite) frontend + Express API backend, both in TypeScript
- PostgreSQL via RDS for the database
- 4 pages: products list, single product view, add to cart, place order
- No authentication in this phase

### Learning format
- Hands-on runbook style: step-by-step guide with actual commands to run
- Explain the "why" alongside each command/config block — not walls of text, but enough to understand what you're doing and why
- Verification checkpoints after each major step (e.g., "curl localhost:3000/health should return...")
- Include common gotchas / troubleshooting tips inline for likely mistakes

### Deployment approach
- Incremental, layered deployment — one component at a time, verified before the next:
  1. Launch EC2, SSH in, run Node API directly
  2. Install + configure Nginx as reverse proxy
  3. Create RDS in private subnet, connect API to DB
  4. Build React frontend, serve via Nginx
- PM2: practical essentials only (start, restart, logs, ecosystem file, startup on reboot)
- Nginx: start from a working template config, then explain each directive
- HTTPS: set up with Let's Encrypt (Certbot + auto-renewal) — hands-on follow-through from Phase 1 SSL/TLS concepts

### AWS cost control
- Budget target: $0-5/month using free tier (t2.micro EC2, db.t3.micro RDS)
- RDS from the start — setting up RDS, security groups, private subnets is a key learning objective
- Include a teardown section with clear steps to destroy resources in order
- Include a rebuild shortcut for resuming in the next session

### Claude's Discretion
- Exact app folder structure and monorepo organization
- Database schema design (tables for products, orders, cart)
- PM2 ecosystem file configuration details
- Nginx config specifics beyond the explained template
- Security group rule details (as long as they follow least-privilege from Phase 1)

</decisions>

<specifics>
## Specific Ideas

- Same app gets deployed with increasing infrastructure sophistication across all 8 phases — keep it simple so the infra is the focus
- Phase 1 already covered SSL/TLS concepts, VPC/subnets, and security groups conceptually — this phase applies that knowledge hands-on
- Incremental deploy mirrors how you'd debug in production: isolate each layer

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-first-deploy*
*Context gathered: 2026-05-06*
