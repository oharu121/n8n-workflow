#!/bin/bash
# =============================================================================
# n8n Startup Script for Hugging Face Spaces
# =============================================================================

set -e

echo "=========================================="
echo "n8n Startup Script"
echo "=========================================="

# Create data directory for persistent storage
mkdir -p /data/.n8n
echo "Data directory: /data/.n8n"

# Wait for database to be ready (Supabase)
echo "Checking database connectivity..."
MAX_DB_RETRIES=30
DB_RETRY_INTERVAL=5

for i in $(seq 1 $MAX_DB_RETRIES); do
    if pg_isready -h "$DB_POSTGRESDB_HOST" -p "$DB_POSTGRESDB_PORT" -U "$DB_POSTGRESDB_USER" -d "$DB_POSTGRESDB_DATABASE" 2>/dev/null; then
        echo "Database is ready!"
        break
    fi

    if [ $i -eq $MAX_DB_RETRIES ]; then
        echo "Warning: Could not verify database connection after $MAX_DB_RETRIES attempts"
        echo "Proceeding anyway - n8n will retry connection on startup"
    else
        echo "Waiting for database... attempt $i/$MAX_DB_RETRIES"
        sleep $DB_RETRY_INTERVAL
    fi
done

# Start the database keep-alive process in background
echo "Starting database keep-alive process..."
/home/node/app/db-keepalive.sh &

# Log configuration (without exposing secrets)
echo ""
echo "Configuration:"
echo "  - Port: $N8N_PORT"
echo "  - Protocol: $N8N_PROTOCOL"
echo "  - Timezone: $GENERIC_TIMEZONE"
echo "  - Database Type: ${DB_TYPE:-not set}"
echo "  - Database Host: ${DB_POSTGRESDB_HOST:-not set}"
echo "  - Metrics Enabled: $N8N_METRICS"
echo "  - Health Check Active: $QUEUE_HEALTH_CHECK_ACTIVE"
echo "  - Basic Auth: ${N8N_BASIC_AUTH_ACTIVE:-false}"
echo ""

# Start n8n
echo "Starting n8n..."
exec n8n start
