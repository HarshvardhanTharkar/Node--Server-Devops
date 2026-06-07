# =============================================================================
# providers.tf — Terraform & AWS Provider Configuration
# =============================================================================
#
# This file declares which provider plugins Terraform must download and
# pins them to exact versions for reproducible infrastructure builds.
# Never omit version constraints — a provider upgrade can introduce
# breaking changes or security issues.

terraform {
  # Minimum Terraform CLI version required
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31" # Allow 5.31.x patch releases, but not 6.x
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ── Remote State (optional but recommended for teams) ──────────────────────
  # Storing state in S3 with DynamoDB locking prevents two engineers from
  # running `terraform apply` simultaneously and corrupting state.
  # Uncomment and configure once you have the S3 bucket + DynamoDB table.
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "nodejs-cicd/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

# ─── AWS Provider ──────────────────────────────────────────────────────────
# The provider authenticates using the AWS credentials chain:
#   1. Environment variables: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
#   2. Shared credentials file: ~/.aws/credentials
#   3. IAM Instance Profile (on EC2)
# Never hard-code credentials here.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
    }
  }
}
