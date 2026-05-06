# Phase 2: First Deploy -- Manual EC2 Deployment

## What You Will Accomplish

In this phase, you deploy a real full-stack application to AWS manually. You will launch an EC2 instance, install and configure every component by hand, and understand exactly what managed platforms like Heroku, Vercel, and AWS Elastic Beanstalk abstract away. By the end, your e-commerce app will be live on the internet with HTTPS.

This is the most important phase for building deployment intuition. Every later phase (containers, CI/CD, IaC) automates what you do here manually.

## Architecture

```
                         Internet
                            |
                      [ Elastic IP ]
                            |
                +-----------+-----------+
                |    EC2 (t2.micro)     |
                |   Amazon Linux 2023   |
                |                       |
                |  +-----------------+  |
                |  |     Nginx       |  |
                |  |  :80 -> :443   |  |
                |  | (SSL termination) |
                |  +----+-------+---+  |
                |       |       |      |
                |    /api/*   /* (static)
                |       |       |      |
                |  +----v----+ dist/   |
                |  |   PM2   | (React  |
                |  |  Node   |  SPA)   |
                |  |  :3000  |         |
                |  +----+----+         |
                +-------+--------------+
                        |
               Private Subnet (no IGW)
                +-------+-------+
                | RDS PostgreSQL |
                |  db.t3.micro   |
                |     :5432      |
                +---------------+
```

**How the pieces fit together:**

- **Nginx** listens on ports 80 and 443, terminates SSL, serves React static files directly, and proxies `/api/*` requests to Node.js
- **PM2** manages the Node.js process -- auto-restarts on crash, persists across reboots, manages logs
- **Node.js/Express** handles API requests on port 3000 (never exposed to the internet directly)
- **RDS PostgreSQL** runs in a private subnet, accessible only from the EC2 security group

## Topics

| # | Topic | What You Build |
|---|-------|---------------|
| 1 | EC2 Deploy (Nginx + PM2 + HTTPS) | Deploy the app to EC2 with reverse proxy, process management, and SSL |
| 2 | RDS Database Setup | Create a PostgreSQL database in a private subnet and connect the API |

## Prerequisites

- Phase 1 complete (VPC, subnets, security groups, DNS, SSL/TLS concepts)
- AWS account with IAM user (created in Phase 1)
- A registered domain pointed to Cloudflare (set up in Phase 1 DNS exercise)
- The e-commerce app built and working locally (Plan 02-01)

## Cost Estimate

| Service | Tier | Monthly Cost |
|---------|------|-------------|
| EC2 | t2.micro (free tier) | $0 |
| RDS PostgreSQL | db.t3.micro (free tier) | $0 |
| Elastic IP | Attached to running instance | $0 |
| VPC | N/A | $0 |
| **Total** | | **$0-5/month** |

Free tier covers 750 hours/month for both EC2 and RDS for the first 12 months. Costs only apply if you exceed free tier limits or forget to tear down resources.

---

*Phase: 02-first-deploy*
