# RDS PostgreSQL Database Setup Runbook

This runbook walks you through creating an RDS PostgreSQL instance in a private subnet, connecting your Express API on EC2 to it, and running Drizzle migrations and seed data. By the end, your app will serve products from a real managed database.

**Prerequisites:**
- EC2 instance running with Nginx + PM2 (completed in the EC2 deploy runbook)
- VPC with 2 public subnets + 2 private subnets across 2 AZs (created during EC2 setup)
- AWS CLI configured with your credentials
- SSH access to your EC2 instance

**Architecture after this runbook:**

```
Browser --> Nginx (:443) --> PM2/Express (:3000) --> RDS PostgreSQL (:5432)
                                                      (private subnet)
```

---

## Section 1: Create the RDS Security Group

The RDS instance needs its own security group that controls who can access port 5432 (PostgreSQL). Instead of allowing a specific IP address, we use **security group referencing** -- the same pattern you learned conceptually in Phase 1 (see `docs/phase-01/05-security-groups/guide.md`).

### Why SG referencing instead of an IP address?

When you reference another security group as the source, you're saying: "Allow any instance that belongs to that security group." This is more flexible and more secure:
- If your EC2 instance gets a new private IP, the rule still works.
- If you add a second EC2 instance to the same SG, it automatically gets database access.
- You never expose the database to arbitrary IP addresses.

### Step 1.1: Find your EC2 security group ID

You need the security group ID of the EC2 instance that was created in the previous runbook.

**Console:** Go to EC2 > Security Groups, find the security group attached to your EC2 instance (e.g., `ecommerce-ec2-sg`). Copy its Group ID (starts with `sg-`).

**CLI:**
```bash
# List security groups in your VPC
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<your-vpc-id>" \
  --query "SecurityGroups[*].[GroupId,GroupName]" \
  --output table
```

Save the EC2 security group ID -- you'll need it in the next step.

```bash
EC2_SG_ID=sg-xxxxxxxxxxxxxxxxx   # Replace with your actual EC2 SG ID
VPC_ID=vpc-xxxxxxxxxxxxxxxxx     # Replace with your VPC ID
```

### Step 1.2: Create the RDS security group

```bash
aws ec2 create-security-group \
  --group-name ecommerce-rds-sg \
  --description "Security group for ecommerce RDS PostgreSQL" \
  --vpc-id $VPC_ID
```

Save the output Group ID:
```bash
RDS_SG_ID=sg-xxxxxxxxxxxxxxxxx   # The new RDS SG ID from the output
```

### Step 1.3: Add the inbound rule using SG referencing

This is the key step. The source is the **EC2 security group ID**, not an IP address.

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --source-group $EC2_SG_ID
```

**What this means:** Only instances that belong to the EC2 security group can connect to port 5432 on instances in the RDS security group. Nothing else on the internet, nothing else in your VPC -- only your EC2 instance.

> **GOTCHA: Never use 0.0.0.0/0 or a specific IP for the RDS security group source.**
>
> If you set the source to `0.0.0.0/0`, your database is accessible from the entire internet. If you use a specific IP like `10.0.1.x/32`, the rule breaks if your EC2 instance gets a new IP. Always use SG referencing for database security groups. This is the pattern used in production AWS environments.

### Verification checkpoint

```bash
aws ec2 describe-security-groups \
  --group-ids $RDS_SG_ID \
  --query "SecurityGroups[0].IpPermissions"
```

You should see:
- `FromPort`: 5432
- `ToPort`: 5432
- `UserIdGroupPairs` containing your EC2 security group ID (NOT an `IpRanges` entry)

**In the Console:** Go to EC2 > Security Groups > ecommerce-rds-sg > Inbound rules. The source column should show `sg-xxxxx` (the EC2 SG), not an IP address.

---

## Section 2: Create the DB Subnet Group

RDS doesn't launch directly into a subnet. Instead, it requires a **DB subnet group** -- a collection of subnets that RDS can use. AWS requires this group to span at least 2 Availability Zones, even if you're deploying a single-AZ instance.

### Why 2 AZs?

AWS enforces this so that if you later enable Multi-AZ (automatic failover), there's already a subnet in a second AZ ready to go. For now we won't use Multi-AZ (it's not free tier), but we still need to satisfy this requirement.

> **GOTCHA: "DB Subnet Group doesn't meet availability zone coverage requirement"**
>
> This is the most common RDS creation error. If you created your VPC with only one private subnet, or both private subnets are in the same AZ, you'll hit this error. The solution: ensure you have private subnets in at least 2 different AZs.

### Step 2.1: Find your private subnet IDs

If you created the VPC with the "VPC and more" wizard (as described in the EC2 runbook), you already have 2 private subnets. Let's find them.

```bash
# List all subnets in your VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]" \
  --output table
```

Private subnets are the ones where `MapPublicIpOnLaunch` is `false`. You need 2 of them in different AZs.

```bash
PRIVATE_SUBNET_1=subnet-xxxxxxxxxxxxxxxxx   # AZ: us-east-1a (example)
PRIVATE_SUBNET_2=subnet-xxxxxxxxxxxxxxxxx   # AZ: us-east-1b (example)
```

> **How to tell private from public:** A private subnet has no route to an Internet Gateway (IGW) in its route table. A public subnet has a `0.0.0.0/0 -> igw-xxx` route. The "VPC and more" wizard labels them clearly.

### Step 2.2: Create the DB subnet group

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --db-subnet-group-description "Private subnets for ecommerce RDS" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2
```

### Verification checkpoint

```bash
aws rds describe-db-subnet-groups \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --query "DBSubnetGroups[0].Subnets[*].[SubnetIdentifier,SubnetAvailabilityZone.Name]" \
  --output table
```

You should see 2 subnets in 2 different AZs (e.g., `us-east-1a` and `us-east-1b`).

---

## Section 3: Launch the RDS PostgreSQL Instance

Now we create the actual database. Pay close attention to the settings -- wrong choices here can cause surprise AWS charges.

### Free tier settings (important)

| Setting | Free Tier Value | Charged If Wrong |
|---------|----------------|-----------------|
| Instance class | `db.t3.micro` | Any other class |
| Storage | 20 GB gp2 | > 20 GB |
| Multi-AZ | No | Yes = 2x cost |
| Performance Insights | Off | On = charges |
| Storage type | gp2 | gp3 or io1 = higher cost |

> **GOTCHA: Multi-AZ, Performance Insights, and storage over 20 GB all cause charges.**
>
> The RDS creation wizard may default some of these to non-free-tier values. Double-check every setting before clicking "Create." The free tier gives you 750 hours/month of db.t3.micro with 20 GB storage for 12 months.

### Step 3.1: Create the RDS instance (CLI)

```bash
aws rds create-db-instance \
  --db-instance-identifier ecommerce-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16 \
  --master-username postgres \
  --master-user-password '<YourStrongPassword>' \
  --allocated-storage 20 \
  --storage-type gp2 \
  --db-name ecommerce \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --no-multi-az \
  --no-publicly-accessible \
  --backup-retention-period 7 \
  --storage-encrypted \
  --no-enable-performance-insights
```

**Important flags explained:**
- `--no-publicly-accessible`: RDS gets a private IP only. It cannot be reached from the internet, only from within the VPC. This is correct -- your EC2 instance (in the same VPC) will connect to it.
- `--no-multi-az`: Single AZ keeps us in the free tier.
- `--storage-encrypted`: Encryption at rest is free and there's no reason not to use it.
- `--backup-retention-period 7`: Automated backups for 7 days. Free within the allocated storage limit.
- `--no-enable-performance-insights`: Performance Insights costs money. Skip it for learning.

**Choose a strong password** and save it somewhere secure. You'll need it for the DATABASE_URL. Never commit passwords to git.

### Step 3.2: Create via Console (alternative)

If you prefer the console:

1. Go to **RDS > Create database**
2. Choose **Standard create**
3. Engine: **PostgreSQL**, Version: **16.x**
4. Templates: **Free tier** (this auto-selects many correct settings)
5. DB instance identifier: `ecommerce-db`
6. Master username: `postgres`
7. Master password: your strong password
8. Instance class: `db.t3.micro` (confirm this is selected)
9. Storage: 20 GB gp2, **uncheck** "Enable storage autoscaling"
10. Connectivity: Your VPC, DB subnet group: `ecommerce-db-subnet-group`
11. Public access: **No**
12. VPC security group: Choose existing > `ecommerce-rds-sg`
13. Additional configuration: Initial database name: `ecommerce`
14. **Uncheck** Performance Insights
15. Backup retention: 7 days
16. **Uncheck** "Enable deletion protection" (so teardown script works)

### Step 3.3: Wait for the instance to be available

RDS takes 5-10 minutes to create. You can watch the progress:

```bash
# Check status (repeat until "available")
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-db \
  --query "DBInstances[0].DBInstanceStatus"

# Or wait automatically (blocks until available)
aws rds wait db-instance-available \
  --db-instance-identifier ecommerce-db
echo "RDS is ready!"
```

### Verification checkpoint

```bash
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-db \
  --query "DBInstances[0].[DBInstanceStatus,Endpoint.Address,DBInstanceClass,AllocatedStorage,MultiAZ]" \
  --output table
```

Confirm:
- Status: `available`
- Endpoint: something like `ecommerce-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com`
- Class: `db.t3.micro`
- Storage: `20`
- MultiAZ: `false`

Save the endpoint -- you'll need it next:
```bash
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier ecommerce-db \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)
echo "RDS Endpoint: $RDS_ENDPOINT"
```

---

## Section 4: Connect the Express API to RDS

Now we connect the dots: your EC2 instance talks to the RDS instance through the security group rules you configured.

### Step 4.1: Install psql on EC2 (for testing)

SSH into your EC2 instance and install the PostgreSQL client:

```bash
ssh -i ~/your-key.pem ec2-user@<elastic-ip>

# Install PostgreSQL 16 client
sudo dnf install -y postgresql16
```

### Step 4.2: Test connectivity from EC2 to RDS

Before configuring the app, verify that EC2 can reach RDS at the network level:

```bash
psql -h <rds-endpoint> -U postgres -d ecommerce
```

Enter your master password when prompted. If you get a `psql` prompt (`ecommerce=>`), the connection works. Type `\q` to exit.

> **GOTCHA: Connection times out?**
>
> If `psql` hangs and eventually times out, check these in order:
>
> 1. **RDS security group**: Does the inbound rule reference the EC2 security group? (Section 1)
> 2. **RDS subnet**: Is RDS in the private subnets of the same VPC as EC2? (Section 2)
> 3. **EC2 and RDS in same VPC**: Both must be in the same VPC for SG referencing to work.
> 4. **RDS status**: Is it `available`? (It takes 5-10 minutes after creation.)
>
> The most common cause is forgetting to reference the EC2 security group (using an IP address or wrong SG instead).

### Step 4.3: Construct the DATABASE_URL

The format is:
```
postgresql://username:password@rds-endpoint:5432/dbname
```

For our setup:
```bash
DATABASE_URL="postgresql://postgres:<YourStrongPassword>@<rds-endpoint>:5432/ecommerce"
```

Replace `<YourStrongPassword>` with your actual password and `<rds-endpoint>` with the endpoint from Section 3.

### Step 4.4: Configure DATABASE_URL for PM2

There are two approaches. Choose one.

**Option A: Add to ecosystem.config.js (recommended for learning)**

Edit the PM2 ecosystem file on EC2:

```bash
cd ~/app
nano ecosystem.config.js
```

Add `DATABASE_URL` to the `env` section:

```javascript
module.exports = {
  apps: [
    {
      name: "ecommerce-api",
      script: "./dist/server/index.js",
      instances: 1,
      exec_mode: "fork",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
        DATABASE_URL: "postgresql://postgres:<password>@<rds-endpoint>:5432/ecommerce",
      },
      max_restarts: 10,
      restart_delay: 1000,
    },
  ],
};
```

> **Never commit ecosystem.config.js with real credentials to git.** The version in the repo uses no DATABASE_URL (it's added only on the server). In production environments, you'd use AWS Secrets Manager or Parameter Store instead of hardcoding credentials.

**Option B: Use a .env file on EC2**

```bash
cd ~/app
echo 'DATABASE_URL=postgresql://postgres:<password>@<rds-endpoint>:5432/ecommerce' > .env
```

The app's `drizzle.config.ts` already imports `dotenv/config`, and the Express server reads `process.env.DATABASE_URL`. Make sure `.env` is in `.gitignore` (it already should be).

### Step 4.5: Restart PM2 to pick up the new environment

```bash
# If you used Option A (ecosystem file):
pm2 restart ecosystem.config.js

# If you used Option B (.env file):
pm2 restart ecommerce-api
```

### Verification checkpoint

```bash
# Check PM2 status -- should show "online"
pm2 status

# Check the API health endpoint
curl http://localhost:3000/api/health
```

Expected health response:
```json
{"status":"ok","timestamp":"2026-05-06T..."}
```

If PM2 shows "errored", check the logs:
```bash
pm2 logs ecommerce-api --lines 20
```

Common errors:
- `ECONNREFUSED` on port 5432: Security group issue (go back to Section 1)
- `password authentication failed`: Wrong password in DATABASE_URL
- `database "ecommerce" does not exist`: The `--db-name` flag wasn't set during RDS creation (create it manually: `psql -h <endpoint> -U postgres -c "CREATE DATABASE ecommerce;"`)

---

## Section 5: Run Migrations and Seed Data

The app has a Drizzle schema (`app/src/server/db/schema.ts`) that defines three tables: `products`, `orders`, and `order_items`. We need to apply this schema to the RDS database and then insert sample data.

### Step 5.1: Apply the schema with Drizzle Kit

On EC2, run the schema push:

```bash
cd ~/app

# Using the DATABASE_URL directly (if not in .env or ecosystem):
DATABASE_URL="postgresql://postgres:<password>@<rds-endpoint>:5432/ecommerce" \
  pnpm run db:push

# Or if DATABASE_URL is already set via .env:
pnpm run db:push
```

`drizzle-kit push` reads `schema.ts` and creates (or updates) the tables in the database to match your Drizzle definitions. You'll see output showing the SQL statements it runs (CREATE TABLE, etc.).

### Step 5.2: Verify the tables were created

```bash
psql -h <rds-endpoint> -U postgres -d ecommerce -c "\dt"
```

You should see three tables:
```
          List of relations
 Schema |    Name     | Type  |  Owner
--------+-------------+-------+----------
 public | order_items | table | postgres
 public | orders      | table | postgres
 public | products    | table | postgres
```

### Step 5.3: Run the seed script

```bash
cd ~/app

DATABASE_URL="postgresql://postgres:<password>@<rds-endpoint>:5432/ecommerce" \
  pnpm run seed

# Or if DATABASE_URL is already set:
pnpm run seed
```

The seed script (`app/src/server/db/seed.ts`) inserts 8 sample products into the products table.

### Step 5.4: Verify the seed data

```bash
psql -h <rds-endpoint> -U postgres -d ecommerce \
  -c "SELECT id, name, price FROM products;"
```

You should see 8 rows of sample products with names and prices.

Count check:
```bash
psql -h <rds-endpoint> -U postgres -d ecommerce \
  -c "SELECT count(*) FROM products;"
```

Expected: `8`

### Step 5.5: Restart PM2 and verify the full stack

```bash
# Restart to ensure the API connects to the database
pm2 restart ecommerce-api

# Wait a moment, then test the products API
curl http://localhost:3000/api/products
```

This should return a JSON array of the 8 seeded products.

Now test through Nginx (from outside EC2):

```bash
# From your local machine (not EC2):
curl http://<elastic-ip>/api/products
```

### Verification checkpoint

```bash
# Full stack verification (run from your local machine):

# 1. API returns products through Nginx
curl -s http://<elastic-ip>/api/products | head -c 200

# 2. Health check still works
curl -s http://<elastic-ip>/api/health

# 3. Visit in browser: http://<elastic-ip>
#    You should see the products list populated with real data from RDS
```

**Final verification:** Open your browser and navigate to `http://<elastic-ip>` (or your domain if DNS is configured). You should see the product list page with all 8 products loaded from the RDS database.

---

## Section 6: Understanding the Full Stack

Now that everything is connected, let's trace a request through the entire system.

### Request flow: Browser to Database and back

```
1. Browser                    GET https://yourdomain.com/api/products
       |
2. Nginx (:443)              Terminates SSL, sees /api/* path
       |                      -> proxy_pass to http://127.0.0.1:3000
3. PM2/Express (:3000)       Route handler: GET /api/products
       |                      -> db.select().from(products)
4. RDS PostgreSQL (:5432)    SELECT * FROM products
       |                      -> Returns 8 rows
5. Express                    -> res.json(allProducts)
       |
6. Nginx                      -> Forwards response to browser
       |
7. Browser                    Renders product list from JSON
```

### What each layer does

| Layer | What it does | What breaks if removed |
|-------|-------------|----------------------|
| **Nginx** | SSL termination, static file serving, API proxying | No HTTPS, Express serves static files (slower), port 3000 exposed |
| **PM2** | Process management, auto-restart on crash, startup persistence | App dies on crash, no logs, doesn't survive reboot |
| **Express** | API logic, route handling, database queries | No API endpoints, no business logic |
| **RDS** | Managed PostgreSQL, automated backups, encryption | No data persistence, no product catalog |

### Security recap

1. **Nginx handles SSL** -- Express never sees raw TLS. Certificates are managed by Certbot.
2. **EC2 security group** limits inbound traffic to SSH (port 22), HTTP (port 80), and HTTPS (port 443).
3. **RDS security group** allows PostgreSQL (port 5432) **only from the EC2 security group**. No internet access.
4. **RDS is in a private subnet** -- it has no public IP and no route to the internet.
5. **Credentials** are set via environment variables on EC2, never committed to git.

### Cost recap

| Resource | Free Tier | What you're paying |
|----------|-----------|-------------------|
| EC2 (t2.micro) | 750 hrs/month for 12 months | $0 (if within limits) |
| RDS (db.t3.micro) | 750 hrs/month, 20 GB for 12 months | $0 (if within limits) |
| Elastic IP | Free when attached to running instance | $0 (charges if instance stopped) |
| Data transfer | 1 GB/month outbound free | $0 (learning traffic is minimal) |

**When you're done studying for the day:** Either leave resources running (free tier covers 24/7 for one instance each) or tear everything down using the teardown script in `scripts/teardown-phase2.sh` and rebuild next session with `scripts/rebuild-phase2.sh`.

> **Elastic IP warning:** If you stop your EC2 instance but don't release the Elastic IP, AWS charges ~$0.005/hour ($3.60/month) for the unused IP. Either keep the instance running or release the Elastic IP when you stop.

---

## Troubleshooting Quick Reference

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `psql` connection timeout | SG rule doesn't reference EC2 SG | Check RDS SG inbound rules (Section 1) |
| `password authentication failed` | Wrong password in DATABASE_URL | Verify password, check for special characters that need URL encoding |
| `database "ecommerce" does not exist` | `--db-name` not set during creation | Run `psql -h <endpoint> -U postgres -c "CREATE DATABASE ecommerce;"` |
| `relation "products" does not exist` | Migrations not run | Run `pnpm run db:push` (Section 5) |
| PM2 shows "errored" | Check logs | `pm2 logs ecommerce-api --lines 50` |
| API returns empty array | Seed not run | Run `pnpm run seed` (Section 5) |
| Curl to Elastic IP fails | Nginx not proxying | Check Nginx config and `sudo nginx -t` |
| RDS creation fails (subnet group) | Not enough AZs | Need private subnets in 2 different AZs (Section 2) |

---

*Next steps:*
- *When you're done for the day, use `scripts/teardown-phase2.sh` to destroy all resources*
- *When you resume, use `scripts/rebuild-phase2.sh` as a guided recreation checklist*
- *Phase 3 will containerize this same app with Docker*
