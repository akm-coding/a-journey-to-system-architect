#!/bin/bash
#
# teardown-phase2.sh
# Destroys all Phase 2 AWS resources in the correct dependency order.
# Resources MUST be deleted in this order to avoid dependency errors.
#
set -e

echo "============================================="
echo "  Phase 2 Teardown -- Destroy All Resources"
echo "============================================="
echo ""
echo "WARNING: This will permanently delete ALL Phase 2 AWS resources:"
echo "  - RDS PostgreSQL instance (all data will be lost)"
echo "  - EC2 instance"
echo "  - Elastic IP"
echo "  - Security groups"
echo "  - DB subnet group"
echo "  - VPC (subnets, route tables, internet gateway)"
echo ""

read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Teardown cancelled."
  exit 0
fi

echo ""
echo "--- Collect Resource IDs ---"
echo "Enter the following resource identifiers."
echo "(You can find them in the AWS Console or via CLI.)"
echo ""

read -p "RDS instance identifier [ecommerce-db]: " RDS_ID
RDS_ID=${RDS_ID:-ecommerce-db}

read -p "DB subnet group name [ecommerce-db-subnet-group]: " DB_SUBNET_GROUP
DB_SUBNET_GROUP=${DB_SUBNET_GROUP:-ecommerce-db-subnet-group}

read -p "EC2 instance ID (i-xxxxxxxxx): " EC2_ID
if [ -z "$EC2_ID" ]; then
  echo "ERROR: EC2 instance ID is required."
  exit 1
fi

read -p "Elastic IP allocation ID (eipalloc-xxxxxxxxx): " EIP_ALLOC_ID
if [ -z "$EIP_ALLOC_ID" ]; then
  echo "ERROR: Elastic IP allocation ID is required."
  exit 1
fi

read -p "RDS security group ID (sg-xxxxxxxxx): " RDS_SG_ID
if [ -z "$RDS_SG_ID" ]; then
  echo "ERROR: RDS security group ID is required."
  exit 1
fi

read -p "EC2 security group ID (sg-xxxxxxxxx): " EC2_SG_ID
if [ -z "$EC2_SG_ID" ]; then
  echo "ERROR: EC2 security group ID is required."
  exit 1
fi

read -p "VPC ID (vpc-xxxxxxxxx): " VPC_ID
if [ -z "$VPC_ID" ]; then
  echo "ERROR: VPC ID is required."
  exit 1
fi

echo ""
echo "============================================="
echo "  Starting teardown in dependency order"
echo "============================================="

# -----------------------------------------------
# Step 1: Delete RDS instance (takes ~5 minutes)
# WHY FIRST: RDS depends on the DB subnet group and RDS security group.
# Must be deleted before we can remove those resources.
# -----------------------------------------------
echo ""
echo "[1/7] Deleting RDS instance: $RDS_ID"
echo "      (skipping final snapshot to save cost)"
aws rds delete-db-instance \
  --db-instance-identifier "$RDS_ID" \
  --skip-final-snapshot \
  2>/dev/null && echo "      Delete initiated." || echo "      Already deleted or not found."

echo "      Waiting for RDS deletion to complete (this takes ~5 minutes)..."
aws rds wait db-instance-deleted \
  --db-instance-identifier "$RDS_ID" \
  2>/dev/null && echo "      RDS deleted." || echo "      RDS already gone."

# -----------------------------------------------
# Step 2: Delete DB subnet group
# WHY AFTER RDS: The subnet group is in use while RDS exists.
# -----------------------------------------------
echo ""
echo "[2/7] Deleting DB subnet group: $DB_SUBNET_GROUP"
aws rds delete-db-subnet-group \
  --db-subnet-group-name "$DB_SUBNET_GROUP" \
  2>/dev/null && echo "      DB subnet group deleted." || echo "      Already deleted or not found."

# -----------------------------------------------
# Step 3: Terminate EC2 instance
# WHY AFTER RDS: No strict dependency, but we keep it running
# until RDS is gone in case we need to debug connectivity issues.
# -----------------------------------------------
echo ""
echo "[3/7] Terminating EC2 instance: $EC2_ID"
aws ec2 terminate-instances --instance-ids "$EC2_ID" \
  2>/dev/null && echo "      Terminate initiated." || echo "      Already terminated or not found."

echo "      Waiting for EC2 termination..."
aws ec2 wait instance-terminated --instance-ids "$EC2_ID" \
  2>/dev/null && echo "      EC2 terminated." || echo "      EC2 already gone."

# -----------------------------------------------
# Step 4: Release Elastic IP
# WHY AFTER EC2: The EIP must be disassociated first.
# Terminating EC2 automatically disassociates it.
# -----------------------------------------------
echo ""
echo "[4/7] Releasing Elastic IP: $EIP_ALLOC_ID"
aws ec2 release-address --allocation-id "$EIP_ALLOC_ID" \
  2>/dev/null && echo "      Elastic IP released." || echo "      Already released or not found."

# -----------------------------------------------
# Step 5: Delete RDS security group
# WHY BEFORE EC2 SG: The RDS SG references the EC2 SG.
# If we delete EC2 SG first, the RDS SG has a dangling reference
# (though AWS handles this -- ordering is cleaner).
# -----------------------------------------------
echo ""
echo "[5/7] Deleting RDS security group: $RDS_SG_ID"
aws ec2 delete-security-group --group-id "$RDS_SG_ID" \
  2>/dev/null && echo "      RDS security group deleted." || echo "      Already deleted or not found."

# -----------------------------------------------
# Step 6: Delete EC2 security group
# WHY AFTER EC2 TERMINATED: SG can't be deleted while instances use it.
# -----------------------------------------------
echo ""
echo "[6/7] Deleting EC2 security group: $EC2_SG_ID"
aws ec2 delete-security-group --group-id "$EC2_SG_ID" \
  2>/dev/null && echo "      EC2 security group deleted." || echo "      Already deleted or not found."

# -----------------------------------------------
# Step 7: Delete VPC
# WHY LAST: VPC contains all networking resources (subnets, route tables, IGW).
# All instances and SGs must be gone first.
# Note: delete-vpc requires manually detaching/deleting the IGW first,
# and deleting subnets. The VPC console "Delete VPC" button handles
# this automatically, but CLI requires explicit steps.
# -----------------------------------------------
echo ""
echo "[7/7] Deleting VPC: $VPC_ID"
echo "      Detaching and deleting Internet Gateway..."

# Find and detach IGW
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text 2>/dev/null)

if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
  aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null
  aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" 2>/dev/null
  echo "      IGW $IGW_ID detached and deleted."
fi

echo "      Deleting subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].SubnetId" \
  --output text 2>/dev/null)

for SUBNET_ID in $SUBNET_IDS; do
  aws ec2 delete-subnet --subnet-id "$SUBNET_ID" 2>/dev/null
  echo "      Deleted subnet: $SUBNET_ID"
done

echo "      Deleting custom route tables..."
RT_IDS=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" \
  --output text 2>/dev/null)

for RT_ID in $RT_IDS; do
  # Disassociate first
  ASSOC_IDS=$(aws ec2 describe-route-tables \
    --route-table-ids "$RT_ID" \
    --query "RouteTables[0].Associations[?!Main].RouteTableAssociationId" \
    --output text 2>/dev/null)
  for ASSOC_ID in $ASSOC_IDS; do
    aws ec2 disassociate-route-table --association-id "$ASSOC_ID" 2>/dev/null
  done
  aws ec2 delete-route-table --route-table-id "$RT_ID" 2>/dev/null
  echo "      Deleted route table: $RT_ID"
done

echo "      Deleting VPC..."
aws ec2 delete-vpc --vpc-id "$VPC_ID" \
  2>/dev/null && echo "      VPC deleted." || echo "      VPC deletion failed -- check for remaining dependencies."

echo ""
echo "============================================="
echo "  Teardown complete!"
echo "============================================="
echo ""
echo "All Phase 2 resources have been destroyed."
echo "Monthly charges from these resources will stop."
echo ""
echo "To rebuild for your next study session, run:"
echo "  ./scripts/rebuild-phase2.sh"
