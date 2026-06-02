# =============================================================================
# Dockerfile — Multi-Stage Production Build
# =============================================================================
#
# STAGE 1 (builder): Install ALL dependencies, run tests.
# STAGE 2 (production): Copy only the built artefacts + prod deps into a
#                       minimal image. The test tooling never ships to prod.
#
# Why multi-stage?
#   - Final image contains ZERO devDependencies (Jest, nodemon, etc.)
#   - Reduces attack surface (fewer packages = fewer CVEs)
#   - Smaller image = faster pulls, lower ECR storage cost
#
# Final image size target: ~150 MB (vs ~400 MB with a single stage)
# =============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# STAGE 1 — Builder
# ──────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

# LABEL metadata helps with image auditing and registry searches
LABEL maintainer="devops@example.com"
LABEL stage="builder"

# Set working directory inside the container
WORKDIR /usr/src/app

# Copy package manifests FIRST (before source code).
# Docker caches each layer. If package.json hasn't changed, npm ci uses the
# cache and skips downloading ~100 MB of packages — saving 60+ seconds per build.
COPY package.json package-lock.json ./

# npm ci (vs npm install):
#   - Reads package-lock.json exactly — deterministic, reproducible builds
#   - Faster than npm install
#   - Deletes node_modules before installing — no leftover deps
RUN npm ci

# Copy application source code AFTER dependencies.
# If only source changes, Docker reuses the npm ci layer from cache.
COPY . .

# ──────────────────────────────────────────────────────────────────────────────
# STAGE 2 — Production
# ──────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS production

# OCI standard labels — visible in ECR and docker inspect
LABEL org.opencontainers.image.title="nodejs-cicd-app"
LABEL org.opencontainers.image.description="Node.js Express CI/CD demo application"
LABEL org.opencontainers.image.vendor="DevOps Team"

# node:20-alpine is based on Alpine Linux (~5 MB).
# Install only the packages required at runtime.
# --no-cache avoids storing the apk index, keeping the layer smaller.
RUN apk add --no-cache \
    dumb-init \
    curl

# dumb-init is a minimal init process for containers.
# Without it Node.js is PID 1 and won't correctly forward signals (SIGTERM)
# to child processes, causing containers to hang on shutdown.

WORKDIR /usr/src/app

# Copy package manifests, then install ONLY production dependencies.
# --omit=dev drops devDependencies (Jest, nodemon…) from the final image.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && \
    npm cache clean --force    # Remove npm cache to reduce layer size

# Copy application source from the builder stage.
# We do NOT use COPY . . here — only copy what production needs.
COPY --from=builder /usr/src/app/app.js     ./app.js
COPY --from=builder /usr/src/app/server.js  ./server.js
COPY --from=builder /usr/src/app/routes     ./routes
COPY --from=builder /usr/src/app/controllers ./controllers
COPY --from=builder /usr/src/app/middleware ./middleware
COPY --from=builder /usr/src/app/utils      ./utils

# ──────────────────────────────────────────────────────────────────────────────
# Security: Non-Root User
# ──────────────────────────────────────────────────────────────────────────────
# Running as root inside a container means a container escape → root on host.
# Create a dedicated user with no login shell and no home directory.
RUN addgroup -S appgroup && \
    adduser  -S appuser -G appgroup

# Give appuser ownership of the working directory
RUN chown -R appuser:appgroup /usr/src/app

# Switch to non-root user — all subsequent RUN/CMD execute as appuser
USER appuser

# Declare the port the app listens on (documentation; does not actually publish it)
EXPOSE 3000

# ──────────────────────────────────────────────────────────────────────────────
# Health Check
# ──────────────────────────────────────────────────────────────────────────────
# Docker daemon polls this command every 30 s.
# After 3 consecutive failures the container status becomes "unhealthy".
# AWS ECS / ALB target groups also respect Docker health status.
#
# --interval=30s   Poll every 30 seconds
# --timeout=10s    Kill the check if it takes longer than 10 s
# --start-period=15s Give the app 15 s to boot before counting failures
# --retries=3      Mark unhealthy after 3 consecutive failures
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# ──────────────────────────────────────────────────────────────────────────────
# Start Command
# ──────────────────────────────────────────────────────────────────────────────
# dumb-init wraps node so signals are forwarded correctly.
# We use JSON array (exec form) instead of shell form to avoid spawning a shell.
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
