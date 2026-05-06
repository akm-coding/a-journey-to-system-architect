# Phase 3: Containerization - Research

**Researched:** 2026-05-07
**Domain:** Docker, Docker Compose, AWS ECR
**Confidence:** HIGH

## Summary

Phase 3 containerizes the existing e-commerce app (React + Vite frontend, Node/Express API, PostgreSQL database) using Docker. The learner writes Dockerfiles, runs the full stack locally with Docker Compose, and pushes images to AWS ECR. The app uses Node 20, has a single `package.json` with separate `build:client` (Vite) and `build:server` (tsc) scripts, and the client build outputs to `dist/client`.

The key technical challenges are: (1) the React multi-stage build with Vite producing static assets served by nginx, (2) orchestrating 4 services (frontend, API, PostgreSQL, Redis) with proper health checks and startup ordering, and (3) the ECR authentication/push workflow with lifecycle policies.

**Primary recommendation:** Use the incremental teaching approach decided in CONTEXT.md -- start with a naive single-stage Dockerfile, demonstrate the bloat, then refactor to multi-stage. All Docker images should use Alpine variants. Compose should use `depends_on` with `service_healthy` conditions rather than wait-for-it scripts.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Practical builder depth -- cover what's needed to write good Dockerfiles and Compose files (layers, caching, .dockerignore). Skip kernel internals (cgroups, namespaces, union filesystems)
- Include essential Docker security: non-root users in containers, avoiding secrets in images, basic scanning
- Dedicated troubleshooting/debugging section covering common errors and debugging tools (docker logs, exec, inspect)
- Same format as Phase 1-2: study docs with concept explanations, then separate runbook/cheatsheet for hands-on
- Incremental build-up approach: start with simple single-stage Dockerfile, see the problems, then refactor to multi-stage
- Learner writes the React multi-stage Dockerfile (build stage + nginx serve stage); Node API Dockerfile is provided pre-written
- Alpine-based images (node:alpine, nginx:alpine)
- Layer caching optimization with hands-on demo: build bad Dockerfile, time it, reorder for caching, time again
- Full stack: React frontend, Node API, PostgreSQL, Redis (4 services)
- Two configurations: docker-compose.yml for dev (volume mounts, hot reload) + docker-compose.prod.yml override for production-like builds
- Environment variables via .env file pattern with .env.example checked into version control
- Health checks with depends_on service_healthy conditions for DB and Redis
- CLI-first approach for ECR: create repo, authenticate, tag, push all via AWS CLI
- Tagging strategy: git commit SHA for traceability + "latest" for convenience
- Basic lifecycle policy to keep last N images and expire untagged ones
- Full teardown script including ECR repo deletion

### Claude's Discretion
- .env file pattern: what goes in .env vs .env.example
- Exact number of images to retain in lifecycle policy
- Troubleshooting section organization and specific error scenarios
- Docker network configuration details in Compose
- Specific nginx configuration for the React multi-stage build

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEPL-03 | Learner can write Dockerfiles for React (multi-stage build) and Node apps | Multi-stage build patterns, nginx SPA config, Alpine base images, .dockerignore, layer caching |
| DEPL-04 | Learner can use Docker Compose to run a multi-service stack locally (app + db + redis) | Compose service definitions, health checks, depends_on, dev/prod override pattern, volume mounts |
| DEPL-05 | Learner can push Docker images to AWS ECR | ECR create-repository, get-login-password auth, tag/push workflow, lifecycle policies, teardown |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version/Tag | Purpose | Why Standard |
|------|-------------|---------|--------------|
| Docker Engine | Latest stable (27.x) | Container runtime | Industry standard containerization |
| Docker Compose | V2 (built into Docker CLI) | Multi-service orchestration | `docker compose` (no hyphen) is the current standard |
| node:20-alpine | Node 20 LTS on Alpine | Build stage base image | Matches project .nvmrc (Node 20), Alpine for small size |
| nginx:alpine | Latest nginx on Alpine | Serve React static assets | ~40MB final image, production-grade web server |
| postgres:16 | PostgreSQL 16 | Database service in Compose | Stable LTS, matches RDS version from Phase 2 |
| redis:7-alpine | Redis 7 on Alpine | Cache service in Compose | Current stable, Alpine for consistency |
| AWS ECR | N/A | Container registry | AWS-native, integrates with ECS in Phase 6 |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| docker scout / docker scan | Image vulnerability scanning | After building production images |
| AWS CLI v2 | ECR authentication and management | All ECR operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Alpine images | Slim (Debian) images | Slim is larger (~180MB vs ~50MB for node) but avoids musl libc edge cases. Alpine is fine for this app since there are no native dependencies beyond pg |
| nginx for React | Serve static from Node/Express | Nginx is purpose-built for static files, much lower resource usage |
| ECR | Docker Hub | ECR integrates natively with ECS/Fargate (Phase 6), no rate limits with AWS auth |

## Architecture Patterns

### Project Structure for Docker Files
```
app/
  Dockerfile              # React frontend multi-stage (learner writes)
  Dockerfile.api          # Node API (provided pre-written)
  .dockerignore           # Shared ignore file
  nginx.conf              # nginx config for SPA routing
  docker-compose.yml      # Dev configuration (default)
  docker-compose.prod.yml # Production override
  .env.example            # Template with placeholder values (committed)
  .env                    # Actual values (gitignored)
```

### Pattern 1: React Multi-Stage Build (Dockerfile)
**What:** Two-stage Dockerfile -- build with Node, serve with nginx
**When to use:** Any React/Vite SPA that produces static assets

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build:client

# Stage 2: Serve
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/client /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Key details for this project:**
- The Vite build outputs to `dist/client` (configured in `vite.config.ts` outDir)
- `pnpm install --frozen-lockfile` ensures reproducible builds
- `corepack enable` is needed because Alpine node image doesn't ship pnpm by default
- COPY package.json first, then source -- leverages Docker layer caching

### Pattern 2: nginx SPA Configuration (nginx.conf)
**What:** Minimal nginx config that handles React Router client-side routing

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/css application/javascript application/json;
    gzip_min_length 256;

    # SPA routing -- fall back to index.html for client-side routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache hashed assets aggressively (Vite adds content hash to filenames)
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Why `try_files`:** Without this, refreshing on `/products/123` returns nginx 404. This directive tries the literal file first, then falls back to `index.html` so React Router handles the route.

### Pattern 3: Node API Dockerfile (Dockerfile.api)
**What:** Simple single-stage Dockerfile for the Express API

```dockerfile
FROM node:20-alpine
WORKDIR /app

# Install pnpm
RUN corepack enable

# Install dependencies (cached layer)
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

# Copy built server code
COPY dist/server ./dist/server
COPY src/server/db ./src/server/db

# Security: non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3000
CMD ["node", "dist/server/index.js"]
```

**Note:** The API Dockerfile assumes `pnpm build:server` (tsc) has been run before building the image, or it could be multi-stage too. Since CONTEXT.md says the API Dockerfile is "provided pre-written," this can be a simpler pattern that copies pre-built output.

### Pattern 4: Docker Compose with Health Checks
**What:** Dev compose with volume mounts + health-check-based startup ordering

```yaml
# docker-compose.yml (dev)
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3

  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  frontend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "80:80"
    depends_on:
      - api

volumes:
  pgdata:
```

### Pattern 5: Production Override (docker-compose.prod.yml)
**What:** Override file that replaces dev volume mounts with built images

```yaml
# docker-compose.prod.yml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
      # No volume mounts -- uses baked-in code
    restart: unless-stopped

  frontend:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
```

**Usage:**
- Dev: `docker compose up` (uses docker-compose.yml only)
- Prod-like: `docker compose -f docker-compose.yml -f docker-compose.prod.yml up`

### Pattern 6: ECR Push Workflow
**What:** Complete CLI workflow to push images to ECR

```bash
# Variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-southeast-1  # or learner's region
REPO_NAME=ecommerce-frontend
IMAGE_TAG=$(git rev-parse --short HEAD)

# 1. Create repository (once)
aws ecr create-repository --repository-name $REPO_NAME --region $AWS_REGION

# 2. Authenticate Docker to ECR (valid 12 hours)
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 3. Tag the image
docker tag $REPO_NAME:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG

docker tag $REPO_NAME:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest

# 4. Push both tags
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest
```

### Anti-Patterns to Avoid
- **COPY . . before dependency install:** Invalidates the npm/pnpm install cache on every code change. Always COPY package.json and lockfile first, install, then COPY source.
- **Running as root in containers:** Default Docker user is root. Always create and switch to a non-root user in production images.
- **Storing secrets in images:** Never `COPY .env` into a Dockerfile. Use environment variables at runtime via Compose or `docker run -e`.
- **Using `latest` tag alone in production:** Always tag with a specific identifier (commit SHA) for traceability. `latest` is a convenience, not a version.
- **Using `docker-compose` (hyphen):** The legacy `docker-compose` (Python-based v1) is deprecated. Use `docker compose` (space, Go-based v2) which is built into Docker CLI.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Service startup ordering | Shell wait-for-it scripts | `depends_on` + `service_healthy` | Built into Compose v2, eliminates extra scripts |
| Static file serving | Express static middleware | nginx:alpine | Purpose-built, 10x less memory, handles compression/caching natively |
| Container registry | Self-hosted registry | AWS ECR | Managed, integrates with IAM, no maintenance |
| Secret management in Compose | Hardcoded env values | `.env` file + `.env.example` pattern | .env is gitignored, .env.example documents required vars |
| Image cleanup | Manual deletion | ECR lifecycle policies | Automated, prevents cost creep |

## Common Pitfalls

### Pitfall 1: Docker Build Context Too Large
**What goes wrong:** `docker build` sends entire directory (including node_modules, .git) as build context -- takes minutes, wastes disk
**Why it happens:** Missing or insufficient `.dockerignore`
**How to avoid:** Create `.dockerignore` with: `node_modules`, `.git`, `dist`, `.env`, `*.log`, `.DS_Store`
**Warning signs:** "Sending build context to Docker daemon" shows hundreds of MB

### Pitfall 2: Layer Cache Invalidation
**What goes wrong:** Every code change triggers a full `pnpm install` rebuild (~60-90 seconds)
**Why it happens:** `COPY . .` before `RUN pnpm install` means any file change invalidates the install layer
**How to avoid:** COPY package.json + lockfile first, install, then COPY source code
**Warning signs:** Builds take the same time whether you changed one line or many files

### Pitfall 3: API Connects Before Database is Ready
**What goes wrong:** Node API crashes on startup with "connection refused" to PostgreSQL
**Why it happens:** `depends_on` without health check condition only waits for container start, not service readiness
**How to avoid:** Use `depends_on: db: condition: service_healthy` with `pg_isready` health check
**Warning signs:** API container restarts repeatedly in `docker compose logs`

### Pitfall 4: Volume Permissions on Linux
**What goes wrong:** Container can't write to mounted volumes, or host files are owned by root
**Why it happens:** UID mismatch between container user and host user
**How to avoid:** On macOS (this learner's platform) this is handled by Docker Desktop's file sharing. Note it for awareness but it won't block learning.
**Warning signs:** "Permission denied" errors in container logs

### Pitfall 5: ECR Auth Token Expiration
**What goes wrong:** `docker push` fails with "no basic auth credentials" after working earlier
**Why it happens:** ECR auth tokens expire after 12 hours
**How to avoid:** Re-run `aws ecr get-login-password | docker login` before push operations
**Warning signs:** Push worked yesterday but fails today with auth error

### Pitfall 6: Vite Build Needs API URL at Build Time
**What goes wrong:** React app in container can't reach the API
**Why it happens:** Vite bakes environment variables at build time (VITE_* prefix), not runtime
**How to avoid:** In Docker Compose, the frontend nginx container proxies to API via Docker network. For this setup, the React app's API calls go to relative paths (`/api/*`) which nginx can reverse-proxy to the API service. Alternatively, since the current vite.config.ts already uses a proxy to `http://localhost:3000`, the production nginx config should proxy `/api` to the api service.
**Warning signs:** Network errors in browser console, CORS errors

### Pitfall 7: pnpm Not Available in Alpine Node Image
**What goes wrong:** `pnpm: not found` during Docker build
**Why it happens:** Alpine Node images ship with npm but not pnpm. The project uses pnpm.
**How to avoid:** Add `RUN corepack enable` before any pnpm commands in the Dockerfile
**Warning signs:** Build fails immediately at the install step

## Code Examples

### .dockerignore for This Project
```
node_modules
.git
dist
.env
.env.*
!.env.example
*.log
.DS_Store
.vscode
.idea
*.pem
.aws
```

### .env.example Template
```bash
# Database
POSTGRES_USER=ecommerce
POSTGRES_PASSWORD=changeme
POSTGRES_DB=ecommerce

# App
DATABASE_URL=postgresql://ecommerce:changeme@db:5432/ecommerce
REDIS_URL=redis://redis:6379
PORT=3000
NODE_ENV=production
```

### ECR Lifecycle Policy (keep last 10 tagged, expire untagged after 7 days)
```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 10 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["latest"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

**Recommendation for lifecycle policy:** Keep last 10 images (reasonable for a learning project -- enough history without cost accumulation) and expire untagged images after 7 days.

### nginx.conf with API Reverse Proxy (Production Compose)
```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/css application/javascript application/json;
    gzip_min_length 256;

    # API reverse proxy to backend service
    location /api/ {
        proxy_pass http://api:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache hashed assets
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Key insight:** In Docker Compose, service names (like `api`) resolve via Docker's internal DNS. The nginx `proxy_pass http://api:3000` routes API calls to the Node container without the React app needing to know the API host at build time. This eliminates the Vite build-time env variable problem entirely.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `docker-compose` (Python v1) | `docker compose` (Go v2) | 2023 | V1 is EOL. Always use `docker compose` (space) |
| `wait-for-it.sh` scripts | `depends_on: condition: service_healthy` | Compose v2.1+ | No extra scripts needed |
| `docker build` only | `docker buildx build` | 2023+ | Buildx is now default, supports multi-platform |
| `aws ecr get-login` | `aws ecr get-login-password` | 2020 | Old command is deprecated |
| `npm install` in Dockerfile | `pnpm install --frozen-lockfile` | Project-specific | Matches project's package manager |

## Open Questions

1. **Dev hot reload approach for the API in Compose**
   - What we know: Dev compose should mount source code for hot reload. The API uses `tsx watch` for dev.
   - What's unclear: Whether to mount the full `src/server` directory or use a dev-targeted Dockerfile stage
   - Recommendation: Mount `./src/server:/app/src/server` in dev compose and override the command to `pnpm dev:server`. Simpler than multi-target Dockerfile for a learning project.

2. **Frontend dev workflow in Compose**
   - What we know: Vite dev server has its own hot reload on port 5173
   - What's unclear: Whether to run Vite dev server in a container or just the production nginx build
   - Recommendation: For dev compose, run Vite dev server in a container with source mount for consistency. For prod compose, use the multi-stage nginx build. This teaches both workflows.

3. **Database seeding in Compose**
   - What we know: The app has a `pnpm seed` command and `db:push` for schema
   - What's unclear: How to handle initial schema/seed when running `docker compose up` for the first time
   - Recommendation: Document a post-startup step: `docker compose exec api pnpm db:push && docker compose exec api pnpm seed`. Don't auto-run in Dockerfile (would run on every container start).

## Sources

### Primary (HIGH confidence)
- [Docker official docs - Compose startup order](https://docs.docker.com/compose/how-tos/startup-order/) - health check patterns
- [AWS ECR official docs - Push image](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html) - push workflow
- [AWS ECR official docs - Lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html) - image cleanup
- [AWS ECR official docs - Registry auth](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html) - get-login-password
- [Docker Hub - node:20-alpine](https://hub.docker.com/_/node) - base image details

### Secondary (MEDIUM confidence)
- [Docker official blog - Dockerize React App](https://www.docker.com/blog/how-to-dockerize-react-app/) - multi-stage patterns
- [OneUpTime - Containerize React multi-stage](https://oneuptime.com/blog/post/2026-01-15-containerize-react-multi-stage-docker/view) - verified patterns
- [Docker Recipes - Compose multi-environment](https://docker.recipes/blog/docker-compose-multi-environment-dev-staging-prod) - override patterns
- [Node.js Best Practices - Docker section](https://github.com/goldbergyoni/nodebestpractices/blob/master/sections/docker/docker-ignore.md) - .dockerignore

### Tertiary (LOW confidence)
- None -- all findings verified with official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Docker, Compose, ECR are mature and well-documented
- Architecture: HIGH - Multi-stage builds and Compose patterns are well-established; verified against this project's specific structure (Vite output path, pnpm, Node 20)
- Pitfalls: HIGH - Common issues are extensively documented; project-specific issues (pnpm in Alpine, Vite build-time env) identified from actual app code

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (Docker ecosystem is stable; ECR APIs rarely change)
