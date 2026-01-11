# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-01-12

### Fixed
- **Database connection timeout issue** - Switched from Supabase Transaction mode (port 6543) to Session mode (port 5432). n8n requires Session mode for persistent connections and prepared statements.
- **X-Forwarded-For validation error** - Added `N8N_TRUST_PROXY=true` to trust proxy headers from HF Spaces reverse proxy, fixing rate-limit validation errors.

### Changed
- Reduced database keepalive interval from 5 minutes to 3.5 days (twice per week). Supabase only pauses after 7 days of inactivity, so frequent pings were unnecessary.
- Updated Dockerfile comments to document correct port (5432) for Supabase Session mode.

### Added
- Documentation comparing Supabase ports 6543 vs 5432 in `.dev-notes/2026-01-11.md`
- Fix documentation in `.plans/2025-01-12-fix-database-connection.md`
- Production environment variables:
  - `EXECUTIONS_DATA_PRUNE=true` - Auto-prune old executions
  - `EXECUTIONS_DATA_MAX_AGE=168` - Keep executions for 7 days
  - `EXECUTIONS_DATA_SAVE_ON_SUCCESS=none` - Don't save successful executions (saves DB space)
  - `N8N_LOG_LEVEL=warn` - Reduce log noise
  - `N8N_CONCURRENCY_PRODUCTION_LIMIT=10` - Limit concurrent executions
  - `N8N_DIAGNOSTICS_ENABLED=false` - Disable telemetry

### Required Manual Changes
After updating, change these secrets in HF Spaces Settings:
- `DB_POSTGRESDB_HOST` → `aws-1-ap-southeast-2.pooler.supabase.com` (session pooler host)
- `DB_POSTGRESDB_PORT` → `5432`
- `DB_POSTGRESDB_USER` → `postgres.<project-ref>` (includes project reference)

## [1.0.0] - 2025-12-30

### Added
- Initial deployment of n8n on Hugging Face Spaces
- Supabase PostgreSQL integration
- Database keepalive script
- GitHub Actions deployment workflow
- Health check endpoints (`/healthz`, `/healthz/readiness`)
