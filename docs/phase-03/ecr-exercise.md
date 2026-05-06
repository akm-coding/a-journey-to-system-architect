# ECR Hands-On Exercise

Push your Docker images to AWS ECR, verify them, and apply lifecycle policies.

**Prerequisites:**
- Docker Desktop running
- AWS CLI configured (`aws sts get-caller-identity` returns your account)
- Dockerfiles from the Docker exercise (app/Dockerfile, app/Dockerfile.api)
- Images built locally (or you'll build them in this exercise)

**Time estimate:** 20-30 minutes

---

## Step 1: Set Your Variables

These variables are used throughout the exercise. Set them once in your terminal:

```bash
# Get your AWS account ID automatically
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Set your region (use the region you configured in Phase 2)
AWS_REGION=ap-southeast-1

# Construct the ECR registry URI
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Verify everything looks right
echo "Account: $AWS_ACCOUNT_ID"
echo "Region:  $AWS_REGION"
echo "ECR URI: $ECR_URI"
```

You should see output like:
```
Account: 123456789012
Region:  ap-southeast-1
ECR URI: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com
```

> **GOTCHA:** If `AWS_ACCOUNT_ID` is empty, your AWS CLI isn't configured. Run `aws configure` first.

---

## Step 2: Create ECR Repositories

Create one repository for each service:

```bash
# Create frontend repository
aws ecr create-repository \
  --repository-name ecommerce-frontend \
  --region $AWS_REGION

# Create API repository
aws ecr create-repository \
  --repository-name ecommerce-api \
  --region $AWS_REGION
```

Each command returns JSON with the repository details. The key field is `repositoryUri`:

```json
{
  "repository": {
    "repositoryUri": "123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-frontend",
    "repositoryName": "ecommerce-frontend"
  }
}
```

**Verify your repos exist:**

```bash
aws ecr describe-repositories --region $AWS_REGION \
  --query "repositories[*].[repositoryName,repositoryUri]" \
  --output table
```

You should see both `ecommerce-frontend` and `ecommerce-api` listed.

> **AWS Console check:** You can also verify in the AWS Console: Services -> ECR -> Repositories. You should see both repos with 0 images.

---

## Step 3: Authenticate Docker to ECR

```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI
```

Expected output:
```
Login Succeeded
```

> **WHY:** Docker needs credentials to push to ECR. This command gets a temporary token (valid 12 hours) from AWS and passes it to Docker. The `--username AWS` is always literally "AWS" -- not your IAM username.

**If you get an error:**
- `Unable to locate credentials` -- Run `aws configure` to set up AWS CLI
- `An error occurred (AccessDeniedException)` -- Your IAM user needs ECR permissions
- Connection timeout -- Check your internet connection and region

---

## Step 4: Build the Frontend Image

Navigate to the app directory and build:

```bash
cd app

# Build the frontend image
docker build -t ecommerce-frontend .
```

This runs the multi-stage Dockerfile:
1. **Build stage:** Installs deps, runs `pnpm build:client` (Vite)
2. **Production stage:** Copies built files to nginx

The final image should be ~40MB (check with `docker images ecommerce-frontend`).

---

## Step 5: Tag the Frontend Image

Every image needs to be tagged with the **ECR repository URI** before pushing. We apply two tags:

```bash
# Get the current git commit SHA (short version)
COMMIT_SHA=$(git rev-parse --short HEAD)
echo "Commit SHA: $COMMIT_SHA"

# Tag with commit SHA (for traceability)
docker tag ecommerce-frontend:latest \
  $ECR_URI/ecommerce-frontend:$COMMIT_SHA

# Tag with latest (for convenience)
docker tag ecommerce-frontend:latest \
  $ECR_URI/ecommerce-frontend:latest
```

**Verify your tags:**

```bash
docker images --filter "reference=$ECR_URI/ecommerce-frontend" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

You should see two entries (both pointing to the same image):
```
REPOSITORY                                                     TAG       SIZE
123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/ecom...     abc123f   42MB
123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/ecom...     latest    42MB
```

> **WHY two tags?** The commit SHA tag (`abc123f`) tells you exactly which code is in this image. The `latest` tag is a convenient pointer to "the newest version." In CI/CD (Phase 4), only the commit SHA tag is used for deployments.

---

## Step 6: Push the Frontend Image

```bash
# Push the commit SHA tagged image
docker push $ECR_URI/ecommerce-frontend:$COMMIT_SHA

# Push the latest tag
docker push $ECR_URI/ecommerce-frontend:latest
```

You'll see output showing each layer being pushed:

```
The push refers to repository [123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-frontend]
5f70bf18a086: Pushed
abc123f: digest: sha256:... size: 1234
```

> **WHY does pushing two tags not double the storage?** Docker images are made of layers. Both tags point to the same layers. ECR deduplicates layers, so you only store each unique layer once.

---

## Step 7: Verify the Frontend Image in ECR

```bash
aws ecr describe-images \
  --repository-name ecommerce-frontend \
  --region $AWS_REGION \
  --query "imageDetails[*].[imageTags,imageSizeInBytes,imagePushedAt]" \
  --output table
```

You should see your image with both tags listed.

> **AWS Console check:** In the ECR console, click on the `ecommerce-frontend` repository. You'll see your image listed with both tags and the push timestamp.

---

## Step 8: Build, Tag, and Push the API Image

Now repeat the process for the API service.

**Important:** The API Dockerfile expects pre-built server code. Build it first:

```bash
# From the project root (not app/)
cd ..
pnpm build:server

# Now build the API image from the app/ directory
cd app
docker build -t ecommerce-api -f Dockerfile.api .
```

**Tag and push:**

```bash
# Tag with commit SHA
docker tag ecommerce-api:latest \
  $ECR_URI/ecommerce-api:$COMMIT_SHA

# Tag with latest
docker tag ecommerce-api:latest \
  $ECR_URI/ecommerce-api:latest

# Push both tags
docker push $ECR_URI/ecommerce-api:$COMMIT_SHA
docker push $ECR_URI/ecommerce-api:latest
```

**Verify:**

```bash
aws ecr describe-images \
  --repository-name ecommerce-api \
  --region $AWS_REGION \
  --query "imageDetails[*].[imageTags,imageSizeInBytes,imagePushedAt]" \
  --output table
```

---

## Step 9: Apply Lifecycle Policies

Without lifecycle policies, images accumulate forever. Let's set up automated cleanup.

**Create the policy file:**

```bash
# From the project root
cd ..

cat > /tmp/ecr-lifecycle-policy.json << 'EOF'
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
EOF
```

**Apply to both repositories:**

```bash
# Apply to frontend repo
aws ecr put-lifecycle-policy \
  --repository-name ecommerce-frontend \
  --lifecycle-policy-text file:///tmp/ecr-lifecycle-policy.json \
  --region $AWS_REGION

# Apply to API repo
aws ecr put-lifecycle-policy \
  --repository-name ecommerce-api \
  --lifecycle-policy-text file:///tmp/ecr-lifecycle-policy.json \
  --region $AWS_REGION
```

**Verify the policies were applied:**

```bash
# Check frontend policy
aws ecr get-lifecycle-policy \
  --repository-name ecommerce-frontend \
  --region $AWS_REGION \
  --query "lifecyclePolicyText" \
  --output text | python3 -m json.tool

# Check API policy
aws ecr get-lifecycle-policy \
  --repository-name ecommerce-api \
  --region $AWS_REGION \
  --query "lifecyclePolicyText" \
  --output text | python3 -m json.tool
```

> **WHY these rules?** Rule 1 cleans up **untagged** images after 7 days -- these are typically superseded layers from previous pushes. Rule 2 keeps only the **last 10 tagged** images -- enough for rollbacks without accumulating indefinitely. These run automatically ~every 24 hours.

---

## Step 10: Preview What Lifecycle Would Delete

You can test what a lifecycle policy would delete without actually deleting anything:

```bash
aws ecr get-lifecycle-policy-preview \
  --repository-name ecommerce-frontend \
  --region $AWS_REGION
```

Since we only have a few images, the preview will likely show no images to expire. As you push more images over time, the preview becomes useful.

---

## Step 11: Cleanup

When you're done with this exercise and want to remove the ECR resources:

```bash
# Use the Phase 3 teardown script
./scripts/phase-03-teardown.sh
```

Or manually delete the repositories:

```bash
# Force-delete removes repos even if they contain images
aws ecr delete-repository \
  --repository-name ecommerce-frontend \
  --force --region $AWS_REGION

aws ecr delete-repository \
  --repository-name ecommerce-api \
  --force --region $AWS_REGION
```

> **WHY `--force`?** Without `--force`, ECR won't delete a repository that contains images. The `--force` flag deletes the repository AND all images inside it.

---

## Troubleshooting

### "no basic auth credentials"

**Cause:** Docker is not authenticated to ECR (token expired or never ran login).

```bash
# Re-authenticate
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI
```

### "repository does not exist"

**Cause:** Typo in repository name, or created in a different region.

```bash
# List all repositories to check
aws ecr describe-repositories --region $AWS_REGION \
  --query "repositories[*].repositoryName" --output text
```

### "An error occurred (RepositoryAlreadyExistsException)"

**Cause:** Repository already exists from a previous run. This is fine -- just skip the create step.

### "denied: Your authorization token has expired"

**Cause:** The 12-hour ECR auth token has expired.

```bash
# Simply re-authenticate
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI
```

### Push is extremely slow

**Cause:** Large image or slow upload speed.

- Check image size: `docker images ecommerce-frontend` -- should be ~40MB for frontend
- If image is hundreds of MB, check your `.dockerignore` and multi-stage build
- First push is always slower (all layers are new). Subsequent pushes only send changed layers.

### "requested access to the resource is denied"

**Cause:** IAM permissions are insufficient.

Your IAM user needs these ECR permissions (at minimum):
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecr:BatchGetImage`
- `ecr:DescribeRepositories`
- `ecr:DescribeImages`
- `ecr:CreateRepository`

The simplest approach for learning: attach the `AmazonEC2ContainerRegistryFullAccess` managed policy to your IAM user.

---

## What You've Learned

After completing this exercise, you can:

- [x] Create ECR repositories for your Docker images
- [x] Authenticate Docker to ECR using AWS CLI
- [x] Tag images with git commit SHA and latest
- [x] Push images to ECR and verify they arrived
- [x] Apply lifecycle policies to automate image cleanup
- [x] Troubleshoot common ECR authentication and push errors

---

*Next: [ECR Cheatsheet](./ecr-cheatsheet.md) -- Quick reference for all ECR commands*
