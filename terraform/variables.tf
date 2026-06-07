# =============================================================================
# variables.tf — Input Variable Declarations
# =============================================================================
#
# Variables make Terraform configurations reusable across environments.
# Actual values live in terraform.tfvars (not committed to git if they
# contain secrets) or are supplied via -var flags / environment variables.

# ─── Core ─────────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region name (e.g. us-east-1, ap-south-1)."
  }
}

variable "project_name" {
  description = "Prefix applied to every resource name for easy identification"
  type        = string
  default     = "nodejs-cicd"
}

variable "environment" {
  description = "Deployment environment (dev | staging | production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

# ─── Networking ───────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ to place the public subnet in"
  type        = string
  default     = "us-east-1a"
}

# ─── EC2 ──────────────────────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type for the Jenkins/app server"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4 GB — enough for Jenkins + Docker
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
  # No default — must be provided via terraform.tfvars
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2023 recommended)"
  type        = string
  default     = "ami-0c101f26f147fa7fd" # Amazon Linux 2023, us-east-1 (update per region)
}

# ─── ECR ──────────────────────────────────────────────────────────────────────
variable "ecr_image_retention_count" {
  description = "Number of images to keep in ECR before older ones are deleted"
  type        = number
  default     = 10
}

# ─── Application ──────────────────────────────────────────────────────────────
variable "app_port" {
  description = "Port the Node.js container listens on"
  type        = number
  default     = 3000
}

variable "jenkins_port" {
  description = "Port Jenkins web UI listens on"
  type        = number
  default     = 8080
}

variable "sonarqube_port" {
  description = "Port SonarQube web UI listens on"
  type        = number
  default     = 9000
}
