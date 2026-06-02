#!/bin/bash
# =============================================================================
# scripts/install-jenkins.sh — EC2 Bootstrap Script
# =============================================================================
#
# This script runs as EC2 user-data on first boot (as root).
# It installs and configures:
#   1. System updates
#   2. Java 17 (Jenkins dependency)
#   3. Jenkins LTS
#   4. Docker Engine
#   5. Git
#   6. AWS CLI v2
#   7. Trivy (security scanner)
#
# Logs are written to /var/log/user-data.log for debugging.
# To view: sudo cat /var/log/user-data.log
# =============================================================================

set -euxo pipefail
# -e  exit immediately on error
# -u  treat unset variables as errors
# -x  print each command before executing (for debugging)
# -o pipefail  catch errors in pipelines (cmd1 | cmd2)

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "=============================="
echo "Bootstrap started: $(date)"
echo "=============================="

# ─── 1. System Update ─────────────────────────────────────────────────────────
echo ">>> Updating system packages..."
dnf update -y
dnf install -y \
    git \
    curl \
    wget \
    unzip \
    tar \
    jq \
    htop \
    tree

# ─── 2. Java 17 ───────────────────────────────────────────────────────────────
# Jenkins requires Java 11 or 17. We use 17 (LTS) for best compatibility.
echo ">>> Installing Java 17..."
dnf install -y java-17-amazon-corretto-headless
java -version

# ─── 3. Jenkins LTS ───────────────────────────────────────────────────────────
# Add the official Jenkins YUM repository (Long Term Support channel).
# LTS releases are more stable and receive back-ported security fixes.
echo ">>> Installing Jenkins LTS..."
wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf upgrade -y
dnf install -y jenkins

# Start Jenkins and enable it to survive reboots
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

echo "Jenkins service status:"
systemctl status jenkins --no-pager

# ─── 4. Docker Engine ─────────────────────────────────────────────────────────
# We install Docker CE (Community Edition) directly from Docker's repo.
# Docker is needed to:
#   - Build the Node.js Docker image in the pipeline
#   - Run SonarQube as a container
#   - Run the application container on this same EC2 instance
echo ">>> Installing Docker..."
dnf install -y docker
systemctl enable docker
systemctl start docker

# Add jenkins user to the docker group so Jenkins can run docker commands
# without sudo. Requires a logout/login to take effect, but user-data
# runs before Jenkins starts, so it's fine.
usermod -aG docker jenkins
usermod -aG docker ec2-user

echo "Docker version: $(docker --version)"

# ─── 5. Docker Compose ────────────────────────────────────────────────────────
echo ">>> Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.0"
curl -SL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
echo "Docker Compose version: $(docker-compose --version)"

# ─── 6. AWS CLI v2 ────────────────────────────────────────────────────────────
# AWS CLI v2 is used by the Jenkins pipeline to:
#   - Authenticate to ECR (aws ecr get-login-password)
#   - Interact with EC2 and SSM
echo ">>> Installing AWS CLI v2..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws
echo "AWS CLI version: $(aws --version)"

# ─── 7. Trivy ─────────────────────────────────────────────────────────────────
# Trivy is an open-source container and filesystem vulnerability scanner.
# It scans both the source code (npm packages) and the Docker image for CVEs.
echo ">>> Installing Trivy..."
TRIVY_VERSION="0.48.3"
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.rpm" \
    -o /tmp/trivy.rpm
rpm -ivh /tmp/trivy.rpm
rm /tmp/trivy.rpm
echo "Trivy version: $(trivy --version)"

# ─── 8. Node.js 20 (for local testing / debugging) ─────────────────────────
echo ">>> Installing Node.js 20..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# ─── 9. SonarQube Scanner CLI ─────────────────────────────────────────────────
# The Jenkins SonarQube plugin manages its own scanner, but having the CLI
# available is useful for manual analysis and debugging.
echo ">>> Installing SonarScanner CLI..."
SONAR_SCANNER_VERSION="5.0.1.3006"
curl -fsSL \
    "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip" \
    -o /tmp/sonar-scanner.zip
unzip -q /tmp/sonar-scanner.zip -d /opt/
ln -sf "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux/bin/sonar-scanner" /usr/local/bin/sonar-scanner
rm /tmp/sonar-scanner.zip
echo "SonarScanner version: $(sonar-scanner --version 2>&1 | head -1)"

# ─── 10. Create SonarQube Data Directory ──────────────────────────────────────
# SonarQube Docker container will mount this directory for persistent data.
mkdir -p /opt/sonarqube/{data,extensions,logs}
chown -R 1000:1000 /opt/sonarqube   # SonarQube runs as UID 1000 inside the container

# ─── 11. Kernel Tuning for SonarQube (Elasticsearch) ─────────────────────────
# Elasticsearch (used by SonarQube internally) requires a higher vm.max_map_count.
# Without this SonarQube will fail to start.
echo ">>> Configuring kernel parameters for Elasticsearch..."
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# ─── 12. Start SonarQube ──────────────────────────────────────────────────────
echo ">>> Starting SonarQube container..."
docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  -e SONAR_JAVA_OPTS="-Xmx512m -Xms256m" \
  sonarqube:lts-community

# ─── 13. Wait for Jenkins to be ready ────────────────────────────────────────
echo ">>> Waiting for Jenkins to start..."
JENKINS_URL="http://localhost:8080"
MAX_WAIT=120
WAIT=0
until curl -sf "${JENKINS_URL}/login" > /dev/null || [ $WAIT -ge $MAX_WAIT ]; do
  echo "Waiting for Jenkins... (${WAIT}s)"
  sleep 5
  WAIT=$((WAIT+5))
done

if [ $WAIT -ge $MAX_WAIT ]; then
  echo "WARNING: Jenkins did not start within ${MAX_WAIT}s, continuing..."
else
  echo "Jenkins is up!"
fi

# Print initial admin password location
echo ""
echo "================================================================"
echo " JENKINS INITIAL ADMIN PASSWORD LOCATION:"
echo "   sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "================================================================"
echo ""
echo "Bootstrap complete: $(date)"
