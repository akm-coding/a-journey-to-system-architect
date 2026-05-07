# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: EC2 Instance
# =============================================================================
#
# Same structure as staging. In a real production environment, you might:
#   - Use a larger instance type (t3.small or t3.medium)
#   - Add an Auto Scaling Group (covered in Phase 6)
#   - Put instances behind an ALB (covered in Phase 6)
#
# For this learning project, we keep it as a single instance to match staging.
# =============================================================================

# Look up the latest Amazon Linux 2023 AMI (same data source as staging)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [module.vpc.app_sg_id]
  key_name               = var.key_pair_name

  # user_data runs ONLY on first boot -- same Docker setup as staging
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name        = "${var.environment}-app"
    Environment = var.environment
  }
}
