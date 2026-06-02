# =============================================================================
# outputs.tf — Terraform Output Values
# =============================================================================
#
# Outputs are printed after `terraform apply` and can be read by other
# Terraform workspaces or CI scripts via `terraform output -raw <name>`.
#
# Usage example in a CI script:
#   ECR_URI=$(cd terraform && terraform output -raw ecr_repository_url)
#   EC2_IP=$(cd terraform && terraform output -raw ec2_public_ip)

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "ec2_public_ip" {
  description = "Elastic IP address of the Jenkins server (static)"
  value       = aws_eip.jenkins.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.jenkins.public_dns
}

output "ecr_repository_url" {
  description = "Full ECR repository URI — used in docker tag and docker push commands"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "Short ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "jenkins_url" {
  description = "URL to access the Jenkins web UI"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "app_url" {
  description = "URL to access the deployed Node.js application"
  value       = "http://${aws_eip.jenkins.public_ip}:3000"
}

output "sonarqube_url" {
  description = "URL to access the SonarQube web UI"
  value       = "http://${aws_eip.jenkins.public_ip}:9000"
}

output "security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.jenkins_ec2.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance"
  value       = aws_iam_role.ec2_role.arn
}
