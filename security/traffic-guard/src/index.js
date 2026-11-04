const WINDOWS = Object.freeze({
  api: { max: 120, durationMs: 60_000 },
  storage: { max: 30, durationMs: 60_000 },
});
const BAN_AFTER_WINDOWS = 3;
const VIOLATION_WINDOW_MS = 15 * 60_000;
const TEMP_BAN_MS = 30 * 60_000;

function json(body, status = 200, headers = {}) {
  return Response.json(body, { status, headers });
}

async function hashIp(ip) {
  const bytes = new TextEncoder().encode(ip.trim());
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, '0')).join('');
}

export class IpGuard {
  constructor(state) {
    this.state = state;
  }

  async fetch(request) {
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    let input;
    try { input = await request.json(); } catch { return json({ error: 'Invalid request' }, 400); }
    const policy = WINDOWS[input.bucket];
    if (!policy || typeof input.ipHash !== 'string' || !/^[a-f0-9]{64}$/.test(input.ipHash)) {
      return json({ error: 'Invalid request' }, 400);
    }

    const now = Date.now();
    const result = await this.state.storage.transaction(async (storage) => {
      const banUntil = await storage.get('ban-until') || 0;
      if (banUntil > now) return { allowed: false, retryAfter: Math.ceil((banUntil - now) / 1000), banned: true, cleanupAt: banUntil };
      if (banUntil) await storage.delete('ban-until');

      const key = `window:${input.bucket}`;
      let window = await storage.get(key);
      if (!window || now - window.startedAt >= policy.durationMs) {
        window = { startedAt: Math.floor(now / policy.durationMs) * policy.durationMs, count: 0 };
      }
      window.count += 1;
      await storage.put(key, window);
      if (window.count <= policy.max) return { allowed: true };

      const violationKey = 'violation-windows';
      const violations = (await storage.get(violationKey) || []).filter((time) => now - time < VIOLATION_WINDOW_MS);
      if (!violations.includes(window.startedAt)) violations.push(window.startedAt);
      if (violations.length >= BAN_AFTER_WINDOWS) {
        await storage.put('ban-until', now + TEMP_BAN_MS);
        await storage.delete(violationKey);
        return { allowed: false, retryAfter: TEMP_BAN_MS / 1000, banned: true, cleanupAt: now + TEMP_BAN_MS };
      }
      await storage.put(violationKey, violations);
      return { allowed: false, retryAfter: Math.max(1, Math.ceil((window.startedAt + policy.durationMs - now) / 1000)), banned: false, cleanupAt: now + VIOLATION_WINDOW_MS };
    });

    await this.state.storage.setAlarm(result.cleanupAt || now + VIOLATION_WINDOW_MS);
    if (result.allowed) return json({ allowed: true });
    return json({ allowed: false, banned: result.banned }, 429, { 'Retry-After': String(result.retryAfter), 'Cache-Control': 'no-store' });
  }

  async alarm() {
    await this.state.storage.deleteAll();
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/check' || request.method !== 'POST') return json({ error: 'Not found' }, 404);
    const configuredSecret = env.GUARD_SHARED_SECRET;
    if (!configuredSecret || request.headers.get('X-Frostly-Guard-Secret') !== configuredSecret) {
      return json({ error: 'Forbidden' }, 403);
    }
    let input;
    try { input = await request.json(); } catch { return json({ error: 'Invalid request' }, 400); }
    const policy = WINDOWS[input.bucket];
    if (!policy || typeof input.ip !== 'string' || input.ip.length > 64 || input.ip === 'unknown') {
      return json({ error: 'Invalid request' }, 400);
    }
    const ipHash = await hashIp(input.ip);
    const id = env.IP_GUARD.idFromName(ipHash);
    return env.IP_GUARD.get(id).fetch('https://ip-guard/check', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ipHash, bucket: input.bucket }),
    });
  },
};
