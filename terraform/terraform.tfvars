# =============================================================================
# terraform.tfvars — Variable Values
# =============================================================================
#
# This file overrides variable defaults for your specific deployment.
#
# ⚠️  NEVER commit this file to git if it contains secrets.
#     Add terraform.tfvars to .gitignore.
#     For secrets, use AWS SSM Parameter Store or Terraform Cloud variables.
#
# Terraform automatically loads this file if it's named terraform.tfvars
# or *.auto.tfvars.

# ─── Core ──────────────────────────────────────────────────────────────────
aws_region   = "us-east-1"
project_name = "nodejs-cicd"
environment  = "dev"

# ─── Networking ────────────────────────────────────────────────────────────
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone  = "us-east-1a"

# ─── EC2 ───────────────────────────────────────────────────────────────────
instance_type = "t3.medium"
key_pair_name = "my-ec2-key"        # ← Replace with your actual key pair name
ami_id        = "ami-0c101f26f147fa7fd"  # Amazon Linux 2023, us-east-1

# ─── ECR ───────────────────────────────────────────────────────────────────
ecr_image_retention_count = 10

# ─── Application Ports ─────────────────────────────────────────────────────
app_port       = 3000
jenkins_port   = 8080
sonarqube_port = 9000
