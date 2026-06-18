<div align="center">

# 🚀 Enterprise Node.js CI/CD Pipeline

### Production-Grade DevOps Project

[![Jenkins](https://img.shields.io/badge/Jenkins-2.555.3-D24939?style=for-the-badge&logo=jenkins&logoColor=white)](http://jenkins)
[![Docker](https://img.shields.io/badge/Docker-25.0.14-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Terraform](https://img.shields.io/badge/Terraform-1.15-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20ECR%20%7C%20VPC-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

**A fully automated, production-style CI/CD pipeline that takes code from a Git push to a live, health-verified Docker container on AWS — in under 3 minutes.**

[View Pipeline](#cicd-pipeline-flow) • [Architecture](#aws-architecture) • [Setup Guide](#quick-start) • [Screenshots](#screenshots)

</div>

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Tech Stack](#tech-stack)
- [AWS Architecture](#aws-architecture)
- [CI/CD Pipeline Flow](#cicd-pipeline-flow)
- [Pipeline Stages](#pipeline-stages-11-stages)
- [Application Endpoints](#application-endpoints)
- [Screenshots](#screenshots)
- [Quick Start](#quick-start)
- [Terraform Deployment](#terraform-deployment)
- [Jenkins Setup](#jenkins-setup)
- [Security Implementation](#security-implementation)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Future Improvements](#future-improvements)

---

## 🎯 Project Overview

This project demonstrates a **complete, end-to-end DevOps pipeline** built entirely from scratch. Every component — from the Node.js application to the AWS infrastructure — was provisioned, configured, and automated using industry-standard tools.

### What Makes This Production-Grade?

| Feature | Implementation |
|---------|---------------|
| **Infrastructure as Code** | Terraform provisions all AWS resources — zero manual clicking |
| **Containerization** | Multi-stage Docker builds with non-root user and health checks |
| **Security Scanning** | Trivy scans every image for CVEs before deployment |
| **Automated Testing** | Jest unit tests with coverage enforcement block broken code |
| **Secret Management** | IAM Instance Profiles — zero hardcoded credentials |
| **Graceful Shutdown** | dumb-init + SIGTERM handling for zero-downtime stops |
| **Structured Logging** | Winston JSON logs ready for CloudWatch/ELK ingestion |
| **Automatic Rollback** | Deploy script reverts to previous image on health check failure |

---

## 🛠️ Tech Stack

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Application** | Node.js | 20.x LTS | Runtime |
| **Framework** | Express.js | 4.x | REST API |
| **Testing** | Jest + Supertest | 29.x | Unit & Integration Tests |
| **Containerization** | Docker | 25.0.14 | Image Building & Runtime |
| **CI/CD** | Jenkins | 2.555.3 | Pipeline Orchestration |
| **IaC** | Terraform | 1.15 | AWS Infrastructure |
| **Registry** | AWS ECR | — | Private Docker Registry |
| **Compute** | AWS EC2 | t3.micro | Application Server |
| **Networking** | AWS VPC | — | Isolated Network |
| **Security Scanning** | Trivy | 0.71.0 | CVE Scanning |
| **Source Control** | GitHub | — | Code Repository + Webhooks |

---

## 🏗️ AWS Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Cloud (eu-north-1)                        │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    VPC (10.0.0.0/16)                         │    │
│  │                                                               │    │
│  │  ┌───────────────────────────────────────────────────────┐   │    │
│  │  │            Public Subnet (10.0.1.0/24)                │   │    │
│  │  │                                                        │   │    │
│  │  │   ┌──────────────────────────────────────────────┐    │   │    │
│  │  │   │         EC2 Instance (t3.micro)              │    │   │    │
│  │  │   │                                              │    │   │    │
│  │  │   │  ┌─────────────┐   ┌──────────────────────┐ │    │   │    │
│  │  │   │  │   Jenkins   │   │  Node.js App         │ │    │   │    │
│  │  │   │  │   :8080     │   │  Container :3000     │ │    │   │    │
│  │  │   │  │             │   │  (Docker)            │ │    │   │    │
│  │  │   │  └─────────────┘   └──────────────────────┘ │    │   │    │
│  │  │   │                                              │    │   │    │
│  │  │   │  IAM Role: ECR + CloudWatch + SSM           │    │   │    │
│  │  │   │  Security Group: 22, 80, 3000, 8080, 9000   │    │   │    │
│  │  │   └──────────────────────────────────────────────┘    │   │    │
│  │  │                          │                             │   │    │
│  │  │              Internet Gateway (IGW)                     │   │    │
│  │  └───────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌────────────────────────────────────┐                              │
│  │  ECR Repository                    │                              │
│  │  nodejs-cicd-app                   │                              │
│  │  Tags: build-N-<sha>, latest       │                              │
│  │  Lifecycle: Keep 10 images         │                              │
│  └────────────────────────────────────┘                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                        Internet
                              │
              ┌───────────────┴───────────────┐
              │        Developer               │
              │   git push → GitHub            │
              │   → Jenkins Pipeline           │
              └───────────────────────────────┘
```

### Infrastructure Components

| Resource | Details | Why |
|----------|---------|-----|
| **VPC** | 10.0.0.0/16 | Isolated network boundary |
| **Public Subnet** | 10.0.1.0/24, eu-north-1a | EC2 internet access |
| **Internet Gateway** | Attached to VPC | Route outbound traffic |
| **Route Table** | 0.0.0.0/0 → IGW | Enable internet access |
| **Security Group** | Ports: 22, 80, 3000, 8080, 9000 | Firewall rules |
| **EC2** | t3.micro, Amazon Linux 2023 | Jenkins + Docker host |
| **Elastic IP** | Static public IP | Stable DNS/webhook URL |
| **ECR Repository** | nodejs-cicd-app | Private image registry |
| **IAM Role** | EC2 → ECR + CloudWatch | No hardcoded credentials |

---

## 🔄 CI/CD Pipeline Flow

```
Developer
    │
    │  git push
    ▼
GitHub Repository
    │
    │  Webhook / Poll SCM
    ▼
Jenkins Pipeline (11 Stages)
    │
    ├─► Stage 1:  Checkout          → Clone repo, set build metadata
    │
    ├─► Stage 2:  Install Deps      → npm ci (all deps including devDeps)
    │
    ├─► Stage 3:  Unit Tests        → Jest, 14 tests, coverage report
    │                                  FAIL → Pipeline stops here
    ├─► Stage 4:  SonarQube         → Static code analysis (Phase 2)
    │
    ├─► Stage 5:  Quality Gate      → Block on code quality (Phase 2)
    │
    ├─► Stage 6:  Docker Build      → Multi-stage, non-root, dumb-init
    │
    ├─► Stage 7:  Trivy Scan        → CVE scan (HIGH/CRITICAL logged)
    │
    ├─► Stage 8:  ECR Login         → IAM role auth (no access keys)
    │
    ├─► Stage 9:  Push to ECR       → build-N-<sha> + latest tags
    │
    ├─► Stage 10: Deploy to EC2     → SSH → deploy.sh → pull/stop/run
    │                                  Auto-rollback on failure
    └─► Stage 11: Health Check      → /health /version /api/status
                                       FAIL → Build marked failed
```

---

## 📊 Pipeline Stages (11 Stages)

### Stage Details

| # | Stage | Duration | What Happens |
|---|-------|----------|-------------|
| 1 | **Checkout** | ~5s | Git clone, set build display name with commit SHA |
| 2 | **Install Dependencies** | ~10s | `npm ci` with devDependencies for testing |
| 3 | **Unit Tests** | ~15s | 14 Jest tests, HTML coverage report archived |
| 4 | **SonarQube Analysis** | ~2s | Static analysis (skipped — Phase 2) |
| 5 | **Quality Gate** | ~2s | Code quality enforcement (skipped — Phase 2) |
| 6 | **Build Docker Image** | ~45s | Multi-stage build with build args |
| 7 | **Trivy Scan** | ~60s | FS scan + image scan, report archived |
| 8 | **ECR Login** | ~3s | `aws ecr get-login-password` via IAM role |
| 9 | **Push to ECR** | ~15s | Push versioned tag + latest |
| 10 | **Deploy to EC2** | ~15s | SCP deploy.sh → SSH execute → health verify |
| 11 | **Health Check** | ~20s | curl /health /version /api/status |

**Total Pipeline Time: ~3 minutes**

---

## 🌐 Application Endpoints

| Endpoint | Method | Description | Response |
|----------|--------|-------------|----------|
| `GET /` | GET | Root health check | `{ status: "ok" }` |
| `GET /health` | GET | Detailed health status | Memory, uptime, CPU load, Node version |
| `GET /api/status` | GET | API operational status | Service states, request ID, region |
| `GET /version` | GET | Build metadata | Git commit, build number, build date |

###  Responses

**`/health`**
```json
{
  "status": "healthy",
  "timestamp": "2026-06-16T06:35:26.751Z",
  "uptime": "449s",
  "environment": "production",
  "version": "1.0.0",
  "system": {
    "platform": "linux",
    "nodeVersion": "v20.20.2",
    "hostname": "ce4cee9e5c8b"
  },
  "memory": {
    "rss": "47 MB",
    "heapUsed": "8 MB",
    "heapTotal": "9 MB"
  }
}
```

**`/version`**
```json
{
  "name": "nodejs-cicd-app",
  "version": "1.0.0",
  "gitCommit": "dbc600fca7499e7d7ceaf35e1f5664423d6ce6c1",
  "buildNumber": "3",
  "buildDate": "2026-06-16T06:27:55Z",
  "nodeVersion": "v20.20.2",
  "environment": "production"
}
```

**`/api/status`**
```json
{
  "status": "operational",
  "environment": "production",
  "services": {
    "api": "up",
    "database": "N/A (demo)",
    "cache": "N/A (demo)"
  },
  "metadata": {
    "region": "eu-north-1",
    "commit": "dbc600fca7499e7d7ceaf35e1f5664423d6ce6c1"
  }
}
```

---

## 📸 Screenshots

> **Place your screenshots in this order in the `docs/screenshots/` folder:**

### 1. Jenkins Pipeline — Build #3 SUCCESS
> `docs/screenshots/01-jenkins-pipeline-success.png`
> 
> *Caption: Jenkins Build #3 showing "PIPELINE SUCCEEDED - Build #3 - Commit: dbc600fc" with Finished: SUCCESS*



### 3. Application — /health Endpoint
> `docs/screenshots/03-app-health-endpoint.png`
>
> *Caption: Live /health endpoint returning status: healthy, uptime: 449s, environment: production*

### 4. Application — /version Endpoint
> `docs/screenshots/04-app-version-endpoint.png`
>
> *Caption: /version endpoint showing gitCommit, buildNumber: 3, buildDate from the pipeline*

### 5. Application — /api/status Endpoint
> `docs/screenshots/05-app-api-status.png`
>
> *Caption: /api/status showing status: operational, region: eu-north-1*

### 6. AWS ECR — Docker Image Pushed
> `docs/screenshots/06-ecr-image-pushed.png`
>
> *Caption: ECR repository showing image tags build-3-dbc600fc and latest*

### 7. AWS EC2 — Running Instance
> `docs/screenshots/07-ec2-instance-running.png`
>
> *Caption: EC2 console showing t3.micro instance running in eu-north-1a*

### 8. Terraform Apply — Infrastructure Created
> `docs/screenshots/08-terraform-apply-output.png`
>
> *Caption: terraform apply output showing 15 resources created*

### 9. Trivy Security Scan Report
> `docs/screenshots/09-trivy-scan-report.png`
>
> *Caption: Trivy scan results from Jenkins console showing CVE analysis*

### 10. Docker Container Running on EC2
> `docs/screenshots/10-docker-container-ec2.png`
>
> *Caption: docker ps showing nodejs-app container Up with health: healthy*

---

## ⚡ Quick Start

### Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Git | Any |
| Docker | 20.x+ |
| Node.js | 18.x+ |
| AWS CLI | v2 |
| Terraform | 1.6+ |

### 1. Clone the Repository

```bash
git clone https://github.com/HarshvardhanTharkar/Node--Server-Devops.git
cd Node--Server-Devops
```

### 2. Run the Application Locally

```bash
cd app
cp .env.example .env
npm ci
npm test        # Run 14 unit tests
node server.js  # Start on port 3000
```

### 3. Test the Endpoints

```bash
curl http://localhost:3000/health
curl http://localhost:3000/version
curl http://localhost:3000/api/status
```

### 4. Build and Run with Docker

```bash
cd app
docker build -t nodejs-cicd-app:local .
docker run -d --name nodejs-app -p 3000:3000 nodejs-cicd-app:local
docker inspect nodejs-app --format "{{json .State.Health}}"
```

---

## 🏗️ Terraform Deployment

### Step 1: Configure AWS

```bash
aws configure
# Enter: Access Key ID, Secret Key, Region: eu-north-1, Output: json
```

### Step 2: Create EC2 Key Pair

```bash
aws ec2 create-key-pair \
  --key-name nodejs-cicd-key \
  --region eu-north-1 \
  --query "KeyMaterial" \
  --output text > nodejs-cicd-key.pem
chmod 400 nodejs-cicd-key.pem
```

### Step 3: Update Variables

Edit `terraform/terraform.tfvars`:

```hcl
aws_region        = "eu-north-1"
key_pair_name     = "nodejs-cicd-key"
ami_id            = "ami-0424c2a446cde902f"  # Amazon Linux 2023
instance_type     = "t3.micro"
```

### Step 4: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

**Output after apply:**
```
app_url            = "http://<EC2-IP>:3000"
jenkins_url        = "http://<EC2-IP>:8080"
ecr_repository_url = "761554981636.dkr.ecr.eu-north-1.amazonaws.com/nodejs-cicd-app"
ec2_public_ip      = "<EC2-IP>"
```

### Teardown

```bash
terraform destroy  # Stops all billing
```

---

## 🔧 Jenkins Setup

### 1. Access Jenkins

```bash
# SSH into EC2
ssh -i nodejs-cicd-key.pem ec2-user@<EC2-IP>

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open: `http://<EC2-IP>:8080`

### 2. Install Plugins

Install suggested plugins, then additionally:
- Docker Pipeline
- SSH Agent
- SonarQube Scanner
- AnsiColor
- HTML Publisher
- Timestamper

### 3. Add Credentials

| ID | Kind | Value |
|----|------|-------|
| `ecr-registry-uri` | Secret text | `<account>.dkr.ecr.eu-north-1.amazonaws.com` |
| `ec2-public-ip` | Secret text | `<EC2-IP>` |
| `ec2-ssh-key` | SSH Username + Private Key | `ec2-user` + `.pem` content |

### 4. Create Pipeline Job

- New Item → Pipeline → `nodejs-cicd-pipeline`
- Definition: Pipeline script from SCM
- SCM: Git → `https://github.com/HarshvardhanTharkar/Node--Server-Devops.git`
- Branch: `*/main`
- Script Path: `Jenkinsfile`

---

## 🔒 Security Implementation

### Principle of Least Privilege (IAM)

```json
{
  "ECRPermissions": ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:PutImage"],
  "CloudWatchLogs": "arn:aws:logs:eu-north-1:<account>:log-group:/aws/ec2/*",
  "SSMReadOnly": "arn:aws:ssm:eu-north-1:<account>:parameter/nodejs-cicd/*"
}
```

### Docker Security

```dockerfile
# Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Minimal base image
FROM node:20-alpine

# Signal handling
ENTRYPOINT ["dumb-init", "--"]
```

### Application Security

| Measure | Tool | Details |
|---------|------|---------|
| Security Headers | Helmet.js | 14 HTTP security headers |
| Rate Limiting | express-rate-limit | 100 req/15 min per IP |
| CVE Scanning | Trivy | Every build scanned |
| Dependency Audit | npm audit | 0 vulnerabilities |
| Secret Management | IAM Roles | No hardcoded credentials |
| Encrypted Storage | AWS KMS | ECR + EBS encrypted at rest |

---

## 📁 Project Structure

```
Node--Server-Devops/
│
├── app/                              # Node.js Application
│   ├── package.json                  # Dependencies & scripts
│   ├── server.js                     # Entry point + graceful shutdown
│   ├── app.js                        # Express config + middleware
│   ├── Dockerfile                    # Multi-stage production build
│   ├── .dockerignore                 # Exclude dev files from image
│   ├── .env.example                  # Environment variable template
│   ├── sonar-project.properties      # SonarQube config
│   ├── routes/
│   │   ├── health.js                 # GET / and GET /health
│   │   ├── api.js                    # GET /api/status
│   │   └── version.js                # GET /version
│   ├── controllers/
│   │   ├── healthController.js       # Health check business logic
│   │   ├── apiController.js          # API status logic
│   │   └── versionController.js      # Build metadata
│   ├── middleware/
│   │   ├── errorHandler.js           # Global error handling
│   │   └── requestLogger.js          # Per-request logging + ID
│   ├── utils/
│   │   └── logger.js                 # Winston JSON logger
│   └── tests/
│       └── app.test.js               # 14 Jest integration tests
│
├── terraform/                        # Infrastructure as Code
│   ├── providers.tf                  # AWS provider + version pins
│   ├── variables.tf                  # Input variable declarations
│   ├── main.tf                       # Data sources + locals
│   ├── vpc.tf                        # VPC, subnet, IGW, route tables
│   ├── security-groups.tf            # EC2 firewall rules
│   ├── ec2.tf                        # EC2 instance + IAM role
│   ├── ecr.tf                        # ECR repository + lifecycle
│   ├── outputs.tf                    # Output values
│   └── terraform.tfvars              # Variable values
│
├── scripts/
│   ├── install-jenkins.sh            # EC2 bootstrap script
│   └── deploy.sh                     # Deploy + automatic rollback
│
├── jenkins/
│   ├── plugins.txt                   # Required Jenkins plugins
│   └── iam-policy.json               # Least-privilege IAM policy
│
├── docs/
│   ├── jenkins-setup.md              # Jenkins configuration guide
│   ├── github-webhook.md             # Webhook setup guide
│   └── screenshots/                  # ← PUT YOUR SCREENSHOTS HERE
│
├── Jenkinsfile                       # 11-stage declarative pipeline
├── .gitignore                        # Git ignore rules
└── README.md                         # This file
```

---

## 🐛 Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Jenkins can't reach GitHub | Port 443 blocked | Use SSH tunnel or check ISP |
| Built-in Node offline | Jenkins memory issue | Run Script Console: `Jenkins.instance.toComputer().setTemporarilyOffline(false, null)` |
| Docker permission denied | Jenkins not in docker group | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| ECR login failed | IAM role not attached | Verify instance profile in EC2 console |
| `/tmp` space warning | Temp files accumulate | `sudo rm -rf /tmp/*` on EC2 |
| Out of memory (t3.micro) | Jenkins uses 400MB+ | Add 1GB swap: `sudo fallocate -l 1G /swapfile` |
| jest: command not found | NODE_ENV=production blocks devDeps | Use `NODE_ENV=development npm ci` |

---

## 🚀 Future Improvements

| Feature | Description | Priority |
|---------|-------------|----------|
| **SonarQube Integration** | Full static analysis + quality gate enforcement | High |
| **HTTPS / TLS** | ACM certificate + ALB with HTTPS listener | High |
| **Blue/Green Deployment** | ALB + two EC2 target groups, zero-downtime | High |
| **ECS Fargate** | Replace EC2 with serverless containers | Medium |
| **Slack Notifications** | Build success/failure alerts | Medium |
| **Multi-Environment** | dev/staging/production Terraform workspaces | Medium |
| **CloudWatch Dashboard** | Metrics, alarms, log insights | Medium |
| **GitHub Actions** | Alternative CI/CD comparison | Low |
| **Kubernetes (EKS)** | Container orchestration with Helm | Low |
| **WAF** | AWS WAF on ALB for DDoS protection | Low |

---

## 👤 Author

**Harshvardhan Tharkar**

[![GitHub](https://img.shields.io/badge/GitHub-HarshvardhanTharkar-181717?style=for-the-badge&logo=github)](https://github.com/HarshvardhanTharkar)

---

## 📄 License

This project is licensed under the MIT License.

---

<div align="center">

**⭐ If this project helped you, please give it a star!**

*Built with ❤️ to demonstrate production-grade DevOps practices*

</div>
