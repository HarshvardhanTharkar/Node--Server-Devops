# =============================================================================
# main.tf — Data Sources and Shared Resources
# =============================================================================
#
# This file contains data sources (read existing AWS resources) and any
# resources that don't cleanly belong to a single other file.

# ─── Data Sources ─────────────────────────────────────────────────────────────

# Retrieve the caller's AWS account ID.
# Used to build ARNs (e.g. ECR repository URI) without hard-coding account numbers.
data "aws_caller_identity" "current" {}

# Retrieve the current AWS region.
# Allows us to reference the region in resource definitions consistently.
data "aws_region" "current" {}

# ─── Random Suffix ────────────────────────────────────────────────────────────
# Append a random hex string to globally unique resources (S3, ECR) to avoid
# name collisions when the same config is deployed in multiple AWS accounts.
resource "random_id" "suffix" {
  byte_length = 4
}

# ─── Local Values (computed constants) ────────────────────────────────────────
# Locals are computed once and referenced many times — like constants.
# They reduce repetition and make intent clearer.
locals {
  # Naming convention: <project>-<environment>-<resource>
  name_prefix = "${var.project_name}-${var.environment}"

  # ECR repo name must be lowercase letters, numbers, hyphens, underscores, dots
  ecr_repo_name = "${var.project_name}-app"

  # Common tags merged into every resource (in addition to provider default_tags)
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Terraform   = "true"
  }

  # Account ID and region for constructing ARNs
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
