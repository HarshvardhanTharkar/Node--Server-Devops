# =============================================================================
# ecr.tf — Amazon Elastic Container Registry
# =============================================================================
#
# ECR is AWS's fully managed Docker image registry.
# Why ECR vs Docker Hub?
#   - Images stay inside the AWS network — no egress costs, faster pulls
#   - IAM integration — no separate registry credentials to manage
#   - Native Trivy + AWS Inspector image scanning
#   - Lifecycle policies prevent unbounded storage growth
#   - Private by default

resource "aws_ecr_repository" "app" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  # MUTABLE allows pushing the same tag (e.g. 'latest') multiple times.
  # For production, consider IMMUTABLE (once a tag is pushed, it cannot be overwritten)
  # to improve audit traceability.

  # Enable ECR's built-in vulnerability scanning.
  # Images are scanned automatically on every push using the Clair open-source scanner.
  # We also run Trivy in the pipeline for defence-in-depth.
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest using AWS-managed KMS key.
  # For stricter compliance (PCI-DSS, HIPAA) use a customer-managed CMK.
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr"
  })
}

# ─── Lifecycle Policy ─────────────────────────────────────────────────────────
# Without a lifecycle policy ECR will accumulate images indefinitely.
# This policy keeps only the N most recent tagged images and removes
# all untagged images after 1 day.
#
# Untagged images accumulate when:
#   - A new 'latest' tag overwrites the previous manifest
#   - A build fails partway through pushing layers
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      # Rule 1: Keep the N most recent tagged images
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_image_retention_count} tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "build-", "latest"]
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_image_retention_count
        }
        action = { type = "expire" }
      },
      # Rule 2: Remove untagged images after 1 day
      {
        rulePriority = 2
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}
