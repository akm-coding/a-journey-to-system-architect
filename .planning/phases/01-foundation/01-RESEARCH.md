# Phase 1: Foundation - Research

**Researched:** 2026-05-06
**Domain:** Linux fundamentals, AWS networking (VPC/subnets/SGs), DNS/SSL, IAM/budget, monorepo skeleton
**Confidence:** HIGH

## Summary

Phase 1 is a pure learning phase -- no application code is built. The deliverables are markdown study guides, hands-on exercises, cheatsheets, and verification checklists in `/docs/phase-01/`. The learner will work through Linux server basics, AWS networking concepts (VPC, subnets, security groups, route tables), DNS configuration, SSL/TLS certificates, and IAM/budget setup. Additionally, the monorepo skeleton is initialized (folder structure, pnpm workspace config, `.gitignore`) even though app code arrives in Phase 2.

The critical insight for planning is the **SSL/TLS gap**: AWS Certificate Manager (ACM) certificates cannot be installed directly on EC2 instances -- they require a load balancer or CloudFront distribution. Since Phase 1 has no load balancer, the learner must use **Let's Encrypt with Certbot** for HTTPS on a standalone EC2 instance. ACM is introduced conceptually but used hands-on in later phases when load balancers appear.

**Primary recommendation:** Structure the phase as four learning waves: (1) AWS account security + budget alerts first, (2) Linux fundamentals on EC2, (3) networking concepts + VPC exercises, (4) DNS + SSL/TLS. Initialize the monorepo skeleton early as a practical git exercise.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Ultra-minimal e-commerce app: products list, single product view, add to cart, place order (4 pages, no auth initially)
- Tech stack: Express + React (Vite) + PostgreSQL + Drizzle ORM
- Package manager: pnpm
- Monorepo structure: `/app`, `/infra`, `/docs`, `/scripts`
- App code is NOT built in Phase 1 -- built in Phase 2 right before first deploy
- Phase 1 focuses purely on infra/networking skills using AWS console and CLI
- "Concept then build" approach: brief explanation (2-3 paragraphs) of WHY/WHAT, then hands-on exercise
- After each guided exercise, tear down and rebuild from scratch without instructions
- Both ASCII diagrams in markdown AND visual diagrams (Excalidraw/images) for architecture/networking topics
- All materials in English
- Study materials in `/docs/phase-01/` folder
- Every concept links to the relevant AWS documentation page
- Each topic includes a `cheatsheet.md` with common commands and patterns
- Structure: concept guide -> hands-on exercise -> cheatsheet -> rebuild challenge
- Checklist of "can you do X?" items for each topic
- Working deployment/configuration as proof (e.g., EC2 accessible, DNS resolving)
- Progress log (`progress-log.md`) with dates, screenshots, and deployment URLs
- Separate rebuild attempt log tracking time taken and issues encountered
- Strict phase gate: ALL checklist items must be verified before advancing to Phase 2

### Claude's Discretion
- Exact ordering of Linux vs networking topics within the phase
- Which specific Linux commands to cover (beyond basics)
- Whether to use Route 53 or a cheaper DNS provider for domain setup
- Visual diagram tool choice (Excalidraw, draw.io, etc.)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | SSH into EC2 and navigate Linux filesystem | Linux fundamentals section: SSH key setup, filesystem navigation commands, key-based auth |
| FOUND-02 | Manage processes, permissions, environment variables | Linux fundamentals: ps/top/kill, chmod/chown, export/env, systemctl |
| FOUND-03 | Explain VPC, subnets, security groups, route tables | Networking section: VPC architecture, public vs private subnets, SG rules, route table config |
| FOUND-04 | Configure DNS records (A, CNAME) and understand resolution | DNS section: A/CNAME records, DNS resolution flow, Route 53 vs Cloudflare analysis |
| FOUND-05 | Set up SSL/TLS certificates using ACM | SSL/TLS section: ACM conceptual understanding + Let's Encrypt/Certbot for EC2 hands-on |
| FOUND-06 | IAM user (not root), AWS CLI, budget alerts | IAM/Budget section: IAM Identity Center vs IAM user analysis, CLI v2 setup, budget alert config |
</phase_requirements>

## Standard Stack

### Core (AWS Services for Phase 1)
| Service | Purpose | Why Standard | Free Tier? |
|---------|---------|--------------|------------|
| EC2 (t2.micro/t3.micro) | Linux practice server | Standard learning instance | Yes -- 750 hrs/month for 12 months |
| VPC | Networking fundamentals | Default for all AWS networking | Free (no charge for VPC itself) |
| IAM | User/role management | Required for secure AWS access | Free |
| AWS Budgets | Cost alerts | Prevents bill shock | Free (first 2 budgets) |
| ACM | SSL/TLS certificates (conceptual) | Free managed certificates | Free (but requires ALB/CloudFront) |

### Supporting Tools
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| AWS CLI v2 | Latest | Command-line AWS management | All AWS operations from terminal |
| Certbot | Latest | Let's Encrypt SSL on EC2 | HTTPS without a load balancer |
| Nginx | Latest stable | Web server for SSL termination | Serving HTTPS on EC2 |
| pnpm | Latest (9.x) | Package manager / workspace init | Monorepo skeleton setup |

### DNS Provider Decision (Claude's Discretion)

**Recommendation: Cloudflare (free tier) for DNS, with Route 53 taught conceptually.**

| Option | Cost | Pros | Cons |
|--------|------|------|------|
| **Cloudflare (recommended)** | Free | Zero cost, fast DNS (~11ms), free SSL proxy, easy UI | Not native AWS integration |
| Route 53 | ~$0.50/month per hosted zone + query fees | Native AWS, alias records, health checks | Costs money for a learning exercise |

**Rationale:** For a learning project focused on understanding DNS concepts (A records, CNAME, TTL, propagation), Cloudflare's free tier teaches the same concepts without recurring cost. Route 53's advanced features (weighted routing, failover) are not needed until later phases. The guide should explain Route 53 conceptually and note it as the production choice for AWS-native setups.

### Visual Diagram Tool Decision (Claude's Discretion)

**Recommendation: Excalidraw.**

Excalidraw is free, open-source, exports to PNG/SVG, has a hand-drawn aesthetic that encourages sketching over perfection, and can be used in-browser at excalidraw.com with no account required. The learner should also draw diagrams by hand on paper as part of exercises (per CONTEXT.md).

## Architecture Patterns

### Recommended Docs Structure
```
docs/
  phase-01/
    00-overview.md              # Phase overview, learning objectives, prerequisites
    01-aws-account-setup/
      guide.md                  # IAM user creation, MFA, CLI setup, budget alerts
      exercise.md               # Hands-on: create IAM user, configure CLI, set budget
      cheatsheet.md             # AWS CLI auth commands, budget CLI commands
    02-linux-fundamentals/
      guide.md                  # Filesystem, navigation, file operations
      exercise.md               # SSH into EC2, navigate, create/edit files
      cheatsheet.md             # Essential Linux commands
    03-processes-permissions/
      guide.md                  # Processes, permissions, env vars, services
      exercise.md               # Install Nginx, manage with systemctl, set perms
      cheatsheet.md             # ps, top, chmod, chown, systemctl commands
    04-networking-vpc/
      guide.md                  # VPC, subnets, route tables, internet/NAT gateways
      exercise.md               # Create VPC from scratch, launch EC2 in public subnet
      cheatsheet.md             # VPC CLI commands, CIDR notation reference
      diagrams/                 # Excalidraw source files + exported PNGs
    05-security-groups/
      guide.md                  # Inbound/outbound rules, stateful nature, best practices
      exercise.md               # Configure SGs, test connectivity with curl/telnet
      cheatsheet.md             # SG CLI commands, common rule patterns
    06-dns/
      guide.md                  # DNS resolution, record types, TTL, propagation
      exercise.md               # Point domain to EC2 via Cloudflare, verify with dig/nslookup
      cheatsheet.md             # DNS commands, record type reference
    07-ssl-tls/
      guide.md                  # How TLS works, certificate chain, ACM overview
      exercise.md               # Install Certbot + Nginx, get Let's Encrypt cert
      cheatsheet.md             # Certbot commands, Nginx SSL config
    progress-log.md             # Dates, screenshots, deployment URLs
    rebuild-log.md              # Rebuild attempt tracking
    phase-gate-checklist.md     # All verification items
```

### Monorepo Skeleton (initialized in Phase 1)
```
/ (project root)
  app/                          # Empty -- populated in Phase 2
    package.json                # Placeholder with name only
  infra/                        # Empty -- populated in Phase 5
  docs/                         # Study guides (populated in Phase 1)
    phase-01/
  scripts/                      # Utility scripts
    teardown-checklist.sh       # Reminder to destroy AWS resources
  package.json                  # Root package.json
  pnpm-workspace.yaml           # Workspace config
  .gitignore                    # Node, AWS credentials, .env, IDE files
  .nvmrc                        # Node version pin
```

### Pattern: Concept-Then-Build Learning Flow
**What:** Each topic follows a rigid 4-step pattern
**When to use:** Every single topic in the phase
**Structure:**
1. **Guide** (2-3 paragraphs WHY/WHAT) -- concept explanation with ASCII diagram
2. **Exercise** (step-by-step) -- hands-on with AWS console/CLI
3. **Cheatsheet** -- command reference, common patterns
4. **Rebuild Challenge** -- tear down, rebuild from memory, log time/issues

### Pattern: Verification-Driven Learning
**What:** Every exercise ends with a concrete verification step
**Examples:**
- "SSH into your instance and run `uname -a` -- paste the output"
- "Run `curl -I https://yourdomain.com` -- you should see a 200 with valid cert"
- "Draw the VPC diagram from memory, then compare to the reference"

### Anti-Patterns to Avoid
- **Copy-paste configs without understanding:** Every config line should be explained in the guide
- **Using root AWS account:** IAM user setup must be the very first exercise
- **Skipping the rebuild:** The rebuild step is not optional -- it is the actual learning
- **Over-scoping Linux content:** Cover DevOps-essential commands, not full sysadmin curriculum

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSL certificates on EC2 | Manual OpenSSL cert generation | Certbot (Let's Encrypt) | Auto-renewal, trusted CA, free, 5-minute setup |
| SSH key management | Manual key file copying | ssh-keygen + ssh-copy-id | Standard, secure, well-documented |
| Budget monitoring | Manual cost checking | AWS Budgets + SNS alert | Automated, catches spend before it hurts |
| DNS management | Editing zone files manually | Cloudflare dashboard or Route 53 | UI prevents syntax errors, instant propagation visibility |

## Common Pitfalls

### Pitfall 1: AWS Bill Shock
**What goes wrong:** Learner forgets to terminate EC2 instances, delete EBS volumes, or release Elastic IPs after practice sessions. A forgotten Elastic IP costs $0.005/hr (~$3.65/month). A forgotten t3.small costs ~$15/month.
**Why it happens:** No teardown habit established. Free tier limits not understood.
**How to avoid:** Budget alert ($10/month) is literally the first exercise. Teardown checklist script in `/scripts/`. Every exercise ends with "Clean up" section.
**Warning signs:** AWS Cost Explorer showing unexpected charges. Running instances in EC2 dashboard when not actively learning.

### Pitfall 2: ACM Certificate Confusion
**What goes wrong:** Learner requests an ACM certificate expecting to install it on EC2 directly. ACM certificates cannot be exported to EC2 (except Nitro Enclaves). Hours wasted troubleshooting.
**Why it happens:** ACM documentation does not make this limitation obvious upfront.
**How to avoid:** Guide explicitly states: "ACM = load balancer/CloudFront only. For standalone EC2, use Let's Encrypt." ACM is taught conceptually, hands-on uses Certbot.
**Warning signs:** Trying to find an "install certificate" option for EC2 in ACM console.

### Pitfall 3: Security Group Lockout
**What goes wrong:** Learner removes SSH (port 22) from security group inbound rules, locking themselves out of the instance. Or opens 0.0.0.0/0 on all ports "to make it work."
**Why it happens:** Security group rules are confusing for beginners. Stateful nature not understood.
**How to avoid:** Exercise explicitly covers: "What happens if you remove port 22?" as a deliberate experiment (with instructions to fix via console). Guide explains stateful = return traffic is auto-allowed.
**Warning signs:** "Connection timed out" after changing SG rules. All ports open to 0.0.0.0/0.

### Pitfall 4: SSH Key Confusion
**What goes wrong:** Learner loses the .pem key file, creates multiple keys and forgets which goes where, or has wrong file permissions on the key.
**Why it happens:** Key-based auth is unfamiliar to web developers used to password auth.
**How to avoid:** Guide covers: (1) generate key pair, (2) download .pem immediately, (3) `chmod 400 key.pem`, (4) store in `~/.ssh/` with a sensible name. Exercise includes recovering from "Permission denied (publickey)."
**Warning signs:** "Permission denied" errors. Multiple .pem files with unclear names.

### Pitfall 5: VPC/Subnet CIDR Confusion
**What goes wrong:** Learner picks overlapping CIDR blocks, or does not understand why /16 vs /24 matters, leading to routing issues.
**Why it happens:** CIDR notation is not intuitive. IP math feels abstract.
**How to avoid:** Guide includes a clear CIDR reference table (10.0.0.0/16 = 65,536 IPs, 10.0.1.0/24 = 256 IPs). Exercise uses a standard pattern: VPC = 10.0.0.0/16, public subnet = 10.0.1.0/24, private subnet = 10.0.2.0/24.
**Warning signs:** Terraform/console errors about overlapping CIDRs. "Why can't my instances talk to each other?"

### Pitfall 6: IAM Long-Lived Access Keys
**What goes wrong:** Learner creates IAM user access keys and hardcodes them in scripts or commits them to git. Keys get leaked.
**Why it happens:** Access keys feel like the "easy" way to authenticate CLI.
**How to avoid:** Guide recommends IAM Identity Center with `aws configure sso` for temporary credentials. If using IAM user (simpler for solo learner), guide covers: never commit keys, use `~/.aws/credentials`, rotate regularly. `.gitignore` includes credential patterns from day one.
**Warning signs:** Access keys in git history. `AWS_ACCESS_KEY_ID` hardcoded in scripts.

## Code Examples

### SSH into EC2
```bash
# Download key pair during EC2 launch, then:
chmod 400 ~/.ssh/my-ec2-key.pem
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>

# Or configure SSH config for convenience:
# ~/.ssh/config
# Host my-ec2
#   HostName <public-ip>
#   User ec2-user
#   IdentityFile ~/.ssh/my-ec2-key.pem
ssh my-ec2
```

### Essential Linux Commands for DevOps
```bash
# Filesystem navigation
ls -la              # List all files with details
cd /var/log         # Change directory
pwd                 # Print working directory
cat /etc/os-release # View file contents
less /var/log/syslog # Page through large files
find / -name "nginx.conf" # Find files

# File operations
mkdir -p /opt/myapp     # Create directory (with parents)
cp -r source/ dest/     # Copy recursively
mv old.txt new.txt      # Move/rename
rm -rf /tmp/test        # Remove recursively (careful!)
chmod 755 script.sh     # Set permissions (rwxr-xr-x)
chown ec2-user:ec2-user file.txt # Change ownership

# Process management
ps aux                  # List all processes
top                     # Real-time process monitor (q to quit)
kill <pid>              # Send SIGTERM to process
kill -9 <pid>           # Force kill (SIGKILL)
systemctl status nginx  # Check service status
systemctl start nginx   # Start a service
systemctl enable nginx  # Start on boot
journalctl -u nginx -f  # Follow service logs

# Environment variables
export NODE_ENV=production  # Set for current session
echo $PATH                  # Print variable
env                         # List all env vars
# Persist in ~/.bashrc or /etc/environment

# Networking diagnostics
curl -I https://example.com    # HTTP headers
ping 8.8.8.8                   # Test connectivity
dig example.com                # DNS lookup
nslookup example.com           # DNS lookup (simpler)
ss -tlnp                       # Show listening ports
```

### VPC Creation via AWS CLI
```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications \
  'ResourceType=vpc,Tags=[{Key=Name,Value=learning-vpc}]'

# Create public subnet
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1}]'

# Create private subnet
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-1}]'

# Create and attach internet gateway
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id vpc-xxx --internet-gateway-id igw-xxx

# Create route table for public subnet
aws ec2 create-route-table --vpc-id vpc-xxx
aws ec2 create-route --route-table-id rtb-xxx \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxx
aws ec2 associate-route-table --route-table-id rtb-xxx --subnet-id subnet-xxx
```

### Security Group Configuration
```bash
# Create security group
aws ec2 create-security-group --group-name web-sg \
  --description "Allow SSH and HTTP/HTTPS" --vpc-id vpc-xxx

# Allow SSH from your IP only
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 22 --cidr <your-ip>/32

# Allow HTTP and HTTPS from anywhere
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
```

### Let's Encrypt / Certbot on EC2 (Amazon Linux 2 / Ubuntu)
```bash
# Install Certbot (Ubuntu)
sudo apt update
sudo apt install certbot python3-certbot-nginx -y

# Install Certbot (Amazon Linux 2)
sudo amazon-linux-extras install epel -y
sudo yum install certbot python2-certbot-nginx -y

# Get certificate (domain must already point to this EC2 IP)
sudo certbot --nginx -d yourdomain.com

# Verify auto-renewal
sudo certbot renew --dry-run

# Certificates stored at: /etc/letsencrypt/live/yourdomain.com/
```

### AWS Budget Alert Setup
```bash
# Create a $10/month budget with email alert
aws budgets create-budget --account-id <account-id> \
  --budget '{
    "BudgetName": "Monthly-10-Dollar-Limit",
    "BudgetLimit": {"Amount": "10", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{
      "SubscriptionType": "EMAIL",
      "Address": "your-email@example.com"
    }]
  }]'
```

### pnpm Workspace Initialization
```bash
# Initialize root
pnpm init

# Create workspace config
cat > pnpm-workspace.yaml << 'EOF'
packages:
  - 'app'
  - 'infra'
  - 'docs'
  - 'scripts'
EOF

# Create placeholder packages
mkdir -p app infra docs/phase-01 scripts
echo '{"name": "app", "private": true}' > app/package.json
echo '{"name": "infra", "private": true}' > infra/package.json

# Create .nvmrc
echo "20" > .nvmrc
```

### .gitignore (Phase 1)
```gitignore
# Dependencies
node_modules/

# Environment & credentials
.env
.env.*
*.pem
.aws/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Build artifacts
dist/
build/

# Terraform (future phases)
.terraform/
*.tfstate
*.tfstate.backup
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| IAM users with long-lived access keys | IAM Identity Center with temporary credentials via `aws configure sso` | 2023-2024 | More secure CLI access, no permanent keys to leak |
| Manual SSL with OpenSSL self-signed certs | Let's Encrypt (Certbot) for free trusted certs | 2016+ (mature) | No more browser warnings, auto-renewal |
| t2.micro only for free tier | t2.micro OR t3.micro (region-dependent) | ~2023 | t3.micro available in regions where t2 is not |
| VPC classic (no VPC) | All new accounts get default VPC | 2013+ | VPC is mandatory, no "EC2 Classic" |
| Console-only learning | AWS CLI v2 + console side-by-side | Current best practice | CLI reinforces understanding, prepares for automation |

## IAM Setup Recommendation (Claude's Discretion)

**Recommendation: Use IAM user with access keys for simplicity, but teach IAM Identity Center conceptually.**

For a solo learner on a personal AWS account, IAM Identity Center adds setup complexity (requires AWS Organizations) that distracts from the learning goal. A dedicated IAM user with:
- MFA enabled
- AdministratorAccess policy (for learning flexibility)
- Access keys stored in `~/.aws/credentials` (never committed)
- Keys rotated monthly

is the pragmatic choice. The guide should explain that IAM Identity Center with temporary credentials is the production best practice for teams, and the learner will encounter it in professional settings.

## Linux Command Coverage Recommendation (Claude's Discretion)

**Core (must cover):**
- Navigation: `ls`, `cd`, `pwd`, `find`, `which`
- Files: `cat`, `less`, `head`, `tail`, `grep`, `cp`, `mv`, `rm`, `mkdir`, `touch`, `nano`/`vim` basics
- Permissions: `chmod`, `chown`, `sudo`, `whoami`, `id`
- Processes: `ps`, `top`, `kill`, `systemctl`, `journalctl`
- Environment: `export`, `env`, `echo`, `source`, `.bashrc`
- Networking: `curl`, `ping`, `dig`, `nslookup`, `ss`, `ip addr`
- Package management: `apt`/`yum` (depending on AMI)
- Archives: `tar`, `zip`, `unzip`
- Disk: `df -h`, `du -sh`

**Skip (not needed for Phase 1):**
- Advanced text processing (`awk`, `sed` beyond basics)
- Shell scripting (beyond simple one-liners)
- Cron jobs (comes naturally in later phases)
- User/group management (single-user learning server)

## Open Questions

1. **Domain purchase**
   - What we know: A cheap domain (~$10/year) is needed for DNS and SSL exercises
   - What's unclear: Whether the learner already has a domain, and preferred registrar
   - Recommendation: Note in exercise that any registrar works. Suggest Cloudflare Registrar or Namecheap for cheapest .dev or .com domains

2. **AWS Region**
   - What we know: us-east-1 is cheapest and has all services
   - What's unclear: Learner's geographic location may affect latency
   - Recommendation: Default to us-east-1 in all exercises, note that any region works

3. **Amazon Linux 2 vs Ubuntu for EC2**
   - What we know: Both are free tier eligible. Ubuntu has more community tutorials. Amazon Linux 2 is AWS-optimized.
   - What's unclear: Learner preference
   - Recommendation: Use Amazon Linux 2023 (AL2023) as the primary AMI since it is AWS's own distribution and the learner will encounter it professionally. Note Ubuntu as an alternative.

## Sources

### Primary (HIGH confidence)
- [AWS VPC Subnets docs](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html) - Subnet configuration, AZ constraints
- [AWS Security Groups docs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) - SG rules, stateful behavior, best practices
- [AWS Route Tables docs](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html) - Route table configuration, association
- [ACM Services Integration](https://docs.aws.amazon.com/acm/latest/userguide/acm-services.html) - Which services can use ACM certs (NOT direct EC2)
- [AWS re:Post ACM on EC2](https://repost.aws/knowledge-center/configure-acm-certificates-ec2) - Confirmed: ACM requires ALB/NLB/CloudFront
- [AWS Budgets best practices](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-best-practices.html) - Budget configuration
- [AWS IAM best practices](https://aws.amazon.com/iam/resources/best-practices/) - IAM user setup, least privilege
- [AWS CLI SSO configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html) - IAM Identity Center CLI setup
- [AWS EC2 Free Tier](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html) - 750 hrs/month t2/t3.micro

### Secondary (MEDIUM confidence)
- [Certbot on Amazon Linux 2](https://repost.aws/articles/ARAv0upzKKTvy0vNZHtyjj-w/use-certbot-to-enable-https-with-apache-or-nginx-on-ec2-instances-running-amazon-linux-2-al2) - AWS re:Post verified guide
- [DigitalOcean Nginx + Let's Encrypt](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-20-04) - Well-maintained tutorial
- [Cloudflare DNS vs Route 53](https://www.spendbase.co/blog/cloud/amazon-route-53-vs-cloudflare-dns-which-one-fits-your-stack/) - Pricing comparison
- [pnpm workspace setup](https://hackernoon.com/how-to-set-up-a-monorepo-with-vite-typescript-and-pnpm-workspaces) - Monorepo config patterns
- [Linux commands for DevOps](https://www.digitalocean.com/community/tutorials/linux-commands) - Command reference

### Tertiary (LOW confidence)
- Specific Certbot package names may vary by AL2023 vs AL2 vs Ubuntu -- verify at install time
- pnpm 9.x workspace syntax should be verified against latest docs at time of writing guides

## Metadata

**Confidence breakdown:**
- AWS networking concepts (VPC/subnets/SGs): HIGH - official AWS docs verified
- SSL/TLS approach (Certbot for EC2, ACM for ALB): HIGH - official AWS docs confirm ACM limitation
- IAM setup approach: HIGH - official best practices reviewed
- Linux command list: HIGH - well-established DevOps curriculum
- DNS provider recommendation: MEDIUM - based on pricing comparison, not official AWS guidance
- Monorepo skeleton: MEDIUM - standard pnpm patterns, but specific config untested
- Amazon Linux 2023 as default AMI: MEDIUM - AWS standard but learner may prefer Ubuntu

**Research date:** 2026-05-06
**Valid until:** 2026-06-06 (30 days -- AWS services are stable)
