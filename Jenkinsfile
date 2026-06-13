// =============================================================================
// Jenkinsfile — Declarative Pipeline
// =============================================================================
//
// This is the heart of the CI/CD project. Every git push triggers this
// pipeline, which runs 11 stages in sequence:
//
//   Checkout → Install Deps → Unit Tests → SonarQube → Quality Gate
//   → Build Image → Trivy Scan → ECR Login → Push Image
//   → Deploy to EC2 → Health Check
//
// Declarative Pipeline vs Scripted Pipeline:
//   Declarative (this file) uses a structured syntax that is easier to read,
//   provides built-in error handling, and integrates better with Blue Ocean UI.
//   Scripted Pipeline (Groovy) is more flexible but harder to maintain.
//
// Prerequisites (configure in Jenkins before running):
//   1. Credentials:
//      - aws-credentials   → AWS Access Key + Secret (type: AWS Credentials)
//      - ec2-ssh-key        → Private key for EC2 SSH (type: SSH Username with Private Key)
//   2. Global Tools:
//      - SonarQube Scanner → configured in Manage Jenkins → Configure System
//   3. Plugins:
//      - Pipeline, Docker Pipeline, SonarQube Scanner,
//        GitHub, Credentials, AWS Steps, SSH Pipeline Steps
// =============================================================================

pipeline {

    // ── Agent ────────────────────────────────────────────────────────────────
    // 'any' runs the pipeline on any available Jenkins agent (including master).
    // For production, use a labeled agent: agent { label 'docker' }
    agent any

    // ── Environment Variables ─────────────────────────────────────────────────
    // These are available in every stage as shell variables.
    environment {
        // ── Application ───────────────────────────────────────────────────
        APP_NAME        = "nodejs-cicd-app"
        APP_PORT        = "3000"
        NODE_ENV        = "production"

        // ── AWS / ECR ──────────────────────────────────────────────────────
        AWS_REGION      = "us-east-1"
        // Read ECR URI from a Jenkins credential (secret text) so it's not
        // hard-coded in source code.
        ECR_REGISTRY    = credentials('ecr-registry-uri')   // e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com
        ECR_REPO        = "nodejs-cicd-app"

        // ── Image Tagging ─────────────────────────────────────────────────
        // Tag every image with the Jenkins build number AND the git commit SHA.
        // This makes it trivial to find which code is deployed.
        IMAGE_TAG       = "build-${BUILD_NUMBER}-${GIT_COMMIT[0..7]}"
        LATEST_TAG      = "latest"

        // ── SonarQube ──────────────────────────────────────────────────────
        SONAR_PROJECT_KEY = "nodejs-cicd-app"

        // ── EC2 ────────────────────────────────────────────────────────────
        // Read the EC2 IP from a Jenkins credential (secret text)
        EC2_HOST        = credentials('ec2-public-ip')
        EC2_USER        = "ec2-user"
    }

    // ── Options ──────────────────────────────────────────────────────────────
    options {
        // Cancel the build if it runs longer than 30 minutes (hung build protection)
        timeout(time: 30, unit: 'MINUTES')
        // Keep only the last 10 build logs (saves disk space on Jenkins master)
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Prevent concurrent builds on the same branch (avoids race conditions)
        disableConcurrentBuilds()
        // Add timestamps to console output
        timestamps()
        // ANSI colour codes in console output
        ansiColor('xterm')
    }

    // ── Triggers ─────────────────────────────────────────────────────────────
    triggers {
        // Poll SCM every minute as a fallback if the GitHub webhook fails
        // In production, webhooks are preferred (immediate trigger, no polling overhead)
        pollSCM('H/1 * * * *')
    }

    // ═════════════════════════════════════════════════════════════════════════
    // STAGES
    // ═════════════════════════════════════════════════════════════════════════
    stages {

        // ── Stage 1: Checkout ─────────────────────────────────────────────────
        // Jenkins automatically checks out the code that triggered the build.
        // We add an explicit stage to print useful metadata and set the build name.
        stage('Checkout') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Checkout                 ║"
                echo "╚══════════════════════════════════╝"

                // checkout scm uses the SCM configuration from the pipeline job.
                // For Multibranch pipelines this is set automatically.
                checkout scm

                script {
                    // Set a descriptive build display name
                    currentBuild.displayName = "#${BUILD_NUMBER} - ${GIT_COMMIT[0..7]}"
                    currentBuild.description = "Branch: ${GIT_BRANCH}"
                }

                sh '''
                    echo "Build Number  : ${BUILD_NUMBER}"
                    echo "Git Commit    : ${GIT_COMMIT}"
                    echo "Git Branch    : ${GIT_BRANCH}"
                    echo "Workspace     : ${WORKSPACE}"
                    echo "Node.js version: $(node --version)"
                    echo "npm version    : $(npm --version)"
                    echo "Docker version : $(docker --version)"
                '''
            }
        }

        // ── Stage 2: Install Dependencies ─────────────────────────────────────
        stage('Install Dependencies') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Install Dependencies     ║"
                echo "╚══════════════════════════════════╝"

                dir('app') {
                    sh '''
                        # npm ci installs exact versions from package-lock.json
                        # It is faster and more reliable than npm install in CI
                        npm ci

                        echo "Installed packages:"
                        npm list --depth=0
                    '''
                }
            }
        }

        // ── Stage 3: Unit Tests ───────────────────────────────────────────────
        // Jest runs all test files in app/tests/ and enforces coverage thresholds.
        // The build fails here if coverage drops below 70% (configured in package.json).
        stage('Unit Test') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Unit Tests               ║"
                echo "╚══════════════════════════════════╝"

                dir('app') {
                    sh 'npm test'
                }
            }
            post {
                always {
                    // Publish JUnit XML report to Jenkins test results page
                    // Jest writes this when --reporters=jest-junit is configured
                    // For now, publish coverage HTML report
                    publishHTML(target: [
                        allowMissing         : false,
                        alwaysLinkToLastBuild: false,
                        keepAll              : true,
                        reportDir            : 'app/coverage/lcov-report',
                        reportFiles          : 'index.html',
                        reportName           : 'Coverage Report'
                    ])
                }
            }
        }

        // ── Stage 4: SonarQube Analysis ───────────────────────────────────────
        // SonarQube performs static code analysis to detect:
        //   - Bugs (incorrect code patterns)
        //   - Vulnerabilities (security hotspots)
        //   - Code Smells (maintainability issues)
        //   - Duplicated code
        //   - Coverage gaps
        //
        // The analysis results are sent to the SonarQube server (running on this EC2).
       stage('SonarQube Analysis') {
    steps {
        echo "SonarQube skipped — will be configured in Phase 2"
    }
}

        // ── Stage 5: Quality Gate ─────────────────────────────────────────────
        // The Quality Gate is a set of conditions defined in SonarQube.
        // Default conditions: no new bugs, no new vulnerabilities, coverage ≥ 80%.
        // If any condition fails, this stage marks the build as UNSTABLE or FAILED.
        //
        // abortPipeline: true → fails the build if the gate fails.
        // This prevents broken code from being promoted to production.
        stage('Quality Gate') {
            steps {
        echo "Quality Gate skipped — will be configured in Phase 2"
    }
        }

        // ── Stage 6: Build Docker Image ───────────────────────────────────────
        // Build the production Docker image using the multi-stage Dockerfile.
        // The image is tagged with:
        //   1. The build-specific tag (build-42-abc1234)
        //   2. The 'latest' tag
        stage('Build Docker Image') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Build Docker Image       ║"
                echo "╚══════════════════════════════════╝"

                dir('app') {
                    sh """
                        echo "Building image: ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

                        docker build \
                            --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                            --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                            --build-arg GIT_COMMIT=${GIT_COMMIT} \
                            --build-arg APP_VERSION=1.0.${BUILD_NUMBER} \
                            -t ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \
                            -t ${ECR_REGISTRY}/${ECR_REPO}:${LATEST_TAG} \
                            .

                        echo "Image built successfully!"
                        docker images | grep ${ECR_REPO}
                    """
                }
            }
        }

        // ── Stage 7: Trivy Security Scan ──────────────────────────────────────
        // Trivy scans the Docker image for known CVEs (Common Vulnerabilities
        // and Exposures) in OS packages and application dependencies.
        //
        // --exit-code 1 → fail the pipeline if HIGH or CRITICAL CVEs are found.
        // This is the "shift left" security model: catch vulnerabilities before
        // the image ever reaches production.
        stage('Trivy Scan') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Trivy Security Scan      ║"
                echo "╚══════════════════════════════════╝"

                sh """
                    echo "=== Trivy Filesystem Scan (dependency check) ==="
                    trivy fs \
                        --format table \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        --no-progress \
                        app/

                    echo "=== Trivy Image Scan ==="
                    trivy image \
                        --format table \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        --timeout 5m \
                        ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \
                        2>&1 | tee trivy-report.txt

                    echo "Trivy scan complete."
                """
            }
            post {
                always {
                    // Archive the Trivy report as a build artefact for audit purposes
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
                }
            }
        }

        // ── Stage 8: ECR Login ─────────────────────────────────────────────────
        // Authenticate Docker to ECR using the IAM instance profile credentials.
        // get-login-password generates a temporary token (12-hour expiry).
        // No static access keys are used — the IAM role handles auth.
        stage('ECR Login') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: ECR Login                ║"
                echo "╚══════════════════════════════════╝"

                withAWS(region: "${AWS_REGION}", role: '') {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        echo "ECR login successful."
                    """
                }
            }
        }

        // ── Stage 9: Push to ECR ──────────────────────────────────────────────
        // Push both the versioned tag and 'latest' to ECR.
        // Having 'latest' means the deploy script can always pull the newest
        // image without knowing the build number.
        stage('Push Image to ECR') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Push to ECR              ║"
                echo "╚══════════════════════════════════╝"

                sh """
                    echo "Pushing versioned tag..."
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}

                    echo "Pushing latest tag..."
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:${LATEST_TAG}

                    echo "Push complete. Verifying..."
                    aws ecr describe-images \
                        --repository-name ${ECR_REPO} \
                        --region ${AWS_REGION} \
                        --query 'sort_by(imageDetails,& imagePushedAt)[-1]' \
                        --output table
                """
            }
        }

        // ── Stage 10: Deploy to EC2 ───────────────────────────────────────────
        // SSH into the EC2 instance and run the deploy script.
        // The deploy script: pulls the new image, stops old container,
        // starts new container, runs health checks, rolls back on failure.
        stage('Deploy to EC2') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Deploy to EC2            ║"
                echo "╚══════════════════════════════════╝"

                sshagent(['ec2-ssh-key']) {
                    sh """
                        # Copy deploy script to EC2 instance
                        scp -o StrictHostKeyChecking=no \
                            scripts/deploy.sh \
                            ${EC2_USER}@${EC2_HOST}:/tmp/deploy.sh

                        # Execute deploy script on EC2
                        ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} \
                            "chmod +x /tmp/deploy.sh && \
                             BUILD_NUMBER=${BUILD_NUMBER} \
                             GIT_COMMIT=${GIT_COMMIT} \
                             AWS_REGION=${AWS_REGION} \
                             /tmp/deploy.sh ${ECR_REGISTRY} ${ECR_REPO} ${IMAGE_TAG}"
                    """
                }
            }
        }

        // ── Stage 11: Health Check ────────────────────────────────────────────
        // After deployment, verify the application is responding correctly
        // from the Jenkins master (external perspective, not just localhost).
        stage('Health Check') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Post-Deploy Health Check ║"
                echo "╚══════════════════════════════════╝"

                sh """
                    echo "Waiting 15s for container to stabilise..."
                    sleep 15

                    echo "Checking /health endpoint..."
                    RESPONSE=\$(curl -sf --max-time 10 http://${EC2_HOST}:${APP_PORT}/health)
                    echo "Response: \${RESPONSE}"

                    echo ""
                    echo "Checking /version endpoint..."
                    curl -sf --max-time 10 http://${EC2_HOST}:${APP_PORT}/version | \
                        python3 -m json.tool

                    echo ""
                    echo "Checking /api/status endpoint..."
                    curl -sf --max-time 10 http://${EC2_HOST}:${APP_PORT}/api/status | \
                        python3 -m json.tool

                    echo ""
                    echo "✅ All health checks passed!"
                """
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // POST — Run after all stages regardless of outcome
    // ═════════════════════════════════════════════════════════════════════════
    post {
        success {
            echo """
            ╔══════════════════════════════════════════════════════╗
            ║  ✅  PIPELINE SUCCEEDED                              ║
            ║  Build   : #${BUILD_NUMBER}                         ║
            ║  Commit  : ${GIT_COMMIT[0..7]}                     ║
            ║  Branch  : ${GIT_BRANCH}                           ║
            ╚══════════════════════════════════════════════════════╝
            """
            // In production, send a Slack/Teams notification here:
            // slackSend(channel: '#deployments', color: 'good',
            //     message: "✅ Deployed ${APP_NAME} build #${BUILD_NUMBER}")
        }

        failure {
            echo """
            ╔══════════════════════════════════════════════════════╗
            ║  ❌  PIPELINE FAILED                                ║
            ║  Build   : #${BUILD_NUMBER}                         ║
            ║  Stage   : ${currentBuild.result}                  ║
            ╚══════════════════════════════════════════════════════╝
            """
            // slackSend(channel: '#deployments', color: 'danger',
            //     message: "❌ FAILED: ${APP_NAME} build #${BUILD_NUMBER} — ${currentBuild.result}")
        }

        always {
            echo ">>> Cleaning up Docker images to free disk space..."
            // Remove dangling images (untagged) and stopped containers
            sh '''
                docker image prune -f || true
                docker container prune -f || true
            '''

            // Clean up workspace to free Jenkins disk space
            cleanWs(
                cleanWhenSuccess: true,
                cleanWhenFailure: false,   // Keep on failure for debugging
                notFailBuild: true
            )
        }
    }
}
