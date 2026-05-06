# Amazon ECR (Elastic Container Registry) Study Guide

## What is ECR?

Amazon ECR is AWS's **managed Docker container registry**. Think of it as a private Docker Hub that lives inside your AWS account. You push Docker images to ECR, and later AWS services (ECS, Fargate, Lambda) pull those images to run your containers.

> **WHY:** You need a registry to store your Docker images somewhere that your production infrastructure can access. Building an image on your laptop is only half the story -- you need to **push** it somewhere so servers can **pull** it.

### ECR vs Docker Hub

| Feature | Docker Hub | ECR |
|---------|-----------|-----|
| **Access control** | Username/password | IAM policies (same as rest of AWS) |
| **Pull rate limits** | 100 pulls/6hr (free) | No limits with AWS auth |
| **Default visibility** | Public | Private |
| **AWS integration** | Manual config | Native (ECS, Fargate, CodeBuild) |
| **Cost** | Free tier limited | $0.10/GB/month storage |
| **Lifecycle policies** | Manual cleanup | Automated image expiry rules |

> **WHY ECR over Docker Hub:** When you deploy to ECS/Fargate in Phase 6, ECR "just works" -- no extra credential management, no pull rate limits, and IAM controls who can push/pull images. Docker Hub would require storing Docker Hub credentials in AWS Secrets Manager, adding unnecessary complexity.

---

## Core Concepts

### Registry, Repository, and Image

ECR has a three-level hierarchy:

```
Registry (your AWS account)
  └── Repository: ecommerce-frontend
  │     ├── Image: ecommerce-frontend:abc123f (commit SHA)
  │     ├── Image: ecommerce-frontend:latest
  │     └── Image: ecommerce-frontend:def456g
  └── Repository: ecommerce-api
        ├── Image: ecommerce-api:abc123f
        └── Image: ecommerce-api:latest
```

- **Registry:** One per AWS account per region. Your registry URL is: `{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com`
- **Repository:** One per application/service. Like a folder that holds all versions of one image.
- **Image:** A specific version of your app, identified by a tag (e.g., `latest`, `abc123f`).

> **GOTCHA:** One repository = one image type. Don't mix frontend and API images in the same repository. Create `ecommerce-frontend` and `ecommerce-api` as separate repos.

---

## Authentication Flow

ECR is private by default. Your Docker CLI needs credentials to push or pull. Here's how it works:

### The Authentication Command

```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

### What's happening step by step:

1. `aws ecr get-login-password` -- Calls AWS to generate a **temporary authentication token** using your IAM credentials
2. The token is piped (`|`) to `docker login` via `--password-stdin`
3. `--username AWS` -- Always "AWS" for ECR (not your IAM username)
4. Docker stores the credentials so subsequent `docker push`/`docker pull` commands work

### Why This Two-Step Process?

Docker CLI was built for Docker Hub's username/password auth. ECR uses IAM. The `get-login-password` command **bridges** the gap -- it translates your IAM credentials into a Docker-compatible token.

> **GOTCHA: 12-Hour Expiry.** The token expires after 12 hours. If you authenticated yesterday and try to push today, you'll get "no basic auth credentials" error. **Re-run the auth command** before pushing.

### Verifying Authentication

After running the login command, you should see:

```
Login Succeeded
```

If you see errors, check:
- AWS CLI is configured (`aws sts get-caller-identity` should return your account)
- Your IAM user has ECR permissions (at minimum: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`)
- The region is correct

---

## Repository Structure

### Creating a Repository

```bash
aws ecr create-repository \
  --repository-name ecommerce-frontend \
  --region $AWS_REGION
```

This creates an empty repository. The response includes the repository URI:

```json
{
  "repository": {
    "repositoryUri": "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-frontend"
  }
}
```

You use this URI when tagging and pushing images.

### One Repository Per Service

For our e-commerce app, we create two repositories:
- `ecommerce-frontend` -- Holds all versions of the React/nginx image
- `ecommerce-api` -- Holds all versions of the Node.js API image

This maps 1:1 to our Dockerfiles:
- `app/Dockerfile` -> `ecommerce-frontend` repository
- `app/Dockerfile.api` -> `ecommerce-api` repository

---

## Tagging Strategy

Tags are how you identify specific versions of an image. Getting tagging right is critical for production deployments.

### Our Two-Tag Strategy

For every push, we apply **two tags**:

1. **Git commit SHA** (e.g., `abc123f`) -- For traceability
2. **`latest`** -- For convenience

```bash
# Tag with commit SHA
docker tag ecommerce-frontend:latest \
  $ECR_URI/ecommerce-frontend:$(git rev-parse --short HEAD)

# Tag with latest
docker tag ecommerce-frontend:latest \
  $ECR_URI/ecommerce-frontend:latest
```

### Why Commit SHA?

The commit SHA creates a **direct link between your code and your running container**. When something breaks in production, you can:

1. Check which image tag is running (`abc123f`)
2. Run `git log abc123f` to see exactly what code is in that image
3. Run `git diff abc123f HEAD` to see what changed since that deploy

Without commit SHA tags, you're guessing which version is deployed.

### Why `latest` Is Dangerous Alone

> **GOTCHA:** Never rely on `latest` as your only tag in production. Here's why:

- `latest` is a **moving pointer** -- it always points to the most recently pushed image
- If you deploy "latest" and something breaks, you can't roll back to "the previous latest" -- it's been overwritten
- Two developers push at the same time? `latest` points to whoever pushed last
- `latest` doesn't tell you WHAT code is inside the image

`latest` is useful for local development ("give me the newest version") but commit SHA tags are essential for production deployments.

---

## Lifecycle Policies

Without lifecycle policies, every image you push to ECR stays **forever**. Over months of development, you'll accumulate hundreds of images and pay storage costs for images you'll never use again.

### What Lifecycle Policies Do

Lifecycle policies are **automated cleanup rules** that delete images based on criteria you define. They run periodically (roughly every 24 hours) and remove images matching your rules.

### Our Lifecycle Policy

We use two rules:

| Rule | Priority | What It Does | Why |
|------|----------|-------------|-----|
| Expire untagged | 1 | Delete untagged images after 7 days | Untagged images are usually intermediate layers or superseded builds |
| Keep last 10 | 2 | Keep only the last 10 tagged images | Limits storage while keeping enough history for rollbacks |

### The Policy JSON

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

### Understanding the Fields

- **`rulePriority`**: Lower number = evaluated first. Rules are evaluated in priority order.
- **`tagStatus`**: `"untagged"` (no tags at all) or `"tagged"` (has at least one tag matching `tagPrefixList`).
- **`countType`**: `"sinceImagePushed"` (time-based) or `"imageCountMoreThan"` (count-based).
- **`action`**: Always `"expire"` (delete the image).

### Applying a Lifecycle Policy

```bash
aws ecr put-lifecycle-policy \
  --repository-name ecommerce-frontend \
  --lifecycle-policy-text file://lifecycle-policy.json
```

### Verifying the Policy

```bash
aws ecr get-lifecycle-policy --repository-name ecommerce-frontend
```

> **WHY:** Lifecycle policies are a cost control tool. For a learning project, the savings are minimal. But in production with CI/CD pushing images on every commit, you can accumulate hundreds of images per month. At $0.10/GB, a 200MB image pushed 100 times = $2/month per repository. Lifecycle policies keep this under control automatically.

---

## The Complete Push Workflow

Here's the full flow from building an image to having it in ECR:

```
Local Machine                          AWS ECR
─────────────                          ──────────
1. docker build -t myapp .  ──>  (image exists locally)
2. aws ecr get-login-password   ──>  (Docker authenticated to ECR)
3. docker tag myapp ECR_URI/myapp:sha  ──>  (image tagged with ECR URI)
4. docker push ECR_URI/myapp:sha  ──>  Image stored in ECR repository
5. aws ecr describe-images    <──  Verify image exists
```

### Step by Step

1. **Build** the image locally using your Dockerfile
2. **Authenticate** Docker to ECR (get temporary token)
3. **Tag** the local image with the ECR repository URI + version tag
4. **Push** the tagged image to ECR
5. **Verify** the image arrived by listing images in the repository

> **WHY:** This workflow is exactly what CI/CD does automatically in Phase 4. Understanding it manually first means you can debug CI/CD pipeline failures.

---

## Cost Awareness

ECR pricing is straightforward:

| Component | Cost | Notes |
|-----------|------|-------|
| **Storage** | $0.10/GB/month | Per image layer, deduplicated |
| **Data transfer OUT** | Standard AWS rates | Free within same region to ECS |
| **Data transfer IN** | Free | Pushing images is always free |

### Cost Tips

- **Use lifecycle policies** to automatically clean up old images
- **Multi-stage builds** reduce image size (40MB vs 800MB = 95% less storage cost)
- **Layer deduplication** means shared base layers (like `node:20-alpine`) are stored only once
- **Same-region pulls are free** -- keep ECR and ECS in the same region

For a learning project, ECR costs will be pennies. But these habits matter at scale.

---

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `no basic auth credentials` | Auth token expired or never authenticated | Re-run `aws ecr get-login-password \| docker login` |
| `repository does not exist` | Typo in repo name or wrong region | Check `aws ecr describe-repositories` output |
| `denied: Your authorization token has expired` | Token is older than 12 hours | Re-authenticate with `get-login-password` |
| `image not found` | Trying to push untagged image | Tag with ECR URI first: `docker tag local:tag ecr-uri:tag` |
| `requested access to the resource is denied` | IAM permissions missing | Add ECR push permissions to your IAM user |

---

## Key Takeaways

1. **ECR is a private Docker registry** managed by AWS, integrated with IAM
2. **Authenticate before pushing** -- tokens expire after 12 hours
3. **One repository per service** -- ecommerce-frontend and ecommerce-api are separate repos
4. **Tag with commit SHA** for traceability, not just `latest`
5. **Lifecycle policies** automate image cleanup and control costs
6. **This manual workflow becomes automated** in Phase 4 (CI/CD)

---

*Next: [ECR Hands-On Exercise](./ecr-exercise.md) -- Create repos, authenticate, push images, apply lifecycle policies*
