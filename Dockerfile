# =============================================================================
# n8n on Hugging Face Spaces (Minimal)
# =============================================================================

FROM node:24-alpine

# Install only essential dependencies
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    postgresql-client \
    tini \
    tzdata

# Set timezone
ENV TZ=Asia/Tokyo
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create app directory
WORKDIR /home/node/app

# Install n8n globally (latest stable)
RUN npm install -g n8n

# Copy scripts
COPY scripts/startup.sh /home/node/app/startup.sh
COPY scripts/db-keepalive.sh /home/node/app/db-keepalive.sh
RUN chmod +x /home/node/app/*.sh

# Copy workflow templates for reference
COPY workflows/ /home/node/app/workflows/
COPY pick-news-and-send-mail/ /home/node/app/pick-news-and-send-mail/

# =============================================================================
# Environment Configuration
# =============================================================================

# n8n Core Settings - Port 7860 is REQUIRED by HF Spaces
ENV N8N_PORT=7860
ENV N8N_PROTOCOL=https
ENV N8N_HOST=0.0.0.0
ENV NODE_ENV=production

# Health & Metrics (required for wake-up endpoint)
ENV QUEUE_HEALTH_CHECK_ACTIVE=true
ENV N8N_METRICS=true

# Timezone for scheduled workflows
ENV GENERIC_TIMEZONE=Asia/Tokyo

# Disable secure cookie - HF Spaces handles HTTPS termination
ENV N8N_SECURE_COOKIE=false

# Chromium for puppeteer-based nodes
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# n8n data directory - use /data for HF persistent storage
ENV N8N_USER_FOLDER=/data/.n8n

# =============================================================================
# Runtime Secrets (set via HF Spaces Settings > Variables and Secrets)
# =============================================================================
# N8N_ENCRYPTION_KEY      - Encryption key for credentials
# N8N_BASIC_AUTH_ACTIVE   - Set to "true" to enable basic auth
# N8N_BASIC_AUTH_USER     - Username for basic auth
# N8N_BASIC_AUTH_PASSWORD - Password for basic auth
# WEBHOOK_URL             - https://oharu121-n8n-workflow.hf.space
# N8N_EDITOR_BASE_URL     - https://oharu121-n8n-workflow.hf.space
# DB_TYPE                 - postgresdb
# DB_POSTGRESDB_HOST      - Supabase host
# DB_POSTGRESDB_PORT      - 6543 (transaction pooler)
# DB_POSTGRESDB_DATABASE  - postgres
# DB_POSTGRESDB_USER      - postgres
# DB_POSTGRESDB_PASSWORD  - Supabase password
# DB_POSTGRESDB_SSL_ENABLED - true

# Expose port 7860 (required by HF Spaces)
EXPOSE 7860

# Use tini as init system for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Start n8n via startup script
CMD ["/bin/bash", "/home/node/app/startup.sh"]
