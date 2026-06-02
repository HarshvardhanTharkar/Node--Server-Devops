#!/bin/bash
# =============================================================================
# scripts/deploy.sh — Application Deployment Script
# =============================================================================
#
# This script is executed on the EC2 instance by the Jenkins pipeline
# during the "Deploy to EC2" stage (via SSH or direct execution).
#
# Deployment strategy: Simple Replacement (Blue/Green lite)
#   1. Pull the new image from ECR
#   2. Stop the running container (if any)
#   3. Remove the old container
#   4. Start the new container
#   5. Verify health
#
# Why not true Blue/Green?
#   Full Blue/Green requires two identical EC2 environments (or ECS/ALB).
#   For a portfolio project on a single EC2 instance, simple replacement
#   with a quick health check and automatic rollback is pragmatic.
#   Production deployments on ECS/EKS would use ALB + two target groups.
#
# Usage:
#   ./deploy.sh <ECR_REGISTRY> <IMAGE_NAME> <IMAGE_TAG>
#
# Example:
#   ./deploy.sh 123456789.dkr.ecr.us-east-1.amazonaws.com nodejs-cicd-app build-42
# =============================================================================

set -euo pipefail

# ─── Arguments ────────────────────────────────────────────────────────────────
ECR_REGISTRY="${1:?Usage: deploy.sh <ECR_REGISTRY> <IMAGE_NAME> <IMAGE_TAG>}"
IMAGE_NAME="${2:?Missing IMAGE_NAME}"
IMAGE_TAG="${3:?Missing IMAGE_TAG}"

FULL_IMAGE="${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
CONTAINER_NAME="nodejs-app"
APP_PORT="3000"
HOST_PORT="3000"
AWS_REGION="${AWS_REGION:-us-east-1}"
HEALTH_RETRIES=12        # 12 × 5s = 60s to become healthy
HEALTH_INTERVAL=5

echo "================================================================"
echo " DEPLOYMENT STARTED: $(date)"
echo " Image: ${FULL_IMAGE}"
echo "================================================================"

# ─── Step 1: ECR Login ────────────────────────────────────────────────────────
echo ">>> Step 1/6: Authenticating to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo "ECR login successful."

# ─── Step 2: Pull New Image ───────────────────────────────────────────────────
echo ">>> Step 2/6: Pulling new image..."
docker pull "${FULL_IMAGE}"
echo "Image pulled: ${FULL_IMAGE}"

# Save the old image tag for rollback (if a container is currently running)
OLD_IMAGE=""
if docker ps -q --filter "name=${CONTAINER_NAME}" | grep -q .; then
    OLD_IMAGE=$(docker inspect "${CONTAINER_NAME}" \
        --format '{{.Config.Image}}' 2>/dev/null || echo "")
    echo "Old image captured for rollback: ${OLD_IMAGE}"
fi

# ─── Step 3: Stop Old Container ───────────────────────────────────────────────
echo ">>> Step 3/6: Stopping old container (if running)..."
if docker ps -q --filter "name=${CONTAINER_NAME}" | grep -q .; then
    docker stop "${CONTAINER_NAME}"
    echo "Container '${CONTAINER_NAME}' stopped."
else
    echo "No running container found. First deployment."
fi

# ─── Step 4: Remove Old Container ────────────────────────────────────────────
echo ">>> Step 4/6: Removing old container (if exists)..."
if docker ps -aq --filter "name=${CONTAINER_NAME}" | grep -q .; then
    docker rm "${CONTAINER_NAME}"
    echo "Container '${CONTAINER_NAME}' removed."
else
    echo "No container to remove."
fi

# ─── Step 5: Start New Container ─────────────────────────────────────────────
echo ">>> Step 5/6: Starting new container..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${HOST_PORT}:${APP_PORT}" \
    -e NODE_ENV=production \
    -e PORT="${APP_PORT}" \
    -e GIT_COMMIT="${GIT_COMMIT:-unknown}" \
    -e BUILD_NUMBER="${BUILD_NUMBER:-unknown}" \
    -e BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -e AWS_REGION="${AWS_REGION}" \
    --log-driver=json-file \
    --log-opt max-size=50m \
    --log-opt max-file=3 \
    --memory="512m" \
    --cpus="1.0" \
    "${FULL_IMAGE}"

echo "Container started: ${CONTAINER_NAME}"

# ─── Step 6: Health Check Verification ───────────────────────────────────────
echo ">>> Step 6/6: Verifying deployment health..."
HEALTH_URL="http://localhost:${APP_PORT}/health"
ATTEMPT=0

until curl -sf "${HEALTH_URL}" > /dev/null; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge $HEALTH_RETRIES ]; then
        echo ""
        echo "================================================================"
        echo " ❌  HEALTH CHECK FAILED after ${ATTEMPT} attempts!"
        echo " Container logs:"
        docker logs --tail=50 "${CONTAINER_NAME}" || true
        echo "================================================================"

        # ── Rollback ───────────────────────────────────────────────────────
        if [ -n "${OLD_IMAGE}" ]; then
            echo ">>> ROLLBACK: Reverting to ${OLD_IMAGE}..."
            docker stop "${CONTAINER_NAME}" 2>/dev/null || true
            docker rm   "${CONTAINER_NAME}" 2>/dev/null || true
            docker run -d \
                --name "${CONTAINER_NAME}" \
                --restart unless-stopped \
                -p "${HOST_PORT}:${APP_PORT}" \
                -e NODE_ENV=production \
                "${OLD_IMAGE}"
            echo "Rollback complete. Previous version restored."
        else
            echo "No previous image available for rollback."
        fi
        exit 1
    fi
    echo "  Health check attempt ${ATTEMPT}/${HEALTH_RETRIES}... (waiting ${HEALTH_INTERVAL}s)"
    sleep "${HEALTH_INTERVAL}"
done

echo ""
echo "================================================================"
echo " ✅  DEPLOYMENT SUCCESSFUL!"
echo "    Container : ${CONTAINER_NAME}"
echo "    Image     : ${FULL_IMAGE}"
echo "    URL       : http://$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):${HOST_PORT}"
echo "    Time      : $(date)"
echo "================================================================"

# ─── Cleanup: Remove Dangling Images ─────────────────────────────────────────
echo ">>> Cleaning up dangling images..."
docker image prune -f || true
