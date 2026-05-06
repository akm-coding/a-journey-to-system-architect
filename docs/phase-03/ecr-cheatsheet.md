# ECR Cheatsheet

Quick reference for AWS ECR commands. Copy-paste ready with variable placeholders.

---

## Setup Variables

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-southeast-1
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
REPO_NAME=ecommerce-frontend
COMMIT_SHA=$(git rev-parse --short HEAD)
```

---

## Authentication

```bash
# Authenticate Docker to ECR (valid 12 hours)
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI
```

---

## Repository Management

```bash
# Create a repository
aws ecr create-repository --repository-name $REPO_NAME --region $AWS_REGION

# List all repositories
aws ecr describe-repositories --region $AWS_REGION \
  --query "repositories[*].[repositoryName,repositoryUri]" --output table

# Delete a repository (with all images)
aws ecr delete-repository --repository-name $REPO_NAME --force --region $AWS_REGION
```

---

## Tag and Push Workflow

```bash
# 1. Build the image
docker build -t $REPO_NAME .

# 2. Tag with commit SHA
docker tag $REPO_NAME:latest $ECR_URI/$REPO_NAME:$COMMIT_SHA

# 3. Tag with latest
docker tag $REPO_NAME:latest $ECR_URI/$REPO_NAME:latest

# 4. Push both tags
docker push $ECR_URI/$REPO_NAME:$COMMIT_SHA
docker push $ECR_URI/$REPO_NAME:latest
```

### One-Liner Push (both tags)

```bash
docker push $ECR_URI/$REPO_NAME:$COMMIT_SHA && docker push $ECR_URI/$REPO_NAME:latest
```

---

## Image Management

```bash
# List images in a repository
aws ecr describe-images --repository-name $REPO_NAME --region $AWS_REGION \
  --query "imageDetails[*].[imageTags,imageSizeInBytes,imagePushedAt]" --output table

# List image tags only
aws ecr list-images --repository-name $REPO_NAME --region $AWS_REGION \
  --query "imageIds[*].imageTag" --output text

# Get details for a specific image tag
aws ecr describe-images --repository-name $REPO_NAME --region $AWS_REGION \
  --image-ids imageTag=$COMMIT_SHA

# Delete a specific image
aws ecr batch-delete-image --repository-name $REPO_NAME --region $AWS_REGION \
  --image-ids imageTag=$COMMIT_SHA
```

---

## Lifecycle Policies

```bash
# Apply a lifecycle policy from a JSON file
aws ecr put-lifecycle-policy \
  --repository-name $REPO_NAME \
  --lifecycle-policy-text file://lifecycle-policy.json \
  --region $AWS_REGION

# View current lifecycle policy
aws ecr get-lifecycle-policy --repository-name $REPO_NAME --region $AWS_REGION \
  --query "lifecyclePolicyText" --output text | python3 -m json.tool

# Preview what lifecycle would delete (dry run)
aws ecr get-lifecycle-policy-preview --repository-name $REPO_NAME --region $AWS_REGION

# Remove lifecycle policy
aws ecr delete-lifecycle-policy --repository-name $REPO_NAME --region $AWS_REGION
```

### Inline Lifecycle Policy (no file needed)

```bash
aws ecr put-lifecycle-policy \
  --repository-name $REPO_NAME \
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
      },
      {
        "rulePriority": 2,
        "description": "Keep last 10 tagged",
        "selection": {
          "tagStatus": "tagged",
          "tagPrefixList": ["latest"],
          "countType": "imageCountMoreThan",
          "countNumber": 10
        },
        "action": { "type": "expire" }
      }
    ]
  }'
```

---

## Pull an Image

```bash
# Pull from ECR (useful for testing or debugging)
docker pull $ECR_URI/$REPO_NAME:$COMMIT_SHA
```

---

## Common Errors

| Error | Fix |
|-------|-----|
| `no basic auth credentials` | Re-run `aws ecr get-login-password \| docker login` (token expired) |
| `repository does not exist` | Check repo name and region: `aws ecr describe-repositories` |
| `authorization token has expired` | Re-authenticate (tokens last 12 hours) |
| `RepositoryAlreadyExistsException` | Repo exists -- this is fine, skip the create step |
| `requested access denied` | Add ECR permissions to your IAM user or attach `AmazonEC2ContainerRegistryFullAccess` |
| Push is slow | Check image size with `docker images` -- should be ~40MB (multi-stage) not 800MB |
| `image not found` on push | Tag with full ECR URI first: `docker tag local:tag $ECR_URI/repo:tag` |

---

## Full Workflow Example

Complete push workflow for both services:

```bash
# Setup
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-southeast-1
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
COMMIT_SHA=$(git rev-parse --short HEAD)

# Authenticate
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

# Frontend: build, tag, push
cd app
docker build -t ecommerce-frontend .
docker tag ecommerce-frontend:latest $ECR_URI/ecommerce-frontend:$COMMIT_SHA
docker tag ecommerce-frontend:latest $ECR_URI/ecommerce-frontend:latest
docker push $ECR_URI/ecommerce-frontend:$COMMIT_SHA
docker push $ECR_URI/ecommerce-frontend:latest

# API: build server first, then build image, tag, push
cd ..
pnpm build:server
cd app
docker build -t ecommerce-api -f Dockerfile.api .
docker tag ecommerce-api:latest $ECR_URI/ecommerce-api:$COMMIT_SHA
docker tag ecommerce-api:latest $ECR_URI/ecommerce-api:latest
docker push $ECR_URI/ecommerce-api:$COMMIT_SHA
docker push $ECR_URI/ecommerce-api:latest

# Verify
aws ecr describe-images --repository-name ecommerce-frontend --region $AWS_REGION
aws ecr describe-images --repository-name ecommerce-api --region $AWS_REGION
```

---

*See [ECR Guide](./ecr-guide.md) for concepts | [ECR Exercise](./ecr-exercise.md) for step-by-step walkthrough*
