# Phase 3: Containerization -- Phase Gate Checklist

Complete all three checkpoints before moving to Phase 4. Each checkpoint maps to a requirement and has a "Prove It" section with commands you should be able to run from memory.

---

## Checkpoint 1: Docker Fundamentals (DEPL-03)

**Requirement:** Learner can write Dockerfiles for React (multi-stage build) and Node apps.

### Knowledge Check

- [ ] Can you explain why a multi-stage build reduces image size by ~95%?
- [ ] Can you describe Docker layer caching and why COPY package.json comes before COPY . .?
- [ ] Can you explain the purpose of .dockerignore?
- [ ] Can you explain why running as non-root user matters in production containers?
- [ ] Can you describe the difference between EXPOSE and publishing a port (-p)?

### Prove It

```bash
# Build the frontend image and check its size (~40MB, not 800MB)
cd app
docker build -t ecommerce-frontend .
docker images ecommerce-frontend --format "{{.Size}}"

# Build the API image
pnpm build:server  # from project root first
cd app
docker build -t ecommerce-api -f Dockerfile.api .
docker images ecommerce-api --format "{{.Size}}"

# Verify non-root user in API container
docker run --rm ecommerce-api whoami
# Expected output: appuser (NOT root)

# Demonstrate layer caching: change a source file, rebuild, observe cached layers
docker build -t ecommerce-frontend .
# You should see "CACHED" for the pnpm install layer
```

### Pass Criteria

- [ ] Frontend image is under 60MB (multi-stage working)
- [ ] API image runs as non-root user (appuser)
- [ ] Rebuild after code-only change reuses the dependency install layer (CACHED)

---

## Checkpoint 2: Docker Compose (DEPL-04)

**Requirement:** Learner can use Docker Compose to run a multi-service stack locally (app + db + redis).

### Knowledge Check

- [ ] Can you explain the difference between `depends_on` and `depends_on: condition: service_healthy`?
- [ ] Can you describe what health checks do and why they matter for startup ordering?
- [ ] Can you explain the dev vs prod Compose override pattern?
- [ ] Can you explain how Docker Compose DNS works (service name = hostname)?
- [ ] Can you describe the .env + .env.example pattern for environment variables?

### Prove It

```bash
cd app

# Start the full stack
docker compose up -d

# Verify all 4 services are running
docker compose ps
# Expected: frontend, api, db, redis -- all "Up" or "healthy"

# Check health status
docker compose ps --format "table {{.Name}}\t{{.Status}}"
# db and redis should show "(healthy)"

# Verify frontend serves the React app
curl -s http://localhost | head -5
# Should return HTML with the React app

# Verify API is reachable through nginx reverse proxy
curl -s http://localhost/api/health
# Should return a response from the Node.js server

# Check logs for a specific service
docker compose logs api --tail 10

# Run with production overrides
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Clean up
docker compose down
```

### Pass Criteria

- [ ] `docker compose up` starts all 4 services without errors
- [ ] Database and Redis show healthy status
- [ ] Frontend is accessible at http://localhost
- [ ] API is reachable through the nginx reverse proxy at /api/
- [ ] You can explain why `docker compose down -v` is different from `docker compose down`

---

## Checkpoint 3: AWS ECR (DEPL-05)

**Requirement:** Learner can push Docker images to AWS ECR.

### Knowledge Check

- [ ] Can you explain why ECR requires authentication and how the auth flow works?
- [ ] Can you describe the ECR authentication token expiry (12 hours) and what happens when it expires?
- [ ] Can you explain the tagging strategy: commit SHA for traceability + latest for convenience?
- [ ] Can you describe what lifecycle policies do and why they matter for cost control?
- [ ] Can you explain why `--force` is needed when deleting a repository with images?

### Prove It

```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-southeast-1
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
COMMIT_SHA=$(git rev-parse --short HEAD)

# Create a repository
aws ecr create-repository --repository-name ecommerce-frontend --region $AWS_REGION

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

# Tag with commit SHA and latest
docker tag ecommerce-frontend:latest $ECR_URI/ecommerce-frontend:$COMMIT_SHA
docker tag ecommerce-frontend:latest $ECR_URI/ecommerce-frontend:latest

# Push both tags
docker push $ECR_URI/ecommerce-frontend:$COMMIT_SHA
docker push $ECR_URI/ecommerce-frontend:latest

# Verify image exists in ECR
aws ecr describe-images --repository-name ecommerce-frontend --region $AWS_REGION

# Apply a lifecycle policy
aws ecr put-lifecycle-policy \
  --repository-name ecommerce-frontend \
  --region $AWS_REGION \
  --lifecycle-policy-text '{
    "rules": [
      {
        "rulePriority": 1,
        "description": "Expire untagged after 7 days",
        "selection": {
          "tagStatus": "untagged",
          "countType": "sinceImagePushed",
          "countUnit": "days",
          "countNumber": 7
        },
        "action": { "type": "expire" }
      }
    ]
  }'

# Verify policy
aws ecr get-lifecycle-policy --repository-name ecommerce-frontend --region $AWS_REGION

# Clean up
aws ecr delete-repository --repository-name ecommerce-frontend --force --region $AWS_REGION
```

### Pass Criteria

- [ ] Can authenticate Docker to ECR without looking up the command
- [ ] Can tag and push an image with both commit SHA and latest tags
- [ ] Can verify the image exists in ECR via CLI
- [ ] Can apply a lifecycle policy and explain what it does
- [ ] Can tear down ECR repos using the teardown script

---

## Phase Gate Summary

| Checkpoint | Requirement | Status |
|-----------|-------------|--------|
| Docker Fundamentals | DEPL-03 | [ ] |
| Docker Compose | DEPL-04 | [ ] |
| AWS ECR | DEPL-05 | [ ] |

**All three checkpoints must pass before starting Phase 4 (CI/CD).**

Phase 4 automates everything you've done manually in Phase 3:
- Building Docker images -> GitHub Actions builds on every push
- Pushing to ECR -> CI/CD pipeline pushes automatically
- Running Compose -> Deployment to ECS/Fargate (Phase 6)

---

*Phase: 03-containerization*
