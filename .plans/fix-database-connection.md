# Fix: Database Connection Timeout on Hugging Face Spaces

**Date:** 2025-01-12
**Status:** Resolved

## Problem

n8n deployed on HF Spaces returned 503 error with "Database is not ready!" message. Logs showed intermittent connectivity with Supabase - occasional heartbeat success followed by multiple timeouts.

## Root Cause

Using **Transaction mode (port 6543)** instead of **Session mode (port 5432)** for Supabase connection.

n8n is a persistent application that:
- Uses prepared statements
- Maintains long-lived connections
- Expects session-level state

Transaction mode assigns a different connection per query, breaking n8n's expectations.

## Solution

1. **Changed `DB_POSTGRESDB_PORT` from `6543` to `5432`** in HF Spaces secrets
2. Updated Dockerfile comment to document correct port
3. Reduced keepalive interval from 5 minutes to 3.5 days (Supabase only pauses after 7 days of zero activity)

## References

- [Supabase Connection Guide](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [n8n Community Discussion](https://community.n8n.io/t/title-database-is-not-ready-503-error-occurs-after-about-10-hours-of-inactivity/220619)
