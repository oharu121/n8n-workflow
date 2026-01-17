# n8n Workflow Auto-Save to Git Repository - Plan

## Goal
Automatically sync n8n workflows to this Git repository every 5 minutes, pushing to a feature branch with auto-merge PR.

## User Decisions
- **Sync Frequency:** Every 5 minutes
- **Push Strategy:** Push to `n8n-sync` branch + auto-merge PR
- **Deletion Sync:** Yes, remove deleted workflows from git

---

## Workflow File

| File | Nodes | Description |
|------|-------|-------------|
| `workflows/git-sync-workflow.json` | 22 | Complete workflow with branch creation logic |

**Note**: Uses HTTP Request nodes for GitHub API calls (more flexible than native GitHub node for create/update operations).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    n8n Instance                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │           "Git Sync" Meta-Workflow                     │ │
│  │                                                        │ │
│  │  [Schedule: 5min] → [n8n API: Get All Workflows]      │ │
│  │          ↓                                             │ │
│  │  [Code: Compare with stored state]                    │ │
│  │          ↓                                             │ │
│  │  [Split: Created/Updated/Deleted]                     │ │
│  │          ↓                                             │ │
│  │  [GitHub API: Commit changes to n8n-sync branch]      │ │
│  │          ↓                                             │ │
│  │  [GitHub API: Create/Update PR to main]               │ │
│  │          ↓                                             │ │
│  │  [GitHub API: Enable auto-merge]                      │ │
│  │          ↓                                             │ │
│  │  [Store new state]                                    │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓
              GitHub Repository (this repo)
              └── workflows/*.json
```

---

## Implementation Details

### Workflow Nodes

#### 1. Schedule Trigger
- Runs every 5 minutes
- Also supports manual execution for testing

#### 2. n8n API Node - Fetch Workflows
- Uses internal n8n API: `GET /api/v1/workflows`
- Returns all workflows with metadata (`id`, `name`, `updatedAt`, `nodes`, etc.)
- **Excludes this sync workflow itself** to prevent infinite loops

#### 3. Code Node - Compare & Detect Changes
```javascript
// Compare current workflows vs. stored state
// Uses getWorkflowStaticData() for persistence
// Returns: { created: [], updated: [], deleted: [] }
```

- **Created:** Workflows in n8n but not in stored state
- **Updated:** Workflows where `updatedAt` changed
- **Deleted:** Workflows in stored state but not in n8n

#### 4. GitHub API - Sync Branch Operations
For each changed workflow:

**Created/Updated:**
1. Get file SHA if exists (needed for updates)
2. PUT `/repos/{owner}/{repo}/contents/workflows/{name}.json`
   - Branch: `n8n-sync`
   - Message: `"chore(n8n): sync workflow '{name}' [auto]"`

**Deleted:**
1. DELETE `/repos/{owner}/{repo}/contents/workflows/{name}.json`
   - Branch: `n8n-sync`
   - Message: `"chore(n8n): remove workflow '{name}' [auto]"`

#### 5. GitHub API - PR Management
1. Check if PR from `n8n-sync` → `main` exists
2. If not, create PR:
   - Title: `"chore(n8n): workflow sync [auto]"`
   - Body: Lists changed workflows
3. Enable auto-merge via GraphQL API:
   ```graphql
   mutation {
     enablePullRequestAutoMerge(input: {
       pullRequestId: "...",
       mergeMethod: SQUASH
     })
   }
   ```

#### 6. Store State
- Save current workflow list with `updatedAt` timestamps
- Uses `getWorkflowStaticData()` for persistence across runs

---

## File Naming Convention

Workflows saved as: `workflows/{sanitized-name}.json`

**Sanitization rules:**
- Lowercase
- Replace spaces with hyphens
- Remove special characters
- Example: `"Pick News & Send Mail"` → `pick-news-send-mail.json`

---

## Required Credentials

### In n8n:
1. **GitHub OAuth2 or Personal Access Token**
   - Scopes: `repo` (full control of private repos)
   - Or fine-grained: `contents:write`, `pull_requests:write`

### Environment Setup:
- Repository: `jeffliuhai/n8n-workflow` (or configurable)
- Branch: `n8n-sync`
- Base branch: `main`

---

## Files Created

| File | Purpose |
|------|---------|
| `workflows/git-sync-workflow.json` | The n8n workflow to import (22 nodes) |
| `.plans/git-sync-implementation.md` | This plan document |
| `.plans/git-sync-comparison.md` | Comparison of n8n vs GitHub Actions approach |

---

## Edge Cases Handled

1. **First run:** No stored state → all workflows treated as "created"
2. **Self-exclusion:** Sync workflow excludes itself to prevent loops
3. **Empty changes:** Skip GitHub operations if nothing changed
4. **Duplicate names:** Append workflow ID if names collide
5. **Rate limits:** GitHub API has 5000 req/hour; 5-min interval is safe
6. **Branch doesn't exist:** Create `n8n-sync` branch from `main` on first run

---

## Verification Plan

1. **Import workflow** into n8n instance
2. **Configure GitHub credentials** in n8n
3. **Activate the workflow**
4. **Create a test workflow** in n8n (e.g., "Test Workflow")
5. **Wait 5 minutes** (or trigger manually)
6. **Verify:**
   - New branch `n8n-sync` created
   - PR created with workflow JSON
   - Auto-merge enabled on PR
   - PR merges to `main`
7. **Test deletion:** Delete test workflow, verify it's removed from repo
8. **Test update:** Modify existing workflow, verify commit updates file

---

## Sources
- [n8n Bidirectional GitHub Sync Template](https://n8n.io/workflows/5081-bidirectional-github-workflow-sync-and-version-control-for-n8n-workflows/)
- [n8n Git Backup Template](https://n8n.io/workflows/1053-git-backup-of-workflows-and-credentials/)
- [n8n Automated Daily Backup to GitHub](https://n8n.io/workflows/4064-automated-daily-workflow-backup-to-github/)
- [n8n Trigger Node Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.n8ntrigger/)
- [n8n GitOps Community Solution](https://community.n8n.io/t/turn-your-n8n-workflows-into-a-real-gitops-pipeline/118130)
- [n8n Polling Triggers Blog](https://blog.n8n.io/creating-triggers-for-n8n-workflows-using-polling/)
