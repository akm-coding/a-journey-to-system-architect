# Docker Compose Exercise: Build the Full Stack

In this exercise, you will build up the Docker Compose stack **incrementally** -- starting with just the database, then adding services one at a time until the full e-commerce app is running. This mirrors how you would develop a real multi-service application.

**Prerequisites:**
- Docker installed and running
- Completed the Docker Fundamentals exercise (Dockerfiles exist for frontend and API)
- Built the server code: `pnpm build:server` (API Dockerfile requires pre-built dist/server/)

---

## Step 1: Create the Environment File

The Compose file uses variable interpolation (`${POSTGRES_USER}`) to avoid hardcoding secrets. You need a `.env` file with actual values.

```bash
# From the app/ directory
cp .env.example .env
```

Open `.env` and review the values. For local development, the defaults work fine:

```bash
# .env
POSTGRES_USER=ecommerce
POSTGRES_PASSWORD=changeme
POSTGRES_DB=ecommerce
```

> **WHY:** We commit `.env.example` (with placeholder values) so every developer knows what variables are needed. The actual `.env` file is gitignored because it may contain real secrets in production.

---

## Step 2: Start with Just the Database

Start small. Run only PostgreSQL to verify the database setup works:

```bash
docker compose up db
```

You should see PostgreSQL initialization logs:

```
db-1  | PostgreSQL init process complete; ready for start up.
db-1  | LOG:  database system is ready to accept connections
```

**Verify the health check works:**

Open a second terminal and check the container status:

```bash
docker compose ps
```

Expected output:

```
NAME              STATUS
ecommerce-db-1    running (healthy)
```

The `(healthy)` status means `pg_isready` succeeded. You can also connect directly:

```bash
docker compose exec db psql -U ecommerce -d ecommerce -c "SELECT 1;"
```

Stop the database before continuing (Ctrl+C in the first terminal, or `docker compose down`).

---

## Step 3: Add Redis

Now check that Redis starts correctly alongside the database.

You do not need to modify anything -- both services are already defined in `docker-compose.yml`. Start both:

```bash
docker compose up db redis
```

**Verify Redis health check:**

```bash
docker compose ps
```

```
NAME                STATUS
ecommerce-db-1      running (healthy)
ecommerce-redis-1   running (healthy)
```

Test Redis directly:

```bash
docker compose exec redis redis-cli ping
```

Expected: `PONG`

> **GOTCHA:** If you see `(health: starting)` for a few seconds, that is normal. Docker runs the health check on the configured interval (5 seconds). Wait for it to transition to `(healthy)`.

---

## Step 4: Add the API with Health-Check Dependencies

This is where `depends_on` with `service_healthy` becomes important. The API service is configured to wait for both the database and Redis to be healthy before starting.

Start the full backend stack:

```bash
docker compose up db redis api
```

**Watch the startup order in the logs:**

```
db-1    | LOG:  database system is ready to accept connections
redis-1 | Ready to accept connections tcp
api-1   | Server listening on port 3000
```

Notice that the API starts **after** both db and redis report they are ready. Without `service_healthy`, the API would start immediately and likely crash with a "connection refused" error.

**Verify the API is running:**

```bash
curl http://localhost:3000/api/health
```

If you have not set up a `/api/health` endpoint yet, try:

```bash
curl http://localhost:3000/api/products
```

This will return an empty array `[]` (no data seeded yet), which confirms the API is connected to the database successfully.

> **WHY:** The `depends_on` with `condition: service_healthy` solves the most common Docker Compose complaint: "my API crashes because the database is not ready." Without health checks, Compose only waits for the container to **start**, not for the service inside to be **ready**.

---

## Step 5: Add the Frontend -- Full Stack Running

Now bring up all four services:

```bash
docker compose up
```

Or if you still have the backend running, open a new terminal:

```bash
docker compose up frontend
```

**Verify the full stack:**

1. Open `http://localhost` in your browser -- you should see the React app
2. The frontend nginx proxies `/api/` requests to the API container
3. Check all services are running:

```bash
docker compose ps
```

```
NAME                  STATUS
ecommerce-db-1        running (healthy)
ecommerce-redis-1     running (healthy)
ecommerce-api-1       running
ecommerce-frontend-1  running
```

All four services, one command. This is the power of Docker Compose.

---

## Step 6: Seed the Database

The database is running but empty. Use `docker compose exec` to run commands inside a running container:

```bash
# Push the Drizzle schema to create tables
docker compose exec api pnpm db:push

# Seed with sample data
docker compose exec api pnpm seed
```

Now refresh `http://localhost` -- you should see products listed.

> **WHY:** `docker compose exec` runs a command in an **already running** container. This is different from `docker compose run`, which creates a **new** container. Use `exec` for one-off commands in your running stack.

**What each command does:**
- `db:push` -- Drizzle ORM reads the schema files and creates/updates tables in PostgreSQL
- `seed` -- Inserts sample products, categories, and other test data

---

## Step 7: Explore the Running Stack

### View Logs

```bash
# All services
docker compose logs

# Follow logs in real time
docker compose logs -f

# Specific service
docker compose logs api

# Last 50 lines of a service
docker compose logs --tail 50 api
```

### Inspect the Network

```bash
# See the auto-created network
docker network ls | grep ecommerce

# Inspect it to see connected containers
docker network inspect app_default
```

You will see all four containers listed with their internal IP addresses. This is how service name DNS resolution works -- Docker maps "api" to its container IP.

### Check Resource Usage

```bash
docker compose stats
```

This shows CPU, memory, and network usage per container.

---

## Step 8: Dev Workflow -- Live Code Changes

### What Hot Reload Looks Like

The dev `docker-compose.yml` bind-mounts source code into the API container:

```yaml
volumes:
  - ./src/server:/app/src/server
  - ./dist/server:/app/dist/server
```

This means changes to `src/server/` files on your host are immediately visible inside the container.

### When Hot Reload Applies

**Changes that take effect without rebuild:**
- Editing server source files (if using a file watcher like `tsx watch`)
- Editing compiled output in `dist/server/` (if the server watches for changes)
- Adding new API routes in existing files

**Changes that require image rebuild (`docker compose up --build`):**
- Adding new dependencies to `package.json`
- Changing the Dockerfile itself
- Modifying nginx configuration
- Changing the frontend (React files are baked into the nginx image)

```bash
# After changing package.json or Dockerfile:
docker compose up --build api

# After changing nginx.conf or frontend code:
docker compose up --build frontend
```

> **GOTCHA:** The frontend container serves pre-built static files from nginx. There are no bind mounts for the React source code in this setup. To see frontend changes, you must rebuild the frontend image. For active frontend development, consider running `pnpm dev:client` on your host instead.

---

## Step 9: Production Workflow

### Running with Production Overrides

The production override file removes dev-specific configuration and adds production best practices:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build
```

**What changes in production mode:**
- Bind mounts are removed (code is baked into images)
- `NODE_ENV=production` is set
- All services get `restart: unless-stopped`
- Images are rebuilt with `--build` to include latest code

### Compare Dev vs Prod

You can validate what the merged configuration looks like without starting anything:

```bash
# Dev config (base only)
docker compose config

# Prod config (base + override merged)
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

Look for the differences:
- The `api` service should have no `volumes` in prod
- All services should have `restart: unless-stopped` in prod
- `NODE_ENV` should be `production` in prod

> **WHY:** `docker compose config` is invaluable for debugging configuration issues. It shows the fully resolved YAML after variable interpolation and file merging. Use it whenever something is not working as expected.

---

## Step 10: Cleanup

### Stop and Remove Containers (Keep Data)

```bash
docker compose down
```

This stops and removes containers and the default network. Named volumes (like `pgdata`) are **preserved** -- your database data survives.

### Full Cleanup (Remove Everything)

```bash
docker compose down -v
```

The `-v` flag removes named volumes too. Your database data is deleted. Use this when you want a completely fresh start.

### Remove Built Images

```bash
docker compose down --rmi local
```

This also removes images that were built by Compose (not pulled from a registry).

### Nuclear Option

```bash
docker compose down -v --rmi all --remove-orphans
```

Removes containers, volumes, all images (including pulled ones like postgres:16), and orphan containers from previous configurations.

> **GOTCHA:** `docker compose down` does NOT remove named volumes by default. This is a safety feature -- you probably do not want to lose your database data every time you stop the stack. The `-v` flag is an explicit opt-in to data deletion.

---

## Troubleshooting

### "API starts before DB is ready"

**Symptom:** API logs show `ECONNREFUSED` or `connection refused` errors.

**Cause:** Missing or incorrect `depends_on` condition.

**Fix:** Ensure the API uses `condition: service_healthy` (not just `service_started`):

```yaml
api:
  depends_on:
    db:
      condition: service_healthy  # NOT just "depends_on: [db]"
```

Also verify the database has a working `healthcheck` directive.

### Port Conflicts

**Symptom:** `Bind for 0.0.0.0:5432 failed: port is already allocated`

**Cause:** Another process (or another Compose stack) is using that port on your host.

**Fix options:**
1. Stop the conflicting process: `lsof -i :5432` to find it
2. Change the host port mapping: `"5433:5432"` (access via port 5433 on host, but containers still use 5432 internally)

### Volume Permission Issues

**Symptom:** `permission denied` errors in container logs, especially with bind mounts.

**Cause:** The container process runs as a non-root user (good!) but the mounted files are owned by a different user.

**Fix options:**
1. Ensure host directory permissions allow the container user to read/write
2. For the API container (runs as `appuser`), the bind-mounted `src/server/` must be readable

### Container Keeps Restarting

**Symptom:** `docker compose ps` shows a service constantly restarting.

**Debug steps:**
```bash
# Check exit code and logs
docker compose logs api --tail 100

# Check if the container starts at all
docker compose ps -a

# Get detailed container info
docker inspect $(docker compose ps -q api)
```

Common causes: missing environment variables, incorrect `CMD`, dependency not ready.

### Changes Not Taking Effect

**Symptom:** You edited code but the running container still shows old behavior.

**Cause:** The file is not bind-mounted (so the container uses the baked-in version), or the image cache is stale.

**Fix:**
```bash
# Force rebuild
docker compose up --build api

# Nuclear: rebuild without cache
docker compose build --no-cache api
docker compose up api
```

---

*Reference: [Compose Cheatsheet](compose-cheatsheet.md) for quick command lookup*
