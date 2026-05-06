# Networking & VPC Exercise

## Prerequisites

- AWS account with IAM user and CLI configured (from 01-aws-account-setup)
- SSH key pair created (from 02-linux-fundamentals)

> **Note:** This exercise uses BOTH the AWS Console and CLI side-by-side. Do each step in the console first to see what is happening visually, then note the CLI equivalent. This builds both muscle memories.

## Step 1: Create a VPC

**Console:** VPC Dashboard > Your VPCs > Create VPC
- Resources to create: VPC only
- Name tag: `learning-vpc`
- IPv4 CIDR block: `10.0.0.0/16`
- Leave everything else as default
- Note the VPC ID (e.g., `vpc-0abc123...`)

**CLI:**
```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=learning-vpc}]'
```

Save the VPC ID from the output -- you will need it for every subsequent step.

```bash
# Store it in a variable for convenience
VPC_ID=vpc-0abc123  # replace with your actual VPC ID
```

## Step 2: Create the Public Subnet

**Console:** VPC Dashboard > Subnets > Create subnet
- VPC: select `learning-vpc`
- Subnet name: `public-1`
- Availability Zone: `us-east-1a`
- IPv4 CIDR block: `10.0.1.0/24`

**CLI:**
```bash
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1}]'
```

Save the subnet ID: `PUBLIC_SUBNET_ID=subnet-xxx`

## Step 3: Create the Private Subnet

**Console:** Same process as Step 2.
- Subnet name: `private-1`
- Availability Zone: `us-east-1a`
- IPv4 CIDR block: `10.0.2.0/24`

**CLI:**
```bash
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-1}]'
```

Save the subnet ID: `PRIVATE_SUBNET_ID=subnet-yyy`

## Step 4: Create and Attach an Internet Gateway

**Console:** VPC Dashboard > Internet Gateways > Create internet gateway
- Name tag: `learning-igw`
- After creation, select it > Actions > Attach to VPC > select `learning-vpc`

**CLI:**
```bash
# Create the IGW
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=learning-igw}]'

# Store the ID
IGW_ID=igw-xxx  # replace with actual

# Attach to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID
```

## Step 5: Create Route Table for Public Subnet

**Console:** VPC Dashboard > Route Tables > Create route table
- Name: `public-rt`
- VPC: `learning-vpc`
- After creation: select the route table > Routes tab > Edit routes > Add route
  - Destination: `0.0.0.0/0`
  - Target: Internet Gateway > select `learning-igw`
- Then: Subnet associations tab > Edit subnet associations > select `public-1`

**CLI:**
```bash
# Create route table
aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]'

RT_ID=rtb-xxx  # replace with actual

# Add route to internet via IGW
aws ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate with public subnet
aws ec2 associate-route-table \
  --route-table-id $RT_ID \
  --subnet-id $PUBLIC_SUBNET_ID
```

## Step 6: Enable Auto-Assign Public IP

**Console:** VPC Dashboard > Subnets > select `public-1` > Actions > Edit subnet settings > Enable auto-assign public IPv4 address

**CLI:**
```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_ID \
  --map-public-ip-on-launch
```

This ensures any EC2 instance launched in the public subnet automatically gets a public IP address.

## Step 7: Launch EC2 in the Public Subnet

**Console:** EC2 Dashboard > Launch Instance
- Name: `public-test`
- AMI: Amazon Linux 2023
- Instance type: t2.micro (free tier)
- Key pair: select your existing key
- Network settings: Edit > VPC: `learning-vpc`, Subnet: `public-1`
- Security group: Create new, allow SSH (port 22) from your IP

**Verify it gets a public IP:**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=public-test" \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
  --output table
```

**SSH into it:**
```bash
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>

# Once connected, verify internet access:
curl ifconfig.me    # Should return the public IP
ping 8.8.8.8        # Should work
```

## Step 8: Launch EC2 in the Private Subnet

**Console:** Same as Step 7, but:
- Name: `private-test`
- Subnet: `private-1`
- Security group: Allow SSH (port 22) from `10.0.0.0/16` (VPC CIDR -- only reachable from within VPC)

**Verify it does NOT get a public IP:**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=private-test" \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
  --output table
```

The `PublicIpAddress` column should be `None` or empty.

**Try to SSH directly -- should fail:**
```bash
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@<private-ip>
# This will hang/timeout -- there is no route from the internet to the private subnet
```

## Step 9: (Optional) Bastion Pattern with NAT Gateway

> **Warning:** NAT Gateway costs $0.045/hr (~$1.08/day). Create it, test it, then tear it down immediately.

**Console:** VPC Dashboard > NAT Gateways > Create NAT gateway
- Name: `learning-nat`
- Subnet: `public-1` (NAT Gateway goes in the public subnet)
- Allocate Elastic IP

Then update the private subnet route table:
- VPC Dashboard > Route Tables > select the main/default route table for your VPC
- Add route: `0.0.0.0/0` -> NAT Gateway

**Test the bastion pattern:**
```bash
# SSH into the public instance first (the "bastion")
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>

# From the public instance, SSH into the private instance
# (you will need to copy your key to the bastion, or use SSH agent forwarding)
ssh -A -i ~/.ssh/my-ec2-key.pem ec2-user@<public-ip>  # with agent forwarding
# Then from the bastion:
ssh ec2-user@<private-ip>

# From the private instance, test internet via NAT:
curl ifconfig.me    # Should return the NAT Gateway's Elastic IP
```

**Tear down the NAT Gateway immediately after testing to avoid charges.**

## Diagram Exercise

Draw the VPC you just created. Include:
- VPC boundary with CIDR (10.0.0.0/16)
- Both subnets with their CIDRs and AZ
- Route tables with their routes (show each entry)
- Internet Gateway
- Both EC2 instances (with their IP types)
- NAT Gateway (if you created it)

Use **Excalidraw** (excalidraw.com) or paper. Save the diagram for your progress log.

## Verification Checklist

- [ ] `curl ifconfig.me` from the public EC2 returns the instance's public IP
- [ ] The private EC2 has no public IP (`aws ec2 describe-instances` confirms `None`)
- [ ] Direct SSH to the private IP from your laptop times out
- [ ] (Optional) From the private EC2 via bastion: `curl ifconfig.me` returns the NAT Gateway IP or times out (if no NAT)
- [ ] You drew the VPC diagram and can explain each component

## Clean Up

**Order matters -- VPC cannot be deleted while resources exist inside it.**

1. Terminate both EC2 instances (wait for them to reach "terminated" state)
2. Delete NAT Gateway (if created) -- wait for it to be deleted
3. Release the Elastic IP (if allocated for NAT)
4. Delete the custom route table (`public-rt`)
5. Detach and delete the Internet Gateway
6. Delete both subnets
7. Delete the VPC

**CLI teardown:**
```bash
# 1. Terminate instances
aws ec2 terminate-instances --instance-ids i-public i-private

# 2. Wait for termination
aws ec2 wait instance-terminated --instance-ids i-public i-private

# 3. Delete NAT Gateway (if created)
aws ec2 delete-nat-gateway --nat-gateway-id nat-xxx

# 4. Release Elastic IP (if allocated)
aws ec2 release-address --allocation-id eipalloc-xxx

# 5. Delete route table (disassociate first)
aws ec2 disassociate-route-table --association-id rtbassoc-xxx
aws ec2 delete-route-table --route-table-id $RT_ID

# 6. Detach and delete IGW
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# 7. Delete subnets
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_ID
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID

# 8. Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## Rebuild Challenge

Delete everything you just created. Then recreate the entire VPC with public and private subnets using **only the CLI** (no console). Time yourself.

**Target time:** Under 10 minutes for the full setup (VPC + 2 subnets + IGW + route table + EC2 launch).

Log your time and any issues in `docs/phase-01/rebuild-log.md`.
