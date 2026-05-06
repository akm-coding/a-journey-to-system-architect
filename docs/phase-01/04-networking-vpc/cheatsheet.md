# Networking & VPC Cheatsheet

## VPC Commands

```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=my-vpc}]'

# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# Delete VPC (must delete all resources inside first)
aws ec2 delete-vpc --vpc-id vpc-xxx
```

## Subnet Commands

```bash
# Create subnet
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1}]'

# List subnets in a VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxx" \
  --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute --subnet-id subnet-xxx --map-public-ip-on-launch

# Delete subnet
aws ec2 delete-subnet --subnet-id subnet-xxx
```

## Internet Gateway Commands

```bash
# Create IGW
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=my-igw}]'

# Attach IGW to VPC
aws ec2 attach-internet-gateway --internet-gateway-id igw-xxx --vpc-id vpc-xxx

# Detach IGW
aws ec2 detach-internet-gateway --internet-gateway-id igw-xxx --vpc-id vpc-xxx

# Delete IGW
aws ec2 delete-internet-gateway --internet-gateway-id igw-xxx
```

## Route Table Commands

```bash
# Create route table
aws ec2 create-route-table --vpc-id vpc-xxx \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]'

# Add route (e.g., internet via IGW)
aws ec2 create-route --route-table-id rtb-xxx \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxx

# Associate route table with subnet
aws ec2 associate-route-table --route-table-id rtb-xxx --subnet-id subnet-xxx

# View routes
aws ec2 describe-route-tables --route-table-ids rtb-xxx \
  --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,State]' \
  --output table

# Disassociate route table
aws ec2 disassociate-route-table --association-id rtbassoc-xxx

# Delete route table
aws ec2 delete-route-table --route-table-id rtb-xxx
```

## CIDR Quick Reference

| CIDR          | IPs     | Usable (AWS) | Common Use       |
|---------------|---------|--------------|------------------|
| /16           | 65,536  | 65,531       | VPC              |
| /20           | 4,096   | 4,091        | Large subnet     |
| /24           | 256     | 251          | Standard subnet  |
| /28           | 16      | 11           | Small subnet     |
| /32           | 1       | 1            | Single IP (SG rules) |

> AWS reserves 5 IPs per subnet: network address, VPC router, DNS server, future use, broadcast.

## Common Troubleshooting

| Problem | Check |
|---------|-------|
| Cannot SSH into EC2 | 1. Does instance have public IP? 2. Is IGW attached? 3. Route table has 0.0.0.0/0 -> IGW? 4. SG allows port 22 from your IP? |
| EC2 cannot reach internet | 1. Is it in a public subnet with IGW route? 2. Or in private subnet with NAT route? 3. SG outbound rules allow it? |
| Cannot delete VPC | Delete in order: instances, NAT GW, release EIPs, route tables, IGW, subnets, then VPC |
| Overlapping CIDRs | Subnets must not overlap. Use /24 blocks: 10.0.1.0/24, 10.0.2.0/24, etc. |

## Teardown Order

1. Terminate EC2 instances (wait for terminated state)
2. Delete NAT Gateway (wait for deleted state)
3. Release Elastic IPs
4. Disassociate and delete custom route tables
5. Detach and delete Internet Gateway
6. Delete subnets
7. Delete security groups (non-default)
8. Delete VPC
