# Security Groups Exercise

## Prerequisites

- VPC from the networking exercise (or use the default VPC)
- EC2 key pair for SSH access
- Your current public IP (find it: `curl ifconfig.me`)

## Step 1: Create the Web Security Group

**Console:** EC2 Dashboard > Security Groups > Create security group
- Security group name: `web-sg`
- Description: "Allow SSH from my IP, HTTP/HTTPS from anywhere"
- VPC: select `learning-vpc` (or default VPC)

Add inbound rules:

| Type  | Port | Source | Description |
|-------|------|--------|-------------|
| SSH   | 22   | My IP (auto-fills your IP/32) | SSH from my machine |
| HTTP  | 80   | 0.0.0.0/0 | HTTP from anywhere |
| HTTPS | 443  | 0.0.0.0/0 | HTTPS from anywhere |

Leave outbound rules as default (all traffic allowed).

**CLI:**
```bash
# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name web-sg \
  --description "Allow SSH from my IP, HTTP/HTTPS from anywhere" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

echo "Security Group ID: $SG_ID"

# Get your public IP
MY_IP=$(curl -s ifconfig.me)

# Allow SSH from your IP only
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr ${MY_IP}/32

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow HTTPS from anywhere
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
```

## Step 2: Launch EC2 with the Security Group

Launch an EC2 instance in the public subnet with `web-sg` attached.

```bash
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>
```

Once connected, install and start Nginx:

```bash
# Amazon Linux 2023
sudo dnf install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify locally
curl localhost
# Should return the Nginx welcome page HTML
```

## Step 3: Test HTTP from Your Local Machine

From your **local machine** (not the EC2):

```bash
curl http://<public-ip>
```

You should see the Nginx welcome page HTML. This works because:
- `web-sg` allows inbound TCP port 80 from `0.0.0.0/0`
- The public subnet has a route to the IGW
- Nginx is listening on port 80

## Step 4: Experiment -- Remove and Re-add HTTP Rule

**Remove the HTTP rule:**

Console: EC2 > Security Groups > `web-sg` > Inbound rules > Edit > Delete the port 80 rule > Save

```bash
# CLI: Revoke the HTTP rule
aws ec2 revoke-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
```

**Test immediately:**
```bash
curl --connect-timeout 5 http://<public-ip>
# Should timeout -- port 80 is no longer allowed
```

**Add it back:**
```bash
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
```

**Test again:**
```bash
curl http://<public-ip>
# Works again -- Nginx welcome page
```

**Key lesson:** Security group changes take effect immediately. No restart needed. No delay.

## Step 5: Deliberate Lockout Experiment

This is intentional -- you will lock yourself out and then fix it.

**Remove the SSH rule:**

Console: EC2 > Security Groups > `web-sg` > Inbound rules > Edit > Delete the port 22 rule > Save

```bash
# CLI: Revoke SSH rule
aws ec2 revoke-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr ${MY_IP}/32
```

**Try to SSH:**
```bash
ssh -o ConnectTimeout=5 -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>
# Connection timed out -- you are locked out
```

**Fix it via the Console:**
1. Go to EC2 > Security Groups > `web-sg`
2. Edit inbound rules
3. Add rule: SSH (port 22) from My IP
4. Save

```bash
# Or fix via CLI
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr ${MY_IP}/32
```

**SSH again:**
```bash
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>
# Works again
```

**Key lesson:** You can always fix a security group lockout via the AWS Console or CLI. You never lose the instance. But if this were a production server with no other access path, you would be scrambling.

## Step 6: Test Outbound Rules

From the EC2 instance:

```bash
# Default outbound allows everything
curl https://example.com
# Should return HTML -- outbound works

ping -c 3 8.8.8.8
# Should succeed -- outbound ICMP allowed
```

**(Optional, advanced):** Try restricting outbound rules and observe the effect. This is rarely done in practice but demonstrates the concept.

## Step 7: Create the Database Security Group

Create a second security group that only allows connections from `web-sg`:

**Console:** Create security group
- Name: `db-sg`
- Description: "Allow PostgreSQL from web-sg only"
- VPC: same as `web-sg`
- Inbound rule: Custom TCP, Port 5432, Source: **select the `web-sg` security group** (not a CIDR)

**CLI:**
```bash
DB_SG_ID=$(aws ec2 create-security-group \
  --group-name db-sg \
  --description "Allow PostgreSQL from web-sg only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# Allow PostgreSQL from web-sg (use SG ID as source)
aws ec2 authorize-security-group-ingress --group-id $DB_SG_ID \
  --protocol tcp --port 5432 --source-group $SG_ID
```

**Verify the SG reference:**
```bash
aws ec2 describe-security-groups --group-ids $DB_SG_ID \
  --query 'SecurityGroups[].IpPermissions[].[FromPort,ToPort,UserIdGroupPairs[].GroupId]' \
  --output text
```

You should see port 5432 with the `web-sg` group ID as the source. This means only instances in `web-sg` can connect to port 5432 on instances in `db-sg`.

**Why this matters:** In Phase 2, you will create an RDS PostgreSQL database with exactly this pattern -- the database security group allows connections only from the application server's security group.

## Verification Checklist

- [ ] `curl http://<public-ip>` returns the Nginx welcome page
- [ ] SSH works only from your IP (test by checking the SG rules)
- [ ] Removing port 80 immediately blocks HTTP access (and adding it back restores it)
- [ ] You successfully locked yourself out of SSH and recovered via the console
- [ ] `db-sg` has port 5432 rule referencing `web-sg` by security group ID (not CIDR)
- [ ] You can explain the difference between stateful (SG) and stateless (NACL)

## Clean Up

1. Terminate the EC2 instance
2. Wait for the instance to reach "terminated" state
3. Delete `db-sg` first (it has no dependencies)
4. Delete `web-sg` (must delete db-sg first if db-sg references web-sg)

```bash
# Terminate instance
aws ec2 terminate-instances --instance-ids i-xxx
aws ec2 wait instance-terminated --instance-ids i-xxx

# Delete security groups (order matters if they reference each other)
aws ec2 delete-security-group --group-id $DB_SG_ID
aws ec2 delete-security-group --group-id $SG_ID
```

## Rebuild Challenge

Create a VPC with two security groups:
1. `web-sg`: allows SSH from your IP, HTTP/HTTPS from anywhere
2. `db-sg`: allows PostgreSQL (5432) only from `web-sg`

Verify the SG references are correct using:
```bash
aws ec2 describe-security-groups --group-ids $DB_SG_ID
```

**Target time:** Under 5 minutes using only the CLI.

Log your time and any issues in `docs/phase-01/rebuild-log.md`.
