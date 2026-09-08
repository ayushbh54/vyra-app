/**
 * =============================================================================
 * MINIMAL HTTP ROUTER
 * =============================================================================
 * Built on node:http rather than Express, deliberately.
 *
 *   - Zero dependencies means zero dependency failures on demo day, and a
 *     cold-start measured in milliseconds on a free-tier host.
 *   - Everything Express gives us here is about 150 lines: routing, JSON body
 *     parsing, CORS, and an error boundary. Owning those 150 lines is cheaper
 *     than owning a dependency tree we did not read.
 *
 * If the project later needs Express middleware, the Handler signature below is
 * close enough that adapting is a mechanical change.
 * =============================================================================
 */

import { IncomingMessage, ServerResponse } from 'node:http';
import type { ApiErrorCode } from '@vyra/types';

export interface Ctx {
  req: IncomingMessage;
  res: ServerResponse;
  params: Record<string, string>;
  query: URLSearchParams;
  body: unknown;
  requestId: string;
  /** Set by the auth middleware. */
  userId?: string;
  ip: string;
}

export type Handler = (ctx: Ctx) => Promise<unknown> | unknown;

/** Thrown anywhere in a handler; the error boundary turns it into a clean response. */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: ApiErrorCode,
    message: string,
    readonly details?: unknown,
    /** Extra headers the error boundary should set on the response — e.g. Retry-After. */
    readonly headers?: Record<string, string>,
  ) {
    super(message);
    this.name = 'HttpError';
  }

  static badRequest(message: string, details?: unknown) {
    return new HttpError(400, 'VALIDATION_FAILED', message, details);
  }
  static unauthorized(message = 'Please sign in to continue.') {
    return new HttpError(401, 'UNAUTHENTICATED', message);
  }
  static forbidden(message = 'You do not have access to this.') {
    return new HttpError(403, 'FORBIDDEN', message);
  }
  static notFound(message = 'Not found.') {
    return new HttpError(404, 'NOT_FOUND', message);
  }
  static conflict(message: string) {
    return new HttpError(409, 'CONFLICT', message);
  }
  static consentRequired(message: string) {
    return new HttpError(403, 'CONSENT_REQUIRED', message);
  }
  /** `retryAfterSec`, when given, is surfaced to the client as a Retry-After header. */
  static rateLimited(message = 'Too many requests. Please slow down.', retryAfterSec?: number) {
    const headers = retryAfterSec !== undefined ? { 'Retry-After': String(retryAfterSec) } : undefined;
    return new HttpError(429, 'RATE_LIMITED', message, undefined, headers);
  }
}

interface Route {
  method: string;
  segments: string[];
  handler: Handler;
}

const MAX_BODY_BYTES = 8 * 1024 * 1024;   // 8 MB — food-scan images arrive as base64

export class Router {
  private routes: Route[] = [];
  private befores: Handler[] = [];

  constructor() {
    // Fail loudly at boot, not silently at request time. Without this, a
    // deploy that forgot ALLOWED_ORIGINS would quietly serve `*` in
    // production — a wildcard CORS policy is not a safe default to fall
    // back into, it's a config bug that should block the deploy.
    if (process.env.NODE_ENV === 'production' && !process.env.ALLOWED_ORIGINS) {
      throw new Error(
        'ALLOWED_ORIGINS must be set in production (comma-separated list of allowed ' +
        'origins, e.g. "https://app.vyra.fit,https://admin.vyra.fit"). Refusing to start ' +
        'with a wildcard CORS policy.',
      );
    }
  }

  use(fn: Handler) { this.befores.push(fn); return this; }

  get(path: string, h: Handler) { return this.add('GET', path, h); }
  post(path: string, h: Handler) { return this.add('POST', path, h); }
  patch(path: string, h: Handler) { return this.add('PATCH', path, h); }
  delete(path: string, h: Handler) { return this.add('DELETE', path, h); }

  private add(method: string, path: string, handler: Handler) {
    this.routes.push({ method, segments: path.split('/').filter(Boolean), handler });
    return this;
  }

  /** Matches ':param' segments and returns the extracted values. */
  private match(method: string, pathname: string): { route: Route; params: Record<string, string> } | null {
    const parts = pathname.split('/').filter(Boolean);
    for (const route of this.routes) {
      if (route.method !== method) continue;
      if (route.segments.length !== parts.length) continue;

      const params: Record<string, string> = {};
      let ok = true;
      for (let i = 0; i < route.segments.length; i++) {
        const seg = route.segments[i]!;
        if (seg.startsWith(':')) params[seg.slice(1)] = decodeURIComponent(parts[i]!);
        else if (seg !== parts[i]) { ok = false; break; }
      }
      if (ok) return { route, params };
    }
    return null;
  }

  handle = async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
    const requestId = randomId();
    const origin = req.headers.origin;

    // CORS. In production ALLOWED_ORIGINS is an explicit list — a wildcard with
    // credentials is both a security hole and rejected by browsers anyway.
    const allowed = (process.env.ALLOWED_ORIGINS ?? '*').split(',').map((s) => s.trim());
    const allowOrigin = allowed.includes('*') ? '*' : (origin && allowed.includes(origin) ? origin : '');
    if (allowOrigin) {
      res.setHeader('Access-Control-Allow-Origin', allowOrigin);
      res.setHeader('Vary', 'Origin');
    }
    res.setHeader('Access-Control-Allow-Headers', 'content-type, authorization, x-device-id');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');

    // Baseline hardening. This API serves JSON only, so the policy can be strict.
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-Request-Id', requestId);

    if (req.method === 'OPTIONS') { res.writeHead(204).end(); return; }

    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
    const found = this.match(req.method ?? 'GET', url.pathname);

    if (!found) {
      send(res, 404, {
        ok: false,
        error: { code: 'NOT_FOUND', message: `No route for ${req.method} ${url.pathname}`, requestId },
      });
      return;
    }

    const ctx: Ctx = {
      req, res,
      params: found.params,
      query: url.searchParams,
      body: undefined,
      requestId,
      ip: clientIp(req),
    };

    try {
      if (req.method !== 'GET' && req.method !== 'DELETE') {
        ctx.body = await readJsonBody(req);
      }

      for (const before of this.befores) {
        const early = await before(ctx);
        if (early !== undefined) { send(res, 200, { ok: true, data: early }); return; }
      }

      const data = await found.route.handler(ctx);
      if (res.writableEnded) return;              // handler responded itself
      send(res, 200, { ok: true, data: data ?? null });
    } catch (error) {
      if (error instanceof HttpError) {
        if (error.headers) {
          for (const [name, value] of Object.entries(error.headers)) res.setHeader(name, value);
        }
        send(res, error.status, {
          ok: false,
          error: { code: error.code, message: error.message, details: error.details, requestId },
        });
        return;
      }

      // Unexpected: log the detail, return none of it. Internal messages leak
      // table names, file paths and query fragments.
      console.error(`[${requestId}]`, error);
      send(res, 500, {
        ok: false,
        error: {
          code: 'INTERNAL',
          message: 'Something went wrong on our side. Please try again.',
          requestId,
        },
      });
    }
  };
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

function send(res: ServerResponse, status: number, payload: unknown): void {
  if (res.writableEnded) return;
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  });
  res.end(body);
}

function readJsonBody(req: IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;

    req.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        // Stop reading rather than buffering an unbounded upload into memory.
        reject(new HttpError(413, 'VALIDATION_FAILED', 'Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (chunks.length === 0) { resolve(undefined); return; }
      const raw = Buffer.concat(chunks).toString('utf8').trim();
      if (!raw) { resolve(undefined); return; }
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(HttpError.badRequest('Request body is not valid JSON.'));
      }
    });

    req.on('error', reject);
  });
}

function clientIp(req: IncomingMessage): string {
  // TRUSTED_PROXY_COUNT is the number of reverse proxies WE control that sit
  // in front of this process (e.g. 1 for a single load balancer). Anything
  // beyond that many hops in X-Forwarded-For was written by whoever made the
  // request, not by infrastructure we trust — so it must never be read.
  const trustedProxyCount = Number(process.env.TRUSTED_PROXY_COUNT ?? 0);

  if (trustedProxyCount > 0) {
    const fwd = req.headers['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) {
      // Chain convention: "client, proxy1, proxy2, ..." — each hop appends
      // itself to the right. The last `trustedProxyCount` entries were
      // appended by proxies we trust; the entry immediately before those is
      // the real client. If the header is shorter than the trusted proxy
      // count (misconfigured, or a client trying to fake extra depth), fall
      // through to the socket address rather than guessing.
      const parts = fwd.split(',').map((s) => s.trim()).filter(Boolean);
      const clientIndex = parts.length - 1 - trustedProxyCount;
      if (clientIndex >= 0) return parts[clientIndex]!;
    }
  }

  // Default (TRUSTED_PROXY_COUNT=0): X-Forwarded-For is fully attacker-
  // controlled with no proxy to vouch for it, so it is never read at all.
  // The socket address is the one value nobody but the actual connecting
  // peer — proxy or otherwise — can set.
  return req.socket.remoteAddress ?? 'unknown';
}

function randomId(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
}

// -----------------------------------------------------------------------------
// Validation helpers — small, explicit, and they name the field that failed
// -----------------------------------------------------------------------------

export function requireObject(body: unknown): Record<string, unknown> {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('Expected a JSON object.');
  }
  return body as Record<string, unknown>;
}

export function str(obj: Record<string, unknown>, key: string, opts: { max?: number } = {}): string {
  const v = obj[key];
  if (typeof v !== 'string' || v.trim() === '') {
    throw HttpError.badRequest(`"${key}" is required.`, { field: key });
  }
  if (opts.max && v.length > opts.max) {
    throw HttpError.badRequest(`"${key}" is too long (max ${opts.max}).`, { field: key });
  }
  return v.trim();
}

export function num(
  obj: Record<string, unknown>,
  key: string,
  range: { min: number; max: number },
): number {
  const v = Number(obj[key]);
  if (!Number.isFinite(v)) {
    throw HttpError.badRequest(`"${key}" must be a number.`, { field: key });
  }
  if (v < range.min || v > range.max) {
    throw HttpError.badRequest(
      `"${key}" must be between ${range.min} and ${range.max}.`,
      { field: key, min: range.min, max: range.max },
    );
  }
  return v;
}

export function optionalNum(
  obj: Record<string, unknown>,
  key: string,
  range: { min: number; max: number },
): number | undefined {
  if (obj[key] === undefined || obj[key] === null || obj[key] === '') return undefined;
  return num(obj, key, range);
}

export function oneOf<T extends string>(
  obj: Record<string, unknown>,
  key: string,
  allowed: readonly T[],
): T {
  const v = obj[key];
  if (typeof v !== 'string' || !allowed.includes(v as T)) {
    throw HttpError.badRequest(
      `"${key}" must be one of: ${allowed.join(', ')}.`,
      { field: key, allowed },
    );
  }
  return v as T;
}

export function bool(obj: Record<string, unknown>, key: string, fallback?: boolean): boolean {
  const v = obj[key];
  if (typeof v === 'boolean') return v;
  if (fallback !== undefined) return fallback;
  throw HttpError.badRequest(`"${key}" must be true or false.`, { field: key });
}

export function isoDate(obj: Record<string, unknown>, key: string): string {
  const v = str(obj, key);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) {
    throw HttpError.badRequest(`"${key}" must be a date like 2026-09-02.`, { field: key });
  }
  return v;
}
