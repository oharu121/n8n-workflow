# Deploy Path Filters

## Problem
The deploy workflow was triggering on every push to main, including documentation changes, config updates, and changelogs. This wasted HF Spaces build resources unnecessarily.

## Solution
Added `paths` filter to `.github/workflows/deploy-to-hf-spaces.yml` to only trigger deployment when relevant files change.

## Implementation

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'Dockerfile'
      - 'scripts/**'
  workflow_dispatch:
    # Manual trigger still available
```

## Path Filter Logic

| Path | Triggers Deploy | Reason |
|------|-----------------|--------|
| `Dockerfile` | ✅ Yes | Container definition, ENV vars, n8n version |
| `scripts/**` | ✅ Yes | Runtime scripts (startup.sh, db-keepalive.sh) |
| `.github/workflows/**` | ❌ No | CI/CD config only |
| `.dev-notes/**` | ❌ No | Documentation |
| `.plans/**` | ❌ No | Planning docs |
| `renovate.json` | ❌ No | Bot config |
| `CHANGELOG.md` | ❌ No | Documentation |
| `README.md` | ❌ No | Documentation |
| `.env` | ❌ No | Not in container (secrets in HF) |

## Manual Override
Use `workflow_dispatch` (manual trigger) when you need to force a deployment without file changes:
1. Go to Actions tab in GitHub
2. Select "Deploy to Hugging Face Spaces"
3. Click "Run workflow"

## Renovate Compatibility
When Renovate updates `ARG N8N_VERSION=x.x.x` in Dockerfile, the path filter correctly triggers a deployment since Dockerfile is in the allowed paths.

## Date
2026-01-15
