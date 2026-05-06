# =============================================================================
# Multi-Stage Dockerfile: React Frontend
# =============================================================================
# Stage 1 (build): Install deps + build the React app with Vite
# Stage 2 (production): Serve static files with nginx
#
# Why multi-stage?
#   - Build stage: ~800MB (Node, npm, dev deps, source code)
#   - Production stage: ~40MB (nginx + compiled static files)
#   - 95% smaller, no build tools in production, smaller attack surface
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
# Start from Node 20 on Alpine Linux (small base image ~180MB)
FROM node:20-alpine AS build

# Set working directory inside the container
WORKDIR /app

# Copy dependency manifests FIRST (for layer caching)
# This layer only changes when dependencies change, so pnpm install
# is cached on code-only changes -- saves 30-60 seconds per rebuild
COPY package.json pnpm-lock.yaml ./

# Enable pnpm via corepack (Alpine doesn't include pnpm by default)
# Then install dependencies with frozen lockfile (no lockfile updates)
RUN corepack enable && pnpm install --frozen-lockfile

# NOW copy source code (this layer changes on every code edit)
COPY . .

# Build the React client (Vite outputs to dist/client/)
RUN pnpm build:client

# ---------------------------------------------------------------------------
# Stage 2: Production
# ---------------------------------------------------------------------------
# Start fresh from nginx on Alpine (~25MB)
# Everything from Stage 1 is discarded except what we explicitly COPY
FROM nginx:alpine

# Copy our custom nginx config (SPA routing + API reverse proxy + gzip)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy ONLY the built static files from the build stage
# This is the key multi-stage benefit: we get the build output
# without carrying over Node.js, node_modules, or source code
COPY --from=build /app/dist/client /usr/share/nginx/html

# Document that this container serves on port 80
# Note: EXPOSE doesn't actually publish the port -- it's documentation
# You still need -p 8080:80 when running the container
EXPOSE 80

# Start nginx in the foreground (required for Docker)
# By default nginx daemonizes, which would cause the container to exit
CMD ["nginx", "-g", "daemon off;"]
