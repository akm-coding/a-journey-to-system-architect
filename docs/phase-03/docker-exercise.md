# Docker Hands-On Exercise: From Naive to Optimized

## Prerequisites

- Docker Desktop installed and running (`docker --version`)
- The e-commerce app source code in `app/`
- Terminal open in the `app/` directory

---

## Exercise 1: The Naive Dockerfile (Feel the Pain)

### Step 1: Create a naive single-stage Dockerfile

Create a file called `Dockerfile.naive` in the `app/` directory:

```dockerfile
# Naive approach: everything in one stage
FROM node:20-alpine

WORKDIR /app

# Copy everything (including node_modules if present!)
COPY . .

# Install all dependencies (including devDependencies)
RUN corepack enable && pnpm install

# Build the client
RUN pnpm build:client

# Serve with a simple Node HTTP server
RUN pnpm add serve

EXPOSE 3000
CMD ["npx", "serve", "dist/client", "-l", "3000"]
```

### Step 2: Build and time it

```bash
# Time the build
time docker build -f Dockerfile.naive -t ecommerce-naive .
```

Note the build time. First builds are always slow due to downloading base images and installing dependencies.

### Step 3: Check the image size

```bash
docker images ecommerce-naive
```

You should see something like:

```
REPOSITORY          TAG       SIZE
ecommerce-naive     latest    ~800MB - 1.2GB
```

> **That's 800MB+ for a React app that compiles to ~5MB of static files.** The image contains Node.js, all node_modules (including devDependencies), TypeScript source, build tools -- none of which are needed to serve static HTML/CSS/JS.

### Step 4: Inspect the layers

```bash
docker history ecommerce-naive --human
```

Notice which layers are largest. The `pnpm install` and `COPY . .` layers dominate.

---

## Exercise 2: Identify the Problems

Before looking at the fix, list what's wrong:

1. **Huge image size** -- Node.js runtime and all deps are in the final image, but we only need static files
2. **Dev dependencies in production** -- TypeScript, Vite, and all `devDependencies` are present
3. **Security risk** -- Build tools and package managers increase attack surface
4. **Slow rebuilds** -- `COPY . .` is before `pnpm install`, so ANY file change invalidates the dependency cache
5. **No .dockerignore** -- `node_modules` from your host gets sent to Docker daemon (slow context transfer)

---

## Exercise 3: Refactor to Multi-Stage

### Step 1: Use the optimized Dockerfile

The `app/Dockerfile` uses multi-stage builds to solve every problem above. Open it and read the comments explaining each instruction.

Key differences from the naive approach:
- **Stage 1 (build):** Installs deps and builds. Package.json copied first for layer caching.
- **Stage 2 (production):** Only nginx + the compiled static files. No Node.js, no node_modules, no source code.

### Step 2: Build and time the multi-stage version

```bash
# Time the optimized build
time docker build -t ecommerce-frontend .
```

### Step 3: Compare image sizes

```bash
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep ecommerce
```

Expected comparison:

| Image               | Size      |
|---------------------|-----------|
| ecommerce-naive     | ~800MB+   |
| ecommerce-frontend  | ~40-50MB  |

> **That's a 95% reduction.** The production image contains only nginx (~25MB) and your built static assets (~5MB). No Node.js, no node_modules, no TypeScript, no build tools.

### Step 4: Verify the optimized image runs

```bash
# Run the frontend container
docker run -d --name frontend-test -p 8080:80 ecommerce-frontend

# Verify it serves the app
curl -s http://localhost:8080 | head -20

# You should see HTML content with your React app's root div
```

Clean up this test container:

```bash
docker stop frontend-test && docker rm frontend-test
```

---

## Exercise 4: Layer Caching Demo

### Step 1: Demonstrate poor caching (bad pattern)

The naive Dockerfile copies everything before installing deps:

```dockerfile
COPY . .              # <-- changes on ANY file edit
RUN pnpm install      # <-- cache busted, reinstalls every time
```

### Step 2: Demonstrate good caching (optimized pattern)

The multi-stage Dockerfile copies dependency files first:

```dockerfile
COPY package.json pnpm-lock.yaml ./   # <-- only changes when deps change
RUN pnpm install --frozen-lockfile     # <-- cached on code-only changes!
COPY . .                               # <-- source code changes trigger from here
RUN pnpm build:client                  # <-- only this rebuilds
```

### Step 3: Test caching in action

```bash
# First build (cold, everything runs)
time docker build -t ecommerce-frontend .

# Make a small source code change
echo "// test change" >> src/client/main.tsx

# Rebuild (should be fast -- deps layer is cached)
time docker build -t ecommerce-frontend .
```

Watch the output. You should see:
- `COPY package.json pnpm-lock.yaml` -- **CACHED**
- `RUN corepack enable && pnpm install` -- **CACHED**
- `COPY . .` -- not cached (source changed)
- `RUN pnpm build:client` -- not cached (depends on changed layer)

The install step is skipped entirely because `package.json` didn't change. This saves 30-60 seconds on every rebuild.

> **Undo the test change:** `git checkout src/client/main.tsx`

### Step 4: Test what happens when deps change

```bash
# Simulate a dependency change (don't actually commit this)
# Just add a comment to package.json to bust the cache
echo "" >> package.json

# Rebuild -- install step will NOT be cached this time
time docker build -t ecommerce-frontend .

# Undo the change
git checkout package.json
```

Now the install step runs because the `COPY package.json` layer changed. This is the correct behavior -- you only pay the install cost when dependencies actually change.

---

## Exercise 5: Understanding the API Dockerfile

The API Dockerfile (`app/Dockerfile.api`) is provided pre-written. Open it and study each instruction.

### Key things to notice

1. **No multi-stage needed**: The API runs on Node.js, so we need the Node runtime in the final image. Multi-stage wouldn't help here.

2. **Production-only dependencies**: `pnpm install --frozen-lockfile --prod` skips devDependencies (TypeScript, tsx, etc.)

3. **Pre-built server**: The Dockerfile expects `dist/server/` to already exist. You must run `pnpm build:server` on your host before building the Docker image.

4. **Non-root user**: The `USER appuser` instruction is a security best practice. The Node process runs with minimal privileges.

5. **Drizzle schema files**: `COPY src/server/db ./src/server/db` is needed because Drizzle reads schema files at runtime for migrations.

### Build the API image

```bash
# First, build the server code on your host
pnpm build:server

# Then build the Docker image
docker build -f Dockerfile.api -t ecommerce-api .
```

### Test the API image

```bash
# Run (it will fail to connect to PostgreSQL -- that's expected)
# We just want to verify the image starts
docker run --rm -e DATABASE_URL="postgres://test:test@host:5432/test" ecommerce-api

# You should see a connection error, NOT a "file not found" or "module not found" error
# That confirms the image is built correctly -- it just needs a database
```

---

## Exercise 6: Verification Checklist

Run these commands to verify everything is built correctly:

```bash
# Both images exist
docker images | grep ecommerce

# Frontend serves content
docker run -d --name verify-frontend -p 8080:80 ecommerce-frontend
curl -s http://localhost:8080 | grep -o "<div id=\"root\">" && echo "Frontend OK"
docker stop verify-frontend && docker rm verify-frontend

# Check image sizes
echo "=== Image Sizes ==="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "ecommerce|REPOSITORY"
```

Expected results:
- `ecommerce-frontend`: ~40-50MB (nginx + static files)
- `ecommerce-api`: ~200-250MB (Node.js + production deps)
- `ecommerce-naive`: ~800MB+ (everything including dev deps)

---

## Cleanup

Remove the images and containers created during this exercise:

```bash
# Remove test containers (if any are still running)
docker stop frontend-test verify-frontend 2>/dev/null
docker rm frontend-test verify-frontend 2>/dev/null

# Remove images
docker rmi ecommerce-naive ecommerce-frontend ecommerce-api 2>/dev/null

# Clean up dangling images and build cache
docker system prune -f

# See what space was freed
docker system df
```

Remove the naive Dockerfile (we don't need it anymore):

```bash
rm Dockerfile.naive
```

---

## Key Lessons

| Lesson | What You Proved |
|--------|-----------------|
| Single-stage is wasteful | 800MB+ image for a 5MB app |
| Multi-stage cuts 95% | ~40MB with only what's needed |
| Layer order matters | Deps cached when package.json unchanged |
| .dockerignore is essential | Prevents sending 500MB+ to daemon |
| Non-root user | Security best practice costs nothing |

---

*Phase 3 - Containerization | Docker Hands-On Exercise*
