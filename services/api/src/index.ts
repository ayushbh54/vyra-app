/**
 * VYRA API entry point.
 *
 * Boots strictly: configuration problems surface here, at startup, rather than
 * as a 500 the first time a user tries to save a blood-pressure reading.
 */

import { createServer } from 'node:http';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { buildRouter, buildDefaultDeps } from './server';
import { LIBRARY_STATS } from './content/exercises';

// Auto-load .env using Node built-in if present
for (const p of ['.env', '../../.env', '../.env']) {
  const full = resolve(process.cwd(), p);
  if (existsSync(full)) {
    try {
      if (typeof (process as unknown as { loadEnvFile?: (path?: string) => void }).loadEnvFile === 'function') {
        (process as unknown as { loadEnvFile: (path?: string) => void }).loadEnvFile(full);
      }
      break;
    } catch {}
  }
}

const PORT = Number(process.env.API_PORT ?? process.env.PORT ?? 4000);

async function main(): Promise<void> {
  let deps;
  try {
    deps = await buildDefaultDeps();
  } catch (error) {
    console.error('\n  VYRA API failed to start:\n');
    console.error(`  ${(error as Error).message}\n`);
    console.error('  Copy .env.example to .env and fill in the blanks. To generate secrets:');
    console.error('    openssl rand -base64 48   # JWT_SECRET');
    console.error('    openssl rand -base64 32   # HEALTH_ENCRYPTION_KEY_V1\n');
    process.exit(1);
  }

  const router = buildRouter(deps);
  const server = createServer(router.handle);

  // Render's proxy holds connections open; a keep-alive shorter than the
  // proxy's causes intermittent 502s under load.
  server.keepAliveTimeout = 72_000;
  server.headersTimeout = 75_000;

  server.listen(PORT, async () => {
    const store = await deps.store.health();
    console.log(`\n  VYRA API listening on http://localhost:${PORT}`);
    console.log(
      `  Store    : ${store.backend}${
        store.backend === 'memory' ? ' — data is lost on restart. Set DATABASE_URL for Postgres.' : ` (${store.detail})`
      }`,
    );
    console.log(`  AI       : ${process.env.GEMINI_API_KEY ? 'Gemini configured' : 'disabled — set GEMINI_API_KEY'}`);
    console.log(`  Library  : ${LIBRARY_STATS.total} items (${LIBRARY_STATS.seatedFriendly} seated-friendly, ${LIBRARY_STATS.recovery} recovery)`);
    console.log(`  Demo mode: ${process.env.DEMO_MODE === 'true' ? 'ON' : 'off'}\n`);
  });

  // Graceful shutdown, so a deploy does not cut off a request mid-write.
  const shutdown = (signal: string) => {
    console.log(`\n  ${signal} received, closing server...`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
