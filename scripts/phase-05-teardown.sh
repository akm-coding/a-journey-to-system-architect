#!/bin/bash
#
# phase-05-teardown.sh
# Destroys all Phase 5 infrastructure: production, staging, then bootstrap.
#
# Resources are destroyed in reverse dependency order:
#   1. Production environment (VPC, EC2, RDS, RDS Proxy)
#   2. Staging environment (VPC, EC2, RDS, RDS Proxy)
#   3. Bootstrap infrastructure (S3 state bucket, DynamoDB lock table, ECR repo)
#
# Bootstrap has prevent_destroy on the S3 bucket -- see notes below.
#
set -euo pipefail

# -----------------------------------------------
# Colors for output
# -----------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# -----------------------------------------------
# Project root (script assumes it runs from repo root or scripts/)
# -----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

# -----------------------------------------------
# Warning banner
# -----------------------------------------------
echo ""
echo -e "${RED}=============================================${NC}"
echo -e "${RED}  Phase 5 Teardown -- DESTROY ALL RESOURCES${NC}"
echo -e "${RED}=============================================${NC}"
echo ""
echo -e "${YELLOW}WARNING:${NC} This will permanently destroy:"
echo ""
echo "  Production environment (if deployed):"
echo "    - VPC, subnets, internet gateway, route tables"
echo "    - EC2 instance"
echo "    - RDS PostgreSQL instance (final snapshot will be created)"
echo "    - RDS Proxy, Secrets Manager secret, IAM role"
echo "    - Security groups"
echo ""
echo "  Staging environment (if deployed):"
echo "    - VPC, subnets, internet gateway, route tables"
echo "    - EC2 instance"
echo "    - RDS PostgreSQL instance (NO final snapshot -- staging skips it)"
echo "    - RDS Proxy, Secrets Manager secret, IAM role"
echo "    - Security groups"
echo ""
echo "  Bootstrap infrastructure (with caveats):"
echo "    - ECR repository (all images deleted)"
echo "    - DynamoDB lock table"
echo "    - S3 state bucket (has prevent_destroy -- see notes)"
echo ""
echo -e "${CYAN}Note:${NC} RDS and RDS Proxy deletion takes 5-10 minutes per environment."
echo ""

# -----------------------------------------------
# Confirmation prompt
# -----------------------------------------------
read -p "Type 'yes' to proceed with teardown: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo ""
  echo "Teardown cancelled."
  exit 0
fi

echo ""

# -----------------------------------------------
# Helper function: destroy an environment
# -----------------------------------------------
destroy_environment() {
  local env_name="$1"
  local env_dir="$2"

  echo -e "${CYAN}=============================================${NC}"
  echo -e "${CYAN}  Destroying: ${env_name}${NC}"
  echo -e "${CYAN}=============================================${NC}"
  echo ""

  if [ ! -d "$env_dir" ]; then
    echo -e "  ${YELLOW}Directory not found:${NC} $env_dir"
    echo -e "  ${YELLOW}Skipping ${env_name}.${NC}"
    echo ""
    return 0
  fi

  if [ ! -d "$env_dir/.terraform" ]; then
    echo -e "  ${YELLOW}Not initialized:${NC} No .terraform directory found."
    echo -e "  ${YELLOW}Skipping ${env_name}${NC} (run 'terraform init' first if resources exist)."
    echo ""
    return 0
  fi

  echo -e "  Running: ${CYAN}terraform destroy -auto-approve${NC}"
  echo ""

  if (cd "$env_dir" && terraform destroy -auto-approve); then
    echo ""
    echo -e "  ${GREEN}${env_name} destroyed successfully.${NC}"
  else
    echo ""
    echo -e "  ${RED}${env_name} destroy failed.${NC}"
    echo -e "  ${YELLOW}Continuing to next environment...${NC}"
    echo -e "  ${YELLOW}You may need to destroy ${env_name} manually.${NC}"
  fi

  echo ""
}

# -----------------------------------------------
# Step 1: Destroy production environment
# -----------------------------------------------
destroy_environment "Production" "$INFRA_DIR/production"

# -----------------------------------------------
# Step 2: Destroy staging environment
# -----------------------------------------------
destroy_environment "Staging" "$INFRA_DIR/staging"

# -----------------------------------------------
# Step 3: Destroy bootstrap infrastructure
# -----------------------------------------------
echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  Destroying: Bootstrap${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

if [ ! -d "$INFRA_DIR/bootstrap" ]; then
  echo -e "  ${YELLOW}Directory not found:${NC} $INFRA_DIR/bootstrap"
  echo -e "  ${YELLOW}Skipping bootstrap.${NC}"
elif [ ! -d "$INFRA_DIR/bootstrap/.terraform" ]; then
  echo -e "  ${YELLOW}Not initialized:${NC} No .terraform directory found."
  echo -e "  ${YELLOW}Skipping bootstrap.${NC}"
else
  echo -e "  ${YELLOW}IMPORTANT:${NC} The S3 state bucket has 'prevent_destroy = true'."
  echo -e "  If terraform destroy fails on the S3 bucket, you have two options:"
  echo ""
  echo -e "    1. Remove the lifecycle block from infra/bootstrap/main.tf, then re-run destroy"
  echo -e "    2. Use -target to destroy other resources individually:"
  echo -e "       cd infra/bootstrap"
  echo -e "       terraform destroy -target=aws_ecr_repository.app -auto-approve"
  echo -e "       terraform destroy -target=aws_ecr_lifecycle_policy.app -auto-approve"
  echo -e "       terraform destroy -target=aws_dynamodb_table.terraform_locks -auto-approve"
  echo -e "       # Then manually delete the S3 bucket via AWS console or CLI"
  echo ""

  read -p "  Attempt bootstrap destroy? (y/N): " BOOTSTRAP_CONFIRM
  if [ "$BOOTSTRAP_CONFIRM" = "y" ] || [ "$BOOTSTRAP_CONFIRM" = "Y" ]; then
    echo ""
    echo -e "  Running: ${CYAN}terraform destroy -auto-approve${NC}"
    echo ""

    if (cd "$INFRA_DIR/bootstrap" && terraform destroy -auto-approve); then
      echo ""
      echo -e "  ${GREEN}Bootstrap destroyed successfully.${NC}"
    else
      echo ""
      echo -e "  ${RED}Bootstrap destroy failed (likely due to prevent_destroy on S3 bucket).${NC}"
      echo -e "  ${YELLOW}See the options above to handle the S3 bucket manually.${NC}"
    fi
  else
    echo ""
    echo -e "  ${YELLOW}Skipping bootstrap destroy.${NC}"
    echo -e "  Bootstrap resources (~$0.55/month) will continue running."
  fi
fi

echo ""

# -----------------------------------------------
# Step 4: Optional cleanup of local Terraform files
# -----------------------------------------------
echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}  Local Cleanup (Optional)${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""
echo "  Local Terraform files (.terraform/ directories and .terraform.lock.hcl)"
echo "  can be removed to save disk space. They will be recreated by 'terraform init'."
echo ""

read -p "  Remove local Terraform files? (y/N): " CLEANUP_CONFIRM
if [ "$CLEANUP_CONFIRM" = "y" ] || [ "$CLEANUP_CONFIRM" = "Y" ]; then
  echo ""

  for dir in "$INFRA_DIR/bootstrap" "$INFRA_DIR/staging" "$INFRA_DIR/production" "$INFRA_DIR/modules/vpc"; do
    if [ -d "$dir/.terraform" ]; then
      rm -rf "$dir/.terraform"
      echo -e "  ${GREEN}Removed:${NC} $dir/.terraform/"
    fi
    if [ -f "$dir/.terraform.lock.hcl" ]; then
      rm -f "$dir/.terraform.lock.hcl"
      echo -e "  ${GREEN}Removed:${NC} $dir/.terraform.lock.hcl"
    fi
  done

  # Also remove bootstrap local state (only if bootstrap was destroyed)
  if [ -f "$INFRA_DIR/bootstrap/terraform.tfstate" ]; then
    echo ""
    echo -e "  ${YELLOW}Found bootstrap local state file:${NC} infra/bootstrap/terraform.tfstate"
    echo -e "  ${YELLOW}Only remove this if bootstrap was successfully destroyed above.${NC}"
    read -p "  Remove bootstrap local state? (y/N): " STATE_CONFIRM
    if [ "$STATE_CONFIRM" = "y" ] || [ "$STATE_CONFIRM" = "Y" ]; then
      rm -f "$INFRA_DIR/bootstrap/terraform.tfstate"
      rm -f "$INFRA_DIR/bootstrap/terraform.tfstate.backup"
      echo -e "  ${GREEN}Removed bootstrap local state files.${NC}"
    fi
  fi

  echo ""
  echo -e "  ${GREEN}Local cleanup complete.${NC}"
else
  echo ""
  echo -e "  ${YELLOW}Skipping local cleanup.${NC}"
fi

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Phase 5 Teardown Summary${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "  Environments processed:"
echo "    - Production"
echo "    - Staging"
echo "    - Bootstrap"
echo ""
echo "  Check the AWS console or CLI to verify all resources are removed:"
echo ""
echo "    aws ec2 describe-vpcs --filters 'Name=tag:Project,Values=journey-sysarch'"
echo "    aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier'"
echo "    aws rds describe-db-proxies --query 'DBProxies[*].DBProxyName'"
echo ""
echo -e "  ${CYAN}Tip:${NC} Manual snapshots persist after instance deletion."
echo "  To delete them:"
echo "    aws rds describe-db-snapshots --snapshot-type manual --output table"
echo "    aws rds delete-db-snapshot --db-snapshot-identifier SNAPSHOT_ID"
echo ""
echo -e "${GREEN}Done.${NC}"
