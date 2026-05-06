# Docker Fundamentals Study Guide

## What Problem Does Docker Solve?

### The "Works on My Machine" Problem

Every developer has heard it: "But it works on my machine!" The root cause is always the same -- your development environment differs from production. Different Node versions, missing system libraries, conflicting Python packages, wrong PostgreSQL version.

Docker solves this by packaging your application **and its entire environment** into a single artifact called an **image**. That image runs identically on your laptop, your colleague's laptop, CI/CD, staging, and production.

### Why Docker Matters for Deployment

Without Docker:
- Manual server setup (install Node, configure Nginx, set up PostgreSQL)
- Configuration drift between environments
- "It worked in staging" failures in production
- Painful rollbacks (which files changed? which configs?)

With Docker:
- One command to run your entire stack: `docker compose up`
- Identical environment everywhere the image runs
- Instant rollbacks: just run the previous image
- New team members productive in minutes, not days

> **WHY:** Docker doesn't just make deployment easier -- it makes deployments **reproducible**. The image you test is the exact image you deploy.

---

## Core Concepts

### Images vs Containers

Think of it like a class vs an instance in programming:

| Concept   | Analogy         | What It Is                                    |
|-----------|-----------------|-----------------------------------------------|
| **Image** | Class/Blueprint | Read-only template with your app + environment |
| **Container** | Instance/Object | Running process created from an image       |

You build an **image** once. You can create many **containers** from that image. Containers are isolated processes -- they have their own filesystem, network, and process space.

```bash
# Build an image (the blueprint)
docker build -t my-app .

# Create and run a container (an instance)
docker run my-app

# List running containers
docker ps

# List all images
docker images
```

### Docker Daemon and CLI

Docker uses a client-server architecture:

- **Docker Daemon** (`dockerd`): Background service that manages images, containers, networks, volumes
- **Docker CLI** (`docker`): Command-line tool that sends commands to the daemon
- **Docker Desktop**: GUI wrapper that includes the daemon, CLI, and extras (used on macOS/Windows)

When you run `docker build`, the CLI sends your files to the daemon, which does the actual building.

### Registries

A **registry** is where Docker images are stored and shared:

- **Docker Hub**: Public registry (like npm for Docker images). Has official images like `node`, `nginx`, `postgres`
- **Amazon ECR**: AWS private registry (we'll use this in Plan 03)
- **GitHub Container Registry (ghcr.io)**: GitHub's registry

```bash
# Pull an image from Docker Hub
docker pull node:20-alpine

# Push your image to a registry
docker push my-registry.com/my-app:v1.0
```

---

## Dockerfile Anatomy

A Dockerfile is a text file with instructions that tell Docker how to build an image. Each instruction creates a **layer** in the image.

### Instruction Reference

| Instruction | Purpose                          | Example                                    |
|-------------|----------------------------------|--------------------------------------------|
| `FROM`      | Base image to start from         | `FROM node:20-alpine`                      |
| `WORKDIR`   | Set working directory            | `WORKDIR /app`                             |
| `COPY`      | Copy files from host into image  | `COPY package.json .`                      |
| `RUN`       | Execute a command during build   | `RUN pnpm install`                         |
| `EXPOSE`    | Document which port the app uses | `EXPOSE 3000`                              |
| `CMD`       | Default command when container starts | `CMD ["node", "server.js"]`           |
| `ENV`       | Set environment variable         | `ENV NODE_ENV=production`                  |
| `ARG`       | Build-time variable              | `ARG API_URL`                              |
| `USER`      | Switch to non-root user          | `USER appuser`                             |

### A Simple Dockerfile Explained

```dockerfile
# Start from the official Node.js image on Alpine Linux (small base)
FROM node:20-alpine

# Create and switch to /app directory inside the image
WORKDIR /app

# Copy dependency files first (for caching -- explained below)
COPY package.json pnpm-lock.yaml ./

# Enable pnpm (not available by default in Alpine) and install dependencies
RUN corepack enable && pnpm install --frozen-lockfile

# Copy the rest of the application source code
COPY . .

# Build the application
RUN pnpm build:client

# Document that this container listens on port 3000
EXPOSE 3000

# Default command to run when the container starts
CMD ["node", "dist/server/index.js"]
```

> **GOTCHA:** `EXPOSE` does NOT publish the port. It's documentation only. You still need `-p 3000:3000` when running the container.

---

## Image Layers and the Layer Cache

### How Layers Work

Each Dockerfile instruction creates a new **layer**. Docker stacks layers on top of each other to form the final image.

```
Layer 5: CMD ["node", "server.js"]         (metadata only)
Layer 4: RUN pnpm build:client             (compiled assets)
Layer 3: COPY . .                          (source code)
Layer 2: RUN pnpm install                  (node_modules)
Layer 1: COPY package.json pnpm-lock.yaml  (dependency manifest)
Layer 0: FROM node:20-alpine               (base OS + Node.js)
```

### Why Layer Caching Matters

Docker caches each layer. On rebuild, if an instruction and its inputs haven't changed, Docker reuses the cached layer instead of re-executing it. This makes builds **dramatically faster**.

The cache invalidation rule is simple: **if a layer changes, all layers after it are rebuilt.**

### The Order Matters -- A Lot

**Bad pattern** (cache busted on every code change):

```dockerfile
COPY . .                          # Changes whenever ANY file changes
RUN pnpm install                  # Reinstalls ALL deps every time!
RUN pnpm build:client             # Rebuilds every time
```

**Good pattern** (deps cached unless package.json changes):

```dockerfile
COPY package.json pnpm-lock.yaml .  # Only changes when deps change
RUN pnpm install                    # Cached if deps haven't changed!
COPY . .                            # Source code changes
RUN pnpm build:client               # Only this and below rebuild
```

> **WHY:** Installing dependencies takes 30-60 seconds. By copying `package.json` first, you only reinstall when dependencies actually change. Source code changes (the common case) skip the install step entirely.

### Viewing Layers

```bash
# See all layers in an image and their sizes
docker history my-app

# Detailed layer information
docker inspect my-app
```

---

## Multi-Stage Builds

### The Problem with Single-Stage

A single-stage Dockerfile for a React app includes **everything** in the final image:

- Node.js runtime (~180MB)
- All node_modules including devDependencies (~400MB)
- Source code, TypeScript files, build tools
- The actual built assets you need (~5MB)

Result: a 1GB+ image where 99% of the contents aren't needed at runtime.

### What Multi-Stage Builds Do

Multi-stage builds use multiple `FROM` instructions. Each `FROM` starts a new **stage**. You can copy artifacts from one stage to another, leaving behind everything else.

```dockerfile
# Stage 1: Build (has Node, npm, all dev tools)
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build:client

# Stage 2: Production (only nginx + built files)
FROM nginx:alpine
COPY --from=build /app/dist/client /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Why Multi-Stage Is Better

| Aspect         | Single-Stage   | Multi-Stage       |
|----------------|----------------|-------------------|
| Image size     | ~1GB           | ~40MB             |
| Attack surface | Node, npm, dev tools all present | Only nginx + static files |
| Build tools in prod | Yes (unnecessary risk) | No (left in build stage) |
| Startup time   | Slower (larger image to pull) | Faster            |

> **WHY:** Smaller images mean faster deployments, less storage cost, and fewer vulnerabilities. The production image should contain **only what's needed to run** -- nothing more.

---

## .dockerignore

### What It Does

When you run `docker build`, Docker sends the entire directory (the **build context**) to the daemon. A `.dockerignore` file tells Docker which files to exclude from the build context.

### Why It Matters

Without `.dockerignore`:
- `node_modules/` (500MB+) gets sent to the daemon, even though `RUN pnpm install` creates fresh ones
- `.git/` history gets sent unnecessarily
- `.env` files with secrets could end up in the image
- Build context transfer takes much longer

### What to Exclude

```
node_modules          # Reinstalled in the image
dist                  # Rebuilt in the image
.git                  # Not needed for build
.env                  # NEVER put secrets in images
.env.*                # Exclude all env variants
!.env.example         # But keep the template
*.log                 # Not needed
.DS_Store             # macOS artifacts
.vscode               # Editor configs
.idea                 # Editor configs
```

> **GOTCHA:** If you don't have a `.dockerignore`, `COPY . .` copies `node_modules` into the image, which then gets overwritten by `RUN pnpm install`. You've wasted time copying 500MB for nothing.

---

## Docker Security Essentials

### Run as Non-Root User

By default, containers run as root. This is a security risk -- if an attacker escapes the container, they have root access on the host.

```dockerfile
# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Switch to that user for all subsequent commands
USER appuser
```

> **WHY:** The principle of least privilege. Your Node.js API doesn't need root access to serve HTTP requests.

### Never Put Secrets in Images

```dockerfile
# WRONG: Secret baked into the image forever (visible in docker history)
COPY .env .
ENV DATABASE_URL=postgres://user:password@host/db

# RIGHT: Pass secrets at runtime
# docker run -e DATABASE_URL=... my-app
# Or use docker compose with env_file
```

Even if you delete a `.env` file in a later layer, it still exists in the image's layer history. **Layers are immutable.**

### Image Scanning

Docker images can contain known vulnerabilities in their base OS packages or dependencies.

```bash
# Docker Scout (built into Docker Desktop)
docker scout quickview my-app

# Scan for vulnerabilities
docker scout cves my-app
```

Use official images, keep them updated, and prefer Alpine-based images (smaller attack surface).

---

## Troubleshooting and Debugging

### Essential Commands

| Command                         | What It Does                                    |
|---------------------------------|-------------------------------------------------|
| `docker logs <container>`       | View stdout/stderr from the container           |
| `docker logs -f <container>`    | Follow logs in real-time (like tail -f)         |
| `docker exec -it <container> sh`| Open a shell inside a running container         |
| `docker inspect <container>`    | Detailed JSON info (networking, mounts, config) |
| `docker stats`                  | Live CPU/memory/network usage                   |
| `docker system df`              | Show disk usage by images, containers, volumes  |

### Common Errors and Fixes

**"pnpm: not found" in Alpine**

Alpine Linux doesn't include pnpm by default. You need corepack:

```dockerfile
RUN corepack enable
```

Make sure this runs BEFORE any `pnpm install` command.

**Port conflicts: "bind: address already in use"**

Something is already listening on that port:

```bash
# Find what's using port 3000
lsof -i :3000

# Or run on a different port
docker run -p 3001:3000 my-app
```

**Build cache not working (rebuilding everything)**

Check your instruction order. If `COPY . .` comes before `RUN pnpm install`, any source change invalidates the install cache. See the layer caching section above.

**Volume permission errors**

When mounting host directories, the container user might not have permission:

```bash
# Check the user inside the container
docker exec my-container whoami

# Fix: match UID/GID or adjust permissions
docker run -u $(id -u):$(id -g) -v ./data:/app/data my-app
```

**Container exits immediately**

The process inside crashed or completed. Check the logs:

```bash
docker logs <container>

# Run interactively to debug
docker run -it my-app sh
```

**Image is unexpectedly large**

Check which layers are taking space:

```bash
docker history my-app --human --no-trunc
```

Common culprits: no `.dockerignore`, dev dependencies installed, build tools left in final image (use multi-stage).

**"COPY failed: file not found"**

The file doesn't exist in the build context (the directory you're building from), or it's excluded by `.dockerignore`.

```bash
# Check what's in the build context
# (temporarily remove .dockerignore to debug)
docker build --no-cache -t debug .
```

---

## Key Takeaways

1. **Images are blueprints, containers are instances** -- build once, run many times
2. **Layer order matters** -- put rarely-changing instructions first for better caching
3. **Multi-stage builds** -- keep production images small and secure
4. **Never put secrets in images** -- use runtime environment variables
5. **Run as non-root** -- principle of least privilege
6. **.dockerignore** -- exclude node_modules, .git, .env from build context
7. **Alpine images** -- smaller base means faster pulls and fewer vulnerabilities

---

*Phase 3 - Containerization | Docker Fundamentals*
