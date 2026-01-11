# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-01-12

### Fixed
- **Database connection timeout issue** - Switched from Supabase Transaction mode (port 6543) to Session mode (port 5432). n8n requires Session mode for persistent connections and prepared statements.

### Changed
- Reduced database keepalive interval from 5 minutes to 3.5 days (twice per week). Supabase only pauses after 7 days of inactivity, so frequent pings were unnecessary.
- Updated Dockerfile comments to document correct port (5432) for Supabase Session mode.

### Added
- Documentation comparing Supabase ports 6543 vs 5432 in `.dev-notes/2026-01-11.md`
- Fix documentation in `.plans/2025-01-12-fix-database-connection.md`

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
