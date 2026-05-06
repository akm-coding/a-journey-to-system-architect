# Phase 1: Foundation - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Linux fundamentals, AWS networking concepts, and secure AWS environment setup. This is the bedrock — SSH, filesystem, processes, VPC/subnets/security groups, DNS, SSL/TLS, IAM, and budget alerts. No app deployment (that's Phase 2). No Docker (Phase 3). No Terraform (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Learning Project (carries through all phases)
- Ultra-minimal e-commerce app: products list, single product view, add to cart, place order (4 pages, no auth initially)
- Tech stack: Express + React (Vite) + PostgreSQL + Drizzle ORM
- Package manager: pnpm
- Monorepo structure organized by concern:
  - `/app` — React frontend + Express API
  - `/infra` — Terraform configs (later phases)
  - `/docs` — Study guides and cheatsheets
  - `/scripts` — Utility scripts
- App code is NOT built in Phase 1 — built in Phase 2 right before first deploy
- Phase 1 focuses purely on infra/networking skills using AWS console and CLI

### Exercise Style
- "Concept then build" approach: brief explanation (2-3 paragraphs) of WHY/WHAT, then hands-on exercise
- After each guided exercise, tear down and rebuild from scratch without instructions
- Both ASCII diagrams in markdown AND visual diagrams (Excalidraw/images) for architecture/networking topics
- All materials in English

### Study Materials
- In-repo markdown guides in `/docs/phase-01/` folder
- Every concept links to the relevant AWS documentation page
- Each topic includes a `cheatsheet.md` with common commands and patterns
- Structure: concept guide → hands-on exercise → cheatsheet → rebuild challenge

### Verification
- Checklist of "can you do X?" items for each topic
- Working deployment/configuration as proof (e.g., EC2 accessible, DNS resolving)
- Progress log (`progress-log.md`) with dates, screenshots, and deployment URLs
- Separate rebuild attempt log tracking time taken and issues encountered
- **Strict phase gate**: ALL checklist items must be verified before advancing to Phase 2

### Claude's Discretion
- Exact ordering of Linux vs networking topics within the phase
- Which specific Linux commands to cover (beyond basics)
- Whether to use Route 53 or a cheaper DNS provider for domain setup
- Visual diagram tool choice (Excalidraw, draw.io, etc.)

</decisions>

<specifics>
## Specific Ideas

- The monorepo structure should be initialized in Phase 1 even though app code comes in Phase 2 — set up the skeleton with proper .gitignore, pnpm workspace config, etc.
- Budget alert should be one of the very first things configured ($10/month threshold per pitfalls research)
- Networking exercises should include drawing diagrams by hand (not just reading them)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-05-06*
