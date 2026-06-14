// =============================================================================
// Jenkinsfile — Declarative Pipeline (Fixed for t3.micro + eu-north-1)
// =============================================================================

pipeline {

    agent any

    environment {
        APP_NAME        = "nodejs-cicd-app"
        APP_PORT        = "3000"
        NODE_ENV        = "production"

        AWS_REGION      = "eu-north-1"
        ECR_REGISTRY    = credentials('ecr-registry-uri')
        ECR_REPO        = "nodejs-cicd-app"

        IMAGE_TAG       = "build-${BUILD_NUMBER}-${GIT_COMMIT[0..7]}"
        LATEST_TAG      = "latest"

        EC2_HOST        = credentials('ec2-public-ip')
        EC2_USER        = "ec2-user"
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timestamps()
        ansiColor('xterm')
    }

    triggers {
        pollSCM('H/1 * * * *')
    }

    stages {

        stage('Checkout') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Checkout                 ║"
                echo "╚══════════════════════════════════╝"

                checkout scm

                script {
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

        stage('Install Dependencies') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Install Dependencies     ║"
                echo "╚══════════════════════════════════╝"

                dir('app') {
                    sh '''
                        npm ci
                        echo "Installed packages:"
                        npm list --depth=0
                    '''
                }
            }
        }

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
                    publishHTML(target: [
                        allowMissing         : true,
                        alwaysLinkToLastBuild: false,
                        keepAll              : true,
                        reportDir            : 'app/coverage/lcov-report',
                        reportFiles          : 'index.html',
                        reportName           : 'Coverage Report'
                    ])
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: SonarQube Analysis       ║"
                echo "╚══════════════════════════════════╝"
                echo "SonarQube skipped — will be configured in Phase 2"
            }
        }

        stage('Quality Gate') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Quality Gate             ║"
                echo "╚══════════════════════════════════╝"
                echo "Quality Gate skipped — will be configured in Phase 2"
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Build Docker Image       ║"
                echo "╚══════════════════════════════════╝"

                dir('app') {
                    sh """
                        echo "Building image: ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

                        docker build \\
                            --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \\
                            --build-arg BUILD_NUMBER=${BUILD_NUMBER} \\
                            --build-arg GIT_COMMIT=${GIT_COMMIT} \\
                            --build-arg APP_VERSION=1.0.${BUILD_NUMBER} \\
                            -t ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \\
                            -t ${ECR_REGISTRY}/${ECR_REPO}:${LATEST_TAG} \\
                            .

                        echo "Image built successfully!"
                        docker images | grep ${ECR_REPO}
                    """
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Trivy Security Scan      ║"
                echo "╚══════════════════════════════════╝"

                sh """
                    echo "=== Trivy Filesystem Scan ==="
                    trivy fs \\
                        --format table \\
                        --severity HIGH,CRITICAL \\
                        --exit-code 0 \\
                        --no-progress \\
                        app/

                    echo "=== Trivy Image Scan ==="
                    trivy image \\
                        --format table \\
                        --severity HIGH,CRITICAL \\
                        --exit-code 0 \\
                        --no-progress \\
                        --timeout 5m \\
                        ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \\
                        2>&1 | tee trivy-report.txt

                    echo "Trivy scan complete."
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('ECR Login') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: ECR Login                ║"
                echo "╚══════════════════════════════════╝"

                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \\
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    echo "ECR login successful."
                """
            }
        }

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

                    echo "Push complete."
                    aws ecr describe-images \\
                        --repository-name ${ECR_REPO} \\
                        --region ${AWS_REGION} \\
                        --query 'sort_by(imageDetails,& imagePushedAt)[-1]' \\
                        --output table
                """
            }
        }

        stage('Deploy to EC2') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Deploy to EC2            ║"
                echo "╚══════════════════════════════════╝"

                sshagent(['ec2-ssh-key']) {
                    sh """
                        scp -o StrictHostKeyChecking=no \\
                            scripts/deploy.sh \\
                            ${EC2_USER}@${EC2_HOST}:/tmp/deploy.sh

                        ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} \\
                            "chmod +x /tmp/deploy.sh && \\
                             BUILD_NUMBER=${BUILD_NUMBER} \\
                             GIT_COMMIT=${GIT_COMMIT} \\
                             AWS_REGION=${AWS_REGION} \\
                             /tmp/deploy.sh ${ECR_REGISTRY} ${ECR_REPO} ${IMAGE_TAG}"
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                echo "╔══════════════════════════════════╗"
                echo "║  Stage: Post-Deploy Health Check ║"
                echo "╚══════════════════════════════════╝"

                sh """
                    echo "Waiting 15s for container to stabilise..."
                    sleep 15

                    echo "Checking /health endpoint..."
                    curl -sf --max-time 10 http://${EC2_HOST}:${APP_PORT}/health

                    echo ""
                    echo "Checking /version endpoint..."
                    curl -sf --max-time 10 http://${EC2_HOST}:${APP_PORT}/version

                    echo ""
                    echo "Checking /api/status endpoint..."
                    curl -sf --max-time 10 http://${EC2_HOST}:${APP_PORT}/api/status

                    echo ""
                    echo "All health checks passed!"
                """
            }
        }
    }

    post {
        success {
            echo "PIPELINE SUCCEEDED - Build #${BUILD_NUMBER} - Commit: ${GIT_COMMIT[0..7]}"
        }

        failure {
            echo "PIPELINE FAILED - Build #${BUILD_NUMBER}"
        }

        always {
            echo "Cleaning up Docker images..."
            sh '''
                docker image prune -f || true
                docker container prune -f || true
            '''

            cleanWs(
                cleanWhenSuccess: true,
                cleanWhenFailure: false,
                notFailBuild: true
            )
        }
    }
}