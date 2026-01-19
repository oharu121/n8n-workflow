# Simplified Git Sync Workflow Plan

## Overview

Simplify the current `git-sync-workflow` from 21 nodes to approximately 8-10 nodes by:
1. Comparing n8n `updatedAt` vs GitHub file's last commit date
2. Using one REST API call per workflow to get commit date
3. Committing directly to `main` branch (no PR workflow)
4. Removing static data state management

## Key Insight

Instead of fetching file content to compare `updatedAt`, we compare:
- **n8n `updatedAt`** = when workflow was last saved in n8n
- **GitHub last commit date** = when file was last committed

```
If n8n.updatedAt > GitHub.lastCommitDate → Commit the file
```

This eliminates the need to read file content from GitHub.

## Current vs Proposed Architecture

### Current Flow (21 nodes)
```
Schedule Trigger → Branch Check/Create → Get Workflows → Detect Changes (static data)
→ Split → Get SHA → Delete/Update → Aggregate → PR Check/Create → Auto-Merge → Save State
```

### Proposed Flow (~8 nodes)
```
Schedule Trigger
    ↓
Get All n8n Workflows
    ↓
Split Into Items (one per workflow)
    ↓
Get Last Commit Date (REST: /commits?path=workflows/{filename})
    ↓
Compare Dates (n8n.updatedAt > GitHub.commitDate?)
    ↓
[If newer] Get File SHA → Commit to Main
```

---

## Detailed Node Changes

### Nodes to REMOVE (13 nodes)

| Node Name | Reason |
|-----------|--------|
| Check Branch Exists | No longer using n8n-sync branch |
| Branch Exists? | No longer using n8n-sync branch |
| Get Main SHA | No longer creating branches |
| Create n8n-sync Branch | No longer using n8n-sync branch |
| Branch is ready | No longer using n8n-sync branch |
| Merge (after branch) | No longer using n8n-sync branch |
| Check Existing PR | No PR workflow |
| PR Exists? | No PR workflow |
| Create PR | No PR workflow |
| Get Existing PR | No PR workflow |
| Merge PR (Auto) | No PR workflow |
| Save State | No static data tracking |
| Delete File | Simplify - only handle updates (see note below) |
| Is Delete? | Simplify - only handle updates |
| Aggregate Results | Not needed with simplified flow |

> **Note on Delete:** If you want to handle deleted workflows, you can add it back later. For now, focusing on sync (create/update) keeps it simple.

### Nodes to KEEP (modified)

| Node Name | Changes Needed |
|-----------|----------------|
| Schedule Trigger | No change |
| Get All Workflows | No change |
| Has Changes? | No change (reuse logic) |
| Split Into Items | Simplify - remove delete handling |
| Get File SHA | Change branch from `n8n-sync` to `main` |
| No Changes | No change |

### Nodes to ADD (2 nodes)

| Node Name | Purpose |
|-----------|---------|
| Get Last Commit Date | REST API: `/commits?path=workflows/{filename}&per_page=1` |
| Compare Dates | Code node to check if n8n.updatedAt > GitHub.commitDate |

### Nodes to MODIFY (2 nodes)

| Node Name | Changes Needed |
|-----------|----------------|
| Create/Update File | Change branch from `n8n-sync` to `main` |
| Build Request Body | Simplify - remove currentMap tracking |

---

## New Node Implementations

### 1. Get Last Commit Date (HTTP Request)

**Node Type:** HTTP Request
**Position:** After "Split Into Items"

**Configuration:**
```
Method: GET
URL: https://api.github.com/repos/oharu121/n8n-workflow/commits
Authentication: Bearer Token (existing: n8n sync github token)
Query Parameters:
  path: =workflows/{{ $json.filename }}
  per_page: 1
Options:
  Never Error: true  (handles new files that have no commits)
```

**Expected Response (existing file):**
```json
[
  {
    "sha": "abc123...",
    "commit": {
      "committer": {
        "date": "2026-01-17T16:10:00Z"
      }
    }
  }
]
```

**Expected Response (new file - no commits):**
```json
[]
```

### 2. Compare Dates (Code Node)

**Node Type:** Code
**Position:** After "Get Last Commit Date"

**JavaScript Code:**
```javascript
const workflow = $('Split Into Items').item.json;
const commits = $json;  // Array from GitHub API

// Get GitHub's last commit date (null if file doesn't exist)
let githubCommitDate = null;
if (Array.isArray(commits) && commits.length > 0) {
  githubCommitDate = new Date(commits[0].commit.committer.date);
}

// Get n8n's updatedAt
const n8nUpdatedAt = new Date(workflow.updatedAt);

// Determine if we need to sync
let needsSync = false;
let reason = '';

if (!githubCommitDate) {
  // File doesn't exist in GitHub yet
  needsSync = true;
  reason = 'new file';
} else if (n8nUpdatedAt > githubCommitDate) {
  // n8n version is newer
  needsSync = true;
  reason = 'updated';
} else {
  reason = 'already synced';
}

return {
  json: {
    ...workflow,
    needsSync,
    reason,
    n8nUpdatedAt: workflow.updatedAt,
    githubCommitDate: githubCommitDate ? githubCommitDate.toISOString() : null
  }
};
```

### 3. Modified: Split Into Items (Code Node)

**Simplified JavaScript Code:**
```javascript
// Convert all workflows to individual items with filename
const workflows = $input.all().map(item => item.json);

// Helper: sanitize workflow name for filename
function sanitizeName(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

return workflows.map(wf => ({
  json: {
    ...wf,
    filename: sanitizeName(wf.name) + '.json',
    workflow: wf  // Keep full workflow for later commit
  }
}));
```

### 4. Modified: Get File SHA (HTTP Request)

**Changes:**
- Query parameter `ref`: Change from `n8n-sync` to `main`

```
URL: https://api.github.com/repos/oharu121/n8n-workflow/contents/workflows/{{ $json.filename }}
Query Parameters:
  ref: main  (changed from n8n-sync)
Options:
  Never Error: true
```

### 5. Modified: Build Request Body (Code Node)

**Simplified JavaScript Code:**
```javascript
const original = $('Split Into Items').item.json;
const sha = $json.sha;

const body = {
  message: `chore(n8n): sync workflow '${original.name}' [auto-sync]`,
  content: original.contentBase64,
  branch: 'main'  // Changed from 'n8n-sync'
};

if (sha) {
  body.sha = sha;
}

return { json: { requestBody: body, filename: original.filename } };
```

### 6. Modified: Create/Update File (HTTP Request)

**Changes:**
- The `jsonBody` now commits to `main` branch (handled by Build Request Body)
- No other changes needed

---

## New Flow Connections

```
Schedule Trigger
        ↓
Get All Workflows (n8n API)
        ↓
Split Into Items (one per workflow)
        ↓
Get Last Commit Date (GitHub REST API)
        ↓
Compare Dates (Code node)
        ↓
    Needs Sync?
    /         \
 [Yes]        [No]
   ↓            ↓
Get File SHA   (skip)
   ↓
Build Request Body
   ↓
Create/Update File (commit to main)
```

---

## Implementation Steps (for n8n UI)

### Step 1: Remove Old Nodes (13 nodes)
Delete these nodes first:
1. Save State
2. Merge PR (Auto)
3. Get Existing PR
4. Create PR
5. PR Exists?
6. Check Existing PR
7. Aggregate Results
8. Delete File
9. Is Delete?
10. Merge (the one after branch creation)
11. Branch is ready
12. Create n8n-sync Branch
13. Get Main SHA
14. Branch Exists?
15. Check Branch Exists
16. Detect Changes (will be replaced)
17. Has Changes? (will be replaced)
18. No Changes (optional, can keep for clarity)

### Step 2: Add New Nodes
1. Add **HTTP Request** node named "Get Last Commit Date"
   - Method: GET
   - URL: `https://api.github.com/repos/oharu121/n8n-workflow/commits`
   - Query: `path=workflows/{{ $json.filename }}`, `per_page=1`
   - Auth: Bearer token
   - Options: Never Error = true

2. Add **Code** node named "Compare Dates"
   - Use the code from section above

3. Add **IF** node named "Needs Sync?"
   - Condition: `{{ $json.needsSync }}` equals `true`

### Step 3: Rewire Connections
```
Schedule Trigger → Get All Workflows → Split Into Items → Get Last Commit Date
→ Compare Dates → Needs Sync? → [true] → Get File SHA → Build Request Body → Create/Update File
```

### Step 4: Modify Existing Nodes
1. **Split Into Items**: Update code (see section above)
2. **Get File SHA**: Change `ref` query param from `n8n-sync` to `main`
3. **Build Request Body**: Change branch from `n8n-sync` to `main`
4. **Create/Update File**: No changes needed (uses Build Request Body output)

### Step 5: Test
1. Manually trigger the workflow
2. Check that "Get Last Commit Date" returns commit info
3. Verify "Compare Dates" correctly identifies newer workflows
4. Confirm commits go directly to `main` branch

---

## Verification Checklist

- [ ] "Get Last Commit Date" returns commit info for existing files
- [ ] "Get Last Commit Date" returns empty array for new files (no error)
- [ ] "Compare Dates" correctly identifies: new files, updated files, already-synced files
- [ ] Unchanged workflows are skipped (not committed)
- [ ] Commits go to `main` branch (not `n8n-sync`)
- [ ] Commit messages are correct
- [ ] No errors when workflow doesn't exist in GitHub yet

## API Rate Limit Info

- **GitHub REST API limit:** 5,000 requests/hour (authenticated)
- **Your usage per sync:** ~2 calls per workflow (commit date + commit)
- **With 10 workflows, hourly sync:** ~20 calls/hour = **0.4% of quota**

---

## Future Enhancements (Optional)

1. **Handle Deletions**: Add logic to detect workflows deleted from n8n
2. **Error Notifications**: Add Slack/Email notification on failure
3. **Dry Run Mode**: Add option to preview changes without committing
4. **Rate Limiting**: Add delay between commits if syncing many workflows
