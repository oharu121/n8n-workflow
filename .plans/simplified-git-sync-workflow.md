# Simplified Git Sync Workflow Plan

## Overview

Simplify the current `git-sync-workflow` from 21 nodes to approximately 8-10 nodes by:
1. Using GitHub GraphQL API to batch fetch all workflow files
2. Comparing `updatedAt` timestamps directly
3. Committing directly to `main` branch (no PR workflow)
4. Removing static data state management

## Current vs Proposed Architecture

### Current Flow (21 nodes)
```
Schedule Trigger → Branch Check/Create → Get Workflows → Detect Changes (static data)
→ Split → Get SHA → Delete/Update → Aggregate → PR Check/Create → Auto-Merge → Save State
```

### Proposed Flow (8-10 nodes)
```
Schedule Trigger
    ↓
┌─────────────────────────────────┐
│  Get n8n Workflows              │  (parallel)
│  Get GitHub Workflows (GraphQL) │
└─────────────────────────────────┘
    ↓
Compare updatedAt
    ↓
[If changes] Split Into Items
    ↓
Get File SHA (for existing files)
    ↓
Commit to Main
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
| Get GitHub Workflows | GraphQL API call to fetch all workflow files |
| Compare updatedAt | New Code node to compare timestamps |

### Nodes to MODIFY (2 nodes)

| Node Name | Changes Needed |
|-----------|----------------|
| Create/Update File | Change branch from `n8n-sync` to `main` |
| Build Request Body | Simplify - remove currentMap tracking |

---

## New Node Implementations

### 1. Get GitHub Workflows (HTTP Request - GraphQL)

**Node Type:** HTTP Request
**Position:** Parallel with "Get All Workflows"

**Configuration:**
```
Method: POST
URL: https://api.github.com/graphql
Authentication: Bearer Token (existing: n8n sync github token)
Headers:
  Content-Type: application/json
Body (JSON):
{
  "query": "query { repository(owner: \"oharu121\", name: \"n8n-workflow\") { object(expression: \"main:workflows\") { ... on Tree { entries { name object { ... on Blob { text } } } } } } }"
}
```

**Expected Response Structure:**
```json
{
  "data": {
    "repository": {
      "object": {
        "entries": [
          {
            "name": "git-sync-workflow.json",
            "object": {
              "text": "{\"updatedAt\": \"2026-01-17T16:07:14.292Z\", ...}"
            }
          }
        ]
      }
    }
  }
}
```

### 2. Compare updatedAt (Code Node)

**Node Type:** Code
**Position:** After both Get Workflows nodes (use Merge node to combine inputs)

**JavaScript Code:**
```javascript
// Get n8n workflows from first input
const n8nWorkflows = $('Get All Workflows').all().map(item => item.json);

// Get GitHub files from GraphQL response
const githubResponse = $('Get GitHub Workflows').first().json;
const githubEntries = githubResponse.data?.repository?.object?.entries || [];

// Build map of GitHub workflows: filename -> updatedAt
const githubMap = {};
for (const entry of githubEntries) {
  if (entry.name.endsWith('.json') && entry.object?.text) {
    try {
      const content = JSON.parse(entry.object.text);
      githubMap[entry.name] = {
        updatedAt: content.updatedAt,
        exists: true
      };
    } catch (e) {
      // Skip invalid JSON files
    }
  }
}

// Helper: sanitize workflow name for filename
function sanitizeName(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

// Find workflows that need updating
const toUpdate = [];
for (const wf of n8nWorkflows) {
  const filename = sanitizeName(wf.name) + '.json';
  const github = githubMap[filename];

  // Update if: file doesn't exist OR updatedAt is different
  if (!github || github.updatedAt !== wf.updatedAt) {
    toUpdate.push({
      ...wf,
      filename: filename,
      action: github ? 'update' : 'create',
      workflow: wf
    });
  }
}

// Return changes summary
const hasChanges = toUpdate.length > 0;

return [{
  json: {
    hasChanges,
    changes: toUpdate,
    summary: `Found ${toUpdate.length} workflow(s) to sync`
  }
}];
```

### 3. Modified: Split Into Items (Code Node)

**Simplified JavaScript Code:**
```javascript
const input = $input.first().json;
const changes = input.changes || [];

return changes.map(change => {
  // Encode workflow content to base64 for GitHub API
  const jsonStr = JSON.stringify(change.workflow, null, 2);
  const contentBase64 = Buffer.from(jsonStr).toString('base64');

  return {
    json: {
      ...change,
      contentBase64: contentBase64
    }
  };
});
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
    ├──→ Get All Workflows ──────────┐
    │                                 │
    └──→ Get GitHub Workflows ───────┤
                                      ↓
                                 Merge (Wait)
                                      ↓
                              Compare updatedAt
                                      ↓
                                Has Changes?
                               /           \
                         [Yes]               [No]
                            ↓                  ↓
                    Split Into Items      No Changes
                            ↓
                      Get File SHA
                            ↓
                    Build Request Body
                            ↓
                    Create/Update File
```

---

## Implementation Steps (for n8n UI)

### Step 1: Add New Nodes
1. Add **HTTP Request** node named "Get GitHub Workflows"
   - Configure as GraphQL POST request (see config above)
2. Add **Merge** node to wait for both API calls
3. Add **Code** node named "Compare updatedAt"

### Step 2: Rewire Connections
1. Connect **Schedule Trigger** to both:
   - Get All Workflows
   - Get GitHub Workflows
2. Connect both to **Merge** node
3. Connect **Merge** → **Compare updatedAt** → **Has Changes?**

### Step 3: Remove Old Nodes
Delete these nodes (in order to avoid breaking connections):
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

### Step 4: Modify Existing Nodes
1. **Get File SHA**: Change `ref` query param to `main`
2. **Build Request Body**: Update code (see above)
3. **Split Into Items**: Update code (see above)
4. **Has Changes?**: Rewire to connect from "Compare updatedAt"

### Step 5: Test
1. Manually trigger the workflow
2. Check that GraphQL returns workflow files
3. Verify comparison logic works correctly
4. Confirm commits go directly to `main` branch

---

## Verification Checklist

- [ ] GraphQL query returns all files in `workflows/` folder
- [ ] Comparison correctly identifies new/updated workflows
- [ ] Unchanged workflows are skipped
- [ ] Commits go to `main` branch (not `n8n-sync`)
- [ ] Commit messages are correct
- [ ] No errors when workflow doesn't exist in GitHub yet

---

## Future Enhancements (Optional)

1. **Handle Deletions**: Add logic to detect workflows deleted from n8n
2. **Error Notifications**: Add Slack/Email notification on failure
3. **Dry Run Mode**: Add option to preview changes without committing
4. **Rate Limiting**: Add delay between commits if syncing many workflows
