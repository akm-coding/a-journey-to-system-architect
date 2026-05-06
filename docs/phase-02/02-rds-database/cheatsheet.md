# RDS Database Cheatsheet

Quick reference for RDS PostgreSQL setup and database commands.

## RDS CLI Commands

```bash
# Create RDS instance (free tier)
aws rds create-db-instance \
  --db-instance-identifier ecommerce-db \
  --db-instance-class db.t3.micro \
  --engine postgres --engine-version 16 \
  --master-username postgres --master-user-password '<password>' \
  --allocated-storage 20 --storage-type gp2 \
  --db-name ecommerce \
  --vpc-security-group-ids <rds-sg-id> \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --no-multi-az --no-publicly-accessible \
  --backup-retention-period 7 --storage-encrypted \
  --no-enable-performance-insights

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-db \
  --query "DBInstances[0].[DBInstanceStatus,Endpoint.Address]" \
  --output table

# Wait for RDS to be available
aws rds wait db-instance-available --db-instance-identifier ecommerce-db

# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-db \
  --query "DBInstances[0].Endpoint.Address" --output text

# Delete RDS instance (skip snapshot to save cost)
aws rds delete-db-instance \
  --db-instance-identifier ecommerce-db \
  --skip-final-snapshot

# Wait for deletion
aws rds wait db-instance-deleted --db-instance-identifier ecommerce-db
```

## Security Group Commands

```bash
# Create RDS security group
aws ec2 create-security-group \
  --group-name ecommerce-rds-sg \
  --description "RDS PostgreSQL security group" \
  --vpc-id <vpc-id>

# Add inbound rule: PostgreSQL from EC2 SG (SG referencing)
aws ec2 authorize-security-group-ingress \
  --group-id <rds-sg-id> \
  --protocol tcp --port 5432 \
  --source-group <ec2-sg-id>

# Verify SG rules
aws ec2 describe-security-groups --group-ids <rds-sg-id> \
  --query "SecurityGroups[0].IpPermissions"
```

## DB Subnet Group

```bash
# Create DB subnet group (needs 2 AZs)
aws rds create-db-subnet-group \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --db-subnet-group-description "Private subnets for RDS" \
  --subnet-ids <private-subnet-1> <private-subnet-2>

# Verify subnet group
aws rds describe-db-subnet-groups \
  --db-subnet-group-name ecommerce-db-subnet-group

# Delete subnet group
aws rds delete-db-subnet-group \
  --db-subnet-group-name ecommerce-db-subnet-group
```

## psql Connection

```bash
# Install psql on Amazon Linux 2023
sudo dnf install -y postgresql16

# Connect to RDS from EC2
psql -h <rds-endpoint> -U postgres -d ecommerce

# Run a query directly
psql -h <rds-endpoint> -U postgres -d ecommerce -c "SELECT count(*) FROM products;"

# List tables
psql -h <rds-endpoint> -U postgres -d ecommerce -c "\dt"
```

## DATABASE_URL Format

```
postgresql://username:password@rds-endpoint:5432/dbname
```

Example:
```
postgresql://postgres:MyStr0ngP@ss@ecommerce-db.xxxx.us-east-1.rds.amazonaws.com:5432/ecommerce
```

**Special characters in password:** URL-encode them (e.g., `@` becomes `%40`, `#` becomes `%23`).

## Drizzle Commands

```bash
# Apply schema to database (creates/updates tables)
DATABASE_URL="postgresql://..." pnpm run db:push

# Run seed script (insert sample data)
DATABASE_URL="postgresql://..." pnpm run seed
```

If `DATABASE_URL` is already set (via .env or ecosystem.config.js):
```bash
pnpm run db:push
pnpm run seed
```

## PM2 with DATABASE_URL

```bash
# Restart PM2 after changing env vars
pm2 restart ecosystem.config.js

# Check if the API is running
pm2 status

# View logs for database connection errors
pm2 logs ecommerce-api --lines 30
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Connection timeout to RDS | SG rules wrong | Verify RDS SG source = EC2 SG ID (not IP) |
| `password authentication failed` | Wrong credentials | Check DATABASE_URL password |
| `database "ecommerce" does not exist` | DB name not set at creation | `psql -h <endpoint> -U postgres -c "CREATE DATABASE ecommerce;"` |
| `relation "products" does not exist` | Schema not pushed | Run `pnpm run db:push` |
| Empty product list | Seed not run | Run `pnpm run seed` |
| DB subnet group error | Only 1 AZ | Need private subnets in 2 different AZs |
| PM2 errored status | Check logs | `pm2 logs ecommerce-api` |

## Free Tier Limits (RDS)

- **Instance:** db.t3.micro only
- **Storage:** 20 GB gp2
- **Multi-AZ:** Must be OFF
- **Performance Insights:** Must be OFF
- **Duration:** 750 hours/month for 12 months
- **Backups:** Free within allocated storage
