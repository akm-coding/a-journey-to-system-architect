# Phase 1: Foundation

## Learning Objectives

By the end of this phase, you will be able to:

- **FOUND-01**: SSH into an EC2 instance and navigate the Linux filesystem (ls, cd, pwd, find, cat, less, nano)
- **FOUND-02**: List processes (ps, top), manage services (systemctl), set permissions (chmod, chown), and work with environment variables
- **FOUND-03**: Explain VPC purpose, diagram public/private subnets, configure security group rules, and trace requests through route tables
- **FOUND-04**: Create DNS A and CNAME records pointing to EC2 instances and verify with dig/nslookup
- **FOUND-05**: Install Certbot, obtain a Let's Encrypt certificate, verify HTTPS, and explain ACM vs Let's Encrypt tradeoffs
- **FOUND-06**: Set up a non-root IAM user with MFA, configure AWS CLI, and create a budget alert

## Prerequisites

- An AWS account (free tier eligible)
- A registered domain name (any registrar -- Route 53 or external)
- A terminal with SSH access (macOS Terminal, Windows WSL, or Linux)
- Git and a GitHub account
- Node.js 20+ and pnpm installed

## Estimated Time

At a pace of 1-2 hours per day, expect this phase to take approximately 2-3 weeks. Each topic has a guided exercise followed by a rebuild-from-scratch challenge.

## Topic Order

Work through these topics in order. Each builds on the previous:

```
  1. AWS Account Setup
     |
     v
  2. Linux Fundamentals
     |
     v
  3. Processes & Permissions
     |
     v
  4. Networking & VPC
     |
     v
  5. Security Groups
     |
     v
  6. DNS
     |
     v
  7. SSL/TLS
```

### 1. AWS Account Setup (FOUND-06)
Create a secure IAM user, configure CLI access, and set a budget alert. This must be done first before any AWS spending begins.
- Guide: `01-aws-account-setup/guide.md`
- Exercise: `01-aws-account-setup/exercise.md`
- Cheatsheet: `01-aws-account-setup/cheatsheet.md`

### 2. Linux Fundamentals (FOUND-01)
Learn to navigate the filesystem, read and edit files, and understand the Linux directory structure. You will practice on an EC2 instance.
- Guide: `02-linux-fundamentals/guide.md`
- Exercise: `02-linux-fundamentals/exercise.md`
- Cheatsheet: `02-linux-fundamentals/cheatsheet.md`

### 3. Processes & Permissions (FOUND-02)
Understand how Linux processes work, manage services with systemctl, and control file access with permissions and ownership.
- Guide: `03-processes-permissions/guide.md`
- Exercise: `03-processes-permissions/exercise.md`
- Cheatsheet: `03-processes-permissions/cheatsheet.md`

### 4. Networking & VPC (FOUND-03)
Learn how AWS networking works: VPCs, subnets, route tables, internet gateways, and NAT gateways. Draw diagrams to internalize the concepts.
- Guide: `04-networking-vpc/guide.md`
- Exercise: `04-networking-vpc/exercise.md`
- Cheatsheet: `04-networking-vpc/cheatsheet.md`

### 5. Security Groups (FOUND-03)
Deep dive into security groups as virtual firewalls. Understand inbound/outbound rules, stateful behavior, and common configurations.
- Guide: `05-security-groups/guide.md`
- Exercise: `05-security-groups/exercise.md`
- Cheatsheet: `05-security-groups/cheatsheet.md`

### 6. DNS (FOUND-04)
Understand how DNS resolution works, create A and CNAME records, and point your domain to an EC2 instance.
- Guide: `06-dns/guide.md`
- Exercise: `06-dns/exercise.md`
- Cheatsheet: `06-dns/cheatsheet.md`

### 7. SSL/TLS (FOUND-05)
Secure your site with HTTPS using Let's Encrypt and Certbot. Understand certificates, certificate authorities, and how TLS handshakes work.
- Guide: `07-ssl-tls/guide.md`
- Exercise: `07-ssl-tls/exercise.md`
- Cheatsheet: `07-ssl-tls/cheatsheet.md`

## Tracking Your Progress

- **Progress Log**: `progress-log.md` -- Record what you did each session
- **Rebuild Log**: `rebuild-log.md` -- Track your rebuild-from-scratch attempts
- **Phase Gate Checklist**: `phase-gate-checklist.md` -- Verify all skills before moving to Phase 2

## Phase Gate

You may NOT proceed to Phase 2 until every item in `phase-gate-checklist.md` is checked off. This is a strict gate -- partial completion means you need more practice.
