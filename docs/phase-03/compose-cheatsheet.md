# Docker Compose Cheatsheet

Quick reference for Docker Compose commands, YAML configuration, and common patterns.

---

## Lifecycle Commands

| Command | What It Does |
|---------|-------------|
| `docker compose up` | Create and start all services |
| `docker compose up -d` | Start in detached mode (background) |
| `docker compose up --build` | Rebuild images before starting |
| `docker compose down` | Stop and remove containers + network |
| `docker compose down -v` | Also remove named volumes (database data!) |
| `docker compose stop` | Stop containers without removing them |
| `docker compose start` | Start previously stopped containers |
| `docker compose restart` | Restart all services |
| `docker compose restart api` | Restart a specific service |

---

## Inspection Commands

| Command | What It Does |
|---------|-------------|
| `docker compose ps` | List running services and their status |
| `docker compose ps -a` | Include stopped containers |
| `docker compose logs` | View output from all services |
| `docker compose logs -f` | Follow log output in real time |
| `docker compose logs --tail 50 api` | Last 50 lines of the API service |
| `docker compose config` | Show the resolved/merged YAML config |
| `docker compose stats` | Live CPU/memory/network per container |
| `docker compose images` | List images used by services |
| `docker compose top` | Show running processes in containers |

---

## Execution Commands

| Command | What It Does |
|---------|-------------|
| `docker compose exec api sh` | Open a shell in a running container |
| `docker compose exec db psql -U ecommerce` | Run psql in the database container |
| `docker compose exec api pnpm seed` | Run a one-off command in a running container |
| `docker compose run --rm api pnpm test` | Create a new container, run command, remove on exit |

> **exec** runs in an existing container. **run** creates a new one.

---

## Build Commands

| Command | What It Does |
|---------|-------------|
| `docker compose build` | Build all images |
| `docker compose build api` | Build a specific service's image |
| `docker compose build --no-cache` | Build without layer cache |
| `docker compose up --build --force-recreate` | Rebuild and recreate everything |

---

## Common Flags

| Flag | Used With | Effect |
|------|-----------|--------|
| `-d` | `up` | Detached mode (run in background) |
| `--build` | `up` | Force image rebuild before starting |
| `-v` | `down` | Remove named volumes (deletes data) |
| `--rmi local` | `down` | Remove locally built images |
| `--remove-orphans` | `down`, `up` | Remove containers for undefined services |
| `-f file.yml` | any | Specify Compose file(s) |
| `--force-recreate` | `up` | Recreate containers even if config unchanged |
| `--no-deps` | `up`, `run` | Skip starting linked/dependent services |
| `--tail N` | `logs` | Show last N lines |
| `--rm` | `run` | Remove container after exit |

---

## YAML Keys Reference

### Service Configuration

```yaml
services:
  service_name:
    image: postgres:16              # Use a pre-built image
    build:                          # OR build from Dockerfile
      context: .                    #   Build context directory
      dockerfile: Dockerfile.api    #   Which Dockerfile to use
    ports:
      - "HOST:CONTAINER"           # Map host port to container port
    environment:                    # Set environment variables
      KEY: value
      KEY: ${INTERPOLATED}         # Read from .env file
    env_file:                       # Load vars from file
      - .env
    volumes:
      - named:/container/path      # Named volume
      - ./host/path:/container/path # Bind mount
    depends_on:                     # Startup ordering
      db:
        condition: service_healthy  # Wait for health check
    healthcheck:
      test: ["CMD", "command"]     # Health check command
      interval: 5s                 # Time between checks
      timeout: 5s                  # Max time for single check
      retries: 5                   # Failures before unhealthy
      start_period: 10s            # Grace period at startup
    restart: unless-stopped         # Restart policy
    working_dir: /app               # Override WORKDIR
    command: ["node", "server.js"]  # Override CMD
    networks:
      - custom_network             # Join specific network
```

### Top-Level Keys

```yaml
volumes:
  pgdata:              # Declare named volumes

networks:
  backend:             # Declare custom networks
    driver: bridge
```

---

## Health Check Patterns

### PostgreSQL

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
  interval: 5s
  timeout: 5s
  retries: 5
```

### Redis

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 3s
  retries: 3
```

### HTTP Service (curl)

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 10s
  timeout: 5s
  retries: 3
```

### HTTP Service (wget -- for Alpine images without curl)

```yaml
healthcheck:
  test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
  interval: 10s
  timeout: 5s
  retries: 3
```

---

## Environment Variable Patterns

### Interpolation from .env

```yaml
# docker-compose.yml reads from .env automatically
environment:
  POSTGRES_USER: ${POSTGRES_USER}
  DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
```

### Pass entire .env to container

```yaml
env_file:
  - .env
```

### Default values

```yaml
environment:
  PORT: ${PORT:-3000}           # Use 3000 if PORT is not set
  NODE_ENV: ${NODE_ENV:-development}
```

---

## Override Pattern (Dev vs Prod)

```bash
# Development (base file only)
docker compose up

# Production (base + override)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build

# Validate merged config
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

---

## Common Troubleshooting

| Problem | Command |
|---------|---------|
| Service won't start | `docker compose logs service_name` |
| Port already in use | `lsof -i :PORT` to find conflicting process |
| Check health status | `docker compose ps` (look for healthy/unhealthy) |
| Stale image cache | `docker compose build --no-cache service_name` |
| See resolved config | `docker compose config` |
| Check what's inside a container | `docker compose exec service_name sh` |
| Database data won't go away | `docker compose down -v` (removes volumes) |
| Orphan containers from old config | `docker compose down --remove-orphans` |
| Container filesystem full | `docker system prune` (careful: removes unused data) |

---

## Quick Recipes

### Fresh start (wipe everything)

```bash
docker compose down -v --rmi local --remove-orphans
docker compose up --build
```

### Rebuild one service without stopping others

```bash
docker compose up --build --no-deps -d api
```

### Run database migrations

```bash
docker compose exec api pnpm db:push
```

### Seed database

```bash
docker compose exec api pnpm seed
```

### Connect to PostgreSQL directly

```bash
docker compose exec db psql -U ecommerce -d ecommerce
```

### Export database dump

```bash
docker compose exec db pg_dump -U ecommerce ecommerce > backup.sql
```

### Import database dump

```bash
docker compose exec -T db psql -U ecommerce ecommerce < backup.sql
```

---

*Study: [Compose Guide](compose-guide.md) | Practice: [Compose Exercise](compose-exercise.md)*
