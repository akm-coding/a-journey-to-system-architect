# =============================================================================
# Staging Environment: EC2 Instance
# =============================================================================
#
# The app server runs on EC2 with Docker installed via user_data.
# After provisioning, deploy by SSH-ing in and running docker compose.
#
# The AMI is looked up dynamically using a data source instead of
# hardcoding an AMI ID. This is important because:
#   - AMI IDs differ between AWS regions
#   - Amazon releases new AMIs regularly with security patches
#   - A hardcoded AMI might not exist in the learner's region
# =============================================================================

# Look up the latest Amazon Linux 2023 AMI.
# This runs at plan time and always finds the newest version.
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

  # user_data runs ONLY on the first boot of the instance.
  # If you change this script, Terraform will recreate the instance
  # (destroy + create) because user_data is immutable after launch.
  #
  # This script installs Docker so the instance is ready to run
  # containers immediately after provisioning.
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
