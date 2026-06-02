# =============================================================================
# ec2.tf — EC2 Instance + IAM Role
# =============================================================================
#
# This file provisions:
#   1. IAM Role + Instance Profile — grants the EC2 instance AWS API permissions
#      without embedding long-lived access keys (security best practice)
#   2. EC2 Instance                — the virtual machine that runs Jenkins + Docker
#   3. Elastic IP                  — static public IP so DNS doesn't change on restart

# ─── IAM Role ─────────────────────────────────────────────────────────────────
# The IAM role defines WHAT the EC2 instance is allowed to do in AWS.
# Using a role (vs hard-coded access keys) means:
#   - Credentials rotate automatically (short-lived tokens)
#   - No secrets to accidentally commit to git
#   - Easy to audit via CloudTrail

resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  # Trust policy — allows EC2 service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# ─── IAM Policy — Least Privilege ─────────────────────────────────────────────
# Grant ONLY the permissions the pipeline needs. This is the Principle of Least
# Privilege: if credentials are compromised, blast radius is minimal.
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${local.name_prefix}-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ECR — Authenticate, pull images, push images, describe repositories
      {
        Sid    = "ECRPermissions"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",           # docker login to ECR
          "ecr:BatchCheckLayerAvailability",     # check if layers exist (optimization)
          "ecr:GetDownloadUrlForLayer",          # pull image layers
          "ecr:BatchGetImage",                   # pull full images
          "ecr:InitiateLayerUpload",             # push image layers
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",                        # push image manifest
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
        ]
        Resource = "*"
      },

      # CloudWatch Logs — publish application and Jenkins logs
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/ec2/*"
      },

      # EC2 Metadata — read instance metadata (region, instance ID)
      {
        Sid    = "EC2Metadata"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
        ]
        Resource = "*"
      },

      # SSM Parameter Store — read secrets (DB passwords, tokens)
      # Use this instead of embedding secrets in environment variables
      {
        Sid    = "SSMReadOnly"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${var.project_name}/*"
      },
    ]
  })
}

# Attach AWS managed policy for ECR read access (belt-and-suspenders)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ─── Instance Profile ─────────────────────────────────────────────────────────
# An Instance Profile is a container for an IAM Role that EC2 can use.
# The EC2 instance references the profile (not the role directly).
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = local.common_tags
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jenkins_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # 30 GB root volume — Jenkins workspace + Docker images can be large
  root_block_device {
    volume_type           = "gp3"   # gp3 is cheaper and faster than gp2
    volume_size           = 30
    delete_on_termination = true    # Delete the disk when instance is terminated
    encrypted             = true    # Encrypt at rest (compliance requirement)

    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-root-volume"
    })
  }

  # User data script runs once at first boot to configure the instance.
  # It references the jenkins installation script from the scripts directory.
  user_data = file("${path.module}/../scripts/install-jenkins.sh")

  # Prevent accidental destruction of the instance in production.
  # Remove this block when doing a planned replacement.
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jenkins-server"
    Role = "jenkins-docker-server"
  })
}

# ─── Elastic IP ───────────────────────────────────────────────────────────────
# An Elastic IP gives the instance a static public IP.
# Without it, the public IP changes every time the instance stops/starts,
# breaking DNS records and Jenkins webhook URLs.
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  # EIP must be created AFTER the IGW
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip"
  })
}
