# Jenkins Setup Guide
## Complete Step-by-Step Configuration

---

## 1. Access Jenkins for the First Time

After the EC2 instance boots (allow 5 minutes for user-data to complete):

```bash
# Get initial admin password
ssh -i your-key.pem ec2-user@<EC2-PUBLIC-IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open browser: `http://<EC2-PUBLIC-IP>:8080`
- Paste the initial admin password
- Choose **Install Suggested Plugins**
- Create your admin user

---

## 2. Install Required Plugins

**Manage Jenkins → Plugin Manager → Available Plugins**

Search and install each plugin from `plugins.txt`:
- Pipeline (workflow-aggregator)
- Docker Pipeline (docker-workflow)
- SonarQube Scanner (sonar)
- GitHub Integration (github)
- AWS Credentials (aws-credentials)
- Pipeline: AWS Steps (pipeline-aws)
- SSH Agent (ssh-agent)
- HTML Publisher (htmlpublisher)
- AnsiColor (ansicolor)
- Timestamper

Restart Jenkins after installation.

---

## 3. Configure Credentials

**Manage Jenkins → Credentials → System → Global → Add Credentials**

### 3a. AWS Credentials
- Kind: **AWS Credentials**
- ID: `aws-credentials`
- Access Key ID: `<your-aws-access-key>`
- Secret Access Key: `<your-aws-secret-key>`

> **Security note:** Prefer IAM Instance Profile over access keys.
> If Jenkins runs on EC2 with an IAM role, no credentials are needed here.

### 3b. EC2 SSH Key
- Kind: **SSH Username with private key**
- ID: `ec2-ssh-key`
- Username: `ec2-user`
- Private Key: (paste your .pem key content)

### 3c. ECR Registry URI
- Kind: **Secret text**
- ID: `ecr-registry-uri`
- Secret: `<account-id>.dkr.ecr.us-east-1.amazonaws.com`

### 3d. EC2 Public IP
- Kind: **Secret text**
- ID: `ec2-public-ip`
- Secret: `<your-ec2-elastic-ip>`

---

## 4. Configure SonarQube Integration

### 4a. Get SonarQube Token
1. Open `http://<EC2-IP>:9000`
2. Login with `admin / admin` (change immediately!)
3. **My Account → Security → Generate Token**
4. Name: `jenkins-token`, Generate, **copy the token**

### 4b. Add SonarQube Token to Jenkins
**Manage Jenkins → Credentials → Add:**
- Kind: **Secret text**
- ID: `sonarqube-token`
- Secret: `<paste token>`

### 4c. Configure SonarQube Server in Jenkins
**Manage Jenkins → Configure System → SonarQube servers:**
- Name: `SonarQube`
- Server URL: `http://localhost:9000`
- Server authentication token: `sonarqube-token`

### 4d. Configure SonarScanner Tool
**Manage Jenkins → Global Tool Configuration → SonarQube Scanner:**
- Name: `SonarScanner`
- Install automatically: ✅
- Version: latest

---

## 5. Create the Pipeline Job

**New Item → Pipeline → Name: nodejs-cicd-pipeline**

**Configuration:**
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/<your-username>/nodejs-cicd-pipeline`
- **Credentials:** (add GitHub credentials if private repo)
- **Branch:** `*/main`
- **Script Path:** `Jenkinsfile`

Save and click **Build Now** for the first run.

---

## 6. Configure GitHub Webhook

See the GitHub Webhook setup guide in `docs/github-webhook.md`.

---

## 7. Verify Everything Works

Run a manual build and confirm all 11 stages pass ✅
