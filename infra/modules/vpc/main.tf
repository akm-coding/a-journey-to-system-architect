# =============================================================================
# Reusable VPC Module: Network + Security Groups
# =============================================================================
#
# Creates a complete VPC with:
#   - Public subnets (for EC2 instances with internet access)
#   - Private subnets (for RDS -- no direct internet access)
#   - Internet Gateway + route tables
#   - Three security groups: app (EC2), rds, rds_proxy
#
# This module is used by BOTH staging and production environments.
# The only difference between environments is the variable values passed in.
# This is the core value of Terraform modules: write once, deploy many.
#
# Architecture:
#
#   Internet
#      |
#   [IGW]
#      |
#   [Public Route Table] --> 0.0.0.0/0 -> IGW
#      |
#   [Public Subnet AZ-a]  [Public Subnet AZ-b]   <-- EC2 lives here
#      |
#   [Private Route Table] --> no internet route
#      |
#   [Private Subnet AZ-a] [Private Subnet AZ-b]  <-- RDS lives here
#
# =============================================================================

# =============================================================================
# VPC
# =============================================================================
#
# The VPC is the top-level network container. All subnets, route tables,
# and security groups exist within this VPC.
#
# enable_dns_hostnames: Allows EC2 instances to get public DNS names
#   (e.g., ec2-1-2-3-4.ap-southeast-1.compute.amazonaws.com)
# enable_dns_support: Enables the Amazon-provided DNS server in the VPC
#   (required for RDS endpoint resolution)

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# =============================================================================
# Internet Gateway
# =============================================================================
#
# The IGW connects the VPC to the public internet. Without it, nothing
# in the VPC can reach the internet (or be reached from the internet).
# Only public subnets route through the IGW.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# =============================================================================
# Public Subnets
# =============================================================================
#
# Public subnets are for resources that need internet access (EC2 instances).
# map_public_ip_on_launch = true means EC2 instances get a public IP
# automatically, so they're reachable from the internet.
#
# We create one subnet per availability zone using count. This gives us
# redundancy -- if one AZ goes down, services in the other AZ still work.

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# =============================================================================
# Private Subnets
# =============================================================================
#
# Private subnets are for resources that should NOT be directly accessible
# from the internet (RDS, RDS Proxy). No public IP assignment, no route
# to the internet gateway.
#
# IMPORTANT: RDS subnet groups require subnets in at least 2 different AZs,
# even for single-AZ deployments. This is an AWS requirement, not optional.
# (See RESEARCH.md pitfall #6: DBSubnetGroupDoesNotCoverEnoughAZs)

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-private-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# =============================================================================
# Route Tables
# =============================================================================
#
# Route tables control where network traffic goes.
#
# Public route table: Routes 0.0.0.0/0 (all internet traffic) through the IGW.
#   This is what makes a subnet "public" -- the route to the internet.
#
# Private route table: Has NO route to the internet. Only the default
#   local route (VPC CIDR -> local) exists, so private subnets can only
#   talk to other resources within the VPC. RDS doesn't need outbound
#   internet access.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # No routes -- only the implicit local route (VPC CIDR -> local) exists.
  # This means private subnets can communicate within the VPC but not
  # reach the internet. Perfect for databases.

  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# Security Groups
# =============================================================================
#
# Security groups act as virtual firewalls for resources. We define THREE
# separate groups with a clear chain of trust:
#
#   Internet --> [app SG] --> [rds_proxy SG] --> [rds SG]
#
# The key pattern here is "SG referencing": instead of allowing traffic from
# an IP range, we allow traffic from another security group. This means
# "any resource in SG X can talk to resources in SG Y", regardless of IP.
#
# IMPORTANT: We use separate aws_security_group_rule resources instead of
# inline ingress/egress blocks. This avoids circular dependency errors
# when security groups reference each other. (See RESEARCH.md pitfall #4)
# =============================================================================

# -----------------------------------------------------------------------------
# App Security Group (for EC2 instances)
# -----------------------------------------------------------------------------
#
# The app server needs to:
#   - Accept HTTP (80), HTTPS (443), and SSH (22) from the internet
#   - Send traffic anywhere (to pull Docker images, call external APIs, etc.)

resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Security group for app EC2 instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-app-sg"
    Environment = var.environment
  }
}

# Allow HTTP traffic from anywhere (for serving the web application)
resource "aws_security_group_rule" "app_http_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "HTTP from internet"
}

# Allow HTTPS traffic from anywhere (for serving the web application over TLS)
resource "aws_security_group_rule" "app_https_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "HTTPS from internet"
}

# Allow SSH from anywhere (for server administration)
# In production, you might restrict this to your IP or a bastion host
resource "aws_security_group_rule" "app_ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "SSH from internet"
}

# Allow all outbound traffic (for pulling Docker images, DNS, API calls)
resource "aws_security_group_rule" "app_all_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "All outbound traffic"
}

# -----------------------------------------------------------------------------
# RDS Security Group (for PostgreSQL database)
# -----------------------------------------------------------------------------
#
# The database should ONLY accept connections from the app security group.
# This is the "SG referencing" pattern from Phase 2: instead of allowing
# a CIDR block, we allow a source security group. If we add more EC2
# instances to the app SG, they automatically get database access.

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-rds-sg"
    Environment = var.environment
  }
}

# Allow PostgreSQL connections from the RDS Proxy security group only.
# The app never connects directly to RDS -- it goes through the proxy.
# The proxy's SG is what gets database access, not the app SG directly.
resource "aws_security_group_rule" "rds_postgres_in" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds_proxy.id
  security_group_id        = aws_security_group.rds.id
  description              = "PostgreSQL from RDS Proxy"
}

# Allow all outbound traffic
resource "aws_security_group_rule" "rds_all_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "All outbound traffic"
}

# -----------------------------------------------------------------------------
# RDS Proxy Security Group
# -----------------------------------------------------------------------------
#
# RDS Proxy sits between the app and the database. It pools connections
# so multiple app instances share a smaller number of database connections.
#
# Traffic flow: App (port 5432) --> RDS Proxy --> RDS (port 5432)

resource "aws_security_group" "rds_proxy" {
  name        = "${var.environment}-rds-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-rds-proxy-sg"
    Environment = var.environment
  }
}

# Allow PostgreSQL connections from the app security group
resource "aws_security_group_rule" "rds_proxy_postgres_in" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.rds_proxy.id
  description              = "PostgreSQL from app instances"
}

# Allow PostgreSQL connections to the RDS security group
resource "aws_security_group_rule" "rds_proxy_postgres_out" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.rds_proxy.id
  description              = "PostgreSQL to RDS instances"
}
