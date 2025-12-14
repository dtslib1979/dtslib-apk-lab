/**
 * Parksy Capture Worker
 * Receives text from Android app, saves to GitHub as Markdown
 */

export default {
  async fetch(request, env) {
    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
        },
      });
    }

    // POST only
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    // Auth check
    const apiKey = request.headers.get('X-API-Key');
    if (!apiKey || apiKey !== env.API_KEY) {
      return json({ error: 'Unauthorized' }, 401);
    }

    try {
      const body = await request.json();
      const { text, source, ts } = body;

      if (!text) {
        return json({ error: 'Missing text' }, 400);
      }

      // Generate filename: logs/YYYY/MM/YYYYMMDD_HHmmss.md
      const now = new Date(ts || Date.now());
      const y = now.getFullYear();
      const m = String(now.getMonth() + 1).padStart(2, '0');
      const d = String(now.getDate()).padStart(2, '0');
      const h = String(now.getHours()).padStart(2, '0');
      const mi = String(now.getMinutes()).padStart(2, '0');
      const s = String(now.getSeconds()).padStart(2, '0');
      
      const filename = `${y}${m}${d}_${h}${mi}${s}.md`;
      const path = `logs/${y}/${m}/${filename}`;

      // Create Markdown content
      const content = `---
date: ${now.toISOString()}
source: ${source || 'unknown'}
---

${text}
`;

      // Push to GitHub
      const ghRes = await createGitHubFile(env, path, content);
      
      if (!ghRes.ok) {
        const err = await ghRes.text();
        return json({ error: 'GitHub API failed', detail: err }, 500);
      }

      return json({ ok: true, path });

    } catch (e) {
      return json({ error: e.message }, 500);
    }
  },
};

async function createGitHubFile(env, path, content) {
  const url = `https://api.github.com/repos/${env.REPO_OWNER}/${env.REPO_NAME}/contents/${path}`;
  
  const body = {
    message: `capture: ${path}`,
    content: btoa(unescape(encodeURIComponent(content))),
    branch: 'main',
  };

  return fetch(url, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'Parksy-Capture-Worker',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
