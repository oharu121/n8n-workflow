---
title: n8n Workflow Automation
emoji: ⚡
colorFrom: orange
colorTo: red
sdk: docker
app_port: 7860
pinned: false
license: fair-code
---

# n8n Workflow Automation on Hugging Face Spaces

Self-hosted n8n instance with Supabase PostgreSQL backend for persistent storage.

## Features

- Full n8n workflow automation platform
- Persistent storage with Supabase PostgreSQL
- Basic authentication for security
- Health endpoints for monitoring and wake-up
- Chromium for web scraping workflows
- FFmpeg and yt-dlp for media processing

## Health Endpoints

| Endpoint | Description |
|----------|-------------|
| `/healthz` | Instance reachability check (returns 200 if up) |
| `/healthz/readiness` | Database connection check (returns 200 if DB connected) |

## Wake-Up

This Space sleeps after 48 hours of inactivity on free tier. To keep it alive:

1. Use Google Apps Script with a time-driven trigger (every 40 hours)
2. Call `GET /healthz` to wake up the Space

```javascript
function wakeUpN8n() {
  const url = 'https://oharu121-n8n-workflow.hf.space/healthz';
  const response = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  Logger.log('n8n status: ' + response.getResponseCode());
}
```

## Workflows

- **pick-news-and-send-mail** - Aggregates Hacker News, processes with AI, sends email summary

## Environment Variables

See [.dev-notes/2025-12-30.md](.dev-notes/2025-12-30.md) for full configuration details.

## Deployment

Automatically deployed via GitHub Actions on push to `main` branch.

## Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Hugging Face Spaces](https://huggingface.co/docs/hub/spaces)
- [Supabase](https://supabase.com/)
