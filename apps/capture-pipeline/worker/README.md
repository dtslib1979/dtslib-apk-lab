# Parksy Capture Worker

Cloudflare Worker for Parksy Capture Pipeline.

## Deploy

1. Install Wrangler CLI:
   ```bash
   npm install -g wrangler
   ```

2. Login to Cloudflare:
   ```bash
   wrangler login
   ```

3. Set secrets:
   ```bash
   wrangler secret put GITHUB_TOKEN
   wrangler secret put API_KEY
   ```

4. Deploy:
   ```bash
   wrangler deploy
   ```

## Environment Variables

| Name | Description |
|------|-------------|
| `GITHUB_TOKEN` | GitHub Personal Access Token (repo scope) |
| `API_KEY` | Simple API key for request validation |
| `REPO_OWNER` | GitHub username (default: dtslib1979) |
| `REPO_NAME` | Archive repo name (default: parksy-logs) |

## API

### POST /

Request:
```json
{
  "text": "Captured text content",
  "source": "android",
  "ts": "2025-12-14T12:00:00Z"
}
```

Headers:
```
X-API-Key: your-api-key
Content-Type: application/json
```

Response:
```json
{
  "ok": true,
  "path": "logs/2025/12/20251214_120000.md"
}
```
