# GitHub Webhook Configuration
## Triggering Jenkins on Every `git push`

---

## Overview

A webhook is an HTTP POST request that GitHub sends to Jenkins whenever
a specified event occurs (e.g., push, pull request, tag).

Without webhooks, Jenkins would poll GitHub every minute — wasteful and delayed.
With webhooks, builds trigger **within seconds** of a git push.

```
Developer → git push → GitHub → Webhook HTTP POST → Jenkins → Pipeline starts
```

---

## Step 1: Configure Jenkins to Accept Webhooks

### 1a. Enable GitHub Plugin

**Manage Jenkins → Configure System → GitHub:**
- Add GitHub Server
- API URL: `https://api.github.com`
- Credentials: Add a GitHub Personal Access Token (PAT)
  - Token scope: `repo`, `admin:repo_hook`

### 1b. Make Jenkins Accessible from the Internet

Your Jenkins must be reachable by GitHub's servers.
The EC2 Elastic IP + port 8080 already satisfies this.

**Security Group** must allow inbound TCP on port 8080 from:
- GitHub's webhook IP ranges (see https://api.github.com/meta → `hooks` field)
- Or 0.0.0.0/0 (less secure but easier for a demo)

### 1c. Generate a Webhook Secret

Generate a strong random secret:
```bash
openssl rand -hex 32
# Example output: a7f3c2b8e4d1f9a6b2c5e8f3a1d4g7h2...
```

Add this secret as a Jenkins credential:
- Kind: **Secret text**
- ID: `github-webhook-secret`
- Secret: `<your-generated-secret>`

---

## Step 2: Add Webhook to GitHub Repository

1. Go to your GitHub repository
2. **Settings → Webhooks → Add webhook**
3. Configure:
   ```
   Payload URL:   http://<EC2-ELASTIC-IP>:8080/github-webhook/
   Content type:  application/json
   Secret:        <your-generated-secret>
   SSL:           Disable SSL verification (if using HTTP, not HTTPS)
   ```
4. **Which events?** Choose:
   - ✅ Just the push event
   - (Or: Let me select → Push, Pull requests)
5. **Active:** ✅
6. Click **Add webhook**

---

## Step 3: Configure Jenkins Pipeline to React to Webhooks

In your Jenkins Pipeline job configuration:

**Build Triggers:**
- ✅ **GitHub hook trigger for GITScm polling**

This tells Jenkins to accept the webhook and start a build.

---

## Step 4: Verify Webhook Works

1. Make a commit and push to the main branch:
   ```bash
   git add .
   git commit -m "test: trigger webhook"
   git push origin main
   ```

2. In GitHub → **Repository Settings → Webhooks → Recent Deliveries**
   - You should see a green ✅ delivery
   - Response: `200 OK`

3. In Jenkins, the pipeline should start within 5 seconds.

---

## Webhook Payload Structure

GitHub sends a JSON payload with the push event details:

```json
{
  "ref": "refs/heads/main",
  "before": "abc123...",
  "after": "def456...",
  "repository": {
    "name": "nodejs-cicd-pipeline",
    "full_name": "username/nodejs-cicd-pipeline",
    "clone_url": "https://github.com/username/nodejs-cicd-pipeline.git"
  },
  "pusher": {
    "name": "username",
    "email": "user@example.com"
  },
  "commits": [
    {
      "id": "def456...",
      "message": "test: trigger webhook",
      "author": { "name": "Developer" }
    }
  ]
}
```

Jenkins uses the `ref` field to determine which branch was pushed to
and only triggers builds for the configured branch (e.g., `main`).

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Webhook shows red ❌ in GitHub | Check EC2 security group allows port 8080 |
| 403 Forbidden | Verify the secret matches between GitHub and Jenkins |
| Build doesn't trigger | Ensure "GitHub hook trigger for GITScm polling" is checked |
| Connection refused | Confirm Jenkins is running: `systemctl status jenkins` |
