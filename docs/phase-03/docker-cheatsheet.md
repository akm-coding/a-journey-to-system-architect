# Docker Cheatsheet

## Build Commands

```bash
# Build image from Dockerfile in current directory
docker build -t <name>:<tag> .

# Build from a specific Dockerfile
docker build -f Dockerfile.api -t my-api .

# Build with no cache (force full rebuild)
docker build --no-cache -t <name> .

# Build with build arguments
docker build --build-arg NODE_ENV=production -t <name> .

# Build for a specific platform
docker buildx build --platform linux/amd64 -t <name> .
```

## Container Commands

```bash
# Run container (foreground)
docker run <image>

# Run container (background/detached)
docker run -d <image>

# Run with port mapping (host:container)
docker run -p 8080:80 <image>

# Run with environment variable
docker run -e DATABASE_URL=postgres://... <image>

# Run with env file
docker run --env-file .env <image>

# Run with volume mount (host:container)
docker run -v ./data:/app/data <image>

# Run with name
docker run --name my-app <image>

# Run and remove on exit
docker run --rm <image>

# Run interactive shell
docker run -it <image> sh

# List running containers
docker ps

# List ALL containers (including stopped)
docker ps -a

# Stop a container
docker stop <container>

# Remove a container
docker rm <container>

# Stop and remove
docker rm -f <container>

# View container logs
docker logs <container>

# Follow logs in real-time
docker logs -f <container>

# Open shell in running container
docker exec -it <container> sh

# View container details (JSON)
docker inspect <container>

# Live resource usage
docker stats
```

## Image Commands

```bash
# List images
docker images

# Remove an image
docker rmi <image>

# Tag an image
docker tag <image> <registry>/<name>:<tag>

# View image layer history
docker history <image>

# Pull image from registry
docker pull <image>:<tag>

# Push image to registry
docker push <registry>/<name>:<tag>

# Remove dangling images
docker image prune

# Remove ALL unused images
docker image prune -a
```

## System Commands

```bash
# Show disk usage
docker system df

# Clean up everything unused (images, containers, networks)
docker system prune

# Nuclear option: remove ALL unused data including volumes
docker system prune -a --volumes
```

## Dockerfile Instructions

| Instruction  | Purpose                                | Example                                      |
|-------------|----------------------------------------|----------------------------------------------|
| `FROM`      | Base image                             | `FROM node:20-alpine`                        |
| `AS`        | Name a build stage                     | `FROM node:20-alpine AS build`               |
| `WORKDIR`   | Set working directory                  | `WORKDIR /app`                               |
| `COPY`      | Copy files from host/stage             | `COPY package.json .`                        |
| `COPY --from` | Copy from another stage              | `COPY --from=build /app/dist ./dist`         |
| `RUN`       | Execute command during build           | `RUN pnpm install`                           |
| `ENV`       | Set runtime environment variable       | `ENV NODE_ENV=production`                    |
| `ARG`       | Set build-time variable                | `ARG API_URL`                                |
| `EXPOSE`    | Document container port (no effect)    | `EXPOSE 3000`                                |
| `CMD`       | Default command on start               | `CMD ["node", "index.js"]`                   |
| `ENTRYPOINT`| Fixed command (CMD becomes arguments)  | `ENTRYPOINT ["node"]`                        |
| `USER`      | Switch to non-root user                | `USER appuser`                               |
| `VOLUME`    | Declare mount point                    | `VOLUME /data`                               |
| `HEALTHCHECK`| Container health check               | `HEALTHCHECK CMD curl -f http://localhost/`  |

## Multi-Stage Build Pattern

```dockerfile
# ---- Stage 1: Build ----
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies (cached unless package.json changes)
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile

# Build application
COPY . .
RUN pnpm build

# ---- Stage 2: Production ----
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Layer Caching Best Practices

```dockerfile
# GOOD: deps cached unless package.json changes
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .

# BAD: deps reinstalled on every code change
COPY . .
RUN pnpm install
```

**Rule:** Put instructions that change less frequently earlier in the Dockerfile.

## Common Troubleshooting

| Problem                          | Command / Fix                                     |
|----------------------------------|---------------------------------------------------|
| Container won't start            | `docker logs <container>`                         |
| Debug inside container           | `docker exec -it <container> sh`                  |
| Port already in use              | `lsof -i :<port>` then kill or use different port |
| Image unexpectedly large         | `docker history <image> --human`                  |
| Build cache not working          | Check `COPY` order; deps before source            |
| "pnpm not found" in Alpine       | Add `RUN corepack enable` before pnpm commands    |
| COPY file not found              | Check `.dockerignore` isn't excluding it           |
| Permission denied in container   | Check `USER` and file ownership                   |
| Volume mount empty               | Host path must be absolute or use named volume     |
| Can't connect to other container | Use Docker network or Compose service names        |

## Useful Flags Reference

```bash
# Format output as table
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Filter containers by name
docker ps -f name=my-app

# Remove all stopped containers
docker container prune

# Copy file from container to host
docker cp <container>:/app/file.txt ./file.txt

# View real-time events
docker events
```

---

*Phase 3 - Containerization | Docker Quick Reference*
