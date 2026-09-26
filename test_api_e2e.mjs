import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';

// Read .env if present
let envFile = '';
try { envFile = readFileSync('.env', 'utf-8'); } catch {}
const envVars = { ...process.env };
for (const line of envFile.split('\n')) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const [k, ...v] = trimmed.split('=');
  envVars[k.trim()] = v.join('=').trim();
}

console.log('🚀 Starting VYRA API test suite...');

const server = spawn('node', ['services/api/dist/index.js'], {
  env: envVars,
  stdio: ['ignore', 'pipe', 'pipe']
});

let serverLogs = '';
server.stdout.on('data', (d) => { serverLogs += d.toString(); });
server.stderr.on('data', (d) => { serverLogs += d.toString(); });

async function wait(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function runTests() {
  // Wait 1.5s for server to start
  await wait(1500);

  const BASE = 'http://127.0.0.1:4000';
  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  ✅ PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  ❌ FAIL: ${name} ->`, err.message);
      if (serverLogs) {
        console.error(`     Server log:\n${serverLogs.trim()}`);
        serverLogs = '';
      }
      failed++;
    }
  }

  // 1. /health
  await test('GET /health', async () => {
    const res = await fetch(`${BASE}/health`);
    const data = await res.json();
    if (res.status !== 200 || !data.ok) throw new Error(JSON.stringify(data));
  });

  // 2. Demo login
  let token = '';
  await test('POST /v1/demo/session', async () => {
    const res = await fetch(`${BASE}/v1/demo/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ preset: 'student' })
    });
    const json = await res.json();
    const payload = json.data ?? json;
    if (!payload.accessToken) throw new Error(`No accessToken: ${JSON.stringify(json)}`);
    token = payload.accessToken;
  });

  const authHeaders = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };

  // 3. /v1/today
  await test('GET /v1/today', async () => {
    const res = await fetch(`${BASE}/v1/today`, { headers: authHeaders });
    const json = await res.json();
    const payload = json.data ?? json;
    if (res.status !== 200 || !payload.plan) throw new Error(JSON.stringify(json));
  });

  // 4. /v1/library
  await test('GET /v1/library', async () => {
    const res = await fetch(`${BASE}/v1/library`, { headers: authHeaders });
    const json = await res.json();
    const payload = json.data ?? json;
    if (res.status !== 200 || !Array.isArray(payload.items)) throw new Error(JSON.stringify(json));
  });

  // 5. /v1/leaderboard (Added in Phase 3)
  await test('GET /v1/leaderboard', async () => {
    const res = await fetch(`${BASE}/v1/leaderboard`, { headers: authHeaders });
    const json = await res.json();
    const payload = json.data ?? json;
    if (res.status !== 200 || !Array.isArray(payload.rows)) throw new Error(JSON.stringify(json));
  });

  // 6. /v1/activities with dual telemetry (Added in Phase 4)
  await test('POST /v1/activities (GPS + stepCount)', async () => {
    const res = await fetch(`${BASE}/v1/activities`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({
        type: 'run',
        title: 'Morning Park Run',
        distanceM: 2500,
        durationSec: 900,
        stepCount: 3200,
        startedAt: new Date().toISOString(),
        route: [
          { lat: 28.6139, lng: 77.2090, t: 0 },
          { lat: 28.6145, lng: 77.2095, t: 60 }
        ]
      })
    });
    const json = await res.json();
    if (res.status !== 200 && res.status !== 201) throw new Error(JSON.stringify(json));
  });

  // 7. /v1/feed
  await test('GET /v1/feed', async () => {
    const res = await fetch(`${BASE}/v1/feed`, { headers: authHeaders });
    const json = await res.json();
    const payload = json.data ?? json;
    if (res.status !== 200 || !Array.isArray(payload.items)) throw new Error(JSON.stringify(json));
  });

  // 8. /v1/tracking
  await test('POST /v1/tracking', async () => {
    const res = await fetch(`${BASE}/v1/tracking`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({ steps: 8500, waterMl: 2000 })
    });
    const json = await res.json();
    if (res.status !== 200) throw new Error(JSON.stringify(json));
  });

  // 9. /v1/reports (Added in Phase 2)
  await test('POST /v1/reports', async () => {
    const res = await fetch(`${BASE}/v1/reports`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({
        targetType: 'user',
        targetId: 'user_test_target_123',
        reason: 'spam',
        detail: 'Test spam report'
      })
    });
    const json = await res.json();
    if (res.status !== 200 || !json.ok) throw new Error(JSON.stringify(json));
  });

  // 10. /v1/blocks/:userId & /v1/blocks (Added in Phase 2)
  await test('POST & GET /v1/blocks', async () => {
    const blockRes = await fetch(`${BASE}/v1/blocks/user_target_456`, {
      method: 'POST',
      headers: authHeaders
    });
    const blockJson = await blockRes.json();
    if (blockRes.status !== 200 || !blockJson.ok) throw new Error(JSON.stringify(blockJson));

    const listRes = await fetch(`${BASE}/v1/blocks`, { headers: authHeaders });
    const listJson = await listRes.json();
    const payload = listJson.data ?? listJson;
    if (listRes.status !== 200 || !Array.isArray(payload.items)) throw new Error(JSON.stringify(listJson));
  });

  // 11. AI graceful degradation when keys are unconfigured
  await test('AI endpoints graceful degradation (HTTP 503 / 400, no server crash)', async () => {
    const recipeRes = await fetch(`${BASE}/v1/ai/recipe`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({ ingredients: ['spinach', 'tofu'] })
    });
    // Should be 503 when no key is set
    if (recipeRes.status !== 503) {
      throw new Error(`Expected 503 for unconfigured recipe AI, got ${recipeRes.status}`);
    }

    const chatRes = await fetch(`${BASE}/v1/chat/message`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({ message: 'Hello coach' })
    });
    if (chatRes.status !== 503) {
      throw new Error(`Expected 503 for unconfigured chat AI, got ${chatRes.status}`);
    }

    const foodRes = await fetch(`${BASE}/v1/food/scan`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({ imageBase64: 'dGVzdA==', mimeType: 'image/jpeg' })
    });
    if (foodRes.status !== 400 && foodRes.status !== 503) {
      throw new Error(`Expected 400/503 for unconfigured food AI, got ${foodRes.status}`);
    }

    const labRes = await fetch(`${BASE}/v1/lab-report/analyse`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({ imageBase64: 'dGVzdA==', mimeType: 'image/jpeg' })
    });
    if (labRes.status !== 400 && labRes.status !== 503) {
      throw new Error(`Expected 400/503 for unconfigured lab AI, got ${labRes.status}`);
    }
  });

  // 12. Follow, Unfollow, Search, and Graph Sync
  await test('Follow / Unfollow / Search / Followers Graph flow', async () => {
    // Login as a second user (nurse)
    const nurseRes = await fetch(`${BASE}/v1/demo/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ preset: 'nurse' })
    });
    const nurseJson = await nurseRes.json();
    const nursePayload = nurseJson.data ?? nurseJson;
    const nurseToken = nursePayload.accessToken;
    const nurseId = nursePayload.userId;
    const nurseHeaders = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${nurseToken}`,
    };

    // User 1 searches for nurse
    const searchRes = await fetch(`${BASE}/v1/users/search?q=nurse`, {
      headers: authHeaders,
    });
    const searchJson = await searchRes.json();
    const searchPayload = searchJson.data ?? searchJson;
    if (!Array.isArray(searchPayload.items)) {
      throw new Error(`Search failed: ${JSON.stringify(searchJson)}`);
    }

    // User 1 follows Nurse
    const followRes = await fetch(`${BASE}/v1/follow/${nurseId}`, {
      method: 'POST',
      headers: authHeaders,
    });
    const followJson = await followRes.json();
    if (followRes.status !== 200 || !(followJson.data?.following ?? followJson.following)) {
      throw new Error(`Follow failed: ${JSON.stringify(followJson)}`);
    }

    // Verify Nurse appears in User 1's following
    const followingRes = await fetch(`${BASE}/v1/me/following`, {
      headers: authHeaders,
    });
    const followingJson = await followingRes.json();
    const followingPayload = followingJson.data ?? followingJson;
    const foundInFollowing = followingPayload.items.some(u => u.id === nurseId);
    if (!foundInFollowing) {
      throw new Error(`User was not found in following list: ${JSON.stringify(followingJson)}`);
    }

    // Verify User 1 appears in Nurse's followers
    const followersRes = await fetch(`${BASE}/v1/me/followers`, {
      headers: nurseHeaders,
    });
    const followersJson = await followersRes.json();
    const followersPayload = followersJson.data ?? followersJson;
    if (!Array.isArray(followersPayload.items) || followersPayload.items.length === 0) {
      throw new Error(`Follower not reflected: ${JSON.stringify(followersJson)}`);
    }

    // User 1 unfollows Nurse
    const unfollowRes = await fetch(`${BASE}/v1/follow/${nurseId}`, {
      method: 'DELETE',
      headers: authHeaders,
    });
    const unfollowJson = await unfollowRes.json();
    if (unfollowRes.status !== 200) {
      throw new Error(`Unfollow failed: ${JSON.stringify(unfollowJson)}`);
    }

    // Verify Nurse is no longer in User 1's following
    const reFollowingRes = await fetch(`${BASE}/v1/me/following`, {
      headers: authHeaders,
    });
    const reFollowingJson = await reFollowingRes.json();
    const reFollowingPayload = reFollowingJson.data ?? reFollowingJson;
    if (reFollowingPayload.items.some(u => u.id === nurseId)) {
      throw new Error(`User still in following list after unfollow`);
    }
  });

  console.log(`\n========================================`);
  console.log(`RESULTS: ${passed} passed, ${failed} failed`);
  console.log(`========================================`);

  server.kill();
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch((err) => {
  console.error('Fatal test runner error:', err);
  if (serverLogs) console.error('Server logs:\n', serverLogs);
  server.kill();
  process.exit(1);
});
