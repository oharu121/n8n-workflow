# Pick News and Send Mail Workflow

An automated n8n workflow that fetches popular Hacker News articles, extracts and summarizes their content using AI, and sends a daily digest email.

## Overview

This workflow automatically:
1. Fetches the newest high-quality posts from Hacker News (100+ points)
2. Limits to the top 3 articles
3. Retrieves full article content from each link
4. Uses Google Gemini AI to generate concise summaries in Traditional Chinese
5. Aggregates all summaries into a single formatted email
6. Sends the digest to a specified Gmail address

## Workflow Components

### Nodes

1. **Schedule Trigger** - Runs the workflow at scheduled intervals
2. **RSS Read** - Fetches articles from Hacker News RSS feed (`https://hnrss.org/newest?points=100`)
3. **Limit** - Restricts to top 3 articles
4. **HTTP Request** - Fetches the full article content from each link
5. **HTML** - Extracts text content from the article body
6. **If** - Validates that article text was successfully extracted
7. **AI Agent** - Processes article text with Google Gemini
8. **Google Gemini Chat Model** - AI language model for summarization
9. **Aggregate** - Combines all article summaries
10. **Markdown** - Converts aggregated summaries to HTML format
11. **Send a message** - Sends the final digest via Gmail

## AI Summarization

The AI Agent uses a custom prompt to extract and format article content:

- **Task**: Extract core content from raw article text, ignoring ads and navigation
- **Output Format**: Structured markdown with:
  - Article title
  - Brief summary (50-80 characters)
  - 3 key bullet points
- **Language**: Traditional Chinese (繁體中文)

## Configuration

### Required Credentials

1. **Google Gemini API** - For AI summarization
   - Credential ID: `5hIbERo5Dcc78b8s`
   - Name: "Google Gemini(PaLM) Api account"

2. **Gmail OAuth2** - For sending emails
   - Credential ID: `tYnFQAtq88aj3pgq`
   - Name: "Gmail account"

### Email Configuration

- **Recipient**: `jefflin1201@gmail.com`
- **Subject**: "熱門新聞彙總" (Popular News Digest)
- **Format**: HTML email with formatted summaries

## Workflow Settings

- **Execution Order**: v1
- **Status**: Active
- **Workflow ID**: `4ClurJJsVM2kdvQg`

## Data Flow

```
Schedule Trigger → RSS Read → Limit → HTTP Request → HTML → If (validation)
                                                              ↓
Gmail ← Markdown ← Aggregate ← AI Agent ← (filtered articles)
                                ↑
                    Google Gemini Chat Model
```

## Customization

### Adjust Article Count
Modify the **Limit** node `maxItems` parameter (currently set to 3)

### Change RSS Source
Update the **RSS Read** node `url` parameter to use different RSS feeds

### Modify Summary Language
Edit the AI Agent's `systemMessage` to change the output language

### Update Email Recipient
Change the **Send a message** node `sendTo` parameter

## Notes

- The workflow filters articles based on Hacker News points (100+)
- Articles with empty content are filtered out before AI processing
- Summaries are converted from Markdown to HTML for better email formatting
- The AI is instructed to ignore ads, navigation, and non-content elements
