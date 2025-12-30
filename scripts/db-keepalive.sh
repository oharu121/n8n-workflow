#!/bin/bash
# =============================================================================
# Database Keep-Alive Script
# Keeps Supabase connection alive by running periodic queries
# =============================================================================

INTERVAL=300  # 5 minutes in seconds

echo "Database keep-alive started (interval: ${INTERVAL}s)"

while true; do
    sleep $INTERVAL

    # Simple query to keep connection alive
    if PGPASSWORD="$DB_POSTGRESDB_PASSWORD" psql \
        -h "$DB_POSTGRESDB_HOST" \
        -p "$DB_POSTGRESDB_PORT" \
        -U "$DB_POSTGRESDB_USER" \
        -d "$DB_POSTGRESDB_DATABASE" \
        -c "SELECT 1;" > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Database heartbeat OK"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Database heartbeat FAILED - connection may have dropped"
    fi
done
