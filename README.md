# Node.js CI/CD Pipeline
### Jenkins · Docker · Terraform · AWS ECR · EC2 · SonarQube · Trivy · GitHub Webhooks

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](http://jenkins-url)
[![SonarQube Quality Gate](https://img.shields.io/badge/quality%20gate-passed-brightgreen)](http://sonarqube-url)
[![Trivy Security](https://img.shields.io/badge/security-scanned-blue)](https://github.com/aquasecurity/trivy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Project Overview

A **production-style end-to-end CI/CD pipeline** demonstrating real-world DevOps practices.

Every `git push` to the main branch automatically:
1. Runs unit tests with coverage enforcement
2. Analyses code quality with SonarQube
3. Fails the build if the Quality Gate is not met
4. Builds a hardened Docker image (multi-stage, non-root, health checks)
5. Scans the image for CVEs using Trivy
6. Pushes the image to AWS ECR
7. Deploys to EC2 via SSH
8. Verifies deployment health from Jenkins

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                      │   │
│  │                                                            │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │            Public Subnet (10.0.1.0/24)             │  │   │
│  │  │                                                     │  │   │
│  │  │  ┌─────────────────────────────────────────────┐   │  │   │
│  │  │  │          EC2 Instance (t3.medium)           │   │  │   │
│  │  │  │                                             │   │  │   │
│  │  │  │  ┌───────────┐  ┌───────────────────────┐  │   │  │   │
│  │  │  │  │  Jenkins  │  │  SonarQube (Docker)   │  │   │  │   │
│  │  │  │  │  :8080    │  │  :9000                │  │   │  │   │
│  │  │  │  └─────┬─────┘  └───────────────────────┘  │   │  │   │
│  │  │  │        │                                     │   │  │   │
│  │  │  │  ┌─────▼─────────────────────────────────┐  │   │  │   │
│  │  │  │  │     Node.js App Container :3000        │  │   │  │   │
│  │  │  │  │  GET /  /health  /api/status /version  │  │   │  │   │
│  │  │  │  └───────────────────────────────────────┘  │   │  │   │
│  │  │  │                                             │   │  │   │
│  │  │  │   Security Group: 22, 80, 3000, 8080, 9000  │   │  │   │
│  │  │  └─────────────────────────────────────────────┘   │  │   │
│  │  │                          │                          │  │   │
│  │  │              Internet Gateway (IGW)                  │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────────────┐                              │
│  │  ECR Repository                │                              │
│  │  nodejs-cicd-app               │                              │
│  │  (Docker image registry)       │                              │
│  └────────────────────────────────┘                              │
└─────────────────────────────────────────────────────────────────┘
                          │
                    Internet │
                          │
                ┌──────────┴──────────┐
                │   Developer's        │
                │   Machine            │
                │   git push → GitHub  │
                └─────────────────────┘
```

---

## CI/CD Pipeline Flow

```
git push
   │
   ▼
GitHub Webhook ──────────────────────────────────────────────────────────────┐
                                                                              │
                                                                    Jenkins Pipeline
                                                                              │
                ┌─────────────────────────────────────────────────────────────┘
                ▼
        ┌───────────────┐
        │  1. Checkout  │  Clone repo, set build metadata
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  2. Install   │  npm ci (deterministic, fast)
        │    Deps       │
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  3. Unit      │  Jest tests + coverage ≥ 70%
        │    Tests      │  ──FAIL──► Build fails
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  4. SonarQube │  Static analysis: bugs, vulns,
        │    Analysis   │  code smells, duplications
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  5. Quality   │  SonarQube Quality Gate check
        │    Gate       │  ──FAIL──► Build fails
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  6. Docker    │  Multi-stage build, non-root user
        │    Build      │  tagged: build-<N>-<sha> + latest
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  7. Trivy     │  Scan image for CVEs
        │    Scan       │  HIGH/CRITICAL ──FAIL──► Build fails
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  8. ECR Login │  aws ecr get-login-password
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │  9. Push to   │  docker push versioned + latest tags
        │    ECR        │
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │ 10. Deploy    │  SSH → deploy.sh → pull/stop/run
        │    to EC2     │  with automatic rollback on failure
        └───────┬───────┘
                ▼
        ┌───────────────┐
        │ 11. Health    │  Verify /health /version /api/status
        │    Check      │  from Jenkins (external perspective)
        └───────┬───────┘
                ▼
           ✅ SUCCESS  or  ❌ FAILURE → notification
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.6 | Provision AWS infrastructure |
| AWS CLI | v2 | AWS API interaction |
| Git | any | Source control |
| AWS Account | — | Cloud provider |

An AWS account with permissions to create: EC2, ECR, VPC, IAM roles.

---

## Terraform Deployment

### Step 1: Configure AWS credentials

```bash
# Option A: Environment variables (CI/CD)
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option B: AWS credentials file (local dev)
aws configure
```

### Step 2: Create an EC2 Key Pair

```bash
aws ec2 create-key-pair \
    --key-name my-ec2-key \
    --query 'KeyMaterial' \
    --output text > my-ec2-key.pem

chmod 400 my-ec2-key.pem
```

### Step 3: Edit terraform.tfvars

```bash
cd terraform
cp terraform.tfvars terraform.tfvars   # already exists, edit it
nano terraform.tfvars
```

Change `key_pair_name` to match the key pair you created.

### Step 4: Deploy Infrastructure

```bash
cd terraform

# Initialise: download AWS provider plugin
terraform init

# Format: auto-format code to canonical style
terraform fmt

# Validate: check syntax without making API calls
terraform validate

# Plan: preview what will be created (no changes made)
terraform plan -out=tfplan

# Apply: create all resources (~3 minutes)
terraform apply tfplan

# Note the outputs — you'll need them:
terraform output jenkins_url
terraform output ecr_repository_url
terraform output ec2_public_ip
```

### Step 5: Wait for Bootstrap to Complete

EC2 user-data installs Jenkins, Docker, Trivy, etc. Allow 5 minutes.

```bash
# SSH into the instance
ssh -i my-ec2-key.pem ec2-user@$(terraform output -raw ec2_public_ip)

# Watch bootstrap progress
sudo tail -f /var/log/user-data.log

# Get Jenkins initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Teardown (when done)

```bash
terraform destroy
# Confirm with 'yes'
# This removes ALL resources and stops billing
```

---

## Jenkins Setup

See [docs/jenkins-setup.md](docs/jenkins-setup.md) for the full step-by-step guide.

**Quick summary:**
1. Open `http://<EC2-IP>:8080`, paste initial admin password
2. Install suggested plugins + extras from `jenkins/plugins.txt`
3. Add credentials: AWS, EC2 SSH key, ECR URI, EC2 IP
4. Configure SonarQube server integration
5. Create Pipeline job pointing to this repo
6. Configure GitHub webhook

---

## SonarQube Setup

```bash
# SonarQube starts automatically via Docker on the EC2 instance
# Access the UI:
open http://<EC2-IP>:9000

# Default credentials (CHANGE IMMEDIATELY):
Username: admin
Password: admin
```

1. Create a project: **Projects → Create project manually**
   - Project key: `nodejs-cicd-app`
   - Display name: `Node.js CI/CD Demo App`
2. Generate a token: **My Account → Security → Generate Token**
   - Name: `jenkins-token`
3. Copy token and add to Jenkins credentials as `sonarqube-token`
4. Configure the server in Jenkins (see jenkins-setup.md)

---

## Trivy Security Scanning

Trivy is installed on the EC2 instance by the bootstrap script.

### Manual scan commands:

```bash
# Scan filesystem (checks npm package vulnerabilities)
trivy fs --severity HIGH,CRITICAL app/

# Scan Docker image
trivy image --severity HIGH,CRITICAL nodejs-cicd-app:latest

# Scan with JSON output (for CI artefacts)
trivy image --format json --output trivy-report.json nodejs-cicd-app:latest

# Scan with exit code (fail if HIGH/CRITICAL found)
trivy image --exit-code 1 --severity HIGH,CRITICAL nodejs-cicd-app:latest
```

### Understanding CVE severity levels:
| Level | Description | Pipeline action |
|-------|-------------|-----------------|
| CRITICAL | Exploitable, high impact | ❌ Fail build |
| HIGH | Exploitable, significant impact | ❌ Fail build |
| MEDIUM | May be exploitable | ⚠️ Warn only |
| LOW | Minimal risk | ✅ Allow |

---

## ECR Setup

ECR is provisioned by Terraform. No manual setup needed.

```bash
# Get the ECR URI
ECR_URI=$(cd terraform && terraform output -raw ecr_repository_url)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin $ECR_URI

# Build and push manually (for testing)
docker build -t $ECR_URI:manual-test ./app
docker push $ECR_URI:manual-test

# List images in ECR
aws ecr list-images --repository-name nodejs-cicd-app
```

---

## Application Endpoints

| Endpoint | Description | Response |
|----------|-------------|----------|
| `GET /` | Root health check | `{ status: "ok" }` |
| `GET /health` | Detailed health | Memory, uptime, system info |
| `GET /api/status` | API status | Service statuses, metadata |
| `GET /version` | Build info | Version, git commit, build number |

---

## Local Development

```bash
# Clone the repo
git clone https://github.com/<username>/nodejs-cicd-pipeline
cd nodejs-cicd-pipeline/app

# Install dependencies
npm install

# Copy and configure env
cp .env.example .env

# Run in development mode
npm run dev     # Uses nodemon for auto-reload

# Run tests
npm test

# Run tests with coverage report
npm test -- --coverage

# Build and run Docker image locally
docker build -t nodejs-cicd-app:local .
docker run -p 3000:3000 --env-file .env nodejs-cicd-app:local

# Check health
curl http://localhost:3000/health
```

---

## Docker Commands Reference

```bash
# Build
docker build -t nodejs-cicd-app:latest ./app

# Run
docker run -d \
    --name nodejs-app \
    -p 3000:3000 \
    -e NODE_ENV=production \
    nodejs-cicd-app:latest

# Inspect running container
docker inspect nodejs-app

# View logs (follow)
docker logs -f nodejs-app

# Execute shell in running container
docker exec -it nodejs-app sh

# Check container resource usage
docker stats nodejs-app

# Stop and remove
docker stop nodejs-app && docker rm nodejs-app
```

---

## Troubleshooting

### Jenkins won't start
```bash
sudo systemctl status jenkins
sudo journalctl -u jenkins -n 50
sudo cat /var/log/jenkins/jenkins.log
```

### SonarQube won't start
```bash
docker logs sonarqube
# Common cause: vm.max_map_count too low
sudo sysctl -w vm.max_map_count=262144
docker restart sonarqube
```

### Docker permission denied on Jenkins
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### ECR authentication failure
```bash
# Verify IAM role has ECR permissions
aws ecr get-login-password --region us-east-1
# If this fails: check IAM role attached to EC2 instance
```

### Pipeline fails at Quality Gate
- Check SonarQube server URL in Jenkins configuration
- Ensure the SonarQube token is valid and not expired
- Check SonarQube is running: `docker ps | grep sonarqube`

### Deployment health check fails
```bash
# SSH to EC2 and check container
docker ps
docker logs nodejs-app
curl http://localhost:3000/health
```

---

## Project Structure

```
project-root/
│
├── app/                          # Node.js application
│   ├── package.json              # Dependencies and scripts
│   ├── server.js                 # HTTP server entry point
│   ├── app.js                    # Express app configuration
│   ├── sonar-project.properties  # SonarQube project config
│   ├── Dockerfile                # Multi-stage production image
│   ├── .dockerignore             # Excluded from Docker build context
│   ├── .env.example              # Environment variable template
│   ├── routes/
│   │   ├── health.js             # / and /health routes
│   │   ├── api.js                # /api/* routes
│   │   └── version.js            # /version route
│   ├── controllers/
│   │   ├── healthController.js   # Health check business logic
│   │   ├── apiController.js      # API status business logic
│   │   └── versionController.js  # Version/build metadata
│   ├── middleware/
│   │   ├── errorHandler.js       # Global error handling
│   │   └── requestLogger.js      # Per-request logging + request ID
│   ├── utils/
│   │   └── logger.js             # Winston logger configuration
│   └── tests/
│       └── app.test.js           # Jest integration tests
│
├── terraform/                    # Infrastructure as Code
│   ├── providers.tf              # AWS provider + version pins
│   ├── variables.tf              # Input variable declarations
│   ├── main.tf                   # Data sources + locals
│   ├── vpc.tf                    # VPC, subnet, IGW, route tables
│   ├── security-groups.tf        # EC2 firewall rules
│   ├── ec2.tf                    # EC2 instance + IAM role
│   ├── ecr.tf                    # ECR repository + lifecycle policy
│   ├── outputs.tf                # Output values after apply
│   └── terraform.tfvars          # Variable values (do not commit secrets)
│
├── jenkins/
│   ├── plugins.txt               # Required Jenkins plugins list
│   └── iam-policy.json           # Least-privilege IAM policy
│
├── scripts/
│   ├── install-jenkins.sh        # EC2 bootstrap (user-data) script
│   └── deploy.sh                 # Application deployment + rollback
│
├── docs/
│   ├── jenkins-setup.md          # Jenkins configuration walkthrough
│   └── github-webhook.md         # GitHub webhook setup guide
│
├── Jenkinsfile                   # 11-stage declarative pipeline
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

---

## Security Best Practices Implemented

| Practice | Implementation |
|----------|---------------|
| Least Privilege IAM | EC2 role only has ECR + CloudWatch + SSM permissions |
| No hardcoded secrets | All secrets in Jenkins credentials / AWS SSM |
| Non-root container | Dockerfile creates and uses `appuser` |
| Image scanning | Trivy scans for CVEs before push to ECR |
| SonarQube | Detects security hotspots in source code |
| Minimal base image | node:20-alpine (~50 MB vs ~900 MB full) |
| Multi-stage build | Dev tools never ship to production |
| Rate limiting | Express rate-limit middleware (100 req/15 min) |
| Security headers | Helmet.js sets 14 security HTTP headers |
| Encrypted EBS | EC2 root volume encrypted at rest |
| ECR encryption | Images encrypted with AES-256 |
| Lifecycle policies | Old images auto-deleted from ECR |

---

## Future Improvements

- [ ] **HTTPS / TLS** — Add ACM certificate + ALB with HTTPS listener
- [ ] **Blue/Green Deployment** — ALB + two EC2 target groups, zero-downtime
- [ ] **ECS Fargate** — Replace EC2 with serverless containers
- [ ] **Kubernetes** — Deploy to EKS with Helm charts
- [ ] **Notifications** — Slack/Teams webhook on build success/failure
- [ ] **Multi-environment** — dev/staging/production Terraform workspaces
- [ ] **Database** — Add RDS PostgreSQL with SSM parameter integration
- [ ] **Monitoring** — CloudWatch dashboard + Grafana
- [ ] **Secret Rotation** — AWS Secrets Manager with automatic rotation
- [ ] **WAF** — AWS WAF on ALB for DDoS and OWASP protection
- [ ] **OIDC Auth** — Replace IAM user access keys with GitHub Actions OIDC

---

## License

MIT © DevOps Engineer
