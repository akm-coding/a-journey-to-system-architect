#!/bin/bash
#
# phase-03-teardown.sh
# Destroys all Phase 3 resources: ECR repositories and local Docker artifacts.
#
# Phase 3 resources are simpler than Phase 2 (just ECR repos + local Docker
# artifacts, no AWS networking). This script handles both AWS and local cleanup.
#
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================="
echo "  Phase 3 Teardown -- Destroy All Resources"
echo "============================================="
echo ""
echo -e "${YELLOW}WARNING:${NC} This will permanently delete:"
echo "  - ECR repository: ecommerce-frontend (all images)"
echo "  - ECR repository: ecommerce-api (all images)"
echo "  - Local Docker Compose stack (containers, volumes, images)"
echo ""

read -p "Are you sure you want to proceed? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Teardown cancelled."
  exit 0
fi

echo ""

# -----------------------------------------------
# Get AWS region
# -----------------------------------------------
AWS_REGION=${AWS_REGION:-ap-southeast-1}
echo -e "${YELLOW}Using AWS region:${NC} $AWS_REGION"
echo ""

# -----------------------------------------------
# Step 1: Delete ECR repositories
# -----------------------------------------------
echo "============================================="
echo "  Deleting ECR Repositories"
echo "============================================="

echo ""
echo -e "[1/3] Deleting ECR repository: ${YELLOW}ecommerce-frontend${NC}"
aws ecr delete-repository \
  --repository-name ecommerce-frontend \
  --force \
  --region "$AWS_REGION" \
  2>/dev/null \
  && echo -e "      ${GREEN}ecommerce-frontend deleted.${NC}" \
  || echo -e "      ${YELLOW}Already deleted or not found.${NC}"

echo ""
echo -e "[2/3] Deleting ECR repository: ${YELLOW}ecommerce-api${NC}"
aws ecr delete-repository \
  --repository-name ecommerce-api \
  --force \
  --region "$AWS_REGION" \
  2>/dev/null \
  && echo -e "      ${GREEN}ecommerce-api deleted.${NC}" \
  || echo -e "      ${YELLOW}Already deleted or not found.${NC}"

# -----------------------------------------------
# Step 2: Clean up local Docker artifacts
# -----------------------------------------------
echo ""
echo "============================================="
echo "  Cleaning Up Local Docker Artifacts"
echo "============================================="

echo ""
echo -e "[3/3] Stopping Compose stack and removing containers, volumes, and images"

# Check if we're in the app directory or project root
if [ -f "app/docker-compose.yml" ]; then
  COMPOSE_DIR="app"
elif [ -f "docker-compose.yml" ]; then
  COMPOSE_DIR="."
else
  COMPOSE_DIR=""
fi

if [ -n "$COMPOSE_DIR" ]; then
  cd "$COMPOSE_DIR"
  docker compose down -v --rmi all 2>/dev/null \
    && echo -e "      ${GREEN}Compose stack cleaned up.${NC}" \
    || echo -e "      ${YELLOW}No running Compose stack found (already clean).${NC}"
  cd - > /dev/null
else
  echo -e "      ${YELLOW}No docker-compose.yml found -- skipping Compose cleanup.${NC}"
fi

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "============================================="
echo -e "  ${GREEN}Teardown complete!${NC}"
echo "============================================="
echo ""
echo "Deleted:"
echo "  - ECR repository: ecommerce-frontend (with all images)"
echo "  - ECR repository: ecommerce-api (with all images)"
echo "  - Local Docker Compose containers, volumes, and images"
echo ""
echo "ECR storage charges from these repositories will stop."
echo ""
echo "To redo the ECR exercise, follow:"
echo "  docs/phase-03/ecr-exercise.md"
