/**
 * =============================================================================
 * RATE LIMITER — in-memory sliding window
 * =============================================================================
 * Zero-dependency by rule (no Redis), so this lives entirely in process memory.
 * That has one real consequence worth stating up front: if VYRA ever runs as
 * more than one API instance behind a load balancer, each instance enforces
 * its own limit independently — a client could get roughly N× the intended
 * budget across N instances. Fine for a single-instance deploy (which is what
 * this project runs today); the moment that changes, this needs a shared store
 * instead. Flagging it here rather than hiding it is the point.
 *
 * ALGORITHM: sliding-window log, not a fixed window or a token bucket.
 *   - A fixed window (e.g. "reset every :00") lets a client burst 2×maxPerWindow
 *     right across a window boundary.
 *   - A sliding window log keeps every hit's timestamp for a key and only
 *     counts the ones still inside `windowMs` of `now`. It costs a little more
 *     memory per key than a token bucket, but for auth/AI endpoints the key
 *     space (per-IP, per-route) is small enough that this doesn't matter, and
 *     it makes the exact "how many are we tracking" number an honest count
 *     rather than an approximation.
 *
 * MEMORY: keys for IPs that stop sending requests would otherwise accumulate
 * forever. A periodic sweep (on ~5 min cadence, piggy-backed on normal calls —
 * no extra timer) drops any key whose entries have all aged out.
 * =============================================================================
 */

export interface RateLimitResult {
  allowed: boolean;
  /** Requests left in the current window when `allowed` is true; 0 otherwise. */
  remaining: number;
  /** Seconds until the caller can retry. 0 when `allowed` is true. */
  retryAfterSec: number;
}

export class RateLimiter {
  private hits = new Map<string, number[]>(); // key -> hit timestamps (ms), ascending
  private lastSweep = Date.now();
  private readonly sweepIntervalMs = 5 * 60_000;

  /**
   * Records a hit for `key` and reports whether it's within
   * `maxPerWindow` hits per rolling `windowMs`.
   *
   * `key` should already encode everything that defines the bucket — caller,
   * IP, route — e.g. `auth:203.0.113.4` or `ai:203.0.113.4`. This function
   * does not know or care what the key means.
   */
  check(key: string, maxPerWindow: number, windowMs: number, now = Date.now()): RateLimitResult {
    this.maybeSweep(now, windowMs);

    const cutoff = now - windowMs;
    const timestamps = (this.hits.get(key) ?? []).filter((t) => t > cutoff);

    if (timestamps.length >= maxPerWindow) {
      this.hits.set(key, timestamps); // still store the trimmed array
      const oldest = timestamps[0]!;
      const retryAfterMs = oldest + windowMs - now;
      return { allowed: false, remaining: 0, retryAfterSec: Math.max(1, Math.ceil(retryAfterMs / 1000)) };
    }

    timestamps.push(now);
    this.hits.set(key, timestamps);
    return { allowed: true, remaining: maxPerWindow - timestamps.length, retryAfterSec: 0 };
  }

  /** Drops keys with no timestamps left inside any window we might see again. */
  private maybeSweep(now: number, windowMs: number): void {
    if (now - this.lastSweep < this.sweepIntervalMs) return;
    this.lastSweep = now;
    const cutoff = now - windowMs;
    for (const [key, timestamps] of this.hits) {
      const fresh = timestamps.filter((t) => t > cutoff);
      if (fresh.length === 0) this.hits.delete(key);
      else this.hits.set(key, fresh);
    }
  }
}

/** One process-wide limiter. See the memory note above for the multi-instance caveat. */
export const rateLimiter = new RateLimiter();

/**
 * Convenience wrapper matching the plain boolean signature originally
 * sketched for this module. Prefer `rateLimiter.check(...)` directly when you
 * need `retryAfterSec` for a 429's Retry-After header (server.ts does) — this
 * wrapper throws that value away.
 */
export function checkRateLimit(key: string, maxPerWindow: number, windowMs: number): boolean {
  return rateLimiter.check(key, maxPerWindow, windowMs).allowed;
}
