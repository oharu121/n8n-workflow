# Plan: Auto-Detect and Deploy New n8n Versions

## Current State Analysis

Your n8n deployment has:
- **Dockerfile** at `Dockerfile` - installs n8n via `npm install -g n8n` (no version pinning)
- **GitHub Actions** at `.github/workflows/deploy-to-hf-spaces.yml` - deploys to Hugging Face Spaces on push to main
- **No automated version checking** currently exists

### Key Finding
Your current setup already uses the latest n8n version on each rebuild, but rebuilds only happen on manual pushes. There's no proactive detection of new releases.

---

## Recommended Approach: Renovate Bot

**Why Renovate over alternatives:**
| Option | Pros | Cons |
|--------|------|------|
| **Renovate** | Industry standard, regex manager for Dockerfile npm packages, auto-merge capable, PR-based (reviewable) | Requires initial setup |
| Dependabot | Built into GitHub | Cannot detect npm packages in Dockerfiles |
| Watchtower | Zero config for Docker | Bypasses CI/CD, no review process |
| Custom GitHub Action | Full control | Maintenance burden |

---

## Implementation Plan

### Step 1: Pin n8n Version in Dockerfile
Modify `Dockerfile` to use explicit version:
```dockerfile
# Change from:
RUN npm install -g n8n
# To:
ARG N8N_VERSION=1.73.1
RUN npm install -g n8n@${N8N_VERSION}
```

### Step 2: Add Renovate Configuration
Create `renovate.json` in repository root:
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["^Dockerfile$"],
      "matchStrings": ["ARG N8N_VERSION=(?<currentValue>.*?)\\n"],
      "depNameTemplate": "n8n",
      "datasourceTemplate": "npm"
    }
  ],
  "packageRules": [
    {
      "matchPackageNames": ["n8n"],
      "automerge": true,
      "automergeType": "pr",
      "schedule": ["every weekend"],
      "prPriority": 10,
      "platformAutomerge": true
    },
    {
      "matchPackageNames": ["n8n"],
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["breaking-change"]
    }
  ]
}
```

**Note**: Major version updates (e.g., 1.x → 2.x) will NOT auto-merge due to potential breaking changes. You'll need to review these manually.

### Step 3: Enable Renovate GitHub App
1. Install Renovate from GitHub Marketplace (free for public repos)
2. Grant access to this repository
3. Renovate will auto-create an onboarding PR

### Step 4: Auto-Deploy on Merge
Your existing workflow already triggers on push to main, so when Renovate auto-merges a PR, it will automatically deploy to HF Spaces.

**End-to-end flow**: Renovate detects update → Creates PR → Auto-merges (weekends) → GitHub Actions deploys → n8n updated

---

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `Dockerfile` | **Modify** | Add `ARG N8N_VERSION=x.x.x` and use it in npm install |
| `renovate.json` | **Create** | Configure Renovate to detect n8n version |

---

## How It Works (Flow)

```
Renovate checks npm registry (scheduled)
         │
         ▼
New n8n version detected
         │
         ▼
PR created: "Update n8n to x.x.x"
         │
         ▼
Auto-merged (weekends) or manual review (major versions)
         │
         ▼
GitHub Actions deploys to HF Spaces
         │
         ▼
n8n updated in production
```

---

## Safety Considerations

1. **Major version protection**: The config blocks auto-merge for major updates (1.x → 2.x). Use n8n's [Migration Report tool](https://blog.n8n.io/introducing-n8n-2-0/) before manually merging these.

2. **Your settings**:
   - Auto-merge: ✅ Enabled for patch AND minor updates
   - Schedule: Weekends only
   - Manual review: Required for major version updates only

3. **Rollback**: If an update breaks workflows:
   - Revert the Renovate PR commit in GitHub
   - Push reverts to trigger redeployment

4. **Monitoring**: Watch the Renovate dashboard issue for update status and any failed merges

---

## Verification

After implementation:
1. Check Renovate dashboard issue in GitHub for detected dependencies
2. Wait for scheduled run or trigger manually via dashboard
3. Review the auto-created PR for n8n update
4. Merge and verify HF Spaces deployment succeeds
5. Test critical workflows in n8n

---

## Sources
- [Renovate Regex Manager Docs](https://docs.renovatebot.com/modules/manager/regex/)
- [n8n 2.0 Migration Guide](https://blog.n8n.io/introducing-n8n-2-0/)
- [n8n Release Notes](https://docs.n8n.io/release-notes/)
- [Renovate vs Dependabot Comparison](https://www.turbostarter.dev/blog/renovate-vs-dependabot-whats-the-best-tool-to-automate-your-dependency-updates)
