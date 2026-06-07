# =============================================================================
# vpc.tf — Virtual Private Cloud Networking
# =============================================================================
#
# This file creates the complete network stack:
#   VPC → Subnet → Internet Gateway → Route Table → Associations
#
# Why a custom VPC?
#   The AWS default VPC is fine for experiments but not production because:
#     - Its CIDR (172.31.0.0/16) is shared and opaque
#     - Default security groups are overly permissive
#     - No audit trail of who changed what
#   A custom VPC gives us full control and is the industry standard.

# ─── VPC ─────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Required for EC2 hostnames to resolve
  enable_dns_hostnames = true # Assigns public DNS names to EC2 instances

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ─── Internet Gateway ─────────────────────────────────────────────────────────
# An Internet Gateway (IGW) is the VPC's door to the public internet.
# Without it, instances in public subnets cannot send/receive internet traffic.
# One IGW per VPC; it scales automatically and has no bandwidth limit.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ─── Public Subnet ────────────────────────────────────────────────────────────
# A subnet is a range of IPs within the VPC.
# "Public" means instances here can have a public IP and route traffic via the IGW.
#
# map_public_ip_on_launch = true
#   → EC2 instances in this subnet automatically receive a public IP.
#     Needed for SSH access and outbound internet (ECR pulls, apt-get, etc.)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet"
    Type = "public"
  })
}

# ─── Route Table ──────────────────────────────────────────────────────────────
# A route table contains rules that determine where network traffic is directed.
# The default route (0.0.0.0/0) pointing to the IGW is what makes a subnet "public".
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route — send all internet-bound traffic to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# ─── Route Table Association ──────────────────────────────────────────────────
# Associate the route table with the subnet.
# Without this association, the subnet uses the VPC's default (local-only) route table
# and instances cannot reach the internet even with an IGW attached.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
