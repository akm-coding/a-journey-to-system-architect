# Docker Compose Study Guide

## What Problem Does Docker Compose Solve?

### The Multi-Container Problem

In the previous section, you learned to build and run individual Docker containers. But our e-commerce app needs **four services** to run: a React frontend, a Node API, PostgreSQL, and Redis. Running them manually looks like this:

```bash
# Create a network so containers can talk to each other
docker network create ecommerce

# Start PostgreSQL
docker run -d --name db --network ecommerce \
  -e POSTGRES_USER=ecommerce -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=ecommerce \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 postgres:16

# Start Redis
docker run -d --name redis --network ecommerce \
  -p 6379:6379 redis:7-alpine

# Start the API (depends on DB and Redis being ready)
docker run -d --name api --network ecommerce \
  -e DATABASE_URL=postgresql://ecommerce:secret@db:5432/ecommerce \
  -e REDIS_URL=redis://redis:6379 -e PORT=3000 \
  -p 3000:3000 ecommerce-api

# Start the frontend
docker run -d --name frontend --network ecommerce \
  -p 80:80 ecommerce-frontend
```

That's four long commands you have to run in the right order, every time. And tearing it all down requires four more `docker stop` and `docker rm` commands, plus cleaning up the network.

> **WHY:** Docker Compose replaces all of this with a single YAML file and one command: `docker compose up`. It defines your entire application stack -- services, networks, volumes, environment variables -- in a declarative configuration that lives in version control.

### What Compose Gives You

| Without Compose | With Compose |
|----------------|--------------|
| Manual `docker run` per service | `docker compose up` starts everything |
| Manual network creation | Automatic network for all services |
| Environment vars scattered across commands | Centralized in `.env` + `docker-compose.yml` |
| No startup ordering | `depends_on` with health checks |
| Manual cleanup | `docker compose down` tears everything down |
| Hard to share setup | YAML file is self-documenting and version-controlled |

---

## Compose File Anatomy

A `docker-compose.yml` file has three main top-level keys:

```yaml
services:    # The containers that make up your application
networks:    # Custom networks (optional -- Compose creates a default one)
volumes:     # Named volumes for persistent data
```

### Services

Each service is a container definition. Here is a minimal example:

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    ports:
      - "3000:3000"
    environment:
      PORT: 3000
```

This is equivalent to:

```bash
docker build -f Dockerfile.api -t <project>-api .
docker run -p 3000:3000 -e PORT=3000 <project>-api
```

The key difference: the YAML is declarative ("here is what I want") while `docker run` is imperative ("do this step by step"). Compose handles the translation.

### `image` vs `build`

Services can use a pre-built image or build from a Dockerfile:

```yaml
services:
  # Use a pre-built image from Docker Hub
  db:
    image: postgres:16

  # Build from a local Dockerfile
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
```

You can also use both -- `image` sets the name/tag for the built image:

```yaml
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    image: my-registry/ecommerce-api:latest  # Tag the built image
```

> **GOTCHA:** When using `build`, Compose does NOT automatically rebuild when your code changes. You must run `docker compose up --build` to trigger a rebuild. Without `--build`, it reuses the existing image.

---

## Docker Networking in Compose

### Automatic Service Discovery

When you run `docker compose up`, Compose creates a **bridge network** for your project automatically. Every service joins this network and is reachable by its **service name** as a hostname.

```
+-------------------------------------------------+
|  Docker Network: ecommerce_default              |
|                                                 |
|  +----------+    +----------+    +----------+   |
|  | frontend |    |   api    |    |    db    |   |
|  | port: 80 |--->| port:3000|--->| port:5432|   |
|  +----------+    +----------+    +----------+   |
|                       |                         |
|                  +----------+                   |
|                  |  redis   |                   |
|                  | port:6379|                   |
|                  +----------+                   |
+-------------------------------------------------+
```

This means:
- The `api` service can connect to PostgreSQL at `db:5432` (not `localhost:5432`)
- The `frontend` nginx config proxies to `http://api:3000` (not `http://localhost:3000`)
- Redis is reachable at `redis:6379` from any service

> **WHY:** Docker's internal DNS resolves service names to container IPs. This is why our nginx config uses `proxy_pass http://api:3000` -- "api" is the service name in `docker-compose.yml`, and Docker resolves it to the API container's IP address on the shared network.

### Port Mapping vs Internal Communication

```yaml
services:
  api:
    ports:
      - "3000:3000"  # Accessible from HOST at localhost:3000
```

The `ports` mapping exposes a container port to your **host machine**. But containers on the same Docker network can reach each other directly on their internal ports **without port mapping**.

You expose ports to the host for:
- **Development access** -- you want to hit the API from your browser or Postman
- **Entry points** -- the frontend on port 80 is how users access the app

You do NOT need to expose ports for:
- **Internal service communication** -- the API talks to PostgreSQL internally, no host mapping needed for `db` in production

> **GOTCHA:** If two services try to map the same host port (e.g., both want `"3000:3000"`), Compose will fail with a port conflict. Internal container ports can overlap freely -- only host port mappings must be unique.

---

## Health Checks

### Why "Container Started" Does Not Mean "Service Ready"

When you start PostgreSQL, the container starts in under a second. But the database itself needs several more seconds to initialize, create the default database, and begin accepting connections.

If the API container starts immediately after the database container, it will try to connect and get "connection refused" errors. The database is running but not **ready**.

```
Timeline without health checks:
  0s  - PostgreSQL container starts
  0s  - API container starts (immediately!)
  0s  - API tries to connect --> CONNECTION REFUSED
  3s  - PostgreSQL finishes initialization, starts accepting connections
  ???  - API has already crashed
```

### The healthcheck Directive

Docker can periodically run a command inside a container to check if the service is actually ready:

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s      # Check every 5 seconds
      timeout: 5s        # Fail if check takes longer than 5 seconds
      retries: 5         # Mark unhealthy after 5 consecutive failures
      start_period: 10s  # Grace period before checks count (optional)
```

The container status transitions through three states:

```
starting --> healthy     (if test succeeds)
starting --> unhealthy   (if test fails after retries)
```

You can see the status with `docker compose ps`:

```
NAME                STATUS
ecommerce-db-1     running (healthy)
ecommerce-redis-1  running (healthy)
ecommerce-api-1    running
```

### Common Health Check Patterns

| Service | Health Check Command | What It Checks |
|---------|---------------------|----------------|
| PostgreSQL | `pg_isready -U $USER` | Database accepts connections |
| Redis | `redis-cli ping` | Redis responds to PING |
| HTTP service | `curl -f http://localhost:PORT/health` | HTTP endpoint returns 200 |
| Node.js API | `wget --spider http://localhost:3000/api/health` | API responds to requests |

> **WHY:** `pg_isready` is a lightweight PostgreSQL utility that checks if the server is accepting connections without actually running a query. It is the recommended way to health-check PostgreSQL containers.

---

## depends_on with Conditions

### service_started vs service_healthy

The `depends_on` directive controls startup order, but it has two modes:

```yaml
services:
  api:
    depends_on:
      # Weak: only waits for container to START (not be ready)
      db:
        condition: service_started

      # Strong: waits for health check to pass
      redis:
        condition: service_healthy
```

| Condition | Waits For | Use When |
|-----------|-----------|----------|
| `service_started` (default) | Container process starts | Service has no health check, or you don't care about readiness |
| `service_healthy` | Health check passes | Service must be ready before dependent starts (databases, caches) |

```
Timeline WITH health checks + service_healthy:
  0s  - PostgreSQL container starts
  1s  - Health check: pg_isready --> not ready
  6s  - Health check: pg_isready --> not ready
  11s - Health check: pg_isready --> READY (healthy!)
  11s - API container starts (database is actually ready!)
  12s - API connects to database --> SUCCESS
```

> **GOTCHA:** The simple form `depends_on: [db]` is equivalent to `condition: service_started`. It only controls startup **order**, not readiness. For databases and caches, always use `condition: service_healthy` with a proper health check.

---

## Volume Types

### Named Volumes vs Bind Mounts

Docker supports two types of volumes, each serving a different purpose:

```yaml
services:
  db:
    volumes:
      # Named volume -- Docker manages the storage location
      - pgdata:/var/lib/postgresql/data

  api:
    volumes:
      # Bind mount -- maps a host directory into the container
      - ./src/server:/app/src/server
```

| Feature | Named Volume | Bind Mount |
|---------|-------------|------------|
| Syntax | `name:/container/path` | `./host/path:/container/path` |
| Managed by | Docker | You |
| Location on host | Docker's internal storage | Your project directory |
| Survives `docker compose down` | Yes | Yes (it's your files) |
| Removed by `docker compose down -v` | Yes | No (never deletes your files) |
| Use case | Persistent data (databases) | Development hot reload |

### Why Named Volumes for Databases

```yaml
volumes:
  pgdata:  # Declared at the top level

services:
  db:
    volumes:
      - pgdata:/var/lib/postgresql/data
```

Without a volume, PostgreSQL data lives inside the container's writable layer. When you run `docker compose down`, the container is removed and **all data is lost**. Named volumes persist independently of containers.

> **WHY:** Named volumes are the correct way to persist database data. The volume `pgdata` survives container restarts, rebuilds, and `docker compose down`. Only `docker compose down -v` (the `-v` flag) explicitly removes named volumes.

### Why Bind Mounts for Development

```yaml
services:
  api:
    volumes:
      - ./src/server:/app/src/server    # Source code
      - ./dist/server:/app/dist/server  # Compiled output
```

Bind mounts map a directory from your host machine into the container. When you edit `src/server/index.ts` on your laptop, the change is immediately visible inside the container. Combined with a file watcher (like `tsx watch`), this gives you hot reload without rebuilding the image.

> **GOTCHA:** Bind mounts work in both directions. If a process inside the container writes to a bind-mounted directory, those files appear on your host. This is useful (compiled output) but can cause surprises with permissions -- files created by `root` inside the container may be owned by `root` on your host.

---

## Environment Variables

### Three Ways to Set Variables

**1. Inline in the Compose file:**

```yaml
services:
  api:
    environment:
      PORT: 3000
      NODE_ENV: development
```

Good for values that are the same across all environments and not secret.

**2. From an `.env` file (automatic):**

Compose automatically loads a `.env` file in the same directory as `docker-compose.yml`. Variables are available for interpolation:

```yaml
# docker-compose.yml
services:
  db:
    environment:
      POSTGRES_USER: ${POSTGRES_USER}      # Reads from .env
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

```bash
# .env
POSTGRES_USER=ecommerce
POSTGRES_PASSWORD=my-secret-password
```

**3. Using `env_file` directive:**

```yaml
services:
  api:
    env_file:
      - .env
```

This passes ALL variables from the file directly to the container's environment, without needing `${...}` interpolation in the Compose file.

### The .env + .env.example Pattern

The standard pattern for environment management:

- **`.env`** -- Contains actual values (secrets, passwords). **Never committed to Git** (add to `.gitignore`).
- **`.env.example`** -- Contains placeholder values. **Committed to Git** as documentation for what variables are needed.

```bash
# .env.example (committed -- shows WHAT variables exist)
POSTGRES_USER=ecommerce
POSTGRES_PASSWORD=changeme
POSTGRES_DB=ecommerce

# .env (gitignored -- has REAL values)
POSTGRES_USER=ecommerce
POSTGRES_PASSWORD=my-actual-secure-password
POSTGRES_DB=ecommerce
```

New developers copy the example to create their local config:

```bash
cp .env.example .env
# Edit .env with your actual values
```

> **GOTCHA:** Docker Compose's automatic `.env` loading only works for variable interpolation in the YAML file (`${VAR}`). It does NOT automatically pass all `.env` variables to containers. Use `env_file: .env` or explicit `environment:` entries to pass variables to containers.

---

## Override Files: Dev vs Production

### The Override Pattern

Docker Compose supports layering multiple files. A common pattern:

- `docker-compose.yml` -- Base configuration (services, networks, volumes)
- `docker-compose.prod.yml` -- Production overrides (no dev volumes, restart policies)

```bash
# Development (uses only the base file)
docker compose up

# Production (base + production overrides)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build
```

The second file **merges** into the first. Matching keys are overridden; new keys are added.

### What Changes Between Dev and Prod

| Aspect | Development | Production |
|--------|------------|------------|
| Source code | Bind-mounted from host (hot reload) | Baked into image at build time |
| NODE_ENV | `development` | `production` |
| Restart policy | None (you want errors to crash loudly) | `unless-stopped` (auto-recover) |
| Debug ports | Exposed (5432, 6379 for debugging) | Internal only |
| Build frequency | Rarely (use cached images) | Always (`--build` flag) |

### How Override Merging Works

Base file (`docker-compose.yml`):

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    environment:
      NODE_ENV: development
    volumes:
      - ./src/server:/app/src/server
```

Override file (`docker-compose.prod.yml`):

```yaml
services:
  api:
    environment:
      NODE_ENV: production     # Overrides "development"
    volumes: []                # Removes all bind mounts
    restart: unless-stopped    # Added (not in base file)
```

Result after merging:

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    environment:
      NODE_ENV: production     # From override
    volumes: []                # From override (empty = no mounts)
    restart: unless-stopped    # From override (added)
```

> **WHY:** The override pattern keeps a single source of truth for service definitions (base file) while allowing environment-specific tweaks. You never duplicate the full configuration -- the prod file only contains what differs.

### Restart Policies

| Policy | Behavior |
|--------|----------|
| `no` (default) | Never restart. If the process exits, the container stops. |
| `always` | Always restart, even if manually stopped. |
| `unless-stopped` | Restart unless explicitly stopped with `docker compose stop`. |
| `on-failure[:max]` | Restart only on non-zero exit code, optional retry limit. |

For production, `unless-stopped` is the standard choice. It ensures services auto-recover from crashes but respects intentional stops during maintenance.

---

## Putting It All Together

Here is how all these concepts combine in our e-commerce stack:

```
docker-compose.yml
├── db (postgres:16)
│   ├── Health check: pg_isready
│   ├── Named volume: pgdata
│   └── Env vars from .env
├── redis (redis:7-alpine)
│   └── Health check: redis-cli ping
├── api (Dockerfile.api)
│   ├── depends_on: db (healthy), redis (healthy)
│   ├── Bind mounts for dev hot reload
│   └── Env vars: DATABASE_URL, REDIS_URL, PORT
└── frontend (Dockerfile)
    ├── depends_on: api
    └── Exposes port 80

docker-compose.prod.yml (overrides)
├── All services: restart: unless-stopped
├── api: remove bind mounts, NODE_ENV=production
└── frontend: restart: unless-stopped
```

The startup flow:
1. `docker compose up` reads `docker-compose.yml` and `.env`
2. Compose creates a bridge network and the `pgdata` volume
3. PostgreSQL and Redis start first (no dependencies)
4. Compose waits for health checks to pass (healthy state)
5. API starts only after db and redis are healthy
6. Frontend starts after API (service_started, since nginx is always ready)
7. Full stack available at `http://localhost`

---

## Key Takeaways

1. **Compose is declarative** -- you describe what you want, not how to do it
2. **Service names are hostnames** -- containers reach each other by service name via Docker DNS
3. **Health checks prevent race conditions** -- `service_healthy` ensures dependencies are truly ready
4. **Named volumes persist data** -- database data survives container restarts
5. **Bind mounts enable hot reload** -- edit code on host, see changes in container instantly
6. **The override pattern separates dev from prod** -- one base config, environment-specific overrides
7. **`.env.example` is documentation** -- commit the template, gitignore the real values

---

*Next: [Compose Exercise](compose-exercise.md) -- Build and run the full stack hands-on*
