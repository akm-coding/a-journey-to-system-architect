# Security Groups Guide

## Why Security Groups Matter

Security groups are your firewall in AWS. They control what traffic is allowed to reach your resources and what traffic can leave them. Every EC2 instance, RDS database, and load balancer has at least one security group attached to it.

The critical thing to understand is **default-deny inbound**: nothing gets in unless you explicitly allow it. If you launch an EC2 instance and forget to allow SSH (port 22) in its security group, you cannot connect to it. Period. There is no "override" or "admin backdoor." This is actually a good thing -- it means your resources are secure by default.

Misconfigured security groups are the number one cause of "it doesn't work" in AWS. Before debugging your application code, your Docker container, or your DNS records -- check the security group. Nine times out of ten, the port is not open.

## What You Need to Know

### Inbound vs Outbound Rules

- **Inbound rules:** Control incoming traffic (what can reach your instance). Default: **all denied**.
- **Outbound rules:** Control outgoing traffic (what your instance can reach). Default: **all allowed**.

This means a fresh security group blocks everything coming in but allows your instance to make any outbound connection (download packages, call APIs, etc.).

### Rule Anatomy

Every security group rule has three components:

| Component | Description | Example |
|-----------|-------------|---------|
| Protocol  | TCP, UDP, or ICMP | TCP |
| Port Range | Single port or range | 22 (SSH), 80 (HTTP), 443 (HTTPS) |
| Source/Destination | CIDR block or another Security Group ID | `203.0.113.50/32` (your IP) or `sg-0abc123` |

### Stateful Nature

Security groups are **stateful**. This means:

- If you allow an **inbound** request (e.g., HTTP on port 80), the **response** is automatically allowed out -- even if there is no outbound rule for it.
- If your instance makes an **outbound** request (e.g., downloading a package), the **response** is automatically allowed in.

You do not need to create matching inbound + outbound rules for the same connection.

```
Stateful Flow (Security Group):

  Client                Security Group              EC2
    │                        │                       │
    │── HTTP Request ──────>│── Port 80 allowed ──>│
    │                        │   (inbound rule)      │
    │                        │                       │
    │<── HTTP Response ─────│<── Auto-allowed ──────│
    │                        │   (stateful: no       │
    │                        │    outbound rule       │
    │                        │    needed)             │
```

**Contrast with Network ACLs (NACLs):** NACLs are **stateless** -- you must explicitly allow both inbound AND outbound traffic. Security groups handle this automatically. For most use cases, security groups are all you need.

### Security Group Referencing

One of the most powerful features: a security group rule can reference another security group as its source. Instead of specifying an IP range, you say "allow traffic from any instance that belongs to security group X."

**Pattern: Web server + Database**
```
web-sg:
  Inbound: Port 80/443 from 0.0.0.0/0 (anyone on internet)
  Inbound: Port 22 from YOUR_IP/32 (SSH from your machine only)

db-sg:
  Inbound: Port 5432 from web-sg (PostgreSQL from web servers only)
```

This is better than using IP addresses because:
- New web servers automatically get access (they join web-sg)
- You do not need to update db-sg when web server IPs change
- It is self-documenting: "only web servers can talk to the database"

### Best Practices

1. **Least privilege:** Only open the ports you actually need
2. **Restrict SSH:** Never allow SSH (port 22) from `0.0.0.0/0` in production. Use your IP with `/32` (single IP)
3. **Use SG references** instead of CIDR blocks when connecting AWS resources to each other
4. **Name your security groups** descriptively: `web-sg`, `db-sg`, `cache-sg` -- not `sg-1`, `sg-2`
5. **One purpose per SG:** Do not create a single "allow everything" security group

### Common Rule Patterns

| Purpose | Protocol | Port | Source | When to Use |
|---------|----------|------|--------|-------------|
| SSH access | TCP | 22 | YOUR_IP/32 | Admin access to EC2 |
| HTTP | TCP | 80 | 0.0.0.0/0 | Public web server |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Public web server (SSL) |
| PostgreSQL | TCP | 5432 | web-sg | Database from app servers |
| MySQL | TCP | 3306 | web-sg | Database from app servers |
| Redis | TCP | 6379 | web-sg | Cache from app servers |
| Custom app | TCP | 3000 | 10.0.0.0/16 | Node.js app within VPC |

### What Happens If You Remove Port 22?

You lock yourself out. You cannot SSH into the instance anymore. The connection will simply time out.

**The good news:** This is always recoverable. Go to the AWS Console > EC2 > Security Groups > find your SG > Edit inbound rules > add SSH back. You never lose the instance -- you just temporarily cannot connect to it.

**This is not true for all lockout scenarios.** If you terminate the instance or lose the SSH key, that is a different (worse) problem. But security group changes are always reversible via the console.

## Further Reading

- [AWS Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Security Group Rules Reference](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html)
- [Network ACLs vs Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Security.html)
