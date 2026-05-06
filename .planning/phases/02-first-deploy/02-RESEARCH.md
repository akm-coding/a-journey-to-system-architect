# Phase 2: First Deploy - Research

**Researched:** 2026-05-06
**Domain:** Full-stack React/Express deployment on EC2, Nginx reverse proxy, PM2 process management, RDS PostgreSQL, HTTPS with Let's Encrypt
**Confidence:** HIGH

## Summary

Phase 2 is the first hands-on deployment phase. The learner builds an ultra-minimal e-commerce app (React/Vite frontend + Express API backend, both TypeScript, with Drizzle ORM for PostgreSQL) and deploys it to EC2 manually, one layer at a time. The deployment follows an incremental approach: (1) run Node API on EC2 directly, (2) add Nginx as reverse proxy, (3) create RDS in a private subnet and connect the API, (4) build and serve React frontend via Nginx, (5) add HTTPS with Let's Encrypt/Certbot.

The critical architectural insight is that RDS requires a **DB subnet group spanning at least two Availability Zones**, even for a single-AZ deployment. This means the VPC from Phase 1 concepts must be extended with at least two private subnets in different AZs. The security group pattern from Phase 1 (SG referencing) is applied directly: the RDS security group allows inbound PostgreSQL (port 5432) only from the EC2 instance's security group.

The app itself is intentionally trivial (4 pages, no auth) so that infrastructure is the focus. It will be the same app deployed with increasing sophistication across all 8 phases. The monorepo already has the `app/` directory as a placeholder from Phase 1.

**Primary recommendation:** Structure the phase as two major deliverable groups: (1) build the sample app locally with working database, then (2) deploy incrementally to AWS using the layered approach described in CONTEXT.md. Each layer gets verified before the next.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Build the e-commerce app as part of this phase (not separately)
- Stack: React (Vite) frontend + Express API backend, both in TypeScript
- PostgreSQL via RDS for the database
- 4 pages: products list, single product view, add to cart, place order
- No authentication in this phase
- Hands-on runbook style: step-by-step guide with actual commands to run
- Explain the "why" alongside each command/config block
- Verification checkpoints after each major step
- Include common gotchas / troubleshooting tips inline
- Incremental, layered deployment:
  1. Launch EC2, SSH in, run Node API directly
  2. Install + configure Nginx as reverse proxy
  3. Create RDS in private subnet, connect API to DB
  4. Build React frontend, serve via Nginx
- PM2: practical essentials only (start, restart, logs, ecosystem file, startup on reboot)
- Nginx: start from a working template config, then explain each directive
- HTTPS: set up with Let's Encrypt (Certbot + auto-renewal)
- Budget target: $0-5/month using free tier (t2.micro EC2, db.t3.micro RDS)
- RDS from the start -- key learning objective
- Include a teardown section with clear steps to destroy resources in order
- Include a rebuild shortcut for resuming in the next session

### Claude's Discretion
- Exact app folder structure and monorepo organization
- Database schema design (tables for products, orders, cart)
- PM2 ecosystem file configuration details
- Nginx config specifics beyond the explained template
- Security group rule details (as long as they follow least-privilege from Phase 1)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEPL-01 | Learner can deploy a React/Node app to EC2 manually (Nginx reverse proxy + PM2) | Full deployment stack researched: Node.js 20 on AL2023, PM2 ecosystem file with startup persistence, Nginx reverse proxy config serving React static files + API proxy, Certbot HTTPS |
| DEPL-02 | Learner can connect the deployed app to an RDS PostgreSQL database | RDS setup researched: DB subnet group (2 AZs), security group referencing for port 5432, db.t3.micro free tier, Drizzle ORM connection via DATABASE_URL |
</phase_requirements>

## Standard Stack

### Core (App Stack)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| React | 19.x | Frontend UI | Industry standard, learner already knows it |
| Vite | 6.x | Frontend build tool | Fast dev server, optimized production builds |
| Express | 4.x | API server | Minimal, well-documented, dominant Node.js framework |
| TypeScript | 5.x | Type safety | Both frontend and backend, catches errors early |
| Drizzle ORM | 0.38+ | Database ORM | Lightweight, type-safe, SQL-like syntax, no code generation |
| pg | 8.x | PostgreSQL driver | Standard Node.js PostgreSQL client, used by Drizzle |

### Core (Infrastructure)
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Nginx | Latest stable (AL2023 repo) | Reverse proxy + static file server | Industry standard, 2x faster than Express for static files |
| PM2 | 5.x | Node.js process manager | Auto-restart, cluster mode, log management, startup persistence |
| Certbot | Latest (pip install) | Let's Encrypt SSL certificates | Free trusted certs, auto-renewal |
| PostgreSQL (RDS) | 16.x | Managed database | Free tier eligible, no server management |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dotenv | 16.x | Environment variable loading | Local development only (production uses OS env vars) |
| cors | 2.x | Cross-origin requests | Dev mode when frontend and API on different ports |
| drizzle-kit | Latest | Schema migrations CLI | Generating and applying database migrations |
| tsx | Latest | TypeScript execution | Running TypeScript files directly during development |

### AWS Services
| Service | Instance/Tier | Purpose | Free Tier? |
|---------|--------------|---------|------------|
| EC2 | t2.micro | App server (Nginx + PM2 + Node) | Yes -- 750 hrs/month for 12 months |
| RDS PostgreSQL | db.t3.micro | Managed database | Yes -- 750 hrs/month, 20GB storage, for 12 months |
| VPC | N/A | Network isolation | Free |
| Elastic IP | 1 | Stable public IP for EC2 | Free when attached to running instance |

**Installation (local development):**
```bash
# In app/ directory
pnpm add react react-dom express pg drizzle-orm dotenv cors
pnpm add -D typescript @types/react @types/react-dom @types/express @types/pg @types/cors drizzle-kit tsx vite @vitejs/plugin-react
```

**Installation (EC2 -- Amazon Linux 2023):**
```bash
# Node.js 20
sudo dnf install -y nodejs20

# PM2 globally
sudo npm install -g pm2

# Nginx
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Certbot via pip (AL2023 does not have certbot in repos)
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot
```

## Architecture Patterns

### Recommended App Structure (Claude's Discretion)
```
app/
  package.json
  tsconfig.json
  drizzle.config.ts
  drizzle/                   # Generated migration files
  src/
    server/
      index.ts               # Express entry point
      routes/
        products.ts           # GET /api/products, GET /api/products/:id
        cart.ts               # POST /api/cart, GET /api/cart
        orders.ts             # POST /api/orders
      db/
        index.ts              # Drizzle client initialization
        schema.ts             # Table definitions (products, orders, order_items, cart_items)
        seed.ts               # Seed data for products
    client/
      index.html              # Vite entry HTML
      src/
        main.tsx              # React entry point
        App.tsx               # Router setup
        pages/
          ProductList.tsx     # Products list page
          ProductDetail.tsx   # Single product view
          Cart.tsx            # Cart page
          PlaceOrder.tsx      # Place order page
        components/           # Shared components
        api.ts                # Fetch wrapper for API calls
      vite.config.ts          # Vite config with API proxy
```

### Database Schema (Claude's Discretion)
```typescript
// src/server/db/schema.ts
import { integer, pgTable, varchar, text, numeric, timestamp } from "drizzle-orm/pg-core";

export const products = pgTable("products", {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  name: varchar({ length: 255 }).notNull(),
  description: text(),
  price: numeric({ precision: 10, scale: 2 }).notNull(),
  imageUrl: varchar("image_url", { length: 500 }),
});

export const orders = pgTable("orders", {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  status: varchar({ length: 50 }).notNull().default("pending"),
  totalAmount: numeric("total_amount", { precision: 10, scale: 2 }).notNull(),
  createdAt: timestamp("created_at").defaultNow(),
});

export const orderItems = pgTable("order_items", {
  id: integer().primaryKey().generatedAlwaysAsIdentity(),
  orderId: integer("order_id").notNull().references(() => orders.id),
  productId: integer("product_id").notNull().references(() => products.id),
  quantity: integer().notNull(),
  price: numeric({ precision: 10, scale: 2 }).notNull(),
});
```

Note: Cart is kept in-memory on the client (localStorage) since there is no auth. This avoids server-side session complexity that is out of scope.

### Deployment Architecture
```
                    Internet
                       |
                   [ Elastic IP ]
                       |
               +-------+-------+
               |   EC2 (t2.micro)   |
               |   Amazon Linux 2023 |
               |                     |
               |  +---------------+  |
               |  |    Nginx      |  |
               |  | :80 -> :443   |  |
               |  | (SSL termination)|
               |  +---+-------+--+  |
               |      |       |      |
               |   /api/*  /* (static)|
               |      |       |      |
               |  +---v---+  dist/   |
               |  | PM2   |  (React) |
               |  | Node  |         |
               |  | :3000 |         |
               |  +---+---+         |
               +------+-------------+
                      |
              Private Subnet (no IGW)
               +------+------+
               | RDS PostgreSQL |
               | db.t3.micro    |
               | :5432          |
               +---------------+
```

### Pattern 1: Nginx Dual-Purpose Configuration
**What:** Nginx serves React static files directly AND proxies API requests to Node.js
**When to use:** Any full-stack app on a single server

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    # Serve React static files
    root /home/ec2-user/app/dist;
    index index.html;

    # React Router: all non-file requests fall back to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to Express
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Pattern 2: PM2 Ecosystem File
**What:** Declarative process management configuration
**When to use:** Always -- never run Node.js with bare `node` in production

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: "ecommerce-api",
    script: "./dist/server/index.js",
    instances: 1,           // t2.micro has 1 vCPU
    exec_mode: "fork",      // cluster mode needs 2+ instances
    env: {
      NODE_ENV: "production",
      PORT: 3000
    },
    // PM2 will auto-restart on crash
    max_restarts: 10,
    restart_delay: 1000
  }]
};
```

**Essential PM2 commands:**
```bash
pm2 start ecosystem.config.js    # Start from config
pm2 restart ecommerce-api        # Restart
pm2 logs ecommerce-api           # View logs
pm2 status                       # List processes
pm2 startup                      # Generate startup script
pm2 save                         # Save process list for reboot persistence
```

### Pattern 3: RDS Connection from EC2
**What:** Connecting to RDS in private subnet using security group referencing
**When to use:** Any EC2-to-RDS communication

```typescript
// Connection string format
// DATABASE_URL=postgresql://username:password@rds-endpoint:5432/dbname

import { drizzle } from 'drizzle-orm/node-postgres';
const db = drizzle(process.env.DATABASE_URL!);
```

The RDS endpoint (e.g., `mydb.xxxxx.us-east-1.rds.amazonaws.com`) resolves to a private IP within the VPC. No internet routing needed.

### Anti-Patterns to Avoid
- **Running Node.js as root:** Use `ec2-user` for the app, Nginx handles port 80/443
- **Hardcoding database credentials:** Use environment variables, never commit `.env`
- **Skipping PM2 startup/save:** Server reboots will kill your app without these
- **Opening RDS to 0.0.0.0/0:** RDS security group should ONLY allow the EC2 security group
- **Using `npm start` in production:** Always use PM2 for crash recovery and log management
- **Serving React via Express static middleware:** Nginx is 2x faster for static files

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Process management | Custom restart scripts, nohup | PM2 | Crash recovery, log rotation, startup persistence, cluster mode |
| Static file serving | Express `express.static()` in production | Nginx `root` + `try_files` | 2x faster, handles gzip, caching headers, frees Node for API work |
| SSL termination | Node.js `https.createServer()` | Nginx + Certbot | Nginx handles SSL offloading, auto-renewal, better performance |
| Database migrations | Raw SQL files run manually | Drizzle Kit (`drizzle-kit push` / `drizzle-kit migrate`) | Type-safe, tracks migration history, rollback support |
| CORS in production | Complex CORS middleware config | Nginx serves both frontend and API on same domain | Same-origin eliminates CORS entirely |
| Health checks | Custom monitoring scripts | PM2 built-in monitoring + `curl` verification | PM2 auto-restarts on crash, monitors memory/CPU |

**Key insight:** The Nginx-in-front pattern eliminates entire categories of problems (CORS, static serving performance, SSL management) that would require custom code in a Node-only setup.

## Common Pitfalls

### Pitfall 1: RDS DB Subnet Group Requires Two AZs
**What goes wrong:** Learner tries to create RDS with a subnet group containing only one private subnet. AWS rejects it.
**Why it happens:** RDS requires a DB subnet group spanning at least 2 AZs even for single-AZ deployments. This is not obvious.
**How to avoid:** Create the VPC with 2 public + 2 private subnets across 2 AZs from the start. Use the "VPC and more" wizard in the VPC console which sets this up automatically.
**Warning signs:** Error message: "DB Subnet Group doesn't meet availability zone coverage requirement."

### Pitfall 2: Security Group Blocks RDS Connection
**What goes wrong:** API can't connect to RDS -- connection timeouts. Learner opens all ports in frustration.
**Why it happens:** RDS security group doesn't reference the EC2 security group, or uses the wrong port.
**How to avoid:** RDS SG inbound rule: Type = PostgreSQL (port 5432), Source = EC2's security group ID (not an IP address). This is the SG referencing pattern from Phase 1.
**Warning signs:** `ECONNREFUSED` or connection timeout from the Express app. `psql` from EC2 hangs.

### Pitfall 3: Node.js Not Found After SSH Reconnect
**What goes wrong:** Learner installs Node.js, logs out, logs back in, and `node` command is not found.
**Why it happens:** On AL2023, `nodejs20` installs as `node-20` binary. The `alternatives` system or PATH may not be configured.
**How to avoid:** After install, run `sudo alternatives --install /usr/bin/node node /usr/bin/node-20 1` or verify with `node-20 --version`. The guide should include this step explicitly.
**Warning signs:** `command not found: node` after reconnecting.

### Pitfall 4: Nginx Config Syntax Errors
**What goes wrong:** Nginx won't start or won't reload after config changes. Learner sees cryptic error messages.
**Why it happens:** Missing semicolons, wrong brace nesting, typos in directive names.
**How to avoid:** Always run `sudo nginx -t` before `sudo systemctl reload nginx`. Include this as a mandatory step in every config change.
**Warning signs:** `nginx: [emerg] unknown directive` or `nginx: configuration file test failed`.

### Pitfall 5: React Build Paths Wrong
**What goes wrong:** React app loads but API calls fail, or page shows blank.
**Why it happens:** Vite build output goes to `dist/` but Nginx `root` directive points elsewhere. Or API base URL is hardcoded to `localhost:3000` instead of relative paths.
**How to avoid:** Use relative API paths (`/api/products` not `http://localhost:3000/api/products`). Verify Nginx `root` matches the actual build output directory. Use `vite.config.ts` proxy for dev, Nginx proxy for production.
**Warning signs:** 404 on API calls in production. Blank page with console errors about failed resource loads.

### Pitfall 6: Forgot PM2 Startup and Save
**What goes wrong:** EC2 instance reboots (scheduled maintenance, manual restart) and the app doesn't come back up.
**Why it happens:** PM2 runs processes in memory. Without `pm2 startup` + `pm2 save`, there's no systemd unit to restore them.
**How to avoid:** The runbook must include `pm2 startup` (generates systemd unit) and `pm2 save` (snapshots running processes) as mandatory final steps.
**Warning signs:** After reboot, `pm2 status` shows no processes.

### Pitfall 7: RDS Free Tier Surprise Charges
**What goes wrong:** Learner gets billed for RDS when expecting free tier.
**Why it happens:** Multi-AZ enabled (not free tier), wrong instance class selected, or storage exceeds 20GB.
**How to avoid:** Explicitly: Single-AZ, db.t3.micro, 20GB gp2 storage, no Multi-AZ, no performance insights. The runbook should have a screenshot/CLI showing exact selections.
**Warning signs:** AWS billing dashboard showing RDS charges > $0.

### Pitfall 8: Certbot Fails Because DNS Not Pointing to EC2
**What goes wrong:** `certbot --nginx` fails with domain validation error.
**Why it happens:** Let's Encrypt validates domain ownership by making an HTTP request to the domain. If DNS doesn't point to the EC2 instance, validation fails.
**How to avoid:** Step order matters: (1) Launch EC2, get Elastic IP, (2) Point DNS to Elastic IP, (3) Verify with `dig`, (4) THEN run Certbot. This builds on Phase 1 DNS knowledge.
**Warning signs:** Certbot error mentioning "Challenge failed" or "Connection refused".

## Code Examples

### Express API Setup with Drizzle
```typescript
// src/server/index.ts
import express from "express";
import { drizzle } from "drizzle-orm/node-postgres";
import { products } from "./db/schema";

const app = express();
app.use(express.json());

const db = drizzle(process.env.DATABASE_URL!);

// Health check endpoint (critical for verification)
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Get all products
app.get("/api/products", async (req, res) => {
  const allProducts = await db.select().from(products);
  res.json(allProducts);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API running on port ${PORT}`);
});
```

### Drizzle Config
```typescript
// drizzle.config.ts
import "dotenv/config";
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  out: "./drizzle",
  schema: "./src/server/db/schema.ts",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
```

### Vite Config with API Proxy (Development)
```typescript
// src/client/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api": "http://localhost:3000",
    },
  },
  build: {
    outDir: "../../dist",  // Build to app/dist for Nginx
  },
});
```

### Nginx Full Production Config
```nginx
# /etc/nginx/conf.d/ecommerce.conf
server {
    listen 80;
    server_name yourdomain.com;

    # Certbot will add SSL config here after running certbot --nginx

    root /home/ec2-user/app/dist;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    # React Router support -- try file, then directory, then fallback to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API to Express via PM2
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Certbot on Amazon Linux 2023
```bash
# Prerequisites: Nginx installed and running, DNS pointing to EC2

# Install Certbot via pip (AL2023 has no certbot package in repos)
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Obtain certificate (interactive -- asks for email, domain)
sudo certbot --nginx -d yourdomain.com

# Verify auto-renewal works
sudo certbot renew --dry-run

# Set up auto-renewal cron (runs twice daily with random delay)
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
```

### PM2 Startup Persistence
```bash
# After app is running with PM2:
pm2 startup        # Generates systemd unit file, prints command to run with sudo
# Copy and run the printed sudo command, e.g.:
# sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user

pm2 save           # Saves current process list -- restored on reboot
```

### Teardown Script
```bash
#!/bin/bash
# scripts/teardown-phase2.sh
echo "=== Phase 2 Teardown ==="
echo "Delete in this order to avoid dependency errors:"
echo ""
echo "1. RDS instance (takes ~5 min, skip final snapshot to save cost)"
echo "   aws rds delete-db-instance --db-instance-identifier ecommerce-db --skip-final-snapshot"
echo ""
echo "2. Wait for RDS deletion to complete"
echo "   aws rds wait db-instance-deleted --db-instance-identifier ecommerce-db"
echo ""
echo "3. Delete DB subnet group"
echo "   aws rds delete-db-subnet-group --db-subnet-group-name ecommerce-db-subnet-group"
echo ""
echo "4. Terminate EC2 instance"
echo "   aws ec2 terminate-instances --instance-ids <instance-id>"
echo ""
echo "5. Release Elastic IP"
echo "   aws ec2 release-address --allocation-id <alloc-id>"
echo ""
echo "6. Delete security groups (wait for instances to terminate first)"
echo "   aws ec2 delete-security-group --group-id <rds-sg-id>"
echo "   aws ec2 delete-security-group --group-id <ec2-sg-id>"
echo ""
echo "7. Delete VPC (deletes subnets, route tables, IGW automatically)"
echo "   aws ec2 delete-vpc --vpc-id <vpc-id>"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Express.static for everything | Nginx serves static files, proxies API only | Current best practice | 2x faster static serving, SSL offloading |
| Sequelize / TypeORM | Drizzle ORM | 2023-2024 (rapid adoption) | Lighter, type-safe, SQL-like, no code gen |
| `serial` for PostgreSQL primary keys | `integer().generatedAlwaysAsIdentity()` | PostgreSQL 10+ / Drizzle standard | Identity columns are the modern PostgreSQL standard |
| Forever / nodemon in production | PM2 | PM2 dominant since ~2018 | Cluster mode, ecosystem files, startup persistence |
| Self-signed SSL certs | Let's Encrypt via Certbot | 2016+ (mature ecosystem) | Free, trusted, auto-renewable |
| Amazon Linux 2 (yum, amazon-linux-extras) | Amazon Linux 2023 (dnf) | 2023 | dnf replaces yum, no amazon-linux-extras |
| `nvm` for Node.js on AL2023 | `dnf install nodejs20` (namespaced packages) | AL2023 native | System-managed, no nvm overhead, supports multiple versions |

**Deprecated/outdated:**
- `amazon-linux-extras`: Does not exist on AL2023. Use `dnf` directly.
- `serial` type in PostgreSQL: Use identity columns instead.
- Express for serving static files in production: Use Nginx.

## Open Questions

1. **Monorepo app structure: monorepo packages vs single app directory**
   - What we know: The pnpm workspace has `app/` as a workspace package. The app needs both a React frontend and Express backend.
   - What's unclear: Whether to put both frontend and backend in `app/` (simpler) or split into `app/client` and `app/server` workspace packages.
   - Recommendation: Keep both in `app/` with `src/server/` and `src/client/` subdirectories. Single package.json with separate build scripts. Simpler for a learning project. Split into separate packages only if needed in later phases.

2. **Database seeding approach**
   - What we know: The app needs sample products to be useful.
   - What's unclear: Whether to use Drizzle Kit's seed feature or a custom seed script.
   - Recommendation: Use a simple `seed.ts` script that inserts 5-10 sample products via Drizzle. Run with `tsx src/server/db/seed.ts`. Keep it simple -- this is about deployment, not data management.

3. **EC2 deployment method**
   - What we know: Phase 2 is manual deployment. Phase 4 introduces CI/CD.
   - What's unclear: Whether to use `scp`, `git clone` on EC2, or `rsync`.
   - Recommendation: Use `git clone` on EC2 (learner already knows git). For updates, `git pull` + `pnpm install` + `pm2 restart`. Include as rebuild shortcut.

## Sources

### Primary (HIGH confidence)
- [AWS RDS VPC Tutorial](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Tutorials.WebServerDB.CreateVPC.html) - VPC setup for RDS, DB subnet group requirements (2 AZs), security group referencing
- [AWS RDS PostgreSQL Getting Started](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_GettingStarted.CreatingConnecting.PostgreSQL.html) - RDS instance creation, connection methods
- [AWS RDS Free Tier](https://aws.amazon.com/rds/free/) - db.t3.micro, 750 hrs/month, 20GB storage, single-AZ only
- [Node.js on AL2023](https://docs.aws.amazon.com/linux/al2023/ug/nodejs.html) - Namespaced nodejs20 packages, dnf installation
- [Drizzle ORM PostgreSQL Setup](https://orm.drizzle.team/docs/get-started/postgresql-new) - Installation, schema definition, pg driver configuration
- [PM2 Ecosystem File](https://pm2.keymetrics.io/docs/usage/application-declaration/) - Configuration format, environment management, startup persistence

### Secondary (MEDIUM confidence)
- [Certbot on AL2023 - AWS re:Post](https://repost.aws/articles/AR_doGU0cxQymwf5A1Gl97yA/) - pip-based Certbot installation on AL2023, verified January 2026
- [Nginx Reverse Proxy + Certbot on AL2023](https://dev.to/0xfedev/how-to-install-nginx-as-reverse-proxy-and-configure-certbot-on-amazon-linux-2023-2cc9) - Nginx reverse proxy config, Certbot via python venv
- [Better Stack PM2 Guide](https://betterstack.com/community/guides/scaling-nodejs/pm2-guide/) - PM2 best practices, ecosystem file patterns
- [Nginx Reverse Proxy for Node.js](https://betterstack.com/community/guides/scaling-nodejs/nodejs-reverse-proxy-nginx/) - Proxy configuration, static file serving pattern
- [Nginx with React Router](https://gist.github.com/tkc/c400263987f1a626e6d9d348b7379caf) - try_files directive for client-side routing

### Tertiary (LOW confidence)
- Exact `nodejs20` package behavior with `alternatives` system on AL2023 -- verify at install time
- PM2 log-rotate plugin (`pm2 install pm2-logrotate`) -- mentioned in guides but not officially required for learning
- Drizzle ORM 0.38+ version number -- approximate based on current release cadence, verify at install time

## Metadata

**Confidence breakdown:**
- App stack (React/Vite/Express/Drizzle): HIGH - official docs verified, widely documented
- EC2 + Nginx + PM2 deployment: HIGH - well-established pattern, multiple verified sources
- RDS setup in private subnet: HIGH - official AWS tutorial verified
- Certbot on AL2023: MEDIUM - AWS re:Post verified but pip installation method may have version quirks
- Node.js 20 on AL2023: MEDIUM - official AWS docs confirm namespaced packages, but `alternatives` behavior needs runtime verification
- Cost (free tier eligibility): HIGH - official AWS pricing page confirmed

**Research date:** 2026-05-06
**Valid until:** 2026-06-06 (30 days -- stable technologies, AWS free tier terms may change)
