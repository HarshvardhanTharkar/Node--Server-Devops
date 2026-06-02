# =============================================================================
# security-groups.tf — EC2 Security Groups (Firewall Rules)
# =============================================================================
#
# Security Groups act as a virtual firewall for EC2 instances.
# They are STATEFUL — if you allow inbound port 80, the response traffic
# is automatically allowed outbound without an explicit egress rule.
#
# LEAST PRIVILEGE PRINCIPLE:
#   Only open the ports actually needed.
#   Never use 0.0.0.0/0 for sensitive ports like SSH in production;
#   restrict to your bastion or VPN CIDR.

resource "aws_security_group" "jenkins_ec2" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for Jenkins/Docker EC2 instance"
  vpc_id      = aws_vpc.main.id

  # ── Inbound Rules ─────────────────────────────────────────────────────────

  # SSH — Remote administration.
  # In production, replace 0.0.0.0/0 with your corporate CIDR or bastion IP.
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # TODO: restrict to your IP in production
  }

  # HTTP — Node.js application traffic from the internet or ALB.
  ingress {
    description = "HTTP application traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node.js app direct port — allows testing without a reverse proxy.
  ingress {
    description = "Node.js application port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins UI — Web-based CI/CD dashboard.
  ingress {
    description = "Jenkins web UI"
    from_port   = var.jenkins_port
    to_port     = var.jenkins_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # TODO: restrict to your IP in production
  }

  # SonarQube UI — Code quality dashboard.
  ingress {
    description = "SonarQube web UI"
    from_port   = var.sonarqube_port
    to_port     = var.sonarqube_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # TODO: restrict to your IP in production
  }

  # ── Outbound Rules ────────────────────────────────────────────────────────
  # Allow ALL outbound traffic.
  # The instance needs internet access for: apt-get, npm, ECR push, AWS API calls.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"   # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
