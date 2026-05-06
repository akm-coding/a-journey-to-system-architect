# Security Groups Cheatsheet

## Security Group Commands

```bash
# Create security group
aws ec2 create-security-group \
  --group-name web-sg \
  --description "Allow HTTP/HTTPS" \
  --vpc-id vpc-xxx

# Add inbound rule (CIDR source)
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 22 --cidr 203.0.113.50/32

# Add inbound rule (SG source -- for cross-SG access)
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 5432 --source-group sg-yyy

# Remove inbound rule
aws ec2 revoke-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# List security groups in a VPC
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-xxx" \
  --query 'SecurityGroups[].[GroupId,GroupName,Description]' \
  --output table

# Show rules for a specific SG
aws ec2 describe-security-groups --group-ids sg-xxx

# Delete security group
aws ec2 delete-security-group --group-id sg-xxx
```

## Common Rule Patterns

```bash
MY_IP=$(curl -s ifconfig.me)

# SSH from your IP only
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 22 --cidr ${MY_IP}/32

# HTTP from anywhere
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# HTTPS from anywhere
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# PostgreSQL from another SG
aws ec2 authorize-security-group-ingress --group-id sg-db \
  --protocol tcp --port 5432 --source-group sg-web

# Custom port from VPC CIDR
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 3000 --cidr 10.0.0.0/16
```

## Port Number Quick Reference

| Port  | Service    | Typical Source          |
|-------|------------|------------------------|
| 22    | SSH        | Your IP/32             |
| 80    | HTTP       | 0.0.0.0/0              |
| 443   | HTTPS      | 0.0.0.0/0              |
| 3000  | Node.js    | VPC CIDR or SG         |
| 3306  | MySQL      | App SG                 |
| 5432  | PostgreSQL | App SG                 |
| 6379  | Redis      | App SG                 |
| 8080  | Alt HTTP   | VPC CIDR or SG         |
| 27017 | MongoDB    | App SG                 |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "Connection timed out" on SSH | Port 22 not open, or wrong source IP | Add SSH rule with your current IP/32 |
| "Connection timed out" on HTTP | Port 80 not open | Add HTTP rule from 0.0.0.0/0 |
| Can reach HTTP but not HTTPS | Port 443 not open | Add HTTPS rule from 0.0.0.0/0 |
| EC2 cannot download packages | Outbound rules restricted (rare) | Check outbound rules allow 0.0.0.0/0 |
| DB connection refused | Port 5432/3306 not open from app SG | Add rule with source = app SG ID |
| "Connection refused" (not timeout) | Port is open but nothing is listening | Check the application is running |
| Locked out of SSH | Removed port 22 rule | Fix via AWS Console -- add SSH rule back |

> **"Connection timed out" vs "Connection refused":**
> - **Timed out** = traffic never reached the instance (SG, route table, or NACL issue)
> - **Connection refused** = traffic reached the instance but nothing is listening on that port (application issue)
