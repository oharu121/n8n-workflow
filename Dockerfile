# =============================================================================
# n8n on Hugging Face Spaces
# Optimized for HF Spaces free tier (2 vCPU, 16GB RAM, 50GB disk)
# =============================================================================

ARG NODE_VERSION=24
FROM node:${NODE_VERSION}-alpine

# Install system dependencies
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    ffmpeg \
    yt-dlp \
    postgresql-client \
    curl \
    bash \
    tzdata \
    tini \
    git \
    python3 \
    py3-pip \
    make \
    g++ \
    build-base \
    cairo-dev \
    pango-dev

# Set timezone
ENV TZ=Asia/Tokyo
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create app directory
WORKDIR /home/node/app

# Install n8n globally (version managed by Renovate)
ARG N8N_VERSION=2.35.7
RUN npm install -g n8n@${N8N_VERSION}

# Copy scripts
COPY scripts/startup.sh /home/node/app/startup.sh
COPY scripts/db-keepalive.sh /home/node/app/db-keepalive.sh
RUN chmod +x /home/node/app/*.sh

# =============================================================================
# Environment Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# Core Server Settings (HF Spaces requirements)
# -----------------------------------------------------------------------------
ENV NODE_ENV=production
ENV N8N_PORT=7860
ENV N8N_PROTOCOL=https
ENV N8N_HOST=0.0.0.0
ENV N8N_SECURE_COOKIE=false
ENV N8N_TRUST_PROXY=true
ENV N8N_USER_FOLDER=/data/.n8n

# -----------------------------------------------------------------------------
# Timezone
# -----------------------------------------------------------------------------
ENV GENERIC_TIMEZONE=Asia/Tokyo

# -----------------------------------------------------------------------------
# Database Configuration (Supabase PostgreSQL)
# -----------------------------------------------------------------------------
ENV DB_POSTGRESDB_SCHEMA=public
ENV DB_POSTGRESDB_TIMEOUT=60000
ENV DB_POSTGRESDB_POOL_MAX_SIZE=5
ENV DB_POSTGRESDB_POOL_IDLE_TIMEOUT=20000

# -----------------------------------------------------------------------------
# Execution & Performance
# -----------------------------------------------------------------------------
ENV N8N_CONCURRENCY_PRODUCTION_LIMIT=10
ENV N8N_RUNNERS_ENABLED=true
ENV N8N_RUNNERS_TASK_TIMEOUT=900

# Execution data pruning (prevents Supabase free tier from filling up)
ENV EXECUTIONS_DATA_PRUNE=true
ENV EXECUTIONS_DATA_MAX_AGE=168
ENV EXECUTIONS_DATA_SAVE_ON_SUCCESS=none
ENV EXECUTIONS_DATA_SAVE_ON_PROGRESS=false
ENV EXECUTIONS_DATA_SAVE_ON_ERROR=all

# -----------------------------------------------------------------------------
# Code Node Settings
# -----------------------------------------------------------------------------
ENV NODE_FUNCTION_ALLOW_EXTERNAL=node-fetch
ENV NODE_FUNCTION_ALLOW_BUILTIN=*
ENV N8N_BLOCK_ENV_ACCESS_IN_NODE=false

# -----------------------------------------------------------------------------
# External Tools (Puppeteer/Chromium)
# -----------------------------------------------------------------------------
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# -----------------------------------------------------------------------------
# Monitoring & Logging
# -----------------------------------------------------------------------------
ENV N8N_LOG_LEVEL=warn
ENV N8N_METRICS=true
ENV N8N_DIAGNOSTICS_ENABLED=false
ENV QUEUE_HEALTH_CHECK_ACTIVE=true

# -----------------------------------------------------------------------------
# Feature Flags & Integrations
# -----------------------------------------------------------------------------
ENV N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
ENV NOTION_MARKDOWN_CONVERSION=true

# =============================================================================
# Runtime Secrets (set via HF Spaces Settings > Variables and Secrets)
# =============================================================================
# Authentication:
#   N8N_ENCRYPTION_KEY      - Encryption key for credentials
#   N8N_BASIC_AUTH_ACTIVE   - Set to "true" to enable basic auth
#   N8N_BASIC_AUTH_USER     - Username for basic auth
#   N8N_BASIC_AUTH_PASSWORD - Password for basic auth
#
# URLs:
#   WEBHOOK_URL             - https://your-space.hf.space
#   N8N_EDITOR_BASE_URL     - https://your-space.hf.space
#
# Database:
#   DB_TYPE                 - postgresdb
#   DB_POSTGRESDB_HOST      - Supabase host
#   DB_POSTGRESDB_PORT      - 5432 (session mode - required for n8n)
#   DB_POSTGRESDB_DATABASE  - postgres
#   DB_POSTGRESDB_USER      - postgres.your-project-ref
#   DB_POSTGRESDB_PASSWORD  - Supabase password
#   DB_POSTGRESDB_SSL_ENABLED - true

# Expose port 7860 (required by HF Spaces)
EXPOSE 7860

# Use tini as init system for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Start n8n via startup script
CMD ["/bin/bash", "/home/node/app/startup.sh"]
