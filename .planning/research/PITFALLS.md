# Pitfalls Research: Common Mistakes Learning Infra/DevOps/System Design

**Research date:** 2026-05-06
**Domain:** What full-stack developers get wrong when learning infrastructure

## Critical Pitfalls

### 1. Tutorial Hell Without Real Deployment
**Severity:** HIGH | **Phase:** All phases
**Description:** Following tutorials step-by-step but never deploying anything real. You think you understand because the tutorial worked, but you can't reproduce it without the guide.
**Warning signs:** Can follow a tutorial but freeze when starting from scratch. Copy-paste YAML/config without understanding each line.
**Prevention:**
- Every phase must end with a deployment you built from scratch (not copied)
- After completing a tutorial exercise, delete everything and rebuild from memory
- Keep a "cheat sheet" you write yourself — not copied snippets

### 2. Skipping Networking Fundamentals
**Severity:** HIGH | **Phase:** Phase 1 (Foundation)
**Description:** Jumping to Docker/Terraform without understanding VPCs, subnets, security groups, DNS. Every debugging session later becomes 10x harder.
**Warning signs:** "It works locally but not on AWS." Can't explain why a security group rule is needed. Don't understand why private subnets exist.
**Prevention:**
- Dedicate real time to networking before touching containers
- Draw network diagrams for every deployment
- Debug connectivity issues manually (telnet, curl, nslookup) before asking for help

### 3. AWS Bill Shock
**Severity:** HIGH | **Phase:** All phases
**Description:** Forgetting to shut down resources after learning sessions. A forgotten NAT gateway costs ~$32/month. An idle RDS instance costs ~$15/month. Load balancers ~$16/month.
**Warning signs:** No budget alerts set up. Resources running 24/7 during learning. Using larger instance types than needed.
**Prevention:**
- Set up AWS Budget alerts immediately ($10/month threshold)
- Use Terraform so you can `terraform destroy` everything in one command
- Create a "teardown checklist" after each session
- Use the AWS Cost Explorer weekly
- Stick to t2.micro/t3.micro (free tier eligible)
- **Expensive resources to watch:** NAT Gateways, Load Balancers, RDS (if not free tier), ECS tasks running 24/7

### 4. Terraform Before Understanding
**Severity:** MEDIUM-HIGH | **Phase:** Phase 5 (IaC)
**Description:** Writing Terraform configs by copying examples without understanding the underlying AWS resources. You can `terraform apply` but can't debug when things go wrong.
**Warning signs:** Can't create the same infrastructure manually in the AWS console. Don't understand what a Terraform resource maps to in AWS. Confused by state file conflicts.
**Prevention:**
- Create every resource manually in the AWS console FIRST
- Then codify it in Terraform
- If you can't explain what a Terraform resource does, don't use it yet

### 5. Premature Microservices
**Severity:** MEDIUM | **Phase:** Phase 9 (System Design)
**Description:** Trying to build microservices architecture before understanding monolith deployment well. Adds network complexity, distributed tracing needs, and deployment overhead.
**Warning signs:** Splitting services before your monolith has any scaling problems. Can't explain when microservices are appropriate.
**Prevention:**
- Start with a well-structured monolith
- Only split when you can articulate the specific problem microservices solve
- Learn the theory in system design phase, but don't implement microservices as your first architecture

### 6. Security Shortcuts During Learning
**Severity:** MEDIUM-HIGH | **Phase:** All phases
**Description:** Using root AWS account, hardcoding credentials, opening security groups to 0.0.0.0/0, skipping IAM roles. These habits are dangerous and hard to unlearn.
**Warning signs:** AWS access keys in code/git. Security group allowing all inbound traffic. Using root account for everything.
**Prevention:**
- Create an IAM user on day 1 (never use root for daily work)
- Never commit credentials — use environment variables or AWS Secrets Manager
- Default security groups to minimum required access
- Learn IAM roles early (even if it feels tedious)

### 7. Over-Engineering the Learning Project
**Severity:** MEDIUM | **Phase:** All phases
**Description:** Building an elaborate app when a simple Express API + React frontend is sufficient. The goal is learning infra, not building a product.
**Warning signs:** Spending more time on app features than infrastructure. Adding GraphQL, WebSockets, etc. before basic deployment works.
**Prevention:**
- Use the same simple app throughout: Express API with 2-3 endpoints + React frontend
- The app should be boring — the infrastructure should be interesting
- Add complexity to the infra, not the app

### 8. Not Understanding Logs and Debugging
**Severity:** MEDIUM | **Phase:** Phase 8 (Observability)
**Description:** When something breaks in production, developers used to console.log have no idea how to find and read server logs, container logs, or CloudWatch logs.
**Warning signs:** Immediately adding console.log instead of checking existing logs. No structured logging. Can't tail logs on a remote server.
**Prevention:**
- Set up structured logging (JSON format) from Phase 2 onward
- Practice reading logs before adding more
- Learn `docker logs`, `journalctl`, CloudWatch Logs Insights
- When something breaks, find the log FIRST

### 9. Ignoring DNS and Domain Management
**Severity:** LOW-MEDIUM | **Phase:** Phase 1-2
**Description:** Always using IP addresses or localhost. Never learning how DNS works, how to set up a domain, how SSL certificates work.
**Warning signs:** Accessing your deployed app by IP address. Don't know what an A record or CNAME is. No HTTPS.
**Prevention:**
- Buy a cheap domain (~$10/year) early in the learning process
- Set up Route 53 and point your domain to your deployment
- Use AWS Certificate Manager for free SSL
- Understand DNS propagation and TTL

### 10. Learning Tools Instead of Concepts
**Severity:** MEDIUM | **Phase:** All phases
**Description:** Memorizing Docker commands or Terraform syntax without understanding the underlying concepts (containerization, infrastructure lifecycle, networking). Tools change; concepts don't.
**Warning signs:** Can run commands but can't explain what they do. Confused when tool versions change. Can't transfer knowledge to similar tools.
**Prevention:**
- For every tool command, explain the concept it implements
- "What problem does this solve?" before "How do I use this?"
- Draw diagrams of what's happening, not just run commands

## Phase-Specific Risk Summary

| Phase | Top Risk | Mitigation |
|-------|----------|------------|
| Foundation | Skipping networking | Dedicated networking exercises |
| Traditional Deploy | Not understanding what you deployed | Manual console deployment first |
| Docker | Treating it as magic | Build images step-by-step, understand layers |
| CI/CD | Copy-paste YAML | Write pipeline from scratch, understand each step |
| Terraform | Codifying what you don't understand | Console first, then codify |
| Production Deploy | Bill shock from ECS/ALB | Terraform destroy after each session |
| Data/Caching | Premature optimization | Start with simple queries, add caching when you can measure |
| Observability | Skipping it (it's "boring") | Make it mandatory — deploy monitoring with every app |
| System Design | Premature microservices | Start with monolith, split only with clear rationale |
